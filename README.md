# Artifacts for Revisiting the Open vSwitch Dataplane Ten Years Later

## Introduction
AF_XDP, Address Family of the eXpress Data Path, is a new Linux socket type
built upon the eBPF and XDP technology.  It aims to have comparable
performance to DPDK but cooperate better with existing kernel's networking
stack.  An AF_XDP socket receives and sends packets from an eBPF/XDP program
attached to the netdev, by-passing a couple of Linux kernel's subsystems.
As a result, AF_XDP socket shows much better performance than AF_PACKET.
For more details about AF_XDP, please see linux kernel's
[AF_XDP documentation](https://www.kernel.org/doc/html/latest/networking/af_xdp.html)

## Building Open vSwitch with AF_XDP
All the source code used in the paper has been upstreamed to the public
Open vSwitch [github repo](https://github.com/openvswitch/ovs).
Please follow the official documentation to install
OVS with AF_XDP at [here](https://docs.openvswitch.org/en/latest/intro/install/afxdp/)

## Measuring Performance with AF_XDP (Section 5.2, Figure 8 in the paper)
Once OVS with AF_XDP is successfully built, we provide several scripts to
reproduce the results in the paper. Specifically, for
* Linux kernel datapath
  * [scripts/kernel-p2p.sh](scripts/kernel-p2p.sh):
    a setup for forwarding packets from a physical port to OVS and a physical port.
  * [scripts/kernel-pvp.sh](scripts/kernel-pvp.sh):
    a setup for forwarding packets from a physical port to OVS, to a virtual port for a VM,
    and loopback to the same virtual port, to OVS, and finally a physical port.
  * [scripts/kernel-pcp.sh](scripts/kernel-pcp.sh):
    a setup for forwarding packets from a physical port to OVS, to a container virtual port,
    and loopback to the same container virtual port, to OVS, and finally a physical port.

* OVS Userspace Datapath with DPDK
  * [scripts/dpdk-p2p.sh](scripts/dpdk-p2p.sh): Same as above, but using userspace datapath with DPDK port.
  * [scripts/dpdk-pvp.sh](scripts/dpdk-pvp.sh): Same as above, but using userspace datapath with DPDK port.
  * [scripts/dpdk-pcp.sh](scripts/dpdk-pcp.sh): Same as above, but using userspace datapath with DPDK port.

* OVS Userspace Datapath with AF_XDP
  * [scripts/afxdp-p2p.sh](scripts/afxdp-p2p.sh): Same as above, but using userspace datapath with OVS AF_XDP port.
  * [scripts/afxdp-pvp.sh](scripts/afxdp-pvp.sh): Same as above, but using userspace datapath with OVS AF_XDP port.
  * [scripts/afxdp-pcp.sh](scripts/afxdp-pcp.sh): Same as above, but using userspace datapath with OVS_AF_XDP port.

See section 5.2 and Figure 8 in the paper for details.

## OpenFlow dataset
