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

        bit<14> mIndex;

        /*********** Math Unit Functions ******************************/

        MathUnit<bit<16>>(MathOp_t.MUL, 1, 256) right_shift;

        /****** Register definition ***********************************/

        Register <bit<32>, _> (32w16384)  rFlowTracker ;
        Register <bit<16>, _> (32w16384)  rIPG_w       ;
        Register <bit<16>, _> (32w16384)  rTS          ;
        Register <bit<8>,  _> (32w16384)  rFL          ; 
        Register <bit<1>,  _> (32w16384)  rIPGflag     ;

        /******** Only for computation *******************************/

        Register <bit<32>, _> (32w1)     rIPGcCal     ;

       /**********  Calculate Table Index and Set IPG flag for first pkt of a flow ****************/

        Hash<bit<14>>(HashAlgorithm_t.CRC32) hTableIndex;
        Hash<bit<32>>(HashAlgorithm_t.CRC32) hFlowTracker;

        action compute_FlowID() {
            {
             /* 5 Tuple */
             meta.hash_meta.flowTrackId = hFlowTracker.get({hdr.ipv4.srcAddr, hdr.ipv4.dstAddr,hdr.ipv4.protocol,hdr.tcp.srcPort,hdr.tcp.dstPort });
             //meta.hash_meta.flowTrackId = hFlowTracker.get({hdr.ipv4.srcAddr, hdr.ipv4.dstAddr});
             //meta.hash_meta.flowTrackId = hFlowTracker.get({hdr.ipv4.srcAddr});
             //meta.hash_meta.flowTrackId = hFlowTracker.get({hdr.ipv4.dstAddr});
            }
        }

        /***** Check whether the slot is vacant or not  *****/

        RegisterAction<bit<1>, bit<14>, bit<1>>(rIPGflag) rIPGflag_action = {
              void apply(inout bit<1> value, out bit<1> readvalue){

              readvalue = value;
              value = 1;
            }
        };
        action compute_FlowIndex_and_set_IPGflag() {
            {
             //mIndex = hTableIndex.get({hdr.ipv4.srcAddr, hdr.ipv4.dstAddr,hdr.ipv4.protocol,hdr.tcp.srcPort,hdr.tcp.dstPort});
             //mIndex = hTableIndex.get({hdr.ipv4.srcAddr});
             //mIndex = hTableIndex.get({hdr.ipv4.dstAddr});
             meta.hash_meta.IPGflag  = rIPGflag_action.execute(mIndex);
            }
        }

       /******************************************************************************************/
       /******* Case I : Insert the new entry when slot is vacant ********************************/
       /******************************************************************************************/

       /**********  Insert new Flow in the hash table ****************/

       RegisterAction<bit<32>, bit<14>, bit<32>>(rFlowTracker) rFlowTracker_action_1 = {
              void apply(inout bit<32> value){
              value = meta.hash_meta.flowTrackId;
          }
       };
       /***************** Set Ingress Timestamp  *********************/

       RegisterAction<bit<16>, bit<14>, bit<16>>(rTS) rTS_action_1 = {
              void apply(inout bit<16> value){
                 //value =  (bit<16>) (meta.hash_meta.TS[28:17]);  // for 128
                 value =  (bit<16>) (meta.hash_meta.TS[28:18]);  // for 256
                 //value =  (bit<16>) (meta.hash_meta.TS[28:19]);  // for 512 
          }
       };

       /***************  Initialized weighted IPG *********************/

       RegisterAction<bit<16>, bit<14>, bit<8>>(rIPG_w) rIPG_w_action_1 = {
              void apply(inout bit<16> value){
                  value = 8000;
          }
       };
 
       /******************* Compute Flow Length  **********************/

       RegisterAction<bit<8>, bit<14>, bit<8>>(rFL) rFL_action_1 = {
              void apply(inout bit<8> value){
                value = 0;
          }
       };

      /*****************************************************************************************/
      /************************ Common for Case II and Case III  *******************************/
      /*****************************************************************************************/

      RegisterAction<bit<32>, bit<14>, bit<8>>(rFlowTracker) rFlowTracker_action = {
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

       RegisterAction<bit<16>, bit<14>, bit<16>>(rTS) rTS_action_2 = {
              void apply(inout bit<16> value, out bit<16> readvalue){
                  bit<16> tmp;
                  if (value > (bit<16>) (meta.hash_meta.TS[28:18])) {
                     tmp = value + 0x8000;
                     readvalue = tmp;
                  } else { tmp = value; readvalue = tmp;} 
                  value = (bit<16>) (meta.hash_meta.TS[28:18]);
          }
       };

      RegisterAction<bit<32>, bit<1>, bit<8>>(rIPGcCal) rIPGcCal_action_2 = {
              void apply(inout bit<32> value, out bit<8> readvalue){
                 
                if (meta.hash_meta.IPGc > 0x200) {
                    readvalue = 1;
                } else { readvalue = 2;}
            }
       };

      /**** Update IPG weighted (approximated calclution) **************/

      RegisterAction<bit<16>, bit<14>, bit<16>>(rIPG_w) rIPG_w_action_1_2 = { 
              void apply(inout bit<16> value, out bit<16> readvalue){     
 
                    readvalue = value; 
                    value = value + meta.hash_meta.IPGc; 
             }   
       };    

     RegisterAction<bit<16>, bit<14>, bit<16>>(rIPG_w) rIPG_w_action_2_2 = { 
              void apply(inout bit<16> value, out bit<16> readvalue){ 

                    readvalue = value;  

                    if (value > meta.hash_meta.IPGccc) { 
                          value = value - right_shift.execute(value); 
                    } else { 
                          value = value + meta.hash_meta.IPGc; 
                    } 
             }  
       }; 
       /***************** Flow Length **************************************/

       RegisterAction<bit<8>, bit<14>, bit<8>>(rFL) rFL_action1_2 = {
              void apply(inout bit<8> value, out bit<8> readvalue){

                    if (value >= 13) {
                       value = 0;
                       readvalue = 1;
                    }
                    else {
                       value = value + meta.hash_meta.reward;
                       readvalue = 2;
                    }
            }
       };
       
       /*******************************************************************************************/
       /*************************** Case III ******************************************************/
       /*******************************************************************************************/

      /**** Update IPG weighted (approximated calclution) ************************/

       RegisterAction<bit<16>, bit<14>, bit<8>>(rIPG_w) rIPG_w_action_3 = {
              void apply(inout bit<16> value, out bit<8> readvalue){
                 
                    /* set rate to increase the IPG_w value, different schemes can be used */  
                    if (value > 9000){
                      readvalue = 1;}
                    else {readvalue = 2;}
                    //value = value + right_shift_by_9.execute(value);
                    value = value + 5;
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
                 meta.hash_meta.TS_current =  (bit<16>)(meta.hash_meta.TS[28:18]);
                 meta.hash_meta.TS_last_new = (bit<16>)(meta.hash_meta.TS_last[11:0]);
       }
       action computeTS_last() {
                 meta.hash_meta.TS_last  =  rTS_action_2.execute(mIndex);
       }
       action check_FT_flag() {
                 meta.hash_meta.FlowTrackerFlag = rFlowTracker_action.execute(mIndex);
       }

       /************ This match-action table is used for adding ****************************/
       /******* the reward based on the IPG variation accross time *************************/


       action action_Reward(bit<8> reward) {
            meta.hash_meta.reward =  reward;
       }

       table flowTransition {
       key = {
        meta.hash_meta.IPG_w_flag_2 :  exact;
       }
       actions = {action_Reward; NoAction; }
       size = 8000;
       default_action = NoAction;
       }


       /****** report HH to CPU for further analysis ********/ 
       /*
       action route_to_64(){
           ig_tm_md.ucast_egress_port=64;
       }*/



     /**************************** Apply *********************************************************************/ 

      apply { 

       if (hdr.tcp.isValid()) {

     /******** Preproecssing for HH detection ************************/
 
        compute_FlowID()                                         ; 
        compute_FlowIndex_and_set_IPGflag()                      ; 
        //meta.hash_meta.IPGflag  = rIPGflag_action.execute(mIndex);
        meta.hash_meta.TS = ig_intr_md.ingress_mac_tstamp        ;
        meta.hash_meta.FL = 2                                    ;

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
                      //meta.hash_meta.Diff = 4096 - meta.hash_meta.TS_last_new; // for 128
                      meta.hash_meta.Diff = 2048 - meta.hash_meta.TS_last_new; // for 256
                      //meta.hash_meta.Diff = 1024 - meta.hash_meta.TS_last_new; // for 512  
                      computeIPGc_2_1(); 
                      
                      meta.hash_meta.IPGc_tmp = rIPGcCal_action_2.execute(0);
                      if (meta.hash_meta.IPGc_tmp == 1) {
                          meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_1_2.execute(mIndex);
                      } else {
                          meta.hash_meta.IPGccc = meta.hash_meta.IPGc << 8;
                          meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_2_2.execute(mIndex);
                      }                      

                      flowTransition.apply();
                      meta.hash_meta.FL = rFL_action1_2.execute(mIndex);
                
                  } else {
                      computeTS_current();
                      computeIPGc_2_2();

                      meta.hash_meta.IPGc_tmp = rIPGcCal_action_2.execute(0);
                     
                      if (meta.hash_meta.IPGc_tmp == 1) {
                           meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_1_2.execute(mIndex);
                      } else {
                          meta.hash_meta.IPGccc = meta.hash_meta.IPGc << 8;
                          meta.hash_meta.IPG_w_flag_2 = rIPG_w_action_2_2.execute(mIndex);
                      }
                  
                  // meta.hash_meta.test16 = (bit<48>) (meta.hash_meta.IPG_w_flag_2) ;
                  //meta.hash_meta.test16 = (bit<48>) (meta.hash_meta.TS_current) ;
                  //meta.hash_meta.test16 = (bit<48>) (meta.hash_meta.TS);
                  // meta.hash_meta.test16 = (bit<48>) (meta.hash_meta.IPGc);
                  // meta.hash_meta.test16 = (bit<48>) (meta.hash_meta.IPGccc) ;
                  //test16();

                  }

          }

          /******************** Case III *******************************************/

         else { 
                  /*** IPGw Calculation  *********************************/

                  meta.hash_meta.IPG_w_flag_3 = rIPG_w_action_3.execute(mIndex);

                  /****** Resubmission pkt *******************************/          
                  
                  if (meta.hash_meta.IPG_w_flag_3 == 1) {
                        ig_intr_dprsr_md.resubmit_type = 1;
                        //meta.resubmit_write.test_data = 2;
                  }
         
                  /*******************************************************/

                 } 
               } 

            }

        /***** HHs are reported to controller and other flows are forwraded to the output port ********/
 
        if (ig_intr_dprsr_md.resubmit_type == 0) {
              if (meta.hash_meta.FL == 1) {
                 ig_tm_md.ucast_egress_port = port;
              } 
            
              ig_tm_md.bypass_egress = 1w1; 
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


