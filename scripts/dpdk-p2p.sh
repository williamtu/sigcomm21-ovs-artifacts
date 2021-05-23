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
ethtool -L enp2s0f0np0 combined 1


ovs-vsctl add-port br0 enp2s0f0np0 -- set int enp2s0f0np0 type=dpdk \
    options:dpdk-devargs=0000:02:00.0

ovs-ofctl add-flow br0 \
"in_port=enp2s0f0np0, actions=set_field:14->in_port,output:enp2s0f0np0"
#"in_port=enp2s0f0np0, actions=set_field:14->in_port,set_field:a0:36:9f:33:b1:40->dl_src,output:enp2s0f0np0"


