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

    echo "$(grep -- "argument keyword .* is expanded to" <<< "$input" | sed -e 's/^[ \t]*//')"
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
ovs-vsctl add-br br0
ovs-vsctl add-port br0 p1


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
        TEST_RESULT=fail
        break
    fi
done

print_result "check all subcommand format" "$TEST_RESULT"


# complex completion check - bfd/set-forwarding
# bfd/set-forwarding [interface] normal|false|true
# test expansion of 'interface'

reset_globals

for i in loop_once; do
    # check the top level completion.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl bfd/set-forwarding TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"normal\" is expanded to: normal
argument keyword \"false\" is expanded to: false
argument keyword \"true\" is expanded to: true
argument keyword \"interface\" is expanded to:  p1"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="false normal p1 true"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to 'true', there should be no more completions.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl bfd/set-forwarding true TAB 2>&1)"
    TMP="$(sed -e '/./,$!d' <<< "$COMP_OUTPUT")"
    EXPECT="Command format:
bfd/set-forwarding [interface] normal|false|true"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to 'p1', there should still be the completion for booleans.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl bfd/set-forwarding p1 TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"normal\" is expanded to: normal
argument keyword \"false\" is expanded to: false
argument keyword \"true\" is expanded to: true"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="false normal true"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to 'p1 false', there should still no more completions.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl bfd/set-forwarding p1 false TAB 2>&1)"
    TMP="$(sed -e '/./,$!d' <<< "$COMP_OUTPUT")"
    EXPECT="Command format:
bfd/set-forwarding [interface] normal|false|true"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    TEST_RESULT=ok
done

print_result "complex completion check - bfd/set-forwarding" "$TEST_RESULT"


# complex completion check - lacp/show
# lacp/show [port]
# test expansion on 'port'

reset_globals

for i in loop_once; do
    # check the top level completion.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl lacp/show TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"port\" is expanded to: br0 p1"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="br0 p1"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to 'p1', there should be no more completions.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl lacp/show p1 TAB 2>&1)"
    TMP="$(sed -e '/./,$!d' <<< "$COMP_OUTPUT")"
    EXPECT="Command format:
lacp/show [port]"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    TEST_RESULT=ok
done

print_result "complex completion check - lacp/show" "$TEST_RESULT"


# complex completion check - ofproto/trace
# ofproto/trace {[dp_name] odp_flow | bridge br_flow} [-generate|packet]
# test expansion on 'dp|dp_name' and 'bridge'

for i in loop_once; do
    # check the top level completion.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl ofproto/trace TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"bridge\" is expanded to: br0
argument keyword \"odp_flow\" is expanded to: odp_flow
argument keyword \"dp_name\" is expanded to: ovs-system"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="br0 odp_flow ovs-system"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to 'ovs-system', should go to the dp-name path.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl ofproto/trace ovs-system TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"odp_flow\" is expanded to: odp_flow"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="odp_flow"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set odp_flow to some random string, should go to the next level.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl ofproto/trace ovs-system "in_port(123),mac(),ip,tcp" TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"-generate\" is expanded to: -generate
argument keyword \"packet\" is expanded to: packet"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="-generate packet"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set packet to some random string, there should be no more completions.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl ofproto/trace ovs-system "in_port(123),mac(),ip,tcp" "ABSJDFLSDJFOIWEQR" TAB 2>&1)"
    TMP="$(sed -e '/./,$!d' <<< "$COMP_OUTPUT")"
    EXPECT="Command format:
ofproto/trace {[dp_name] odp_flow | bridge br_flow} [-generate|packet]"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to 'br0', should go to the bridge path.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl ofproto/trace br0 TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"br_flow\" is expanded to: br_flow"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="br_flow"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to some random string, should go to the odp_flow path.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl ofproto/trace "in_port(123),mac(),ip,tcp" TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"-generate\" is expanded to: -generate
argument keyword \"packet\" is expanded to: packet"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="-generate packet"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    TEST_RESULT=ok
done

print_result "complex completion check - ofproto/trace" "$TEST_RESULT"


# complex completion check - vlog/set
# vlog/set {spec | PATTERN:facility:pattern}
# test non expandable arguments
for i in loop_once; do
    # check the top level completion.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl vlog/set TAB 2>&1)"
    TMP="$(get_argument_expansion "$COMP_OUTPUT" | sed -e 's/[ \t]*$//')"
    EXPECT="argument keyword \"PATTERN:facility:pattern\" is expanded to: PATTERN:facility:pattern
argument keyword \"spec\" is expanded to: spec"

    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # check the available completions.
    TMP="$(get_available_completions "$COMP_OUTPUT" | tr '\n' ' ' | sed -e 's/[ \t]*$//')"
    EXPECT="PATTERN:facility:pattern spec"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    # set argument to random 'abcd', there should be no more completions.
    COMP_OUTPUT="$(bash ovs-appctl-compgen.bash debug ovs-appctl vlog/set abcd TAB 2>&1)"
    TMP="$(sed -e '/./,$!d' <<< "$COMP_OUTPUT")"
    EXPECT="Command format:
vlog/set {spec | PATTERN:facility:pattern}"
    if [ "$TMP" != "$EXPECT" ]; then
        TEST_RESULT=fail
        break
    fi

    TEST_RESULT=ok
done

print_result "complex completion check - vlog/set" "$TEST_RESULT"


# negative test => delete the configuration

# negative test => incorrect input

# negative test => no vswitchd, no ovsdb-server, no ovs-ofctl