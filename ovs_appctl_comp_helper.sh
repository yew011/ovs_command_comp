#!/bin/bash

# This script will take the current command line arguments as input,
# find the command format and output the possible completions.
#
# The output will contain comment and the completion word list.  The
# comment will be output to stderr while the word list to stdout.

# Expandable keywords.
KWORDS=(bridge port interface dpname br_flow odp_flow)

# Input and parsing related.
CMD_LINE_SO_FAR=($@)
SUBCMD=""
KWORD=""
ARGS=()
j=-1

# Output related.
COMP_WORDLIST=""

# Helper functions.
arg_to_kword() {
    local kword
    local var="$1"

    KWORD="$var"
    # find all args
    for kword in ${KWORDS[@]}; do
	> .___arg2kword.tmp
	case "$kword" in
            bridge|port|interface)
		ovs-vsctl --columns=name list $kword | tr -d ' ' | cut -d ':' -f2 \
		    | sed -e 's/^"//' -e 's/"$//' | grep "$var" > .___arg2kword.tmp
		if [ -s .___arg2kword.tmp ]; then
		    KWORD="bpi"
		    return
		fi
		;;
            dpname)
		if [[ $var =~ ovs-system|ovs-netdev ]]; then
		    KWORD="dpname"
		    return
		fi
		;;
	    br_flow)
		if [[ $var =~ "in_port=" ]]; then
		    KWORD="br_flow"
		    return
		fi
		;;
	    odp_flow)
		if [[ $var =~ "in_port(" ]]; then
		    KWORD="odp_flow"
		    return
		fi
		;;
	    *)
		continue
		;;
	esac
    done
}

kword_to_args() {
    local kword
    local vars=($@)

    # find all args
    for kword in ${vars[@]}; do
	case "$kword" in
	    bridge|port|interface)
		ARGS+=($(ovs-vsctl --columns=name list $kword | tr -d ' ' | cut -d ':' -f2 \
		    | sed -e 's/^"//' -e 's/"$//'))
		continue
		;;
	    dpname)
		ARGS+=(ovs-system ovs-netdev)
		continue
		;;
	    *)
		ARGS+=($kword)
		;;
	esac
    done
}

# Main logic.

# Try locating the sub-command.
for i in "${!CMD_LINE_SO_FAR[@]}"; do
    if [ $i -le $j ]; then continue; fi

    j=$i
    if [ `sed -n '/^--.*$/p' <<< "${CMD_LINE_SO_FAR[j]}"` ]; then

        if [ "=" = "${CMD_LINE_SO_FAR[j+1]}" ]; then
	    ((j++))
	    if [ -n "${CMD_LINE_SO_FAR[j+1]}" ]; then
		COMP_WORDLIST="no_opt"
		((j++))
	    else
		COMP_WORDLIST="__`grep -- \"${CMD_LINE_SO_FAR[j-1]}\" \
                               __ovs_appctl_opts.comp | cut -d '=' -f2`__"
		((j++))
	    fi
        fi
	continue
    fi

    SUBCMD="${CMD_LINE_SO_FAR[i]}"
    break
done

if [ -z "$SUBCMD" ]; then
    # If no comment, all options/subcmds are available.
    if [ -z "$COMP_WORDLIST" ]; then
	COMP_WORDLIST="`cat __ovs_appctl_*.comp | cut -d ' ' -f1 | \
                        sed 's/=.*$/=/'`"
    elif [ "$COMP_WORDLIST" = "no_opt" ]; then
	COMP_WORDLIST="`cat __ovs_appctl_subcmds.comp | cut -d ' ' -f1`"
    fi
else
    cp __ovs_appctl_subcmds.comp .___tmp.tmp

    # $j stores the index of the subcmd in CMD_LINE_SO_FAR.
    for arg in "${CMD_LINE_SO_FAR[@]:$j}"; do
	> .___tmp.tmp.tmp

	arg_to_kword $arg
	if [ "$KWORD" = "bpi" ]; then
	    iter=(bridge port interface)
	else
	    iter=($KWORD)
	fi

	for kword in ${iter[@]}; do
	    #TODO: optional input
	    awk -v opt=$kword '$1 ~ opt {$1=""; print $0}' \
		.___tmp.tmp | cut -c2- >> .___tmp.tmp.tmp
	done
	cat .___tmp.tmp.tmp > .___tmp.tmp
    done

    kword_to_args `awk '{print $1}' .___tmp.tmp | sed 's/^\*//'`
    COMP_WORDLIST="${ARGS[@]}"
fi

rm -f .___tmp*.tmp

echo "$COMP_WORDLIST"