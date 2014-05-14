ovs_command_comp
================

Open Vswitch Command Completion, Bash~

Requirement: Open Vswitch installed.

To run the script:
root@promg-2n-a-dhcp85:~/ovs_command_comp# . ovs_appctl_compgen.sh

```html
<pre>
Example output:

root@promg-2n-a-dhcp85:~/ovs_command_comp# ovs-appctl 
--help                    bond/enable-slave         bridge/dump-flows         dpif/dump-dps             memory/show               stp/tcn
--target=                 bond/hash                 bridge/reconnect          dpif/dump-flows           ofproto/list              vlog/disable-rate-limit
--version                 bond/list                 cfm/set-fault             dpif/show                 ofproto/self-check        vlog/enable-rate-limit
bfd/set-forwarding        bond/migrate              cfm/show                  fdb/flush                 ofproto/trace             vlog/list
bfd/show                  bond/set-active-slave     coverage/show             fdb/show                  ofproto/trace-packet-out  vlog/reopen
bond/disable-slave        bond/show                 dpif/del-flows            lacp/show                 qos/show                  vlog/set

root@promg-2n-a-dhcp85:~/ovs_command_comp# ovs-appctl ofproto/trace 
ofproto/trace [dpname] odp_flow [-generate|packet]
ofproto/trace bridge br_flow [-generate|packet]

argument keyword (optional) "dpname" is expanded to: ovs-system ovs-netdev 
argument keyword "bridge" is expanded to: br0 
br0         odp_flow    ovs-netdev  ovs-system  


</pre>
