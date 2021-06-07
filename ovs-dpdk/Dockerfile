# This Dockerfile tests building OVS with DPDK and starting
# the OVS-DPDK with userspace datapath. Tutorial is at:
#   https://docs.openvswitch.org/en/latest/intro/install/dpdk/
#
# HOWTO:
# docker build -t ovs-dpdk ovs-dpdk/
# docker run --privileged -it <image id>
#
# Ususally you have to setup physical machine with hugepages.
# If you run it inside a VM, it will build successfully, but when start,
# expected error like below:
# 2021-06-07T20:25:39Z|00015|dpdk|INFO|EAL: Detected static linkage of DPDK
# 2021-06-07T20:25:39Z|00016|dpdk|INFO|EAL: Multi-process socket /var/run/dpdk/rte/mp_socket
# 2021-06-07T20:25:39Z|00017|dpdk|INFO|EAL: Selected IOVA mode 'PA'
# 2021-06-07T20:25:39Z|00018|dpdk|WARN|EAL: No available hugepages reported in hugepages-2048kB
# 2021-06-07T20:25:39Z|00019|dpdk|WARN|EAL: No available hugepages reported in hugepages-1048576kB
# EAL: FATAL: Cannot get hugepage information.
# 2021-06-07T20:25:39Z|00020|dpdk|ERR|EAL: Cannot get hugepage information.
# 2021-06-07T20:25:39Z|00021|dpdk|EMER|Unable to initialize DPDK: Permission denied
FROM ubuntu:21.04

ARG OVS_VERSION=v2.15.0
ENV DPDK_DIR=/usr/src/dpdk-stable-20.11.1
ENV DPDK_BUILD=/usr/src/dpdk-stable-20.11.1/build

# Download and install DPDK
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install autoconf automake libtool libcap-ng-dev libssl-dev \
    python3-pip python3-openssl libelf-dev python3-setuptools python3-wheel python3-sphinx libnuma-dev \
    sudo pkg-config iproute2 meson wget tar xz-utils

RUN cd /usr/src/ &&  wget https://fast.dpdk.org/rel/dpdk-20.11.1.tar.xz && \
    tar xf dpdk-20.11.1.tar.xz

RUN cd $DPDK_DIR; meson build && ninja -C build
RUN cd $DPDK_DIR; sudo ninja -C build install && sudo ldconfig

RUN pkg-config --modversion libdpdk

# Download and install OVS
WORKDIR /src
RUN wget https://github.com/openvswitch/ovs/archive/${OVS_VERSION}.tar.gz
RUN mkdir -p /src/ovs
RUN tar --strip-components=1 -C ovs -xvf ${OVS_VERSION}.tar.gz

WORKDIR /src/ovs

# Enable OVS with DPDK
RUN ./boot.sh && ./configure --with-dpdk=static

# Build OVS with AF_XDP support
RUN make -j2 && make install

# Setup OVSDB
RUN mkdir -p /usr/local/etc/openvswitch/ && mkdir -p /usr/local/var/run/openvswitch/ && \
    mkdir -p /usr/local/var/log/openvswitch/

# Start OVS
ADD ../start-ovs-dpdk.sh /

ENTRYPOINT ["/start-ovs-dpdk.sh"]
CMD ["/start-ovs-dpdk.sh"]
