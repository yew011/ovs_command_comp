#!/bin/bash

# set a big enough column size.
stty cols 120

cmds_all="`man -P cat ovs-vswitchd | cut -c8- | sed -n '/^[a-z]\+\/[a-z]\+.*$/p'`"

echo "$cmds_all" |  while read -r line
do
    declare -a options
    level=0
    idx=0

    IFS=' ' read -a words <<< "$line"
    for i in "${words[@]}"
    do
	old_level=$level

	# parse the word,
	case "$i" in
	    \[*\])
		options[idx]="$i"
		;;
	    \[*)
		options[idx]="$i]"
		;;
	    *\])
		options[idx]="[$i"
		;;
	    \|)
		continue
		;;
	    *)
		options[idx]="$i"
		((level++))
	    ;;
	esac

	((idx++))

	# print out the options at this level
	if [ $old_level -ne $level ]
	then
	    echo "level $level"
	    echo "options are: ${options[*]}"

	    ((idx=0))
	    unset options
	fi
    done
done