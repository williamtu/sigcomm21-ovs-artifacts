FROM ubuntu:21.04

ARG OVS_VERSION=v2.15.0

ADD https://github.com/openvswitch/ovs/archive/${OVS_VERSION}.tar.gz /src/

WORKDIR /src
RUN mkdir -p /src/ovs
RUN tar --strip-components=1 -C ovs -xvf ${OVS_VERSION}.tar.gz

WORKDIR /src/ovs
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get -y install autoconf automake libtool libcap-ng-dev libssl-dev \
    python3-pip python3-openssl libelf-dev python3-setuptools python3-wheel
RUN apt-get -y install libbpf-dev
RUN apt-get -y install python3-sphinx
RUN apt-get -y install libnuma-dev
RUN ./boot.sh
RUN ./configure --enable-afxdp
RUN make -j2 && make install

