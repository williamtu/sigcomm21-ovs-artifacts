#!/bin/bash
set -x
modprobe openvswitch
ovs-dpctl add-dp br0 

ovs-dpctl add-if br0 enp2s0f0np0

ip netns add at_ns0
ip link add p0 type veth peer name afxdp-p0
ip link set p0 netns at_ns0
ip link set dev afxdp-p0 up
ovs-dpctl add-if br0 afxdp-p0

ip netns exec at_ns0 sh << NS_EXEC_HEREDOC
ip addr add "10.1.1.1/24" dev p0
ip link set dev p0 up
NS_EXEC_HEREDOC

ovs-dpctl add-flow br0 "in_port(2),eth()" 1
ovs-dpctl add-flow br0 "in_port(1),eth()" 2

ip link set afxdp-p0 xdpdrv obj /root/xdp_noop.o section xdp
ip netns exec at_ns0 /root/bpf-next/samples/bpf/xdp_rxq_info --action XDP_TX -d p0

