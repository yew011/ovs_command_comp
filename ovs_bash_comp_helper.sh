#!/bin/bash

rm __ovs_bash_comp_helper.tmp 1>&2 2>/dev/null

cat vsctl-commands.tmp 1>__ovs_vsctl_full_subcmd_extract.tmp 2>/dev/null
cat vsctl-options.tmp 1>__ovs_vsctl_full_option_extract.tmp 2>/dev/null
cat vsctl-prefix-options.tmp 1>__ovs_vsctl_subcmd_prefix_option_extract.tmp 2>/dev/null

LINE_SO_FAR=($@)

KEYWORDS=(TABLE RECORD BRIDGE PORT IFACE COLUMN KEY VALUE)
PREV="${LINE_SO_FAR[@]:(-1)}"
SUBCMD=""
OUTPUT=""

# create a variable for each keyword
for keyword in "${KEYWORDS[@]}"; do
    eval $keyword=\"\"
done
# Helpers

# return the index of element in array.
find_array_idx() {
    local ret=$1
    local tmp_subcmd=$2
    eval local tmp_arr=\(\${$3[@]}\)

    for i in "${!tmp_arr[@]}"; do
	if [ "${tmp_arr[$i]}" = "$tmp_subcmd" ]; then
	    eval $ret=\$i
	    break
	fi
    done
}

# if the command argument is a keyword, assign the user argument to the
# corresponding keyword variable.
check_keyword() {
    local cmd_arg="$1"
    local usr_arg="$2"

    if [ echo "$KEYWORDS[@]" | tr " " "\n" | grep -i -- "$cmd_arg" ]; then
	eval $cmd_arg="$usr_arg"
    fi
}

# Main logic

# try finding the command(s) that match the command line so-far.
# assume:
# - the -* options are not used.
#
for arg in "${LINE_SO_FAR[@]}"; do
    if [ `sed -n '/^--.*$/p' <<< $arg` ]; then
	tmp_opt="cut -d '=' -f1 <<< $arg"
	continue
    fi
    grep "$arg " __ovs_vsctl_full_subcmd_extract.tmp \
	>> __ovs_bash_comp_helper.tmp
    SUBCMD="$arg"
    break
done

# if the .tmp file does not exist, still at option completion stage.
if [ ! -f __ovs_bash_comp_helper.tmp ]; then
    tmp_opt="`cut -d '=' -f1 <<< $PREV`"

    # if $PREV is not a prefix option, this stage could match anything.
    # else, could only match certain prefix options and subcmds.
    if [ "$PREV" = "" ] || [ `grep -- "$tmp_opt" __ovs_vsctl_full_option_extract.tmp` ]; then
	# TODO: split [opt1|opt2] as two separate options in one line.
	OUTPUT="`cat __ovs_vsctl_full_option_extract.tmp \
                     __ovs_vsctl_subcmd_extract.tmp \
                     __ovs_vsctl_subcmd_prefix_option_extract.tmp`"
    else
	# narrow down the commands.
	grep -- "$tmp_opt" __ovs_vsctl_full_subcmd_extract.tmp \
	| while read line; do
	    tmp_line_arr=($line)

	    for i in "${!tmp_line_arr[@]}"; do
		if [ `grep -- "$tmp_opt" <<< "${tmp_line_arr[i]}"` ]; then
		    if [ `grep -- "\[--" <<< ${tmp_line_arr[i+1]}` ]; then
			OUTPUT="$OUTPUT ${tmp_line_arr[i+1]} ${tmp_line_arr[i+2]}"
			echo "$OUTPUT"
			break
		    else
			OUTPUT="$OUTPUT ${tmp_line_arr[i+1]}"
			break
		    fi
		fi
	    done
	done
    fi
else
    FULL_SUBCMD=(`cat __ovs_bash_comp_helper.tmp`)
    REQUIRED=""
    idx_cmd=0
    subcmd_len=${#FULL_SUBCMD[@]}
    idx_line_so_far=0
    line_so_far_len=${#LINE_SO_FAR[@]}

    # get the idx of the subcmd in the full sub-command and the
    # command line argument so far.
    find_array_idx "idx_cmd" $SUBCMD "FULL_SUBCMD"
    find_array_idx "idx_line_so_far" $SUBCMD "LINE_SO_FAR"

    ARG_SUBCMD="${FULL_SUBCMD[++idx_cmd]}"
    ARG_LINE_SO_FAR="${LINE_SO_FAR[++idx_line_so_far]}"

    # if the command argument is a keyword, assign the user argument to the
    # corresponding keyword variable.
    while [ ! -z "$ARG_SUBCMD" ] && [ ! -z "$ARG_LINE_SO_FAR" ]; do
	if [ `echo "$KEYWORDS[@]" | tr " " "\n" | grep -i -- "$ARG_SUBCMD"` ]; then
	    eval $ARG_SUBCMD="$ARG_LINE_SO_FAR"
	fi
	ARG_SUBCMD="${FULL_SUBCMD[++idx_cmd]}"
	ARG_LINE_SO_FAR="${LINE_SO_FAR[++idx_line_so_far]}"
    done

    # if all empty, not need to go further.
    if [ -z "$ARG_SUBCMD" ]; then
	exit 0
    else
	if [ `echo "${KEYWORDS[@]}" | tr " " "\n" | grep -i -- "$ARG_SUBCMD"` ]; then
	    case "$ARG_SUBCMD" in
		TABLE)
		    OUTPUT="`ovsdb-client list-tables | tail -n +3`"
		    ;;
		RECORD)
		    OUTPUT="`ovs-vsctl list $TABLE | grep -- \"name\" | cut -d ':' -f2`"
		    ;;
		COLUMN)
		    OUTPUT="`ovs-vsctl list $TABLE $RECORD | cut -d ':' -f1`"
		    ;;
		BRIDGE)
		    OUTPUT="`ovs-vsctl list-br`"
		    ;;
	    esac
	else
	    if [ `grep -- "\[*" <<< "$ARG_SUBCMD"` ]; then
		OUTPUT="$ARG_SUBCMD"
	    else
		OUTPUT="$ARG_SUBCMD ${FULL_SUBCMD[++idx_cmd]}"
	    fi
	fi
    fi
fi

# return the completion word list.
echo "$OUTPUT" | tr " " "\n" | sort
