#!/bin/bash
set -x 
ethtool -L enp2s0f0np0 combined 1
#ethtool -N enp2s0f0np0 flow-type udp4 action 1

rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/ovs/vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach
> /root/ovs/ovs-vswitchd.log

ovs-vsctl --no-wait init 
#ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
if [ "$1" == "gdb" ]; then
    gdb -ex=r --args ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl --disable-system
elif [ "$1" == "callgrind" ]; then
    valgrind --tool=callgrind ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl --disable-system --detach
else
    taskset 0x3 ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log  --disable-system --detach
fi
ovs-vsctl -- add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type=netdev 


ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=0xff
ovs-vsctl add-port br0 enp2s0f0np0 -- set int enp2s0f0np0 type=afxdp \
   options:n_rxq=1 options:xdp-mode=native-with-zerocopy options:use-need-wakeup=false

ovs-ofctl -O OpenFlow13 add-flow br0  "in_port=enp2s0f0np0, actions=set_field:14->in_port,enp2s0f0np0"
