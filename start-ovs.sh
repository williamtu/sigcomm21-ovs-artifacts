#!/bin/sh

set -ex

ovsdb-tool create /usr/local/etc/openvswitch/conf.db /src/ovs/vswitchd/vswitch.ovsschema

ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach

ovs-vsctl --no-wai -- init
sleep 1

ovs-vswitchd --no-chdir --pidfile --log-file --disable-system --detach

ovs-vsctl show 

ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type=netdev

ovs-vsctl add-port br0 eth0 -- set interface eth0 type=afxdp options:xdp-mode=generic

ovs-vsctl show

