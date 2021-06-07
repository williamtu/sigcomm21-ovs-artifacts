# To run Trex using a DPDK device isn't trivial. You have to map many system
# path using -v option. This is an exmaple run on my system.
#
# $ docker run -it --privileged --network host --cap-add=ALL -v /mnt/huge:/mnt/huge -v /sys/bus/pci/devices:/sys/bus/pci/devices -v /sys/devices/system/node:/sys/devices/system/node -v /dev:/dev -v /usr/bin/ofed_info:/usr/bin/ofed_info -v /etc/trex_cfg.yaml:/etc/trex_cfg.yaml -v /sys/devices/:/sys/devices -v /etc/network:/etc/network -v /sys/bus/:/sys/bus -v /lib/modules/:/lib/modules  fdaebc54679d /bin/bash

FROM ubuntu:20.04
RUN apt-get update
RUN apt-get -y install python \
             wget \
             bash \
             net-tools \
             netbase \
             strace \
             iproute2 \
             iputils-ping \
             pciutils \
             vim libibverbs-dev libibverbs1

RUN wget --no-check-certificate https://trex-tgn.cisco.com/trex/release/v2.80.tar.gz && \
    tar -zxvf v2.80.tar.gz -C / && \
    chown root:root /v2.80  && \
    rm v2.80.tar.gz
WORKDIR /v2.80

# Use 1 core and imix_64 template
CMD ["./t-rex-64", "-f", "cap2/imix_64.yaml", "-c", "1"]
