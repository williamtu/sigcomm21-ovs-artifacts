# Figure 7(a) VM-to-VM Cross Host

## Hardware Requirements
Figure 7(a) requires two physical machines connected back-to-back. In our paper,
we're using two dual-port Mellanox Connect-X 6Dx cards connected back-to-back
to form a loop. You can use NIC from other vendors such as Intel i40e.
For the servier running OVS, we recommend having Linux kernel 5.4+ or simply
using Ubuntu 21.04.

## The TRex Traffic generator
We use one machine as traffic generator and install [TRex](https://trex-tgn.cisco.com/)
and [TRex installation](https://trex-tgn.cisco.com/trex/doc/trex_manual.html#_first_time_running).

```shell
docker pull trexcisco/trex                                   
d cker run --rm -it --privileged --cap-add=ALL trexcisco/trex:latest  
root@]./t-rex-64 -i                                    
```
Assume that you have physical interface name 'enp2s0f0' at PCI slot 02:00.0
and 'enp2s0f1' at PCI slot 02:00.1, configure the Trex to send traffic to
enp2s0f0 and receive from enp2s0f1. Example TRex configurations

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
          #- ip         : 2.2.2.2                                               
          #  default_gw : 1.1.1.1       
```
After install TRex and its configuration, run command to send 64-byte packet to
port 0 and receive on port1.
```shell
./t-rex-64 -f cap2/imix_64.yaml -c 1 -m 150 -d 1000 -l 1000
```
The following sections are configurations of OVS server.

## The OVS running server
Here we assume OVS server also has a dual-port NIC, with two interface 'enp2s0f0'
and 'enp2s0f1'.

### kernel + tap/veth (csum and TSO)

```bash
set -x
modprobe openvswitch
ovs-dpctl add-dp br0 
ovs-dpctl add-if br0 enp2s0f0np0
ovs-dpctl add-flow br0 "in_port(1),eth()" 1
```

### AF_XDP + tap/veth (interrupt)
### AF_XDP + tap/veth (polling)
### AF_XDP + vhostuser (no offload)
### AF_XDP + vhostuser (csum offload)

