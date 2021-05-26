# Figure 8(b) and Table 4: PVP

## Requirements
For running PVP tests, we first need to create a VM. There are many ways to
create VMs. Assume that you already have a VM image named
"ubuntu1810.qcow" and qemu installed.


## Kernel with tap
First, start a VM with tap device.
```shell
# VM1: tap + vhost kernel mode
qemu-system-x86_64 -hda ubuntu1810.qcow \
  -m 4096   -serial mon:stdio \
  -cpu host,+x2apic -enable-kvm \
  -device virtio-net-pci,mac=00:02:00:00:00:01,netdev=net0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=net0,vhost=on,queues=8 \
  -device virtio-net-pci,mac=00:02:00:00:00:02,netdev=xxx0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=xxx0,vhost=on,queues=8 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic
```
This will create a tap interface using vhost kernel mode.
Then start OVS kernel datapath by doing:
```shell
/usr/share/openvswitch/scripts/ovs-ctl start
ovs-vsctl add-br br0
# add physical NIC
ovs-vsctl add-port br0 enp2s0f0 # by default, it uses device's kernel driver
ovs-vsctl add-port br0 enp2s0f1
# add virtual device
ovs-vsctl add-port br0 tap0

# add PVP forwarding rule
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 "in_port=enp2s0f0, actions=output:tap0"
ovs-ofctl add-flow br0 "in_port=tap0, actions=output:enp2s0f1"
```
Start the TRex traffic generator and now, with the rule above, the packets
coming from enp2s0f0 will be forwarded to tap0 and arrives at VM.
You might want to check in the VM whether the packets arrived, by doing
```shell
# inside VM, assume interface name is ens4
tcpdump -n -i ens4 
```
Next, inside the VM, we need to forward/loopback the packets received from
ens4 to ens4's tx. You can do it by installing DPDK l2fwd in the VM.
Or use Linux kernel's xdp_rxq_info tool, ex:
```shell
Linux/samples/bpf/xdp_rxq_info --action XDP_TX -d ens4
```
Once the xdp_rxq_info is running, it will receive packet from ens4 and
send the packet back to ens4, which will arrive at OVS again.
Since we've installed the OpenFlow rules "in_port=tap0, actions=output:enp2s0f1",
the packet will be sent back to the TRex server.

Finally, we can observe the packet forwardnig rate and CPU utilization.

### Install xdp_rxq_info
The xdp_rxq_info tool is part of the Linux kernel source.
You can download and compile it by
```shell
git clone git://git.kernel.org/pub/scm/linux/kernel/git/bpf/bpf-next.git
cd bpf-next/samples/bpf/
# you might need to upgrade your clang and LLVM here...
make
```


## AF_XDP with tap
The setup is pretty much the same as above, kernel with tap. But instead of
running OVS kernel datapath, we have to switch to use OVS userspace datapath
with AF_XDP. First start the VM using the same command as above.
```shell
# VM1: tap + vhost kernel mode
qemu-system-x86_64 -hda ubuntu1810.qcow \
  -m 4096   -serial mon:stdio \
  -cpu host,+x2apic -enable-kvm \
  -device virtio-net-pci,mac=00:02:00:00:00:01,netdev=net0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=net0,vhost=on,queues=8 \
  -device virtio-net-pci,mac=00:02:00:00:00:02,netdev=xxx0,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -netdev type=tap,id=xxx0,vhost=on,queues=8 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic
```

This will create a tap interface using vhost kernel mode.
Then start OVS userspace datapath by doing:
```shell
ovsdb-tool create /usr/local/etc/openvswitch/conf.db /src/ovs/vswitchd/vswitch.ovsschema
ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options --pidfile --detach
ovs-vsctl --no-wai -- init
sleep 1

ovs-vswitchd --no-chdir --pidfile --log-file --disable-system --detach
ovs-vsctl show

# start OVS userspace datapath, "datapath_type=netdev"
ovs-vsctl add-br br0 -- set Bridge br0 protocols=OpenFlow10,OpenFlow11,OpenFlow12,OpenFlow13,OpenFlow14,OpenFlow15 fail-mode=secure datapath_type=netdev

# Use single HW queue
ethtool -L enp2s0f0 combined 1
ethtool -L enp2s0f1 combined 1

# Attach the port using AF_XDP type
ovs-vsctl add-port br0 enp2s0f0 -- set interface enp2s0f0 type=afxdp options:xdp-mode=best-effort
ovs-vsctl add-port br0 enp2s0f1 -- set interface enp2s0f1 type=afxdp options:xdp-mode=best-effort

# Attach the tap port
ovs-vsctl add-port br0 tap0
ovs-vsctl show
```

