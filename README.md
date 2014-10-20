ovs_command_comp
================

Open Vswitch Command Completion, Bash~

Requirement: Open Vswitch installed.

To use the script, run:
root@promg-2n-a-dhcp85:~/ovs_command_comp# . ovs-command-compgen.bash

With rounds of optimization, there should not be noticeable display lag. ;D

Supported commands:
ovs-appctl, ovs-ofctl, ovs-dpctl, ovsdb-tool

*Limitations:
- only support small set of important keywords (dp, datapath, bridge, switch, port, interface, iface).

- does not support parsing of nested option (e.g. ovsdb-tool create [db [schema]]).

- does not support expansion on repeatitive argument (e.g. ovs-dpctl show [dp...]).

- only support matching on long options, and only in the format (--option [arg], i.e. should not use --option=[arg]).


Example Output:
```html
<pre>

root@promg-2n-a-dhcp85:~/ovs_command_comp# ovs-appctl [tab]

Available completions:

--execute                      bridge/dump-flows              dpctl/help                     help                           time/stop
--help                         bridge/reconnect               dpctl/mod-flow                 lacp/show                      time/warp
--option                       cfm/set-fault                  dpctl/normalize-actions        mdb/flush                      upcall/disable-megaflows
--target                       cfm/show                       dpctl/parse-actions            mdb/show                       upcall/enable-megaflows
--version                      coverage/show                  dpctl/set-if                   memory/show                    upcall/set-flow-limit
bfd/set-forwarding             dpctl/add-dp                   dpctl/show                     netdev-dummy/conn-state        upcall/show
bfd/show                       dpctl/add-flow                 dpif-dummy/change-port-number  netdev-dummy/receive           version
bond/disable-slave             dpctl/add-if                   dpif-dummy/delete-port         netdev-dummy/set-admin-state   vlog/disable-rate-limit
bond/enable-slave              dpctl/del-dp                   dpif/dump-dps                  ofproto/list                   vlog/enable-rate-limit
bond/hash                      dpctl/del-flow                 dpif/dump-flows                ofproto/trace                  vlog/list
bond/list                      dpctl/del-flows                dpif/show                      ofproto/trace-packet-out       vlog/reopen
bond/migrate                   dpctl/del-if                   exit                           qos/show                       vlog/set
bond/set-active-slave          dpctl/dump-dps                 fdb/flush                      revalidator/wait
bond/show                      dpctl/dump-flows               fdb/show                       stp/tcn


root@promg-2n-a-dhcp85:~/alex_dev/ovs_command_comp# ovs-appctl ofproto/trace [tab]

Command format:
ofproto/trace {[dp_name] odp_flow | bridge br_flow} [-generate|packet]

Argument expansion:
     argument keyword "bridge" is expanded to:
     argument keyword "odp_flow" is expanded to: odp_flow
     argument keyword "dp_name" is expanded to: ovs-system

Available completions:

odp_flow    ovs-system
root@promg-2n-a-dhcp85:~/alex_dev/ovs_command_comp# ovs-appctl ofproto/trace

</pre>
