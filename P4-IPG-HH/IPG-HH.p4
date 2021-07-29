#include <core.p4>
#if __TARGET_TOFINO__ == 2
#include <t2na.p4>
#else
#include <tna.p4>
#endif

#include "include/parser.p4"
#include "include/standard_headers.p4"

control SwitchIngress(
        inout header_t hdr,
        inout ingress_metadata_t meta,
        in ingress_intrinsic_metadata_t ig_intr_md,
        in ingress_intrinsic_metadata_from_parser_t ig_prsr_md,
        inout ingress_intrinsic_metadata_for_deparser_t ig_intr_dprsr_md,
        inout ingress_intrinsic_metadata_for_tm_t ig_tm_md) {

        /*********** Math Unit Functions ******************************/
        MathUnit<bit<16>>(MathOp_t.MUL, 1, 16) right_shift;

        /****** Register definition ***********************************/
        Register <bit<32>, _> (32w2048)  rFlowId      ;
        Register <bit<16>, _> (32w2048)  rIPGw        ;
        Register <bit<16>, _> (32w2048)  rTSlast      ;
        Register <bit<16>, _> (32w2048)  rTau         ;
        Register <bit<1>,  _> (32w2048)  rIPGflag     ;

       /**********  Calculate Table Index and Set IPG flag for first pkt of a flow ****************/
        Hash<rSize>(HashAlgorithm_t.CRC32) hTableIndex;
        Hash<bit<32>>(HashAlgorithm_t.CRC32) hFlowId;

        action computeFlowId() {
            { /* 5 Tuple */
             meta.hash_meta.flowId = hFlowId.get({hdr.ipv4.srcAddr, hdr.ipv4.dstAddr,
                                     hdr.ipv4.protocol, meta.hash_meta.l4_sport, meta.hash_meta.l4_dport });
            }
        }
        /***** Check whether the slot is vacant or not  *****/
        RegisterAction<bit<1>, rSize, bit<1>>(rIPGflag) rIPGflag_action = {
              void apply(inout bit<1> value, out bit<1> readvalue){
              readvalue = value;
              value = 1;
            }
        };
        action computeFIndex_setIPGflag() {
            {
             meta.hash_meta.mIndex = hTableIndex.get({hdr.ipv4.srcAddr, hdr.ipv4.dstAddr,hdr.ipv4.protocol,
                                      meta.hash_meta.l4_sport, meta.hash_meta.l4_dport});
            }
        }
       /******************************************************************************************/
       /******* Case I : Insert new entry when the slot is vacant ********************************/
       /******************************************************************************************/

       /**********  Insert new Flow in the hash table ****************/
       RegisterAction<bit<32>, rSize, bit<32>>(rFlowId) rFlowId_action1 = {
              void apply(inout bit<32> value){
              value = meta.hash_meta.flowId;
          }
       };
       /***************** Set Ingress Timestamp  *********************/
       RegisterAction<bit<16>, rSize, bit<16>>(rTSlast) rTSlast_action1 = {
              void apply(inout bit<16> value){
                 value =  (bit<16>) (meta.hash_meta.TS[21:10]);
          }
       };
       /***************  Initialize weighted IPG *********************/
       RegisterAction<bit<16>, rSize, bit<8>>(rIPGw) rIPGw_action1 = {
              void apply(inout bit<16> value){
                  value = IPG_INIT;
          }
       };
       /***** Initilize Tau metric for keeping throughput state ******/
       RegisterAction<bit<16>, rSize, bit<16>>(rTau) rTau_action1 = {
              void apply(inout bit<16> value){
                value = 0;
          }
       };

       /******************************************************************************************/
       /*********************** Case II : Update the existing entry ******************************/
       /******************************************************************************************/

       /****** Update the last noted Timestamp **********************/
       RegisterAction<bit<16>, rSize, bit<16>>(rTSlast) rTSlast_action2 = {
              void apply(inout bit<16> value, out bit<16> readvalue){
                  bit<16> tmp;
                  if (value > (bit<16>) (meta.hash_meta.TS[21:10])) {
                     tmp = value + 0x8000;
                     readvalue = tmp;
                  } else { tmp = value; readvalue = tmp;}
                  value = (bit<16>) (meta.hash_meta.TS[21:10]);
          }
       };
 
      /**** Update IPG weighted (approximate calclution) **************/
      RegisterAction<bit<16>, rSize, bit<16>>(rIPGw) rIPGw_action2 = {
              void apply(inout bit<16> value, out bit<16> readvalue){
                    readvalue = value;
                    if (value > meta.hash_meta.IPGc) {
                          value = value - right_shift.execute(value);
                    } 
                    else {
                          value = value + meta.hash_meta.IPGcComp;
                    }
             }
       };
      /**** Update Tau to keep flow throughput state  ********************/
      RegisterAction<bit<16>, rSize, bit<16>>(rTau) rTau_action2_1 = {
              void apply(inout bit<16> value, out bit<16> readvalue){
              if (value > TAU_TH) {
                 value = 0;
                 readvalue = 1;
              }
              else {
                 value = value + meta.hash_meta.tau;
                 readvalue = 2;
              }
            }
       };
      RegisterAction<bit<16>, rSize, bit<16>>(rTau) rTau_action2_2 = {
              void apply(inout bit<16> value, out bit<16> readvalue){
              if (value > TAU_TH) {
                 value = 0;
                 readvalue = 1;
              }
              else {
                 readvalue = 2;
              }
            }
       };

     /*******************************************************************************************/
     /*************************** Case III ******************************************************/
     /*******************************************************************************************/

    /**** Update IPG weighted (approximated calclution) *******************/
    RegisterAction<bit<16>, rSize, bit<8>>(rIPGw) rIPGw_action3 = {
             void apply(inout bit<16> value, out bit<8> readvalue){
              if (value > IPG_INIT){
                readvalue = 1;}
              else {readvalue = 2;}
              value = value + CONST;
              }
       };

      /** Check incoming flowId already exist in the register **************/
      RegisterAction<bit<32>, rSize, bit<8>>(rFlowId) rFlowId_action = {
              void apply(inout bit<32> value, out bit<8> readvalue){
              if ( value == meta.hash_meta.flowId ) {
                   readvalue = 1;}
              else {readvalue = 0;}
               }
       };

      /**********************  Required Actions  *****************************************/
       action checkFlowId_flag() {
                 meta.hash_meta.FlowIdFlag = rFlowId_action.execute(meta.hash_meta.mIndex);
       }
       action computeTSlast() {
                 meta.hash_meta.TSlastComp  =  rTSlast_action2.execute(meta.hash_meta.mIndex);
       }
       action computeTSc() {
                 /*********** Set wraptime 4096 microseconds ***********************/ 
                 meta.hash_meta.TSc     =  (bit<16>)(meta.hash_meta.TS[21:10]);
                 meta.hash_meta.TSlast  =  (bit<16>)(meta.hash_meta.TSlastComp[11:0]);
       }
       action computeIPGc_wt() {
                 meta.hash_meta.IPGc = meta.hash_meta.Diff + meta.hash_meta.TSc;
       }
       action computeIPGc() {
                 meta.hash_meta.IPGc = meta.hash_meta.TSc - meta.hash_meta.TSlast;
       }


       /********* match-action table for keeping flow throughput *********************/
       action setTau(bit<16> tau) {
            meta.hash_meta.tau =  tau;
       }
       action setTauNull() {
            meta.hash_meta.tau =  0;
       }
       table storeFlowTPState {
       key = {
        meta.hash_meta.IPGw :  exact;
       }
       actions = {setTau; setTauNull; }
       size = IPG_INIT;
       default_action = setTauNull;
       }

     /********** forwarding packets to output port ***********************************/
       action setOutputPort(port_t port) {
            ig_tm_md.ucast_egress_port = port;
       }
       table tblForwarding {
       key = {
        hdr.ipv4.srcAddr :  exact;
       }
       actions = {setOutputPort; NoAction; }
       size = 512;
       default_action = NoAction;
       }


     /**************************** Apply *********************************************/
      apply {

     /******** Preproecssing for HH detection ************************/
      computeFlowId()                                                         ;
      computeFIndex_setIPGflag()                                              ;
      meta.hash_meta.IPGflag  = rIPGflag_action.execute(meta.hash_meta.mIndex);
      meta.hash_meta.TS = ig_intr_md.ingress_mac_tstamp                       ;
      meta.hash_meta.tauFlag = 2                                              ;
 
    /************************* Case I *******************************/
      if ( meta.hash_meta.IPGflag == 0 || ig_intr_md.resubmit_flag == 1 ) {
          rFlowId_action1.execute(meta.hash_meta.mIndex)  ;
          rTSlast_action1.execute(meta.hash_meta.mIndex)  ;
          rIPGw_action1.execute(meta.hash_meta.mIndex)    ;
          rTau_action1.execute(meta.hash_meta.mIndex)     ;
      }
      else {
          checkFlowId_flag();
          /****************** Case II  ******************************/
          if (meta.hash_meta.FlowIdFlag == 1) {
                  computeTSlast();
                  computeTSc();
                  if (meta.hash_meta.TSlastComp[15:15] == 0x1) {
                      meta.hash_meta.Diff = WRAPTIME - meta.hash_meta.TSlast;
                      computeIPGc_wt();
                      meta.hash_meta.IPGcComp = (bit<16>) (meta.hash_meta.IPGc[15:4]); 
                      meta.hash_meta.IPGw = rIPGw_action2.execute(meta.hash_meta.mIndex);
                      storeFlowTPState.apply();
                      meta.hash_meta.tauFlag = rTau_action2_1.execute(meta.hash_meta.mIndex);
                  } else {
                      computeIPGc();
                      meta.hash_meta.IPGcComp = (bit<16>) (meta.hash_meta.IPGc[15:4]);
                      meta.hash_meta.IPGw = rIPGw_action2.execute(meta.hash_meta.mIndex);
                      meta.hash_meta.tauFlag = rTau_action2_2.execute(meta.hash_meta.mIndex);
                  }
          }
          /******************** Case III *******************************************/
         else {
                  /*** IPGw Calculation  *********************************/
                  meta.hash_meta.IPGw_flag = rIPGw_action3.execute(meta.hash_meta.mIndex);

                  /****** Resubmission pkt *******************************/
                  if (meta.hash_meta.IPGw_flag == 1) {
                        ig_intr_dprsr_md.resubmit_type = 1;
                  }
               }
             }

        /******* Detected HHs can be dropped or put in lower priority queue or route to ******/
        /********** other path or report to the controller for further actions ***************/
        if (ig_intr_dprsr_md.resubmit_type == 0) {
              if (meta.hash_meta.tauFlag == 1) {
                 // inform to the controller
              }
              tblForwarding.apply();
              //ig_tm_md.bypass_egress = 1w1;
           }
       }
      }

      /*********************  E G R E S S   P R O C E S S I N G  ********************************************/
      control SwitchEgress(
           inout header_t hdr,
           inout egress_metadata_t meta,
           in egress_intrinsic_metadata_t eg_intr_md,
           in egress_intrinsic_metadata_from_parser_t eg_intr_from_prsr,
           inout egress_intrinsic_metadata_for_deparser_t eg_intr_md_for_dprsr,
           inout egress_intrinsic_metadata_for_output_port_t eg_intr_md_for_oport) {

           apply{ }
      }

     /********************************  S W I T C H  ********************************************************/
      Pipeline(SwitchIngressParser(),
           SwitchIngress(),
           SwitchIngressDeparser(),
           SwitchEgressParser(),
           SwitchEgress(),
           SwitchEgressDeparser()) pipe;


     Switch(pipe) main;

    /************************************* End ************************************************/
