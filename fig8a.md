# Figure 8(a) P2P and Table 4: Physical-to-Physical 
Here we are setting up the server running OVS.
We assume OVS server also has a dual-port NIC, with two interface
'enp2s0f0' and 'enp2s0f1'. The server needs to install or configure
three different OVS to reproduce the results, which are:
* Kernel datapath
* Userspace datapath with AF_XDP
* Userspace datapath with DPDK


## Kernel Datapath
First, install openvswitch packages from the Ubuntu, by doing
```shell
apt-get install openvswitch-switch openvswitch-common
/usr/share/openvswitch/scripts/ovs-ctl start
```
This will start ovs-vswitchd and load the ovs kernel module.
Double check it by doing
```shell
lsmod | grep openvswitch
```
Then create a bridge br0, attach the physical NIC to br0, and

```bash
ovs-vsctl add-br br0
ovs-vsctl add-port br0 enp2s0f0
ovs-vsctl add-port br0 enp2s0f1
ovs-ofctl del-flows br0
# add P2P forwarding rule
ovs-ofctl add-flow br0 "in_port=enp2s0f0, actions=output:enp2s0f1"
```
Then start the TRex at the other server and measure the forwarding rate.
To collect the CPU utilizations shown in Table 4, use:
```shell
mpstat -u -P ALL <interval>
```
After finishing, cleanup by doing
```
/usr/share/openvswitch/scripts/ovs-ctl stop
apt-get remove openvswitch-switch openvswitch-common
```


## Userspace Datapath with AF_XDP
Userspace Datapath with AF_XDP does not come with the Linux distribution, so
we have to build it from our source code.
* Install required packages
```shell
apt-get update && \
apt-get -y install autoconf automake libtool libcap-ng-dev \
           libssl-dev python3-pip python3-openssl libelf-dev python3-setuptools \
           python3-wheel python3-sphinx libnuma-dev

# Install LIBBPF
apt-get -y install libbpf-dev
```
* Build OVS v2.15 with AF_XDP (--enable-afxdp)
```shell
OVS_VERSION=v2.15.0
wget https://github.com/openvswitch/ovs/archive/${OVS_VERSION}.tar.gz
mkdir -p ovs
tar --strip-components=1 -C ovs -xvf ${OVS_VERSION}.tar.gz
cd ovs
./boot.sh
./configure --enable-afxdp
make -j2 && make install
```

* start OVS, create bridge br0, and attach physical nic.
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

# Attach an AF_XDP port
ovs-vsctl add-port br0 enp2s0f0 -- set interface enp2s0f0 type=afxdp options:xdp-mode=best-effort
ovs-vsctl add-port br0 enp2s0f1 -- set interface enp2s0f1 type=afxdp options:xdp-mode=best-effort
ovs-vsctl show
```
Finally, install the OpenFlow rules and start the TRex traffic gen.
```shell
ovs-ofctl del-flows br0
# add P2P forwarding rule
ovs-ofctl add-flow br0 "in_port=enp2s0f0, actions=output:enp2s0f1"
```


## Userspace Datapath with DPDK
You can build your own OVS-DPDK by following the OVS official document
[here](https://docs.openvswitch.org/en/latest/intro/install/dpdk/).

Once OVS-DPDK is installed, follow the similar steps as above:
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

ovs-vsctl add-port br0 enp2s0f0 -- set int enp2s0f0 type=dpdk \
    options:dpdk-devargs=0000:02:00.0
ovs-vsctl add-port br0 enp2s0f1 -- set int enp2s0f1 type=dpdk \
    options:dpdk-devargs=0000:02:00.1

# Add P2P forwarding rule
ovs-ofctl add-flow br0 \
"in_port=enp2s0f0, actions=output:enp2s0f1"
``` 
#Another way is to use Ubuntu 21.04 openvswitch-switch-dpdk packages,
#by doing
#```
#apt-get -y install openvswitch-switch-dpdk






