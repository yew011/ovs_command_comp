#!/bin/bash

rm __ovs_bash_comp_helper*.tmp 2>/dev/null

cat vsctl-commands.tmp > __ovs_vsctl_full_subcmd_extract.tmp
cat vsctl-options.tmp > __ovs_vsctl_full_option_extract.tmp
cat vsctl-prefix-options.tmp > __ovs_vsctl_subcmd_prefix_option_extract.tmp

LINE_SO_FAR=($@)

KEY_WORDS=(TABLE RECORD BRIDGE PORT IFACE COLUMN)
TABLES=(Open_vSwitch Bridge Port Interface Flow_Table QoS Queue Mirror \
        Controller Manager NetFlow SSL sFlow IPFIX Flow_Sample_Collector_Set)

PREV="${LINE_SO_FAR[@]:(-1)}"
OUTPUT=()

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
    break
done

# if the .tmp file does not exist, still at option completion stage.
if [ ! -f __ovs_bash_comp_helper.tmp ]; then
    tmp_opt="cut -d '=' -f1 <<< $PREV"

    # if $PREV is not a prefix option, this stage could match anything.
    # else, could only match certain prefix options and subcmds.
    if [ "$PREV" = "" ] || [ `grep -- "\[$tmp_opt" __ovs_vsctl_full_option_extract.tmp` ]; then
	# TODO: split [opt1|opt2] as two separate options in one line.
	OUTPUT="`cat __ovs_vsctl_full_option_extract.tmp \
                     __ovs_vsctl_subcmd_extract.tmp \
                     __ovs_vsctl_subcmd_prefix_option_extract.tmp`"
    else
	# narrow down the commands.
	grep -- "$tmp_opt" __ovs_vsctl_full_subcmd_extract.tmp \
	| while read -r line; do
	    tmp_line_arr=($line)

	    for i in "${!tmp_line_arr[@]}"; do
		if [ `grep -- "$tmp_opt" <<< ${tmp_line_arr[i]}` ]; then
		    if [ `grep -- "\[--" <<< ${tmp_line_arr[i+1]}` ]; then
			OUTPUT="${tmp_line_arr[i+1]} ${tmp_line_arr[i+2]}"
		    else
			OUTPUT="${tmp_line_arr[i+1]}"
		    fi
		fi
	    done
	done
    fi
else
    while read line; do
	tmp_line_arr=($line)

        # TODO: When the returned value is a actual bridge name.
	for i in "${!tmp_line_arr[@]}"; do
	    if [ "$PREV" = "${tmp_line_arr[i]}" ]; then
		OUTPUT="$OUTPUT ${tmp_line_arr[i+1]}"
		break
	    fi
	done
    done < __ovs_bash_comp_helper.tmp
fi

# return the completion word list.
echo $OUTPUT