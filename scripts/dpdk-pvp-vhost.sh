#!/bin/bash
set -x 
rm -f /usr/local/etc/openvswitch/conf.db
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /root/ovs/vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --pidfile --detach

> /root/ovs/ovs-vswitchd.log

ovs-vsctl --no-wait init 
if [ "$1" == "gdb" ]; then
    gdb -ex=r --args ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl --disable-system
else
    ovs-vswitchd --no-chdir --pidfile --log-file=/root/ovs/ovs-vswitchd.log -vvconn -vofproto_dpif -vunixctl --disable-system --detach
fi
ovs-vsctl --no-wait set Open_vSwitch . other_config:dpdk-init=true
ovs-vsctl -- add-br br0 -- set Bridge br0 datapath_type=netdev other_config:pmd-cpu-mask=0xff

ovs-vsctl add-port br0 vhost-user-1 \
        -- set Interface vhost-user-1 type=dpdkvhostuserclient \
                     options:vhost-server-path=/tmp/vhost

ovs-vsctl add-port br0 enp2s0f0np0 -- set int enp2s0f0np0 type=dpdk \
    options:dpdk-devargs=0000:02:00.0

ovs-ofctl del-flows br0 
ovs-ofctl add-flow br0 "in_port=enp2s0f0np0, actions=vhost-user-1"
ovs-ofctl add-flow br0 "in_port=vhost-user-1, actions=enp2s0f0np0"

exit

# start VM using, OVS is the client
qemu-system-x86_64 -hda ubuntu1810.qcow -m 4096 -cpu host,+x2apic -enable-kvm \
-chardev socket,id=char1,path=/tmp/vhost,server \
-netdev type=vhost-user,id=mynet1,chardev=char1,vhostforce,queues=4  \
-device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
-object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
-numa node,memdev=mem -mem-prealloc -smp 2 -nographic
