#!/bin/bash

# set a big enough column size.
stty cols 120

cmds_all="`man -P cat ovs-vswitchd | cut -c8- | sed -n '/^[a-z]\+\/[a-z]\+.*$/p'`"

subcmds_uniq=`man -P cat ovs-vswitchd | cut -c8- | sed -n '/^[a-z]\+\/[a-z]\+.*$/p' | cut -d ' ' -f1`



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
		options[$idx]="$i"
		;;
	    \[*)
		options[$idx]="$i]"
		;;
	    *\])
		options[$idx]="[$i"
		;;
	    \|)
		continue
		;;
	    *)
		options[$idx]="$i"
		((level++))
		;;
	esac

	((idx++))

	if [ $old_level -ne $level ]
	then
	    ((idx=0))
	    unset options
	fi
    done
    unset options
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