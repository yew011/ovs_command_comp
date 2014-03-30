#!/bin/bash

export LC_ALL=C

_ovs_appctl_complete() {
  local cur prev comp_wordlist
  local input=()

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  # check what the current word should be.
  input=(${COMP_WORDS[@]:1:COMP_CWORD-1})
  bash ovs_appctl_comp_helper.sh "${input[@]}" > __comp_wordlist.tmp
  comp_wordlist="`cat __comp_wordlist.tmp | tr -d '*'`"
  rm -f __comp_wordlist.tmp

  COMPREPLY=( $(compgen -W "$comp_wordlist" -- $cur) )

  return 0
}

complete -F _ovs_appctl_complete ovs-appctl