#!/bin/bash
set -x 
#./configure --with-bpf=/root/bpf-next/tools/ --with-dpdk=/root/dpdk/x86_64-native-linuxap-gcc
ulimit -l unlimited
rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/ovs/vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach

> /root/ovs/ovs-vswitchd.log

ovs-vsctl --no-wait init 
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
if [ "$1" == "gdb" ]; then
    gdb -ex=r --args ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl --disable-system
else
    ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl --disable-system --detach
fi

ovs-vsctl -- add-br br0 -- set Bridge br0 datapath_type=netdev other_config:pmd-cpu-mask=0xff
ovs-vsctl add-port br0 enp2s0f0np0 -- set int enp2s0f0np0 type=dpdk \
    options:dpdk-devargs=0000:02:00.0

#ovs-ofctl add-flow br0 \
#"in_port=enp2s0f0np0, actions=set_field:14->in_port,set_field:a0:36:9f:33:b1:40->dl_src,output:enp2s0f0np0"

# create namespaces

ip netns add at_ns0

ip link add p0 type veth peer name afxdp-p0
ip link set p0 netns at_ns0
ip link set dev afxdp-p0 up

ovs-vsctl add-port br0 afxdp-p0

ovs-vsctl -- set interface afxdp-p0 type=dpdk \
     options:dpdk-devargs="vdev:net_af_packet,iface=afxdp-p0,blocksz=4096,framesz=2048,framecnt=512,qpairs=1,qdisc_bypass=0"

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add "10.1.1.1/24" dev p0
ip link set dev p0 up
NS_EXEC_HEREDOC

ovs-ofctl add-flow br0 "in_port=afxdp-p0, actions=actions=set_field:14->in_port,set_field:a0:36:9f:33:b1:40->dl_src,output:enp2s0f0np0"
ovs-ofctl add-flow br0 "in_port=enp2s0f0np0, actions=output:afxdp-p0"

ip link set afxdp-p0 xdpdrv obj /root/xdp_noop.o section xdp
ip netns exec at_ns0 /root/bpf-next/samples/bpf/xdp_rxq_info --action XDP_TX -d p0

