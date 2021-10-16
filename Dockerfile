# This Dockerfile tests building OVS with AF_XDP,starting OVS userspace
# datapath, and attaching an af_xdp port
#
# HOWTO:
# docker build . 
# docker run --privileged -it 654d284db02b /bin/bash
# root@75bbf4f7faff:/src/ovs# /start-ovs.sh 

# Use Ubuntu 21.04 which has kernel support for AF_XDP
FROM ubuntu:21.04

ARG OVS_VERSION=v2.14.2
ADD https://github.com/openvswitch/ovs/archive/${OVS_VERSION}.tar.gz /src/

WORKDIR /src
RUN mkdir -p /src/ovs
RUN tar --strip-components=1 -C ovs -xvf ${OVS_VERSION}.tar.gz

WORKDIR /src/ovs

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install autoconf automake libtool libcap-ng-dev libssl-dev \
    python3-pip python3-openssl libelf-dev python3-setuptools python3-wheel python3-sphinx libnuma-dev

# libbpf is required when using OVS with AF_XDP
RUN apt-get -y install libbpf-dev
RUN apt-get -y install vim build-essential
RUN apt-get -y install man-db

RUN ./boot.sh
RUN ./configure --enable-afxdp

# Build OVS with AF_XDP support
RUN make -j2 && make install

RUN apt-get -y install iproute2

# Setup OVSDB
RUN mkdir -p /usr/local/etc/openvswitch/ && mkdir -p /usr/local/var/run/openvswitch/ && \
    mkdir -p /usr/local/var/log/openvswitch/

# Start OVS
ADD start-ovs.sh /

#ENTRYPOINT ["/start-ovs.sh"]
CMD ["/start-ovs.sh"]


