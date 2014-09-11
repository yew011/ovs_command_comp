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
_KWORDS=(bridge port interface dp_name dp)
# Printf enabler.
_PRINTF_ENABLE=
# Bash prompt.
_BASH_PROMPT=
# Target in the current completion, default ovs-vswitchd.
_APPCTL_TARGET="ovs-vswitchd"
# Output to the compgen.
_APPCTL_COMP_WORDLIST=
# Possible targets.
_POSSIBLE_TARGETS="ovs-vswitchd ovsdb-server ovs-ofctl"

# Command Extraction
# ==================
#
#
#
# Extracts all subcommands of target.
# If cannot read pidfile, returns nothing.
extract_subcmds() {
    local target=$_APPCTL_TARGET
    local subcmds=

    ovs-appctl --target $target help 2>/dev/null 1>&2 && \
      subcmds="$(ovs-appctl --target $target help | tail -n +2 | cut -c3- \
                 | cut -d ' ' -f1)"

    echo "$subcmds"
}

# Extracts all options of ovs-appctl.
extract_options() {
    echo "$(ovs-appctl --option)"
}



# Combination Discovery
# =====================
#
#
#
# Given the subcommand formats at current completion level, finds
# all possible completions.
find_possible_comps() {
    local combs="$@"
    local comps=
    local line

    while read line; do
        local arg=

        for arg in $line; do
            # If it is an optional argument, gets all completions,
            # and continues.
            if [ ! -z "$(grep -- "\[*\]" <<< "$arg")" ]; then
                local opt_arg="$(sed -e 's/^\[\(.*\)\]$/\1/' <<< "$arg")"
                local opt_args=()

                IFS='|' read -a opt_args <<< "$opt_arg"
                comps="${opt_args[@]} $comps"
            # If it is a compulsory argument, adds it to the comps
            # and break, since all following args are for next stage.
            else
                local args=()

                IFS='|' read -a args <<< "$arg"
                comps="${args[@]} $comps"
                break;
            fi
        done
    done <<< "$combs"

    echo "$comps"
}

# Given the subcommand format, and the current command line input,
# finds all possible completions.
subcmd_find_comp_based_on_input() {
    local format="$1"
    local cmd_line=($2)
    local mult=
    local combs=
    local comps=
    local arg line

    # finds all combinations by searching for '{}'.
    # there should only be one '{}', otherwise, the
    # command format should be changed to multiple commands.
    mult="$(sed -n 's/^.*{\(.*\)}.*$/ \1/p' <<< "$format" | tr '|' '\n' | cut -c1-)"
    if [ -n "$mult" ]; then
        while read line; do
            local tmp=

            tmp="$(sed -e "s@{\(.*\)}@$line@" <<< "$format")"
            combs="$combs@$tmp"
        done <<< "$mult"
        combs="$(tr '@' '\n' <<< "$combs")"
    else
        combs="$format"
    fi

    # Now, starts from the first argument, narrows down the
    # subcommand format combinations.
    for arg in "${subcmd_line[@]}"; do
        local kword possible_comps

        # Finds next level possible comps.
        possible_comps=$(find_possible_comps "$combs")
        # Finds the kword.
        kword="$(arg_to_kwords "$arg" "$possible_comps")"
        # Trims the 'combs', keeps context only after 'kword'.
        if [ -n "$combs" ]; then
            combs="$(sed -n "s@^.*\[\?$kword|\?[a-z_]*\]\? @@p" <<< "$combs")"
        fi
    done
    comps="$(find_possible_comps "$combs")"

    echo "$(kwords_to_args "$comps")"
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
                        | tail -1 | sed 's/ exit//g')"
    fi
}



# Keyword Conversion
# ==================
#
#
#
# All completion functions.
complete_bridge () {
    local result error

    result=$(ovs-vsctl list-br | grep -- "^$1") || error="TRUE"

    if [ -z "$error" ]; then
        echo  "${result}"
    fi
}

complete_port () {
    local ports result error
    local all_ports

    all_ports=$(ovs-vsctl --format=table \
        --no-headings \
        --columns=name \
        list Port) || error="TRUE"
    ports=$(printf "$all_ports" | sort | tr -d '"' | uniq -u)
    result=$(grep -- "^$1" <<< "$ports")

    if [ -z "$error" ]; then
        echo  "${result}"
    fi
}

complete_iface () {
    local bridge bridges result error

    bridges=$(ovs-vsctl list-br)
    for bridge in $bridges; do
        local ifaces

        ifaces=$(ovs-vsctl list-ifaces "${bridge}") || error="TRUE"
        result="${result} ${ifaces}"
    done

    if [ -z "$error" ]; then
        echo  "${result}"
    fi
}

complete_dp () {
    local dps result error

    dps=$(ovs-appctl dpctl/dump-dps | cut -d '@' -f2) || error="TRUE"
    result=$(grep -- "^$1" <<< "$dps")

    if [ -z "$error" ]; then
        echo  "${result}"
    fi
}

# Converts the argument (e.g. bridge/port/interface/dp name) to
# the corresponding keywords.
# Returns empty string if could not map the arg to any keyword.
arg_to_kwords() {
    local arg="$1"
    local possible_kwords=($2)
    local non_parsables=()
    local match=
    local kword

    for kword in ${possible_kwords[@]}; do
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
            dp_name|dp)
                match="$(complete_dp "$arg")"
                ;;
            *)
                if [ "$arg" = "$kword" ]; then
                    match="$kword"
                else
                    non_parsables+=("$kword")
                    continue
                fi
                ;;
        esac

        if [ -n "$match" ]; then
            echo "$kword"
            return
        fi
    done

    # If there is only one non-parsable kword,
    # just assume the user input it.
    if [ "${#non_parsables[@]}" -eq "1" ]; then
        echo "$non_parsables"
        return
    fi
}