Then setup the OpenFlow rules.
```shell
# add PVP forwarding rule
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 "in_port=enp2s0f0, actions=output:tap0"
ovs-ofctl add-flow br0 "in_port=tap0, actions=output:enp2s0f1"
```
Then starts the TRex, and login to the VM to setup loopback forwarding using
xdp_rxq_info. Finally, measure the performance.


## AF_XDP with vhostuser
This setup uses vhostuser interface for OVS, see OVS's official
[vhostuser doc](https://docs.openvswitch.org/en/latest/topics/dpdk/vhost-user/).
First, start VM using vhostuser interface
```shell
# VM: vhostuserclient mode, set the type=vhost-user and socket path to /tmp/vhost
qemu-system-x86_64 -hda ubuntu1810.qcow \
  -m 4096 \
  -cpu host,+x2apic -enable-kvm \
  -chardev socket,id=char1,path=/tmp/vhost,server \
  -netdev type=vhost-user,id=mynet1,chardev=char1,vhostforce,queues=4  \
  -device virtio-net-pci,mac=00:00:00:00:00:01,netdev=mynet1,mq=on,vectors=10,mrg_rxbuf=on,rx_queue_size=1024 \
  -object memory-backend-file,id=mem,size=4096M,mem-path=/dev/hugepages,share=on \
  -numa node,memdev=mem -mem-prealloc -smp 2 -nographic
```
For this experiment, we are using OVS AF_XDP for the physical interface (enp2s0f0 and enp2s0f1)
and using OVS-DPDK's implementation of vhostuser. As a result, we need to build OVS with
both AF_XDP support and DPDK support.
* Follow the [OVS-DPDK](https://docs.openvswitch.org/en/latest/intro/install/dpdk/) build instruction
* When doing "configure", add additional "--enable-afxdp" to it.
example:
```shell
./configure --with-dpdk=static --enable-afxdp
make && make install
```

Once OVS with AF_XDP and DPDK is ready, create bridge br0 and attach the vhostuser port.
```shell
# Attach an AF_XDP port
ovs-vsctl add-port br0 enp2s0f0 -- set interface enp2s0f0 type=afxdp options:xdp-mode=best-effort
ovs-vsctl add-port br0 enp2s0f1 -- set interface enp2s0f1 type=afxdp options:xdp-mode=best-effort

# Attach the vhostuser port
ovs-vsctl add-port br0 vhost-user-1 \
        -- set Interface vhost-user-1 type=dpdkvhostuserclient \
         options:vhost-server-path=/tmp/vhost
ovs-vsctl show

# add PVP forwarding rule
ovs-ofctl del-flows br0
ovs-ofctl add-flow br0 "in_port=enp2s0f0, actions=output:vhost-user-1"
ovs-ofctl add-flow br0 "in_port=vhost-user-1, actions=output:enp2s0f1"
```
The rest steps (start TRex, setup VM, and measure performance) are the same as previous. 


## DPDK with vhostuser
The only difference in this setup is to also use DPDK on the physical port
(enp2s0f0 and enp2s0f1). So following the steps above, but when attaching
the port, use
```shell
ovs-vsctl add-port br0 enp2s0f0 -- set int enp2s0f0 type=dpdk \
    options:dpdk-devargs=0000:02:00.0
ovs-vsctl add-port br0 enp2s0f0 -- set int enp2s0f0 type=dpdk \
    options:dpdk-devargs=0000:02:00.0
# ... rest are the same
```
