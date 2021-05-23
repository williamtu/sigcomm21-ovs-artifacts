#!/bin/bash

# see 
# https://patchwork.ozlabs.org/project/openvswitch/cover/20200731025514.1669061-1-toshiaki.makita1@gmail.com/

set -x 
#no need below when using native mode
#ethtool -L enp2s0f0np0 combined 1
#ethtool -N enp2s0f0np0 flow-type udp4 action 1
# make sure works!
# ./xdpsock -i enp2s0f0np0 -r -z -q1

ulimit -l unlimited
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
ovs-vsctl set Open_vSwitch . other_config:pmd-cpu-mask=0x3
#ovs-appctl vlog/set netdev_afxdp::dbg
#ovs-vsctl -- add-br br0 -- set Bridge br0 datapath_type=netdev other_config:pmd-cpu-mask=0xfff
#ovs-vsctl add-port br0 enp2s0 -- set interface enp2s0 type="afxdp" other_config:pmd-rxq-affinity="0:1,1:3"
# queue 0, pmd 1, queue 1, pmd 2
#ovs-appctl vlog/set netdev_afxdp::dbg
ovs-vsctl add-port br0 enp2s0f0np0 -- set int enp2s0f0np0 type=afxdp \
   options:n_rxq=1 options:xdp-mode=native options:xdp-obj="/root/ovs/bpf/flowtable_afxdp.o"
ip netns add at_ns0
ip link add p0 type veth peer name afxdp-p0
ip link set p0 netns at_ns0
ip link set dev afxdp-p0 up
ovs-vsctl add-port br0 afxdp-p0
ovs-vsctl -- set interface afxdp-p0 type=afxdp options:xdp-mode=native \
    options:xdp-obj="/root/ovs/bpf/flowtable_afxdp.o"

ovs-vsctl set Open_vSwitch . other_config:offload-driver=linux_xdp
ovs-vsctl set Open_vSwitch . other_config:hw-offload=true
#ethtool -K afxdp-p0 tx off 
#ip netns exec at_ns0 ethtool -K p0 tx off 

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add "10.1.1.1/24" dev p0
ip link set dev p0 up
NS_EXEC_HEREDOC

ovs-ofctl add-flow br0 "in_port=afxdp-p0, actions=enp2s0f0np0"
ovs-ofctl add-flow br0 "in_port=enp2s0f0np0, actions=output:afxdp-p0"

#ip link set afxdp-p0 xdpdrv obj /root/xdp_noop.o section xdp
ip netns exec at_ns0 /root/bpf-next/samples/bpf/xdp_rxq_info --action XDP_TX -d p0

exit

