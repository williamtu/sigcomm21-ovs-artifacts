#!/bin/sh

set -ex

# Start OVS, use the OVSDB file from dataset
/usr/share/openvswitch/scripts/ovs-ctl --db-file=/src/conf.db start

# NSX uses the following Geneve TLV fields
# ovs-ofctl dump-tlv-map nsx-managed
#NXT_TLV_TABLE_REPLY (xid=0x2):
# max option space=256 max fields=64
# allocated option space=32 mapping table:
#  class  type  length  match field
# ------  ----  ------  --------------
#  0x104  0x80       4  tun_metadata0
#  0x104  0x81       4  tun_metadata1
#  0x104  0x82       8  tun_metadata2
#  0x104  0x84       4  tun_metadata3
#  0x104  0x85       8  tun_metadata4
#  0x104     0       4  tun_metadata5 
sleep 1
ovs-ofctl add-tlv-map nsx-managed "{class=0x104,type=0x80,len=4}->tun_metadata0"
ovs-ofctl add-tlv-map nsx-managed "{class=0x104,type=0x81,len=4}->tun_metadata1"
ovs-ofctl add-tlv-map nsx-managed "{class=0x104,type=0x82,len=8}->tun_metadata2"
ovs-ofctl add-tlv-map nsx-managed "{class=0x104,type=0x84,len=4}->tun_metadata3"
ovs-ofctl add-tlv-map nsx-managed "{class=0x104,type=0x85,len=8}->tun_metadata4"
ovs-ofctl add-tlv-map nsx-managed "{class=0x104,type=0x0,len=4}->tun_metadata5"

ovs-ofctl add-flows breth0 /src/ovs-ofctl-dump-flows-breth0.out
ovs-ofctl add-flows nsx-switch.0 /src/ovs-ofctl-dump-flows-nsx-switch.0.out

echo "This will take longer time..."
# loading around 50K rules, this takes longer time...
ovs-ofctl add-flows nsx-managed /src/ovs-ofctl-dump-flows-nsx-managed.out

# check
ovs-vsctl show
# ovs-ofctl dump-flows nsx-managed
