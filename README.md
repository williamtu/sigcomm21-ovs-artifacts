# Revisiting the Open vSwitch Dataplane Ten Years Later

This is the artifacts page for the SIGCOMM2021 paper, Revisiting the Open vSwitch Dataplane Ten Years Later.
We provide
* VMware NSX OpenFlow and OVSDB dataset (Section 5.1 and Table 3).
* Instructions for building OVS with AF_XDP and DPDK, and how to reproduce the performance
  number (Section 5.2 and Figure 8).

## NSX and OpenFlow dataset (Section 5.1)
* [dataset/ovs-ofctl-dump-flows.out.decoded](dataset/ovs-ofctl-dump-flows.out.decoded):
  OpenFlow tables and rules installed at Linux host.
* [dataset/ovs-vsctl-show.out](dataset/ovs-vsctl-show.out):
  Configurations of OVS bridges, tunnels, and interfaces.
* [dataset/nsx-openflow-pipeline.txt](dataset/nsx-openflow-pipeline.txt):
  The text explanation of the OpenFlow pipeline.

If you're familar with Docker, use the [dataset/Dockerfile](dataset/Dockerfile) to automatically
run OVS and load the dataset of OpenFlow rules, by doing
```shell
  docker build dataset/ 
  docker run --privileged -it <image id> /bin/bash
  root@<image id>:/src/ovs# cd ../;
  root@<image id>:/src# ./start-ovs-dataset.sh 
  root@<image id>:/src# ovs-ofctl dump-flows nsx-managed
```
Note that Section 5.1 in the paper is a testbed with 100 hypervisors. Here we are simply
reproducing one server and loading the configurations mentioned in Table 3.
We can successfully load all the OpenFlow rules, but it's expected that some of the tunnel
interfaces are down or not existed.
Even if we can manually create similar setup, the performance number might differ.
Due to this reason, we don't provde instructions to reproduce figure 7.

## Packet Forwarding Rate (Section 5.2)
This section explains how to setup and create results in section 5.2 and figure 8.
## Testbed Configuration
In the paper, we use two machines connected back-to-back (see Section 5.2).
With one Xeon E5 2620 v3 12-core 2.4GHz connected back-to-back through dual-port 25-Gbps Mellanox Connect-X 6Dx NICs. One server ran the TRex traffic generator, the other ran OVS with different datapaths and packet I/O configurations as well as a VM with 2 vCPUs and 4 GB memory. We tested three scenarios, all loopback configurations in which a server receives packets from TRex on one NIC port, forwards them internally across a scenario-specific path, and then sends them back to it on the other.
We measured OVS performance with the in-kernel datapath, with AF_XDP, and with DPDK.
![](testbed.png)

## Hardware Requirements
Figure 8(a) requires two physical machines connected back-to-back. In our paper,
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

Once the TRex traffic-gen server is ready, we can move on to setup the
other machine, theOVS running server. Follow the information below:
* Figure 8(a): [P2P](fig8a.md)
* Figure 8(b): [PVP](fig8b.md)
* Figure 8(c): [PCP](fig8c.md)


## Building Open vSwitch with AF_XDP
Most of the source code used in the paper has been upstreamed to the public
Open vSwitch [github repo](https://github.com/openvswitch/ovs) at the commit
[AF_XDP](https://github.com/openvswitch/ovs/commit/0de1b425962db073ebbaa3ddbde445580afda840)
Please follow the official documentation to install
OVS with AF_XDP at [here](https://docs.openvswitch.org/en/latest/intro/install/afxdp/)

If you're familar with Docker, use the [Dockerfile](Dockerfile) to automatically
build and run OVS with AF_XDP, by doing
```shell
  docker build . 
  docker run --privileged -it <image id> /bin/bash
  root@<image id>:/src/ovs# /start-ovs.sh 
```
