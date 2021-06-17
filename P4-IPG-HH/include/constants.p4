
const bit<16> ETHERTYPE_ARP  = 0x0806;
const bit<16> ETHERTYPE_VLAN = 0x8100;
const bit<16> ETHERTYPE_IPV4 = 0x0800;

const bit<8>  IPPROTO_ICMP   = 0x01;
const bit<8>  IPPROTO_IPv4   = 0x04;
const bit<8>  IPPROTO_TCP   = 0x06;
const bit<8>  IPPROTO_UDP   = 0x11;

const bit<16> ARP_HTYPE_ETHERNET = 0x0001;
const bit<16> ARP_PTYPE_IPV4     = 0x0800;
const bit<8>  ARP_HLEN_ETHERNET  = 6;
const bit<8>  ARP_PLEN_IPV4      = 4;
const bit<16> ARP_OPER_REQUEST   = 1;
const bit<16> ARP_OPER_REPLY     = 2;

const bit<8> ICMP_ECHO_REQUEST = 8;
const bit<8> ICMP_ECHO_REPLY   = 0;

const bit<16> GTP_UDP_PORT     = 2152;
const bit<16> UDP_PORT_VXLAN   = 4789;

const bit<32> MAC_LEARN_RECEIVER = 1;
const bit<32> ARP_LEARN_RECEIVER = 1025;

/**** pre-defined parameters for HH detection ***/
const bit<16>  IPG_INIT  = 1600;  // for 5 Mbps HH threhsold
const bit<16>  CONST     = 20;    // contant rate linear increase of weighted IPG 
const bit<16>  TAU_TH    = 300;   // tau threshold to decide HHs 
const bit<16>  WRAPTIME  = 4096;  // in microseconds
const  bit<5>  QID_LP    = 7;   
const  bit<5>  QID_HP    = 1; 
typedef bit<11>rSize;             // size of register 

typedef bit<9> port_t;
//const port_t port = 136;
//const port_t port = 129;
const port_t CPU_PORT = 255;
