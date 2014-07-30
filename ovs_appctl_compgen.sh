#!/bin/bash
#
# A bash command completion script for ovs-appctl.
#
# Keywords
# ========
#
#
#
# Expandable keywords.
_KWORDS=(bridge port interface dpname dp)
# Printf enabler.
_PRINTF_ENABLE=
# Bash prompt.
_BASH_PROMPT=
# Target in the current completion.
_APPCTL_TARGET="ovs-vswitchd"
# Output to the compgen.
_APPCTL_COMP_WORDLIST=



# Command Extraction
# ==================
#
#
#
# Extracts all subcommands of daemon.
# Sub-commands not following the <module>/<action> rule will not be
# extracted (e.g. exit).  Luckily, for now, 'exit' is the only one.
# So, add it to output manually.
extract_subcmds() {
    local daemon=$_APPCTL_TARGET
    local subcmds

    subcmds="$(MANWIDTH=2048 man -P cat $daemon | cut -c8- | sed -n \
	'/^[a-z-]\+\/[a-z-]\+.*$/p' | tr -s ' ' | sed 's/ | /|/g' \
	| cut -f1 -d ' ')"

    echo "$subcmds exit"
}

# Extracts all options of ovs-appctl.
extract_options() {
    local options

    options="$(MANWIDTH=2048 man -P cat ovs-appctl | cut -c8- | sed -n \
              '/^\-\-.*$/p' | cut -d ' ' -f1 | cut -d '=' -f1 | sort | uniq)"

    echo "$options"
}

# Extracts all ovs* commands as possible daemons.
# The daemon's manpage must contains the "RUNTIME MANAGEMENT COMMANDS"
# string.
extract_daemons() {
    local daemons daemon

    daemons="$(compgen -c ovs | sort | uniq)"
    # If no change of daemons, use the cache.
    # Else, recalculate everything.
    if [ "$_APPCTL_ALL_DAEMONS" != "$daemons" ]; then
	_APPCTL_TARGET_DAEMONS=()
	_APPCTL_ALL_DAEMONS="$daemons"
	for daemon in `compgen -c ovs`; do
	    local stderr_workaround

	    stderr_workaround="$(MANWIDTH=2048 man -P cat $daemon 2>/dev/null)"
	    if [ -n "`grep -- "^RUNTIME MANAGEMENT COMMANDS" <<< \
                 "$stderr_workaround"`" ]; then
		_APPCTL_TARGET_DAEMONS+=($daemon)
	    fi
	done
    fi
}



# Combination Discovery
# =====================
#
#
#
# Given the subcommand formats, finds and returns all combinations.
subcmd_find_combinations() {
    local formats="$@"
    local line combinations

    while read line; do
	local arg
	local combinations_new=

	for arg in $line; do
            # If it is an optional argument, expands the existing
            # combinations.
	    if [ ! -z "`grep -- \"\[*\]\" <<< \"$arg\"`" ]; then
		local opt_arg="`sed -n 's/^\[\(.*\)\]$/\1/p' <<< $arg`"
		local opt_args=()
		local opt nlines

		IFS='|' read -a opt_args <<< "$opt_arg"
		nlines=`wc -l <<< "$combinations_new"`
		for opt in "${opt_args[@]}"; do
		    local combinations_tmp=

		    combinations_tmp="$(head -$nlines <<< "$combinations_new" | \
			sed "s@\$@ *${opt}@g")"
		    combinations_new="$(printf "%s\n%s\n" "$combinations_new" \
                                        "$combinations_tmp")"
		done
	    else
                # Else just appends the argument to the end of each
                # combination.
		combinations_new="$(sed "s@\$@ ${arg}@g" <<< \
                                    "$combinations_new")"
	    fi
	done
	combinations="$(printf "%s\n%s\n" "$combinations" "$combinations_new")"
    done <<< "$formats"

    echo "`sed 's/^ //g' <<< "$combinations"`"
}



# Helper
# ======
#
#
#
# Prints the input to stderr.  $_PRINTF_ENABLE must be filled.
printf_stderr() {
    local stderr_out="$@"

    if [ -n "$_PRINTF_ENABLE" ]; then
	printf "\n$stderr_out" 1>&2
    fi
}

# Extracts the bash prompt PS1, output it with the input argument
# via 'printf_stderr'.
#
# Idea inspired by:
# http://stackoverflow.com/questions/10060500/bash-how-to-evaluate-ps1-ps2
extract_bash_prompt() {
    if [ -z "$_BASH_PROMPT" ]; then
    _BASH_PROMPT="$(echo want_bash_prompt_PS1 | bash -i 2>&1 \
	| grep want_bash_prompt_PS1| head -1 | sed 's/ want_bash_prompt_PS1//g')"
    fi
}



# Keyword Conversion
# ==================
#
#
#
# All completion functions.
complete_bridge () {
    local result

    result=$(ovs-vsctl list-br | grep -- "^$1")

    echo  "${result}"
}

complete_port () {
    local ports result
    local all_ports

    all_ports=$(ovs-vsctl --format=table \
                          --no-headings \
                          --columns=name \
                          list Port)
    ports=$(printf "$all_ports" | sort | tr -d '" ' | uniq -u)
    result=$(grep -- "^$1" <<< "$ports")

    echo "${result}"
}

