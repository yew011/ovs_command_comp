#!/bin/bash

_ovs_vsctl_complete() {
  local cur prev ret
  local input=()

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}
  prev=${COMP_WORDS[COMP_CWORD-1]}

  # check what the current word should be.
  input=(${COMP_WORDS[@]:1:COMP_CWORD-1})
  ret="`./ovs_bash_comp_helper.sh \"${input[@]}\"`"

  COMPREPLY=( $(compgen -W "$ret" -- $cur) )

  return 0
}

complete -F _ovs_vsctl_complete ovs-vsctl