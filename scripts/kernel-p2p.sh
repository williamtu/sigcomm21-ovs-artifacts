#!/bin/bash
set -x
modprobe openvswitch
ovs-dpctl add-dp br0 

ovs-dpctl add-if br0 enp2s0f0np0
ovs-dpctl add-flow br0 "in_port(1),eth()" 1