# Expands the keywords to the corresponding instance names.
kwords_to_args() {
    local possible_kwords=($@)
    local args=()
    local kword

    for kword in ${possible_kwords[@]}; do
        local match=

        case "${kword}" in
            bridge)
                match="$(complete_bridge "")"
                ;;
            port)
                match="$(complete_port "")"
                ;;
            interface)
                match="$(complete_iface "")"
                ;;
            dp_name|dp)
                match="$(complete_dp "")"
                ;;
            -*)
                # Treats option as kword as well.
                match="$kword"
                ;;
            *)
                match=($kword)
                ;;
        esac
        match=$(echo "$match" | tr '\n' ' ')
        args+=( $match )
        if [ -n "$_PRINTF_ENABLE" ]; then
            local output_stderr=

            if [ -z "$printf_expand_once" ]; then
                printf_expand_once="once"
                printf -v output_stderr "\nArgument expansion:\n"
            fi
            printf -v output_stderr "$output_stderr     argument keyword \
\"%s\" is expanded to: %s " "$kword" "$match"

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
    local target=$_APPCTL_TARGET
    local subcmd_format=
    local comp_wordlist=

    # Extracts the subcommand format.
    subcmd_format="$(ovs-appctl --target $target help | tail -n +2 | cut -c3- \
                     | awk -v opt=$subcmd '$1 == opt {print $0}' | tr -s ' ' )"

    # Prints subcommand format.
    printf_stderr "$(printf "\nCommand format:\n%s" "$subcmd_format")"

    # Finds the possible completions based on input argument.
    comp_wordlist="$(subcmd_find_comp_based_on_input "$subcmd_format" \
                     "${subcmd_line[@]}")"

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
# At the beginning, the options are checked and completed.  The function
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
    local comp_wordlist appctl_subcmd i
    local j=-1

    for i in "${!cmd_line_so_far[@]}"; do
        # if $i is not greater than $j, it means the previous iteration
        # skips not-visited args.  so, do nothing and catch up.
        if [ $i -le $j ]; then continue; fi
        j=$i
        if [[ "${cmd_line_so_far[i]}" =~ ^--*  ]]; then
            # If --target is found, locate the target daemon.
            # Else, it is an option command, fill the comp_wordlist with
            # all options.
            if [[ "${cmd_line_so_far[i]}" =~ ^--target$ ]]; then
                if [ -n "${cmd_line_so_far[j+1]}" ]; then
                    local daemon

                    for daemon in $_POSSIBLE_TARGETS; do
                        # Greps "$daemon" in argument, since the argument may
                        # be the path to the pid file.
                        if [ "$daemon" = "${cmd_line_so_far[j+1]}" ]; then
                            _APPCTL_TARGET="$daemon"
                            ((j++))
                            break
                        fi
                    done
                    continue
                else
                    comp_wordlist="$_POSSIBLE_TARGETS"
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
      _PRINTF_ENABLE=
  else
      _PRINTF_ENABLE="enabled"
  fi

  # Extracts bash prompt PS1.
  if [ "$1" != "debug" ]; then
      extract_bash_prompt
  fi

  # Invokes the helper function to get all available completions.
  # Always not input the 'COMP_WORD' at 'COMP_CWORD', since it is
  # the one to be completed.
  _APPCTL_COMP_WORDLIST="$(ovs_appctl_comp_helper \
      ${COMP_WORDS[@]:1:COMP_CWORD-1})"

  # This is a hack to prevent autocompleting when there is only one
  # available completion and printf disabled.
  if [ -z "$_PRINTF_ENABLE" ] && [ -n "$_APPCTL_COMP_WORDLIST" ]; then
      _APPCTL_COMP_WORDLIST="$_APPCTL_COMP_WORDLIST void"
  fi

  # Prints all available completions to stderr.  If there is only one matched
  # completion, do nothing.
  if [ -n "$_PRINTF_ENABLE" ] \
      && [ -n "$(echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | \
                grep -- "^$cur")" ]; then
      printf_stderr "\nAvailable completions:\n"
  fi

  # If there is no match between '$cur' and the '$_APPCTL_COMP_WORDLIST'
  # print a bash prompt since the 'complete' will not print it.
  if [ -n "$_PRINTF_ENABLE" ] \
      && [ -z "$(echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | grep -- "^$cur")" ] \
      && [ "$1" != "debug" ] ; then
      printf_stderr "\n$_BASH_PROMPT ${COMP_WORDS[@]}"
  fi

  if [ "$1" = "debug" ] ; then
      if [ -n "$cur" ]; then
          printf_stderr "$(echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | sort -u | grep -- "$cur")\n"
      else
          printf_stderr "$(echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' | sort -u | grep -- "$cur")\n"
      fi
  else
      COMPREPLY=( $(compgen -W "$(echo $_APPCTL_COMP_WORDLIST | tr ' ' '\n' \
                                 | sort -u)" -- $cur) )
  fi

  return 0
}

if [ "$1" = "debug" ] ; then
    shift
    COMP_TYPE=0
    COMP_WORDS=($@)
    COMP_CWORD="$(expr $# - 1)"

    # If the last argument is TAB, it means that the previous
    # argument is already complete and script should complete
    # next argument which as not being input yet.  This is a
    # hack since compgen will break the input whitespace even
    # though there is no input after it but bash cannot.
    if [ "${COMP_WORDS[-1]}" = "TAB" ]; then
        COMP_WORDS[${#COMP_WORDS[@]}-1]=""
    fi

    _ovs_appctl_complete "debug"
else
    complete -F _ovs_appctl_complete ovs-appctl
fi