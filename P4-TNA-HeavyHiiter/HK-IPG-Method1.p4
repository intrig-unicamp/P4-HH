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

        bit<13> mIndex;

        /*********** Math Unit Functions *******************************/

        MathUnit<bit<16>>(MathOp_t.MUL, 1, 512) right_shift_by_9;

        /****** Register definition ************************************/

        Register <bit<32>, _> (32w8192)  rFlowTracker ;
        Register <bit<16>, _> (32w8192)  rIPG_w       ;
        Register <bit<16>, _> (32w8192)  rTS          ;
        Register <bit<8>,  _> (32w8192)  rFL          ;
        Register <bit<1>,  _> (32w8192)  rIPGflag     ;

        /******** Only for computation *******************************/

        Register <bit<32>, _> (32w1)     rIPGcCal     ;

       /******** Flow ID extraction ***********************************/

        action extract_flow_id () {

             meta.hash_meta.flowId[31:0]   = hdr.ipv4.srcAddr ;
             meta.hash_meta.flowId[63:32]  = hdr.ipv4.dstAddr ;
             meta.hash_meta.flowId[71:64]  = hdr.ipv4.protocol;
             meta.hash_meta.flowId[87:72]  = hdr.tcp.srcPort  ;
             meta.hash_meta.flowId[103:88] = hdr.tcp.dstPort  ;
       }

       /**********  Calculate Table Index and Set IPG flag for first pkt of a flow ****************/

        Hash<bit<13>>(HashAlgorithm_t.CRC32) hTableIndex;
        Hash<bit<32>>(HashAlgorithm_t.CRC32) hFlowTracker;

        action compute_FlowID() {
            {
            meta.hash_meta.flowTrackId = hFlowTracker.get(meta.hash_meta.flowId);
            }
        }

        /***** Check whether the slot is vacant or not  *****/

        RegisterAction<bit<1>, bit<13>, bit<1>>(rIPGflag) rIPGflag_action = {
              void apply(inout bit<1> value, out bit<1> readvalue){

              readvalue = value;
              value = 1;
            }
        };
        action compute_FlowIndex_and_set_IPGflag() {
            {
             mIndex = hTableIndex.get(meta.hash_meta.flowId);
             meta.hash_meta.IPGflag  = rIPGflag_action.execute(mIndex);
            }
        }

       /******************************************************************************************/
       /******* Case I : Insert the new entry when slot is vacant ********************************/
       /******************************************************************************************/

       /**********  Insert new Flow in the hash table ****************/

       RegisterAction<bit<32>, bit<13>, bit<32>>(rFlowTracker) rFlowTracker_action_1 = {
              void apply(inout bit<32> value){
              value = meta.hash_meta.flowTrackId;
          }
       };
       /***************** Set Ingress Timestamp  *********************/

       RegisterAction<bit<16>, bit<13>, bit<16>>(rTS) rTS_action_1 = {
              void apply(inout bit<16> value){
                 value =  (bit<16>) (meta.hash_meta.TS[28:19]);
          }
       };

       /***************  Initialized weighted IPG *********************/

       RegisterAction<bit<16>, bit<13>, bit<8>>(rIPG_w) rIPG_w_action_1 = {
              void apply(inout bit<16> value){
                  value = 7000;
          }
       };

       /******************* Compute Flow Length  **********************/

       RegisterAction<bit<8>, bit<13>, bit<8>>(rFL) rFL_action_1 = {
              void apply(inout bit<8> value){
                value = 0;
          }
       };

      /*****************************************************************************************/
      /************************ Common for Case II and Case III  *******************************/
      /*****************************************************************************************/

      RegisterAction<bit<32>, bit<13>, bit<8>>(rFlowTracker) rFlowTracker_action = {
              void apply(inout bit<32> value, out bit<8> readvalue){

              if ( value == meta.hash_meta.flowTrackId ) {
                   readvalue = 0;
              } else {
                   readvalue = 1;}
           }
       };

       /******************************************************************************************/
       /*********************** Case II : Update the existing entry ******************************/
       /******************************************************************************************/

       /************** Ingress Timestamp ********************************/

       RegisterAction<bit<16>, bit<13>, bit<16>>(rTS) rTS_action_2 = {
              void apply(inout bit<16> value, out bit<16> readvalue){
                  bit<16> tmp;
                  if (value > (bit<16>) (meta.hash_meta.TS[28:19])) {
                     tmp = value + 0x8000;
                     readvalue = tmp;
                  } else { tmp = value; readvalue = tmp;}
                  value = (bit<16>) (meta.hash_meta.TS[28:19]);
          }
       };

      RegisterAction<bit<32>, bit<1>, bit<8>>(rIPGcCal) rIPGcCal_action_2 = {
              void apply(inout bit<32> value, out bit<8> readvalue){
                value = 2;
                if (meta.hash_meta.IPGc > 0x80) {
                    readvalue = 1;
                } else { readvalue = 2;}
            }
       };

      /**** Update IPG weighted (approximated calclution) **************/

      RegisterAction<bit<16>, bit<13>, bit<8>>(rIPG_w) rIPG_w_action_1_2 = {
              void apply(inout bit<16> value, out bit<8> readvalue){

                    if (value > 8192){
                        readvalue = 1;}
                    else {readvalue = 2;}
                    value = value + meta.hash_meta.IPGc;
             }
       };

     RegisterAction<bit<16>, bit<13>, bit<8>>(rIPG_w) rIPG_w_action_2_2 = {
              void apply(inout bit<16> value, out bit<8> readvalue){

                    if (value > 8192){
                      readvalue = 1;}
                    else {readvalue = 2;}

                    if (value >= meta.hash_meta.IPGccc) {
                          value = value - right_shift_by_9.execute(value);
                    } else {
                          value = value + meta.hash_meta.IPGc;
                    }
             }
       };
       /***************** Flow Length **************************************/

       RegisterAction<bit<8>, bit<13>, bit<8>>(rFL) rFL_action1_2 = {
              void apply(inout bit<8> value, out bit<8> readvalue){

                   if (value == 12) {
                       value = 0;
                       readvalue = 1;
                    }
                    else {
                       if (meta.hash_meta.IPG_w_flag_2 == 2) {
                            value = value + 1;}
                       readvalue = 2;
                    }
            }
       };
       RegisterAction<bit<8>, bit<13>, bit<8>>(rFL) rFL_action2_2 = {
              void apply(inout bit<8> value, out bit<8> readvalue){
                readvalue = 2;
          }
       };
       /*******************************************************************************************/
       /*************************** Case III ******************************************************/
       /*******************************************************************************************/

      /**** Update IPG weighted (approximated calclution) ************************/

       RegisterAction<bit<16>, bit<13>, bit<8>>(rIPG_w) rIPG_w_action_3 = {
              void apply(inout bit<16> value, out bit<8> readvalue){

                    /* set rate to increase the IPG_w value, different schemes
                       can be to increase the precision */
                    if (value > 10000){
                      readvalue = 1;}
                    else {readvalue = 2;}
                    value = value + right_shift_by_9.execute(value);
            }
       };


      /**********************  Required Actions for Case II  ******************************/

       action computeIPGc_2_1() {
                 meta.hash_meta.IPGc = meta.hash_meta.Diff + meta.hash_meta.TS_current;
       }
       action computeIPGc_2_2() {
                 meta.hash_meta.IPGc = meta.hash_meta.TS_current - meta.hash_meta.TS_last_new;
       }
       action computeTS_current() {
                 meta.hash_meta.TS_current =  (bit<16>)(meta.hash_meta.TS[28:19]);
                 meta.hash_meta.TS_last_new = (bit<16>)(meta.hash_meta.TS_last[9:0]);
       }
       action computeTS_last() {
                 meta.hash_meta.TS_last  =  rTS_action_2.execute(mIndex);
       }
       action check_FT_flag() {
                 meta.hash_meta.FlowTrackerFlag = rFlowTracker_action.execute(mIndex);
       }

     /**************************** Apply *********************************************************************/

      apply {

        if (hdr.tcp.isValid()) {

     /******** Preproecssing for HH detection ************************/

        extract_flow_id()                                 ;
        compute_FlowID()                                  ;
        compute_FlowIndex_and_set_IPGflag()               ;
        meta.hash_meta.TS = ig_intr_md.ingress_mac_tstamp ;
        meta.hash_meta.FL = 2                             ;

    /************************* Case I *******************************/

      if ( meta.hash_meta.IPGflag == 0 || ig_intr_md.resubmit_flag == 1 ) {

          rFlowTracker_action_1.execute(mIndex);
          rTS_action_1.execute(mIndex);
          rIPG_w_action_1.execute(mIndex);
          rFL_action_1.execute(mIndex);
     }
     else {
          check_FT_flag();

          /****************** Case II  ******************************/

          if (meta.hash_meta.FlowTrackerFlag == 0) {

                  computeTS_last();
                  if (meta.hash_meta.TS_last[15:15] == 0x1) {
                      computeTS_current();
                      meta.hash_meta.Diff = 1024 - meta.hash_meta.TS_last_new;
                      computeIPGc_2_1();
                      meta.hash_meta.IPGc_tmp = rIPGcCal_action_2.execute(0);
                      if (meta.hash_meta.IPGc_tmp == 1) {
                          meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_1_2.execute(mIndex);
                      } else {
                          meta.hash_meta.IPGccc = meta.hash_meta.IPGc << 9;
                          meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_2_2.execute(mIndex);
                      }
                      meta.hash_meta.FL = rFL_action1_2.execute(mIndex);

                  } else {
                      computeTS_current();
                      computeIPGc_2_2();
                      meta.hash_meta.IPGc_tmp = rIPGcCal_action_2.execute(0);
                      if (meta.hash_meta.IPGc_tmp == 1) {
                           meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_1_2.execute(mIndex);
                      } else {
                          meta.hash_meta.IPGccc = meta.hash_meta.IPGc << 9;
                          meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_2_2.execute(mIndex);
                      }
                      meta.hash_meta.FL = rFL_action2_2.execute(mIndex);

                  }

          }
          /******************** Case III *******************************************/
         else {
                  /*** IPGw Calculation  *********************************/

                  meta.hash_meta.IPG_w_flag_3 = rIPG_w_action_3.execute(mIndex);

                  /****** Resubmission pkt *******************************/

                  if (meta.hash_meta.IPG_w_flag_3 == 1) {
                        //meta.resubmit_data.port_id = port;
                        ig_intr_dprsr_md.resubmit_type = 1;
                  }

                  /*******************************************************/
                  }
               }
            }

        /***** For analysis, only HH flows can be forwarded to the output port ********/

        if (ig_intr_dprsr_md.resubmit_type == 0) {
              if (meta.hash_meta.FL == 1) {
                     ig_tm_md.ucast_egress_port = port; }
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
