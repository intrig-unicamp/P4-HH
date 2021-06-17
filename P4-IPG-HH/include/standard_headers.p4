#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#ifndef _HEADERS_
#define _HEADERS_

/*************************************************************************
*********************** H E A D E R S  ***********************************
*************************************************************************/

header ethernet_t {
    bit<48>   dstAddr;
    bit<48>   srcAddr;
    bit<16>   etherType;
}

header ipv4_t {
    bit<4>    version;
    bit<4>    ihl;
    bit<8>    diffserv;
    bit<16>   totalLen;
    bit<16>   identification;
    bit<3>    flags;
    bit<13>   fragOffset;
    bit<8>    ttl;
    bit<8>    protocol;
    bit<16>   hdrChecksum;
    bit<32>   srcAddr;
    bit<32>   dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> plength;
    bit<16> checksum;
}

header resubmit_h {
    PortId_t port_id; // 9 bits - uses 16 bit container
    bit<48>  _pad2;
}

/* Local metadata */
struct hash_metadata_t {
    bit<32>  flowId;
    bit<1>   IPGflag;
    bit<48>  TS;
    bit<16>  tauFlag;
    bit<8>   FlowIdFlag;
    bit<8>   IPGw_flag;
    bit<16>  TSlastComp;
    bit<16>  TSlast;
    bit<16>  Diff;
    bit<16>  IPGw;
    bit<16>  tau;
    bit<16>  IPGc;
    bit<16>  TSc;
    bit<16>  IPGcComp;
    bit<11>  mIndex;
    bit<16>  l4_sport;
    bit<16>  l4_dport;
}

struct header_t {
    ethernet_t   ethernet;
    ipv4_t       ipv4;
    udp_t        udp;
    tcp_t        tcp;
}


struct ingress_metadata_t {
    hash_metadata_t hash_meta;
    resubmit_h resubmit_data;
}

struct egress_metadata_t {

}


#endif