complete_iface () {
    local bridge bridges result

    bridges=$(ovs-vsctl list-br)
    for bridge in $bridges; do
	local ifaces

	ifaces=$(ovs-vsctl list-ifaces "${bridge}")
	result="${result} ${ifaces}"
    done

    echo "${result}"
}

complete_dp () {
    local dps result

    dps=$(ovs-dpctl dump-dps | cut -d '@' -f2)
    result=$(grep -- "^$1" <<< "$dps")

    echo "$result"
}

# Converts the argument (e.g. bridge/port/interface name) to the corresponding
# keyword.
arg_to_kword() {
    local arg="$1"
    local possible_kwords=($2)
    local kword match

    # If the to-be-completed argument is an option,
    # echo it back directly.
    if [[ $arg =~ ^- ]]; then
	echo "$arg"
	return
    fi

    for kword in ${possible_kwords[@]}; do
	match=

	case "$kword" in
            bridge)
		match="$(complete_bridge "$arg")"
		;;
	    port)
		match="$(complete_port "$arg")"
		;;
	    interface)
		match="$(complete_iface "$arg")"
		;;
            dpname|dp)
		match="$(complete_dp "$arg")"
		;;
	    remote)
		match="$(complete_remote "$arg")"
		;;
	    *)
		continue
		;;
	esac

	if [ -n "$match" ]; then
	    echo "$kword"
	    return
	fi
    done

    # If there is only on possible kword and it is not a kword,
    # just assume the user input it.
    if [ "${#possible_kwords[@]}" -eq "1" ]; then
	echo "$possible_kwords"
	return
    fi

    echo "NOMATCH"
}

# Expands the keyword to the corresponding instance names.
kword_to_args() {
    local possible_kwords=($@)
    local args=()
    local kword

    for kword in ${possible_kwords[@]}; do
	local trimmed_kword=
	local optional=
	local match=

	# Cuts the first character is the argument is optional.
	if [ "${kword:0:1}" == "*" ]; then
	    optional=" (optional)"
	    trimmed_kword="${kword:1}"
	else
	    trimmed_kword="${kword}"
	fi

	case "${trimmed_kword}" in
            bridge)
		match="$(complete_bridge "")"
		;;
	    port)
		match="$(complete_port "")"
		;;
	    interface)
		match="$(complete_iface "")"
		;;
            dpname|dp)
		match="$(complete_dp "")"
		;;
	    remote)
		match="$(complete_remote "")"
		;;
	    -*)
		# Treats option as kword as well.
		match="$trimmed_kword"
		;;
	    *)
		match=($trimmed_kword)
		;;
	esac
	args+=( $match )
	if [ -n "$_PRINTF_ENABLE" ]; then
	    local output_stderr=

	    if [ -z "$printf_expand_once" ]; then
		printf_expand_once="once"
		printf -v output_stderr "\nArgument expansion:\n"
	    fi
	    printf -v output_stderr "$output_stderr     argument keyword%s \
\"%s\" is expanded to: %s " "$optional" "$trimmed_kword" "$match"

	    printf_stderr "$output_stderr"
	fi
    done

    echo "${args[@]}"
}




# Parse and Compgen
# =================
#
#
#
# This function takes the current command line arguments as input,
# find the command format and returns the possible completions.
parse_and_compgen() {
    local subcmd_line=($@)
    local subcmd=${subcmd_line[0]}
    local daemon=$_APPCTL_TARGET
    local subcmd_combinations subcmd_format arg
    local comp_wordlist=""

    # Extracts the subcommand format.
    subcmd_format="$(MANWIDTH=2048 man -P cat $daemon | cut -c8- | sed -n \
	    '/^[a-z-]\+\/[a-z-]\+.*$/p' | tr -s ' ' | sed 's/ | /|/g' \
	    | awk -v opt=$subcmd '$1 == opt {print $0}')"
    if [ -z "$subcmd_format" ]; then
	subcmd_format="$subcmd"
    fi

    # Prints subcommand format.
    printf_stderr "`printf "\nCommand format:\n%s" "$subcmd_format"`"

    # Finds all subcmd combinations.
    subcmd_combinations="$(subcmd_find_combinations "$subcmd_format")"

    # Now, starts from the first argument, narrows down the
    # subcommand format combinations.
    for arg in "${subcmd_line[@]}"; do
	local kword narrow_1 narrow_2 narrow

	if [ "$arg" == "$subcmd" ]; then
	    kword="$subcmd"
	else
	    local possible_kwords

	    possible_kwords="$(echo "$subcmd_combinations" | awk '{print $1}' \
                               | sort | uniq)"
	    kword="$(arg_to_kword "$arg" "$possible_kwords")"
	    if [ "$kword" == "NOMATCH" ]; then
		return
	    fi
	fi

	narrow_1="$(awk -v opt=$kword '$1 == opt {$1=""; print $0}' \
                    <<< "$subcmd_combinations" | cut -c2-)"
	narrow_2="$(awk -v opt=*$kword '$1 == opt {$1=""; print $0}' \
                    <<< "`echo "$subcmd_combinations"`" | cut -c2-)"
   	subcmd_combinations="`printf "%s\n%s" "$narrow_1" "$narrow_2" `"
    done

    comp_wordlist="$(kword_to_args `awk '{print $1}' <<< "$subcmd_combinations" \
                                    | sort | uniq`)"

    echo "$comp_wordlist"
}



