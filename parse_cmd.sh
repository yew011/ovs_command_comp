#!/bin/bash

# set a big enough column size.
stty cols 120

APPCTL_ALL_CMDS="`man -P cat ovs-vswitchd | cut -c8- | sed -n \
                 '/^[a-z]\+\/[a-z]\+.*$/p'`"
APPCTL_ALL_SUBCMDS=(`man -P cat ovs-vswitchd | cut -c8- | sed -n \
                     '/^[a-z]\+\/[a-z]\+.*$/p' | cut -d ' ' -f1 | uniq`)

N_CMDS=${#APPCTL_ALL_SUBCMDS[@]}
echo "- Number of appctl commands: $N_CMDS"

# COMPOSING LOGIC #

# declare the ARG_CHAIN_*.
# it is composed of the "arg at previous level" at index 0
# and followed by the "args at current level".
for i in `seq 1 256`
do
    declare -a ARG_CHAIN_$i
done

N_ARGS=0
CUR_IN_ARG_CHAIN=0
PREV_IN_ARG_CHAIN=0
# longest argument in SUBCMD_CHAIN_*.
SUBCMD_CHAIN_LONGEST_IDX=0

# if $prev is in one of the ARG_CHAIN_*[0], returns the
# index to ARG_CHAIN_$i.
find_prev_in_arg_chain() {
    local prev=$1
    local n_args=$N_ARGS
    PREV_IN_ARG_CHAIN=0

    for i in `seq 1 $n_args`
    do
	eval local prev_arg=\${ARG_CHAIN_$i[0]}
	if [ "$prev_arg" = "$prev" ]
	then
	    PREV_IN_ARG_CHAIN=$i
	    break
	fi
    done
}

# if $cur is already in the ARG_CHAIN_$prev_in_arg[0], returns the
# index in ARG_CHAIN_${prev_in_arg}[0].
find_cur_in_arg_chain() {
    local cur=$1
    local prev_in_arg=$PREV_IN_ARG_CHAIN
    eval local args=\(\${ARG_CHAIN_${prev_in_arg}[@]:1}\)
    local arg=""
    CUR_IN_ARG_CHAIN=0

    for arg in "${args[@]}"
    do
	if [ "$cur" = "$arg" ]
	then
	    CUR_IN_ARG_CHAIN=$i
	    break
	fi
    done
}

# return the last idx of the longest SUBCMD_CHAIN_* in
# SUBCMD_CHAIN_LONGEST_IDX.
subcmd_chain_longest_idx() {
    local n_chains=$N_CHAINS
    local longest=0

    for i in `seq 1 $n_chains`
    do
	eval local len=\${#SUBCMD_CHAIN_$i[@]}
	if [ "$len" -gt "$longest" ]
	then
	    longest=$len
	fi
    done

    SUBCMD_CHAIN_LONGEST_IDX=`expr $longest - 1`
}

# given the level in $cur_level, generates the ARG_CHAIN_* for this
# level of completion.
subcmd_get_args() {
    local cur_level=$1
    local prev_level=`expr $1 - 1`
    local n_chains=$N_CHAINS
    local arg_idx=0

    for i in `seq 1 $n_chains`
    do
	eval local cur_arg=\${SUBCMD_CHAIN_$i[$cur_level]}
	eval local prev_arg=\${SUBCMD_CHAIN_$i[$prev_level]}

	if [ "$cur_arg" = "" ]
	then
	    continue
	fi

	find_prev_in_arg_chain $prev_arg

	find_cur_in_arg_chain $cur_arg

	if [ "$CUR_IN_ARG_CHAIN" -gt "0" ]
	then
	    continue
	fi

	# prev_arg not in the ARG_CHAIN_*, create a new ARG_CHAIN_*.
	if [ "$PREV_IN_ARG_CHAIN" = "0" ]
	then
	    ((arg_idx++))
	    ((N_ARGS++))
	    eval ARG_CHAIN_${arg_idx}+=\($prev_arg\)
	    eval ARG_CHAIN_${arg_idx}+=\($cur_arg\)
	else
	    eval ARG_CHAIN_${PREV_IN_ARG_CHAIN}+=\($cur_arg\)
	fi
    done
}

clear_args() {
    for i in `seq 1 256`
    do
	eval ARG_CHAIN_$i=\(\)
    done
    N_ARGS=0
}

# write the SUBCMD_CHAIN_* into file as a compgen function.
write_compgen() {
    local arg_idx=0
    local n_chains=$N_CHAINS
    local subcmd=${SUBCMD_CHAIN_1[0]}

    subcmd_chain_longest_idx

    echo "_${subcmd}_complete() {
  local cur prev

  COMPREPLY=()
  cur=\${COMP_WORDS[COMP_CWORD]}
  prev=\${COMP_WORDS[COMP_CWORD-1]}
" >> appctl_compgen.sh

    for cwd in `seq 1 $SUBCMD_CHAIN_LONGEST_IDX`
    do
	subcmd_get_args $cwd
	local level=`expr $cwd + 1`

	echo "  if [ \$COMP_CWORD -eq $level ]; then
    case \"\$prev\" in" >> appctl_compgen.sh
	for j in `seq 1 $N_ARGS`
	do
	    eval local prev_arg=\${ARG_CHAIN_$j[0]}
	    eval local cur_args=\(\${ARG_CHAIN_$j[@]:1}\)

	    echo "      \"$prev_arg\")
        COMPREPLY=( \$(compgen -W \"${cur_args[*]}\" -- \$cur) )
        ;;" >> appctl_compgen.sh
	done
	echo "    esac
  fi" >> appctl_compgen.sh
	clear_args
    done

    echo "
  return 0
}
" >> appctl_compgen.sh
}

# PARSING LOGIC #

# function that appends the argument to subcmd chains
# from $start to $end.
append_chains() {
    local start=$1
    local end=$2
    local arg=$3

    for i in `seq $start $end`
    do
	eval SUBCMD_CHAIN_$i+=\( $arg \)
    done
}

# make $n_copy copies of the current SUBCMD_CHAIN_*.
make_subcmd_chains_copy() {
    local start_idx=$1
    local end_idx=`expr $start_idx + $2 - 1`
    local n_copy=$3
    local idx=$N_CHAINS

    for i in `seq 1 $n_copy`
    do
	for j in `seq $start_idx $end_idx`
	do
	   ((idx++))
	   eval SUBCMD_CHAIN_$idx=\( \${SUBCMD_CHAIN_$j[*]} \)
	done
    done
    N_CHAINS=$idx
}

# check the format of options and expain the SUBCMD_CHAIN_*
# to include all combinations.
expand_chains_options() {
    local opt="`sed -n 's/\[\(.*\)\]/\1/p' <<< $1`"

    # if there are multiple options, extract the options and
    # store them in an array.
    local arg_idx=0
    local n_copy=0
    local start=$start_idx
    local step=`expr $N_CHAINS - $start + 1`
    local next=0

    IFS='|' read -a opts <<< "$opt"
    n_copy=${#opts[@]}
    make_subcmd_chains_copy $start $step $n_copy

    for i in "${opts[@]}"
    do
	next=`expr $start + $step`
	((start++))
	append_chains $start $next $i
	start=$next
    done
}

# function that will clear all subcmd chains.
reset_subcmd_chains() {
    for i in `seq 1 256`
    do
	eval SUBCMD_CHAIN_$i=\(\)
    done
    N_CHAINS=0
}

# given the argument array, conduct the following operation:
# 1. if the current cmd is different from the previou cmd,
#    commit the previous subcmd chain to a compgen function.
# 2. generate the subcmd chains which includes all combinations
#    of the ${args[*]}.
update_subcmd_chains() {
    eval local args=\( \${$1[@]} \)
    local cur_subcmd=${args[0]}
    local start_idx=0

    if [ "$cur_subcmd" != "$LAST_SUBCMD" ]
    then
	write_compgen
	reset_subcmd_chains $N_CHAINS
	LAST_SUBCMD="$cur_subcmd"
    fi

    ((N_CHAINS++))
    start_idx=$N_CHAINS

    for i in ${args[@]}
    do
	case "$i" in
	    \[*\])
                expand_chains_options $i $start_idx
		;;
	    *)
	        append_chains $start_idx $N_CHAINS $i
		;;
	esac
    done
}

LAST_SUBCMD=""
N_CHAINS=0
# declare the global SUBCMD_CHAIN_* for use.
for i in `seq 1 256`
do
    declare -a SUBCMD_CHAIN_$i
done

# the main loop.
rm appctl_compgen.sh
touch appctl_compgen.sh
echo "#!/bin/bash" >> appctl_compgen.sh

echo "$APPCTL_ALL_CMDS" | while read -r line
do
    # reprocess the arguments, especially combine the
    # [option1 | option2] format into [option1|option2]
    declare -a args
    arg_idx=0
    IFS=' ' read -a words <<< "$line"
    for i in "${words[@]}"
    do
	case "$i" in
	    \[*\])
	        args[$arg_idx]=$i
		((arg_idx++))
		;;
	    \[*)
	        args[$arg_idx]=$i
		;;
	    *\])
	        args[$arg_idx]=${args[$arg_idx]}$i
		((arg_idx++))
		;;
	    \|)
	        args[$arg_idx]=${args[$arg_idx]}$i
		;;
	    *)
	        args[$arg_idx]=$i
		((arg_idx++))
		;;
	esac
    done

    # update the subcmd chains.
    update_subcmd_chains args
    unset args
done

# write the last subcmd.
dummy=()
update_subcmd_chains dummy

# finish the main complete function.
echo "
_appctl_complete()
{
  local cur subcmd

  COMPREPLY=()
  cur=\${COMP_WORDS[COMP_CWORD]}

  if [ \$COMP_CWORD -eq 1 ]; then
    COMPREPLY=( \$(compgen -W \"${APPCTL_ALL_SUBCMDS[*]}\" -- \$cur) )
  else
    subcmd=\${COMP_WORDS[1]}
    case \"\$subcmd\" in" >> appctl_compgen.sh

for subcmd in "${APPCTL_ALL_SUBCMDS[@]}"
do
    echo "      \"$subcmd\")
        _${subcmd}_complete
        ;;" >> appctl_compgen.sh
done

echo "
    esac
  fi

  return 0
}

complete -F _appctl_complete ovs-appctl
" >> appctl_compgen.sh