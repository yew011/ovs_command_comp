#!/bin/bash

# set a big enough column size.
stty cols 120

APPCTL_ALL_CMDS="`man -P cat ovs-vswitchd | cut -c8- | sed -n \
                 '/^[a-z]\+\/[a-z]\+.*$/p'`"
APPCTL_ALL_SUBCMDS=(`man -P cat ovs-vswitchd | cut -c8- | sed -n \
                     '/^[a-z]\+\/[a-z]\+.*$/p' | cut -d ' ' -f1 | uniq`)

N_CMDS=${#APPCTL_ALL_SUBCMDS[@]}
echo "- Number of appctl commands: $N_CMDS"

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

# write the SUBCMD_CHAIN_* into file as a compgen function.
write_compgen() {
    local n_chains=$1

    # TODO, compose the compgen function.
    for i in `seq 1 $n_chains`
    do
	eval echo \${SUBCMD_CHAIN_$i[*]}
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
	write_compgen $N_CHAINS $LAST_SUBCMD
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


#
_appctl_complete()
{
  local cur prev

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  if [ $COMP_CWORD -eq 1 ]; then
    COMPREPLY=( $(compgen -W "$subcmds_uniq" -- $cur) )
  fi

  return 0
}

complete -F _appctl_complete ovs-appctl