# Compgen Helper
# ==============
#
#
#
# Takes the current command line arguments and returns the possible
# completions.
#
# At beginning, the options are checked and completed.  The function
# looks for the --target option which gives the target daemon name.
# If it is not provided, by default, 'ovs-vswitchd' is used.
#
# Then, tries to locate and complete the subcommand.  If the subcommand
# is provided, the following arguments are passed to the 'parse_and_compgen'
# function to figure out the corresponding completion of the subcommand.
#
# Returns the completion arguments on success.
ovs_appctl_comp_helper() {
    local cmd_line_so_far=($@)
    local appctl_target_daemons="${_APPCTL_TARGET_DAEMONS[@]}"
    local comp_wordlist appctl_subcmd i
    local j=-1

    for i in "${!cmd_line_so_far[@]}"; do
	if [ $i -le $j ]; then continue; fi
	j=$i
	if [ `sed -n '/^--.*$/p' <<< ${cmd_line_so_far[i]}` ]; then
	    # If --target is found, locate the target daemon.
	    # Else, it is an option command, fill the comp_wordlist with
	    # all options.
	    if [ "${cmd_line_so_far[i]}" == "--target" ]; then
		if [ -n "${cmd_line_so_far[j+1]}" ]; then
		    local daemon

		    for daemon in ${appctl_target_daemons[@]}; do
			# Greps "$daemon" in argument, since the argument may
			# be the path to the pid file.
			if [ `grep -- "$daemon" <<< \
                             "${cmd_line_so_far[j+1]}"` ]; then
			    _APPCTL_TARGET="$daemon"
			    ((j++))
			    break
			fi
		    done
		    continue
		else
		    comp_wordlist="$appctl_target_daemons"
		    break
		fi
	    else
		comp_wordlist="$(extract_options)"
		break
	    fi
	fi
	# Takes the first non-option argument as subcmd.
	appctl_subcmd="${cmd_line_so_far[i]}"
	break
    done

    if [ -z "$comp_wordlist" ]; then
        # If the subcommand is not found, provides all subcmds.
        # Else parses the current arguments and finds the possible completions.
	if [ -z "$appctl_subcmd" ]; then
	    comp_wordlist="$(extract_subcmds) $(extract_options)"
	else
            # $j stores the index of the subcmd in cmd_line_so_far.
	    comp_wordlist="$(parse_and_compgen "${cmd_line_so_far[@]:$j}")"
	fi
    fi

    echo "$comp_wordlist"
}



export LC_ALL=C

# Compgen
# =======
#
#
#
# The compgen function.
_ovs_appctl_complete() {
  local cur prev

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  # Do not print anything at first [TAB] execution.
  if [ "$COMP_TYPE" -eq "9" ]; then
      _PRINTF_ENABLE=""
  else
      _PRINTF_ENABLE="enabled"
  fi

  # Checks for any change of daemons.  If recalculation needed, the execution
  # may take several seconds.
  extract_daemons

  # Extracts bash prompt PS1.
  extract_bash_prompt

  # Invokes the helper function to get all available completions.
  _APPCTL_COMP_WORDLIST="$(ovs_appctl_comp_helper \
      ${COMP_WORDS[@]:1:COMP_CWORD-1})"

  # This is a hack to prevent autocompleting when there is only one
  # available completion.
  if [ -z "$_PRINTF_ENABLE" ] && [ -n "$_APPCTL_COMP_WORDLIST" ]; then
      _APPCTL_COMP_WORDLIST="$_APPCTL_COMP_WORDLIST void"
  fi

  # Prints all available completions to stderr.  If there is only one matched
  # completion, do nothing.
  if [ -n "$_PRINTF_ENABLE" ] \
      && [ -n "`echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | \
                grep -- "^$cur"`" ]; then
      printf_stderr "\nAvailable completions:\n"
  fi

  # If there is no match between '$cur' and the '$_APPCTL_COMP_WORDLIST'
  # print a bash prompt since the 'complete' will not print it.
  if [ -n "$_PRINTF_ENABLE" ] \
      && [ -z "`echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | grep -- "^$cur"`" ]; then
      printf_stderr "\n$_BASH_PROMPT ${COMP_WORDS[@]}"
  fi

  if [ "$1" = "debug" ] ; then
      printf_stderr "`echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | sort -u`"
  else
      COMPREPLY=( $(compgen -W "`echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | sort \
                                 | uniq`" -- $cur) )
  fi

  return 0
}

if [ "$1" = "debug" ] ; then
    COMP_TYPE=0
    COMP_WORDS="${@:2}"
    COMP_CWORD="$(expr $# - 1)"
    _ovs_appctl_complete "debug"
else
    complete -F _ovs_appctl_complete ovs-appctl
fi