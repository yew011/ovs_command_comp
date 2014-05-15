#!/bin/bash

# A bash command completion script for ovs-appctl.

# Keywords
# ========
#
# Expandable keywords.
KWORDS=(bridge port interface dpname br_flow odp_flow)
# Arguments after keyword expansion.
ARGS=()
# Output to the compgen.
COMP_WORDLIST=
# Index of the input argument, that, COMP_WORDLIST is targeting.
COMP_IDX=-1
# Keyword expanded.
KWORD_EXPANDED=
# Printf enabler.
PRINTF_ENABLE=
# Printf keyword expansion string once.
PRINTF_KWORD_EXPAND_ONCE=

# Command Extraction
# ==================
#
# This function parses the ovs-appctl and ovs-vswitchd manpage,
# for all ovs-appctl sub-commands and generates three files.
#
# 1. File containing all full subcommands.
#    .__ovs_appctl_subcommands.comp
# 2. File containing all argument combinations of all sub-commands.
#    .__ovs_appctl_subcmds.comp
# 3. File containing all options.
#    .__ovs_appctl_opts.comp
#
# This function assumes the ovs-appctl sub-commands will always have
# 'ovs-appctl module/function ...' format.
#
# Note, optional argument will have a leading *.
extract_subcmd_opts() {
    local line name arg opts_tmp nlines opt
    # Tricks the console, so subcommands are all in one line.
    local cur_cols="`tput cols`"
    stty cols 1024

    rm .__ovs_appctl_*.comp 1>&2 2>/dev/null
    rm .__ovs_appctl_*.tmp 1>&2 2>/dev/null
    for name in opts subcmds subcommands; do
	touch .__ovs_appctl_$name.comp
    done

    man -P cat ovs-appctl | cut -c8- | sed -n \
	'/^\-\-.*$/p' | cut -d ' ' -f1 | uniq > .__ovs_appctl_opts.comp
    man -P cat ovs-vswitchd | cut -c8- | sed -n \
	'/^[a-z]\+\/[a-z]\+.*$/p' | tr -s ' ' | sed 's/ | /|/g' \
	> .__ovs_appctl_subcommands.comp

    # Finds all combinations of each sub-command.
    touch .__ovs_appctl_subcmds.tmp
    while read line; do
	printf "\n" > .__ovs_appctl_subcmds.tmp
	for arg in $line; do
            # If it is an optional argument, expands the existing
            # combinations.
	    if [ ! -z "`grep -- \"\[*\]\" <<< \"$arg\"`" ]; then
		opts_tmp="`sed -n 's/^\[\(.*\)\]$/\1/p' <<< $arg`"
		IFS='|' read -a opts_arr_tmp <<< "$opts_tmp"

		nlines=`wc -l .__ovs_appctl_subcmds.tmp | cut -d ' ' -f1`
		for opt in "${opts_arr_tmp[@]}"; do
		    head -$nlines .__ovs_appctl_subcmds.tmp | \
			sed "s@\$@ *${opt}@g" >> .__ovs_appctl_subcmds.tmp
		done
	    else
                # Else just appends the argument to the end of each
                # combination.
		sed "s@\$@ ${arg}@g" -i .__ovs_appctl_subcmds.tmp
	    fi
	done
        # Appends the combinations to .__ovs_appctl_subcmds.comp
	cat .__ovs_appctl_subcmds.tmp >> .__ovs_appctl_subcmds.comp
    done < .__ovs_appctl_subcommands.comp

    sed -i 's/^ //g' .__ovs_appctl_subcmds.comp
    rm .__ovs_appctl_*.tmp* 1>&2 2>/dev/null
    eval stty cols $cur_cols
}

