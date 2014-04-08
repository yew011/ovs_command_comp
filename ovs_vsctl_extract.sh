#!/bin/bash

# trick the console. ;D
CUR_COLS="`tput cols`"
stty cols 1024

rm __ovs_vsctl_*_extract.tmp 1>&2 2>/dev/null

VSCTL_SUBCMDS="`ovs-vsctl --help | sed -e '/Options/q0' | sed -n '/^  .*$/p' \
               | cut -c3- | cut -d ' ' -f1 | uniq`"

man -P cat ovs-vsctl | cut -c8- | sed -n '/^[[a-z].*$/p' \
> __ovs_vsctl_tmp_extract.tmp

for subcmd in $VSCTL_SUBCMDS; do
    grep "$subcmd" __ovs_vsctl_tmp_extract.tmp | while read -r line; do
	tmp_subcmd_arr=($line)

	if [ "${#tmp_subcmd_arr[@]}" -gt "8" ]; then
	    continue
	fi
	echo "$line " >> __ovs_vsctl_full_subcmd_extract.tmp
    done
done

man -P cat ovs-vsctl | cut -c8- | sed -n '/^--.*$/p' | cut -d ' ' -f1 \
| cut -d '=' -f1 | uniq >> __ovs_vsctl_full_option_extract.tmp

ovs-vsctl --help | sed -e '/Options/q0' | sed -n '/^  .*$/p' | cut -c3- \
| cut -d ' ' -f1 | uniq >> __ovs_vsctl_subcmd_extract.tmp

while read line; do
    tmp_line_arr=($line)

    for arg in "${tmp_line_arr[@]}"; do
	if [ `sed -n '/^\[--.*/p'<<< $arg` ]; then
	    echo $arg >> __ovs_vsctl_subcmd_prefix_option_tmp_extract.tmp
	else
	    break
	fi
    done
done < __ovs_vsctl_full_subcmd_extract.tmp

sort __ovs_vsctl_subcmd_prefix_option_tmp_extract.tmp | uniq > \
__ovs_vsctl_subcmd_prefix_option_extract.tmp

eval stty cols $CUR_COLS