 ################################################################################
 # Copyright 2022 INTRIG
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 ################################################################################

#!/bin/bash

from utils import ip2long
import matplotlib.pyplot as plt
from zlib import crc32

import numpy as np
import pdb

WRAPTIME = 20000
FLOW_TP_STATE_TH = 200
DEFAULT_PKT_SIZE = 1000 ## in bytes

hashA =        [62,   72,   88,   92,   102,  104,  106,  107,  109,  113,
                127,  131,  137,  139,  149,  151,  157,  163,  167,  173,
                179,  181,  191,  193,  197,  199,  211,  223,  227,  229]

hashB =        [73,   3079, 617,  619,  631,  641,  643,  647,  653,  659,
                661,  673,  677,  683,  691,  701,  709,  719,  727,  733,
                739,  743,  751,  757,  761,  769,  773,  787,  797,  809]

class SimulatorIPG:

  def __init__(self, filename, memory, flow_definition, windowsize, \
               hh_threhsold, weighting_decrease):
    flow_definition = int(flow_definition)
    self.m = memory
    self.flowTables = np.zeros((1, memory), dtype=(float,4))
    i = 0
    self.HH_Flows = []
    with open(filename, 'r') as f:
      for line in f:
        fields = line.split(',')
        ipSrc     = fields[0]
        if len(fields) != 6 or not ipSrc:
          continue

        ipSrc     = fields[0]
        ipDst     = fields[1]
        tcpSrcP   = fields[3]
        tcpDstP   = fields[4]
        ipsource  = ip2long(ipSrc)
        ipdest    = ip2long(ipDst)

        if flow_definition == 1:
             flowId = ipsource + ipdest + int(tcpSrcP) + int(tcpDstP)
        elif flow_definition == 2:
             flowId = ipsource
        elif flow_definition == 3:
             flowId = ipdest
        elif flow_definition == 4:
             flowId = ipsource + ipdest
        else:
             flowId = ipsource + ipdest + int(tcpSrcP) + int(tcpDstP)

        TSc = float(fields[5])*1000000

        # set wraptime
        if TSc > (i+1)*WRAPTIME:
            i += 1
        if TSc > i*WRAPTIME:
            TSc = TSc - i*WRAPTIME
        TS_c = int(TSc)

        self.HeavyKeeperIPG(flowId, TS_c, windowsize, hh_threhsold, weighting_decrease)

  def flowIdHash(self, flowId, stage):
     return (hashA[stage] * flowId + hashB[stage]) % self.m

  def CRC32Hash(self, flowId):
    s1 = 'aaa'
    flowId = str(flowId) + s1
    return ((crc32(flowId) % (1<<32)) % self.m)

  def setFlowState(self, IPG_weighetd, windowsize, hh_threhsold):

     pkts = (windowsize * hh_threhsold * 1000000) / (DEFAULT_PKT_SIZE * 8)
     num_wraptime    = (pkts * IPG_weighetd) / WRAPTIME
     if num_wraptime == 0:
         num_wraptime = 2

     return (FLOW_TP_STATE_TH / num_wraptime)


  def HeavyKeeperIPG(self, flowId, TS_c, windowsize, hh_threhsold, weighting_decrease):

    windowsize = int(windowsize)
    hh_threhsold = int(hh_threhsold)
    HH_IPG_TH = (DEFAULT_PKT_SIZE * 8)/hh_threhsold
    n = (HH_IPG_TH * 0.1)/100

    tableSlot = self.flowIdHash(flowId, 10)
    #tableSlot = self.CRC32Hash(flowId)
    tableFlowId, IPG_w, TS_last, tau_hh  = self.flowTables[0][tableSlot]

    #### Case I
    if tableFlowId == flowId:

        ###### Update the entry ##########
        if TS_last > TS_c :
           IPG_c = (WRAPTIME - TS_last) + TS_c
           flow_tp_state = self.setFlowState(IPG_w, windowsize, hh_threhsold)
           tau_hh += flow_tp_state
        else:
           IPG_c = TS_c - TS_last

        IPG_w = (int(weighting_decrease) * IPG_w + (100-int(weighting_decrease)) * IPG_c)/100

        if tau_hh >= (FLOW_TP_STATE_TH):
                self.HH_Flows.append(tableFlowId)
                tau_hh = 0

        self.flowTables[0][tableSlot][1] = IPG_w
        self.flowTables[0][tableSlot][2] = TS_c
        self.flowTables[0][tableSlot][3] = tau_hh

        return None

    # Case II
    elif tableFlowId == 0:

        # Insert new entry
        self.flowTables[0][tableSlot] = flowId, HH_IPG_TH, TS_c, 0
        return None

    else:
       # Increase IPG_w at constant rate
       IPG_w += n

       if IPG_w > (HH_IPG_TH):
          self.flowTables[0][tableSlot] = flowId, HH_IPG_TH, TS_c, 0
       else:
          self.flowTables[0][tableSlot][1] = IPG_w

       return None

  def getHeavyHitters(self):
       return set(self.HH_Flows)
