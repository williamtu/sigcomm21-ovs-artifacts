# Figure 7(b) VM-to-VM within Host

## kernel + tap/veth (csum and TSO)
There are many ways to create VMs. Assume that you already have a VM image named
"ubuntu1810.qcow" and qemu installed. Run below command to start two VMs, VM1 and VM2.

```shell
# VM1: tap + vhost kernel mode
qemu-system-x86_64 -hda ubuntu1810-1.qcow \
  -m 4096   -serial mon:stdio \
  -cpu host,+x2apic -enable-kvm \
  -device virtio-net-pci,mac=00:02:00:00:00:01,netdev=net0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=net0,vhost=on,queues=8 \
  -device virtio-net-pci,mac=00:02:00:00:00:02,netdev=xxx0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=xxx0,vhost=on,queues=8 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic

# VM2
qemu-system-x86_64 -hda ubuntu1810-2.qcow \
  -m 4096   -serial mon:stdio \
  -cpu host,+x2apic -enable-kvm \
  -device virtio-net-pci,mac=00:02:00:00:00:11,netdev=net0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=net0,vhost=on,queues=8 \
  -device virtio-net-pci,mac=00:02:00:00:00:12,netdev=xxx0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=xxx0,vhost=on,queues=8 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic
```

This will create a tap interface for each VM1 and VM2, using vhost kernel mode.
Then start OVS kernel datapath by doing:
```shell
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /src/ovs/vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
ovs-vsctl --no-wai -- init
ovs-vswitchd --no-chdir --pidfile --log-file --detach
ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure
ovs-vsctl add-port br0 tap0 # tap0 is created by VM1
ovs-vsctl add-port br0 tap1 # tap1 is created by VM2
ovs-ofctl add-flow br0 "actions=noraml"
```
Next, login to VM1 and run iperf TCP. By default, the checksum offload is
enabled as well as TSO. This will reproduce the Figure 7(a) csum and TSO.


## AF_XDP + tap/veth (no offload)
Since this is using the tap/veth kernel interface, follow the same VM creation
instructions above to create VM1 and VM2.
However, this time, instead of using OVS kernel datapath, we start OVS using
OVS userspace datapath. By doing:
```shell
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /src/ovs/vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach --disable-system
ovs-vsctl --no-wai -- init
ovs-vswitchd --no-chdir --pidfile --log-file --detach

# datapath_type=netdev means userspace datapath
ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type=netdev

# attach tap interface for VM1 and VM2
ovs-vsctl add-port br0 tap0 # tap0 is created by VM1
ovs-vsctl add-port br0 tap1 # tap1 is created by VM2
ovs-ofctl add-flow br0 "actions=noraml"
```
By default, the checksum offload is enabled.
So we need to login to VM1 and VM2 to disable csum/tso offload. By doing:
```shell
ethtool -i eth0 tx off
```
Finally, login to VM1 and run iperf TCP. 


## AF_XDP + vhostuser (no offload)
Similarly, start two VMs. But this time, instead of using tap, uses vhostuser,
with vhost socket path at /tmp/vhost
```shell
# VM1: vhostuserclient mode
qemu-system-x86_64 -hda ubuntu1810.qcow \
  -m 4096 \
  -cpu host,+x2apic -enable-kvm \
  -chardev socket,id=char1,path=/tmp/vhost1,server \
  -netdev type=vhost-user,id=mynet1,chardev=char1,vhostforce,queues=4  \
  -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic

# VM2: vhostuserclient mode
qemu-system-x86_64 -hda ubuntu1810.qcow \
  -m 4096 \
  -cpu host,+x2apic -enable-kvm \
  -chardev socket,id=char1,path=/tmp/vhost2,server \
  -netdev type=vhost-user,id=mynet1,chardev=char1,vhostforce,queues=4  \
  -device virtio-net-pci,mac=00:00:00:00:00:02,netdev=mynet1,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic
```

The VM1 and VM2 will wait for OVS vhostuser port to connect to the socket.
Now start userspace OVS by doing:

```shell
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /src/ovs/vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach --disable-system
ovs-vsctl --no-wai -- init
ovs-vswitchd --no-chdir --pidfile --log-file --detach
ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type=netdev
ovs-vsctl add-port br0 vhost-user-1 \
        -- set Interface vhost-user-1 type=dpdkvhostuserclient \
                     options:vhost-server-path=/tmp/vhost1
ovs-vsctl add-port br0 vhost-user-2 \
        -- set Interface vhost-user-2 type=dpdkvhostuserclient \
                     options:vhost-server-path=/tmp/vhost2
ovs-ofctl add-flow br0 "actions=noraml"
ovs-vsctl show
```
By default, the checksum offload is enabled.
So we need to login to VM1 and VM2 to disable csum/tso offload. By doing:
```shell
ethtool -i eth0 tx off
```
Finally, login to VM1 and run iperf TCP. 


## AF_XDP + vhostuser (csum offload)
This is the same as above, but do not turn off the offload feature.
Or explicitly enable tx offload by 
```shell
ethtool -i eth0 tx on
```
Then measure the iperf performance between two VMs.
