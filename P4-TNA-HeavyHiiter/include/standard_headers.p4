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
    bit<104>    flowId;
    bit<10>     s1Index;
    bit<10>     s2Index;
    bit<32>     mKeyCarried;
    bit<32>     mKey;
    bit<32>     mCountCarried;
    bit<32>     hash_flowId_s1;
    bit<32>     hash_flowId_s2;
    bit<32>     count_s2;
    bit<32>     FlowTrackerID;
    bit<13>     FlowIndex;
    bit<104>    FlowTrackerId;
    bit<32>     flowTrackId;
    //bit<32>     IngressTS;
    bit<16>     VTS2;
    bit<16>     IPGc_com;
    bit<16>     Diff;
    bit<32>     Diff_2;
    bit<32>     Diff_3;
    bit<32>     VirtualClk;
    bit<16>     IPGc;
    bit<16>     IPGccc;
    bit<32>     IPGc_2;
    bit<32>     IPGc_3;

    bit<48>   TS;
    bit<48>   TS_1;
    bit<48>   TS_2;
    bit<48>   TS_3;
    bit<48>   rTS;
    bit<8>    FL_3;
    bit<8>    TS_msb_fl1;
    bit<16>   TS_lsb;
    bit<16>   TS_lsb1;
    bit<32>   Current_TS;
    bit<32>   Current_TS_2;
    bit<32>   Current_TS_3;
    bit<32>   Last_TS;
    bit<32>   Last_TS_2;
    bit<32>   Last_TS_3;
    bit<16>   TS_last;
    bit<16>   TS_current;
    bit<8>    FL;
    bit<8>    FL1;
    bit<8>   IPG_w_flag;
    bit<8>   IPG_w_flag_2;
    bit<8>   IPG_w_flag_3;
    bit<16> IPG_w1;
    bit<16> IPG_w2;
    bit<8>    FlowTrackerFlag;

    //bit<48>  test16;
    //bit<48>  test18;
    //bit<13>  Index;
    bit<1> IPGflag;

    //bit<8> TS_ub;

    bit<16> TS_last_new;

    //bit<8> TS_ub_new;
    bit<16> TS_lb_last;
    bit<8>  TS_ub_last;

    bit<16> TS_lb_last_2;
    bit<8>  TS_ub_last_2;

    //bit<16> TS_lb_last_3;
    //bit<8>  TS_ub_last_3;

    //bit<8> IPGc_tmp;
    bit<8> IPGc_tmp_2;
    bit<8> IPGc_tmp;
    bit<16> IPGc_tmp_ttt;
    //bit<8> IPGc_tmp_3;
      bit<32> IPGc_tmp_t;


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