# Helpers
# =======
#
# Converts the argument (e.g. bridge/port/interface name) to the corresponding
# keyword.
arg_to_kword() {
    local word
    local var="$1"

    # find all args
    for word in ${KWORDS[@]}; do
	> .___arg2kword.tmp
	case "$word" in
            bridge|port|interface)
		ovs-vsctl --columns=name list $word | tr -d ' ' \
		    | cut -d ':' -f2 | sed -e 's/^"//' -e 's/"$//' \
		    | grep "$var" > .___arg2kword.tmp
		if [ -s .___arg2kword.tmp ]; then
		    # Abbrev of bridge/port/interface.
		    echo "bpi"
		    return
		fi
		;;
            dpname)
		if [[ $var =~ ovs-system|ovs-netdev ]]; then
		    echo "dpname"
		    return
		fi
		;;
	    br_flow)
		if [[ $var =~ "in_port=" ]]; then
		    echo "br_flow"
		    return
		fi
		;;
	    odp_flow)
		if [[ $var =~ "in_port(" ]]; then
		    echo "odp_flow"
		    return
		fi
		;;
	    *)
		continue
		;;
	esac
    done
    echo "$var"
}

# Expands the keyword to the corresponding instance names.
kword_to_args() {
    local word trimmed_word optional is_kword
    local vars=($@)
    local args=()

    # find all args
    for word in ${vars[@]}; do
	optional=
	is_kword=

	# Cuts the first character is the argument is optional.
	if [ "${word:0:1}" == "*" ]; then
	    optional=" (optional)"
	    trimmed_word="${word:1}"
	else
	    trimmed_word="${word}"
	fi

	case "${trimmed_word}" in
	    bridge|port|interface)
		args=($(ovs-vsctl --columns=name list $trimmed_word \
		    | tr -d ' ' | cut -d ':' -f2 \
		    | sed -e 's/^"//' -e 's/"$//'))
		is_kword="kword"
		;;
	    dpname)
		args=(ovs-system ovs-netdev)
		is_kword="kword"
		;;
	    *)
		args=($trimmed_word)
		;;
	esac
	ARGS+=( "${args[@]}" )
	if [ -n "$is_kword" ] && [ -n "$PRINTF_ENABLE" ]; then
	    printf "\n"
	    if [ -z "$PRINTF_KWORD_EXPAND_ONCE" ]; then
		PRINTF_KWORD_EXPAND_ONCE="once"
		printf "Argument expansion:\n"
	    fi
	    printf "    argument keyword%s \"%s\" is expanded to: " "$optional" \
		$trimmed_word
	    printf "%s " ${args[@]}
	fi
    done
}

