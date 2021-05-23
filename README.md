# Artifacts for SIGCOMM 2021 Open vSwitch

## Introduction
AF_XDP, Address Family of the eXpress Data Path, is a new Linux socket type
built upon the eBPF and XDP technology.  It aims to have comparable
performance to DPDK but cooperate better with existing kernel's networking
stack.  An AF_XDP socket receives and sends packets from an eBPF/XDP program
attached to the netdev, by-passing a couple of Linux kernel's subsystems.
As a result, AF_XDP socket shows much better performance than AF_PACKET.
For more details about AF_XDP, please see linux kernel's
[af_xdp documentation](https://www.kernel.org/doc/html/latest/networking/af_xdp.html)

## Building Open vSwitch with AF_XDP
All the source code used in the paper has been upstreamed to the public
Open vSwitch [github repo](https://github.com/openvswitch/ovs).
Please follow the official documentation to install
OVS with AF_XDP at [here](https://docs.openvswitch.org/en/latest/intro/install/afxdp/)

## Measuring Performance with AF_XDP



## OpenFlow dataset
