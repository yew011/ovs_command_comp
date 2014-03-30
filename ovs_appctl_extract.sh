#!/bin/bash

# this file will parse the ovs-appctl and ovs-vswitchd manpage
# and generate two files, containing all options and all combination
# of sub-commands, respectively.
#
# this script assumes the ovs-appctl sub-commands will always have
# 'ovs-appctl module/function ...' format.
#
# this script will save the options and sub-commands in __ovs_appctl_*.comp
# files.

# trick the console. ;D
CUR_COLS="`tput cols`"
stty cols 1024

rm __ovs_appctl_*.comp 1>&2 2>/dev/null
rm __ovs_appctl_*.tmp 1>&2 2>/dev/null
for name in opts subcmds; do
    touch __ovs_appctl_$name.comp
done

man -P cat ovs-appctl | cut -c8- | sed -n \
    '/^\-\-.*$/p' | cut -d ' ' -f1 | uniq > __ovs_appctl_opts.comp
man -P cat ovs-vswitchd | cut -c8- | sed -n \
    '/^[a-z]\+\/[a-z]\+.*$/p' | tr -s ' ' | sed 's/ | /|/g' \
    > __ovs_appctl_subcmds.tmp

# find all combinations of each sub-command.
touch __ovs_appctl_subcmd.tmp
while read line; do
    echo -en "\n" > __ovs_appctl_subcmd.tmp
    for arg in $line; do
	# if it is an optional argument, must expand the existing
	# combinations.
	if [ ! -z "`grep -- \"\[*\]\" <<< \"$arg\"`" ]; then
	    opts_tmp="`sed -n 's/^\[\(.*\)\]$/\1/p' <<< $arg`"
	    IFS='|' read -a opts_arr_tmp <<< "$opts_tmp"

	    nlines=`wc -l __ovs_appctl_subcmd.tmp | cut -d ' ' -f1`
	    for opt in "${opts_arr_tmp[@]}"; do
		head -$nlines __ovs_appctl_subcmd.tmp | \
		    sed "s@\$@ *${opt}@g" >> __ovs_appctl_subcmd.tmp
	    done
	else
	    # else just append the argument to the end of each
	    # combination.
	    sed "s@\$@ ${arg}@g" -i __ovs_appctl_subcmd.tmp
	fi
    done
    # append the combinations to __ovs_appctl_subcmds.comp
    cat __ovs_appctl_subcmd.tmp >> __ovs_appctl_subcmds.comp
done < __ovs_appctl_subcmds.tmp

sed -i 's/^ //g' __ovs_appctl_subcmds.comp
rm __ovs_appctl_*.tmp* 1>&2 2>/dev/null
eval stty cols $CUR_COLS