# Parser
# ======
#
# This script takes the current command line arguments as input,
# find the command format and returns the possible completions.
ovs_appctl_comp_helper() {
    local cmd_line_so_far=($@)
    local iter=()
    local subcmd kword args no_opt comp_wordlist line arg
    local j=-1

    # Extracts the subcmds only when needed.
    if [ ! -e .__ovs_appctl_subcommands.comp ] \
	|| [ ! -e .__ovs_appctl_subcmds.comp ] \
	|| [ ! -e .__ovs_appctl_opts.comp ]; then
	extract_subcmd_opts
    fi

    KWORD_EXPANDED=
    PRINTF_KWORD_EXPAND_ONCE=
    ARGS=()

    # Tries locating the sub-command.
    for i in "${!cmd_line_so_far[@]}"; do
	if [ $i -le $j ]; then continue; fi
	j=$i
	if [ `sed -n '/^--.*$/p' <<< "${cmd_line_so_far[j]}"` ]; then
            if [ "=" = "${cmd_line_so_far[j+1]}" ]; then
		((j++))
		if [ -n "${cmd_line_so_far[j+1]}" ]; then
		    no_opt="no_opt"
		    ((j++))
		else
		    KWORD_EXPANDED="true"
		    COMP_WORDLIST="`grep -- "${cmd_line_so_far[j-1]}" \
                        __ovs_appctl_opts.comp | cut -d '=' -f2`"
		    if [ -n "$PRINTF_ENABLE" ]; then
			printf "\n"
			printf "Option takes in: %s" $COMP_WORDLIST
		    fi
		    return
		fi
            fi
	    continue
	fi
	subcmd="${cmd_line_so_far[i]}"
	break
    done

    # If subcommand is not found, should present all available completions.
    # Otherwise, start parsing the input arguments.
    if [ -z "$subcmd" ]; then
        # If no comment, all options/subcmds are available.
	if [ -z "$no_opt" ]; then
	    comp_wordlist="`cat .__ovs_appctl_*.comp | cut -d ' ' -f1 | \
                        sed 's/=.*$/=/'`"
	else
	    comp_wordlist="`cat .__ovs_appctl_subcmds.comp | cut -d ' ' -f1`"
	fi
    else
	if [ -n "$PRINTF_ENABLE" ]; then
	    printf "\n"
	    printf "Command format:\n"
	    while read -r line
	    do
		printf "    %s\n" "$line"
	    done <<< "`awk -v opt=$subcmd '$1 == opt {print $0}' \
                       .__ovs_appctl_subcommands.comp`"
	fi

	KWORD_EXPANDED="true"
	cp .__ovs_appctl_subcmds.comp .___tmp.tmp

        # $j stores the index of the subcmd in cmd_line_so_far.
	# Now, starts from the first argument, narrows down the
	# subcommand format combinations.
	for arg in "${cmd_line_so_far[@]:$j}"; do
	    > .___tmp.tmp.tmp

	    kword=$(arg_to_kword $arg)
	    if [ "$kword" = "bpi" ]; then
		iter=(bridge port interface)
	    else
		iter=($kword)
	    fi

	    for word in ${iter[@]}; do
		awk -v opt=$word '$1 == opt {$1=""; print $0}' \
		    .___tmp.tmp | cut -c2- >> .___tmp.tmp.tmp
		awk -v opt=*$word '$1 == opt {$1=""; print $0}' \
		    .___tmp.tmp | cut -c2- >> .___tmp.tmp.tmp
	    done
	    cat .___tmp.tmp.tmp > .___tmp.tmp
	done

	kword_to_args `awk '{print $1}' .___tmp.tmp | sort | uniq`
	comp_wordlist="${ARGS[@]}"
    fi
    COMP_WORDLIST="$comp_wordlist"
}

export LC_ALL=C

# Compgen
# =======
#
# The compgen function.
_ovs_appctl_complete() {
  local cur prev

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  # Do not print anything at first [TAB] execution.
  if [ "$COMP_TYPE" -eq "9" ]; then
      PRINTF_ENABLE=""
  else
      PRINTF_ENABLE="enabled"
  fi

  # Important to skip unwanted printf to stdout.
  if [ -z "$cur" ] || [ $COMP_CWORD -ne $COMP_IDX ]; then
      ovs_appctl_comp_helper ${COMP_WORDS[@]:1:COMP_CWORD-1}
      COMP_IDX=$COMP_CWORD
  fi

  # If there is only one expanded keyword, and the keyword expands to only
  # one instance name, the completion will fill in the name automatically.
  # This caused a confusing display in the output (i.e. a new line with only
  # the name).  To fix this, we will print a fake comand line.
  # Otherwise, prints the help message to separate completions.
  if [ -n "$KWORD_EXPANDED" ] \
      && [ "`echo $COMP_WORDLIST | tr ' ' '\n' | wc -l`" -le "1" ] \
      && [ -n "$PRINTF_ENABLE" ] ; then
      printf "\n$USER@$HOSTNAME:$PWD#"
      printf -- ' %s' "${COMP_WORDS[@]}"
  elif [ -n "$PRINTF_ENABLE" ]; then
      printf "\n\n"
      printf "Available completions:\n"
  fi

  COMPREPLY=( $(compgen -W "`echo $COMP_WORDLIST | tr ' ' '\n' | sort \
                             | uniq`" -- $cur) )

  return 0
}

complete -F _ovs_appctl_complete ovs-appctl