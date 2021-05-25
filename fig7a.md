# Figure 7(a) VM-to-VM Cross Host

## Hardware Requirements
Figure 7(a) requires two physical machines connected back-to-back. In our paper,
we're using two dual-port Mellanox Connect-X 6Dx cards connected back-to-back
to form a loop. You can use NIC from other vendors such as Intel i40e.
In short, you need one server as traffic generator, called TRex server,
the other server runs OVS. For the servier running OVS, we recommend having
Linux kernel 5.4+ or simply using Ubuntu 21.04.

## The TRex Traffic generator
We use one machine as traffic generator and install [TRex](https://trex-tgn.cisco.com/)
, [TRex installation](https://trex-tgn.cisco.com/trex/doc/trex_manual.html#_first_time_running).

#```shell
#docker pull trexcisco/trex                                   
#d cker run --rm -it --privileged --cap-add=ALL trexcisco/trex:latest  
#root@]./t-rex-64 -i                                    
#```
Assume that your TRex server has physical interface name 'enp2s0f0' at PCI slot
02:00.0 and 'enp2s0f1' at PCI slot 02:00.1, configure the TRex to send traffic
to enp2s0f0 (port 0) and receive from enp2s0f1 (port 1. Example TRex
configurations is below:
```yaml
# cat /etc/trex_cfg.yaml
- port_limit      : 2                                                           
  version         : 2                                                           

#List of interfaces. Change to suit your setup. Use ./dpdk_setup_ports.py -s to see available options
  interfaces    : ["02:00.0", "02:00.1"]                                        
  port_info       :  # Port IPs. Change to suit your needs. In case of loopback, you can leave as is.
          - dest_mac   : 'e4:11:22:33:44:50'                                    
            src_mac    : '1c:34:da:64:3b:b4'                                    
          - dest_mac   : 'e4:11:c6:d3:45:f2'                                    
            src_mac    : '1c:34:da:64:3b:b5'                                    
          - ip         : 2.2.2.2                                               
            default_gw : 1.1.1.1       
```
After install TRex and its configuration, run command to send 64-byte packet to
port 0 and receive on port 1.
```shell
./t-rex-64 -f cap2/imix_64.yaml -c 1 -m 150 -d 1000 -l 1000
```
To verify the packets are arriving at the OVS server, run
```shell
sar -n DEV 1
```
or
```shell
ip link -s 
```
To see the packets statistics on all network devices on OVS server.

## The OVS running server
Here we assume OVS server also has a dual-port NIC, with two interface
'enp2s0f0' and 'enp2s0f1'. The server needs to install OVS first.

### kernel + tap/veth (csum and TSO)
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
set -x
modprobe openvswitch
ovs-dpctl add-dp br0 
ovs-dpctl add-if br0 enp2s0f0np0
ovs-dpctl add-flow br0 "in_port(1),eth()" 1
```
### Build userspace datapath
```shell
apt-get update && \
apt-get -y install autoconf automake libtool libcap-ng-dev \
           libssl-dev python3-pip python3-openssl libelf-dev python3-setuptools \
           python3-wheel python3-sphinx libnuma-dev

# Install LIBBPF
apt-get -y install libbpf-dev
```
* Build OVS with kernel datapath
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

### AF_XDP + tap/veth (interrupt)
### AF_XDP + tap/veth (polling)
### AF_XDP + vhostuser (no offload)
### AF_XDP + vhostuser (csum offload)

