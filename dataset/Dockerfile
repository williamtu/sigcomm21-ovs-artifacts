# This Dockerfile installs distro's openvswitch package.
# The start-ovs-with-dataset.sh starts OVS kernel datapath
# and load the NSX configurations and OpenFlow rule set.

# HOWTO:
# docker build . 
# docker run --privileged -it 654d284db02b /bin/bash
# root@75bbf4f7faff:/src# ./start-ovs-with-dataset.sh 

# Use Ubuntu 21.04 which has kernel support for AF_XDP
FROM ubuntu:21.04


WORKDIR /src

# libbpf is required when using OVS with AF_XDP
RUN apt-get update
RUN apt-get -y install openvswitch-common openvswitch-switch
RUN apt-get -y install iproute2

# Start OVS
ADD . /src/
CMD ["/src/start-ovs-with-dataset.sh"]
