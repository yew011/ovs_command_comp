#!/bin/bash
#
# Tests for the ovs-appctl-compgen.bash
#
# Please run this script inside ovs-sandbox.
# For information about running the ovs-sandbox, please refer to
# the tutorial directory.
#
#
#
#
COMP_OUTPUT=
TMP=
EXPECT=
TEST_RESULT=

TEST_COUNTER=0
TEST_TARGETS=(ovs-vswitchd ovsdb-server ovs-ofctl)

#
# Helper functions.
#
get_command_format() {
    local input="$@"

    echo "$(grep -A 1 "Command format" <<< "$input" | tail -n+2)"
}

get_argument_expansion() {
    local input="$@"

    echo "$(grep -- "argument keyword .* is expanded to" | sed -e 's/^[ \t]*//')"
}

get_available_completions() {
    local input="$@"

    echo "$(sed -e '1,/Available/d' <<< "$input" | tail -n+2)"
}

reset_globals() {
    COMP_OUTPUT=
    TMP=
    EXPECT=
    TEST_RESULT=
}

#
# $1: Test name.
# $2: ok or fail.
#
print_result() {
    (( TEST_COUNTER++ ))
    printf "%2d: %-70s %s\n" "$TEST_COUNTER" "$1" "$2"
}

#
# Sub-tests.
#
ovs_apptcl_TAB() {
    local target="$1"
    local target_line=
    local comp_output tmp expect

    if [ -n "$target" ]; then
        target_line="--target $target"
    fi
    comp_output="$(bash ovs-appctl-compgen.bash debug ovs-appctl $target_line TAB 2>&1)"
    tmp="$(get_available_completions "$comp_output")"
    expect="$(ovs-appctl --option | sort)
$(ovs-appctl $target_line help | tail -n +2 | cut -c3- | cut -d ' ' -f1)"

    if [ "$tmp" = "$expect" ]; then
        echo "ok"
    else
        echo "fail"
    fi
}

#
# Test preparation.
#
ovs-vsctl --may-exist add-br br0


#
# Begin the test.
#
cat <<EOF

## ------------------------------ ##                                                                                                                                   [1530/1928]
## ovs-appctl-compgen unit tests. ##
## ------------------------------ ##

EOF


# complete ovs-appctl --tar[TAB]

reset_globals

COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl --tar 2>&1)"
TMP="$(get_available_completions "$COMP_OUTPUT")"
EXPECT="--target"

if [ "$TMP" = "$EXPECT" ]; then
    TEST_RESULT=ok
else
    TEST_RESULT=fail
fi

print_result "complete ovs-appctl --targ[TAB]" "$TEST_RESULT"


# complete ovs-appctl --target [TAB]

reset_globals

COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl --target TAB 2>&1)"
TMP="$(get_available_completions "$COMP_OUTPUT")"
EXPECT="$(echo ${TEST_TARGETS[@]} | tr ' ' '\n' | sort)"

if [ "$TMP" = "$EXPECT" ]; then
    TEST_RESULT=ok
else
    TEST_RESULT=fail
fi

print_result "complete ovs-appctl --target [TAB]" "$TEST_RESULT"


# complete ovs-appctl [TAB]
# complete ovs-appctl --target ovs-vswitchd [TAB]
# complete ovs-appctl --target ovsdb-server [TAB]
# complete ovs-appctl --target ovs-ofctl [TAB]

reset_globals

for i in NONE ${TEST_TARGETS[@]}; do
    input=
    test_target=

    if [ "$i" != "NONE" ]; then
        input="$i"
        test_target="--target $i "
    fi

    if [ "$i" = "ovs-ofctl" ]; then
        ovs-ofctl monitor br0 --detach --no-chdir --pidfile
    fi

    TEST_RESULT="$(ovs_apptcl_TAB $input)"

    print_result "complete ovs-appctl ${test_target}[TAB]" "$TEST_RESULT"

    if [ "$i" = "ovs-ofctl" ]; then
        ovs-appctl --target ovs-ofctl exit
    fi
done


# check all subcommand formats

reset_globals

TMP="$(ovs-appctl help | tail -n +2 | cut -c3- | cut -d ' ' -f1)"

# for each subcmd, check the print of subcmd format
for i in $TMP; do
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl $i TAB 2>&1)"
    tmp="$(get_command_format "$COMP_OUTPUT")"
    EXPECT="$(ovs-appctl help | tail -n+2 | cut -c3- | grep -- "^$i " | tr -s ' ')"

    if [ "$tmp" = "$EXPECT" ]; then
        TEST_RESULT=ok
    else
        echo "$COMP_OUTPUT"
        echo "$tmp"
        echo "$EXPECT"
        echo "failed at subcommand: $i"
        TEST_RESULT=fail
        break
    fi
done

print_result "check all subcommand format" "$TEST_RESULT"

# complex completion check - bfd/set-forwarding
# complex completion check - lacp/show
# complex completion check - ofproto/trace
# complex completion check - vlog/set
# netgative test => no vswitchd, no ovsdb-server, no ovs-ofctl