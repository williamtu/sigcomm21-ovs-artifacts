#!/bin/sh

set -ex

ovsdb-tool create /usr/local/etc/openvswitch/conf.db /src/ovs/vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach

ovs-vsctl --no-wait init
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true \
	other_config:pmd-cpu-mask=0x1
ovs-vswitchd --no-chdir --pidfile --log-file --disable-system --detach

# start OVS userspace datapath, "datapath_type=netdev"
#ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type=netdev

# try attach an DPDK port
# ovs-vsctl add-port br0 eth0 -- set interface eth0 type=dpdk

ovs-vsctl show

