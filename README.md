# Revisiting the Open vSwitch Dataplane Ten Years Later

This is the artifacts page for the SIGCOMM2021 paper,
[Revisiting the Open vSwitch Dataplane Ten Years Later](sigcomm2021-paper300.pdf).
We provide
* VMware NSX OpenFlow and OVSDB dataset (Section 5.1 and Table 3).
* Instructions for building OVS with AF_XDP and DPDK, and how to reproduce the performance
  number (Section 5.2 and Figure 8).
* Rough instructions for Section 5.3, Figure 9 and 10.
* Section 5.4 is skipped, because it requires using another project, [p4c-xdp](https://github.com/vmware/p4c-xdp)

## Building Open vSwitch with AF_XDP
Most of the source code used in the paper has been upstreamed to the public
Open vSwitch [github repo](https://github.com/openvswitch/ovs) at the commit
[AF_XDP](https://github.com/openvswitch/ovs/commit/0de1b425962db073ebbaa3ddbde445580afda840)
Please follow the official documentation to install
OVS with AF_XDP at [here](https://docs.openvswitch.org/en/latest/intro/install/afxdp/)

If you're familar with Docker, use the [Dockerfile](Dockerfile) to automatically
build and run OVS with AF_XDP, by doing either:
```shell
  docker pull u9012063/ovs-afxdp:latest
  docker run -it <image id> /bin/bash
  root@<image id>:/src/ovs# /start-ovs.sh
```
Or, if you want to build the image by yourself:
```shell
  docker build . 
  docker run --privileged -it <image id> /bin/bash
  root@<image id>:/src/ovs# /start-ovs.sh 
```


## NSX and OpenFlow dataset (Section 5.1)
* [dataset/ovs-ofctl-dump-flows.out.decoded](dataset/ovs-ofctl-dump-flows.out.decoded):
  OpenFlow tables and rules installed at Linux host. Around 100k OpenFlow rules using 40
  OpenFlow tables.
* [dataset/ovs-vsctl-show.out](dataset/ovs-vsctl-show.out):
  Configurations of OVS bridges, tunnels, and interfaces.
* [dataset/nsx-openflow-pipeline.txt](dataset/nsx-openflow-pipeline.txt):
  The text explanation of the OpenFlow pipeline.

If you're familar with Docker, use the [dataset/Dockerfile](dataset/Dockerfile) to automatically
run OVS and load the dataset of OpenFlow rules, by doing either:
```shell
  docker pull u9012063/ovs-dataset:latest
```
Or, if you prefer building your own image:
```shell
  docker build dataset/
```
Then you can start using it by:
```
  docker run --privileged -it <image id> /bin/bash # don't forget --privileged
  root@<image id>:/src# ./start-ovs-dataset.sh 
  # it takes around 60 sec to load around 51k OpenFlow rules
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

The Mellanox card has different XDP design than Intel's cards.
See how to setup Mellanox card for AF_XDP [here](afxdp_mlx.md)
## The TRex Traffic generator
We use one machine as traffic generator and install [TRex](https://trex-tgn.cisco.com/)
. See [TRex installation guide](https://trex-tgn.cisco.com/trex/doc/trex_manual.html#_first_time_running).
Assume that your TRex server has physical interface name 'enp2s0f0' at PCI slot
02:00.0 and 'enp2s0f1' at PCI slot 02:00.1, configure the TRex to send traffic
to enp2s0f0 (port 0) and receive from enp2s0f1 (port 1). Example TRex
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
* Figure 8(a): [P2P: Physical-to-Physical](fig8a.md)
* Figure 8(b): [PVP: Physical-to-Virtual-to-Physical](fig8b.md)
* Figure 8(c): [PCP: Physical-to-Container-to-Physical](fig8c.md)


## Section 5.3 Latency and Transaction Rate
Section 5.3, figure 9(a) is pretty much the same as creating figure 8,
using the three configurations: kernel, AF_XDP, and DPDK.
However, instead of using TRex packet generator, we run netperf on
the TRex server
```shell
netperf -H 192.168.12.189 -t TCP_RR --   -o
min_latency,max_latency,mean_latency,stddev_latency,transaction_rate,P50_LATENCY,P90_LATENCY,P99_LATENCY
```
and assign IP 192.168.12.189 inside the VM.
Section 5.3, figure 9(b) requires only one physical server, with another VM in the same host.
Follow the similar instructions to create another VM with tap/af_xdp/vhostuer interface
attached to OVS bridge. And use netperf to measure the performance numbers.

## Questions?
Feel free to create a ticket or PR in this github repo!
