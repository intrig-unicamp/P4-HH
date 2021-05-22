#!/bin/bash

from collections import Counter
from utils import ip2long
import numpy as np
import pandas as pd

import pdb

DEFAULT_PKT_SIZE = 1000 ## in bytes
WRAPTIME = 20000
FLOW_TP_STATE_TH = 200

hashA =        [421,  199,  83, 89, 97, 101,  103,  107,  109,  113,
                127,  131,  137,  139,  149,  151,  157,  163,  167,  173,
                179,  181,  191,  193,  197,  199,  211,  223,  227,  229,
                233,  239,  241,  251,  257,  263,  269,  271,  277,  281,
                283,  293,  307,  311,  313,  317,  331,  337,  347,  349,
                353,  359,  367,  373,  379,  383,  389,  397,  401,  409,
                419,  421,  431,  433,  439,  443,  449,  457,  461,  463,
                467,  479,  487,  491,  499,  503,  509,  521,  523,  541,
                547,  557,  563,  569,  571,  577,  587,  593,  599,  601,
                1153, 1163, 1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223,
                1229, 1231, 1237, 1249, 1259, 1277, 1279, 1283, 1289, 1291,
                1297, 1301, 1303, 1307, 1319, 1321, 1327, 1361, 1367, 1373,
                1381, 1399, 1409, 1423, 1427, 1429, 1433, 1439, 1447, 1451]

hashB =        [73,   3079, 617,  619,  631,  641,  643,  647,  653,  659,
                661,  673,  677,  683,  691,  701,  709,  719,  727,  733,
                739,  743,  751,  757,  761,  769,  773,  787,  797,  809,
                811,  821,  823,  827,  829,  839,  853,  857,  859,  863,
                877,  881,  883,  887,  907,  911,  919,  929,  937,  941,
                947,  953,  967,  971,  977,  983,  991,  997,  1009, 1013,
                1019, 1021, 1031, 1033, 1039, 1049, 1051, 1061, 1063, 1069,
                1087, 1091, 1093, 1097, 1103, 1109, 1117, 1123, 1129, 1151,
                1153, 1163, 1171, 1181, 1187, 1193, 1201, 1213, 1217, 1223,
                1453, 1459, 1471, 1481, 1483, 1487, 1489, 1493, 1499, 1511,
                1523, 1531, 1543, 1549, 1553, 1559, 1567, 1571, 1579, 1583,
                1597, 1601, 1607, 1609, 1613, 1619, 1621, 1627, 1637, 1657]



class CorrDataset:

  def __init__(self, filename, flow_definition, memory, windowsize, hh_threhsold):
    self.csv_file = open("CorrDataset.csv", "w")
    self.m = memory
    self.flowTables = np.zeros((1, memory), dtype=(float,13))
    flow_definition = int(flow_definition)
    self.counts = Counter()
    self.countPkts = Counter()
    self.HH_Flows = []
    self.arr = []
    with open(filename, 'r') as f:
      for line in f:
        fields = line.split(',')
        ipSrc = fields[0]
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

        self.preparingDataset(flowId, TSc, windowsize, hh_threhsold)
    self.csv_file.close()
    df = pd.read_csv("CorrDataset.csv", header=None)
    df.to_csv("CorrDataset.csv", header=["FlowSize", "IPGw,alpha=0.5", "IPGw,alpha=0.80", "IPGw,alpha=0.99", "IPGw,alpha=0.999", \
    "tau,alpha=0.50", "tau,alpha=0.80", "tau,alpha=0.99", "tau,alpha=0.999"], index=False)


  def setFlowState(self, IPG_weighetd, windowsize, hh_threhsold):

     pkts = (int(windowsize) * int(hh_threhsold) * 1000000) / (DEFAULT_PKT_SIZE * 8)
     num_wraptime    = (pkts * IPG_weighetd) / WRAPTIME
     if num_wraptime == 0:
         num_wraptime = 2

     return (FLOW_TP_STATE_TH / num_wraptime)

  def flowIdHash(self, flowId, stage):
     return (hashA[stage] * flowId + hashB[stage]) % self.m


  def preparingDataset(self, flowId, TSc, windowsize, hh_threhsold):

    HH_IPG_TH = (1000 * 8)/int(hh_threhsold)

    tableSlot = self.flowIdHash(flowId, 10)
    tableFlowId, IPGw50, IPGw80, IPGw99, IPGw999, TS_last, \
    TSinit, TSwt, tau_hh50, tau_hh80, tau_hh99, tau_hh999, PktCounts \
    = self.flowTables[0][tableSlot]

    PktCounts += 1
    IPG_c   = TSc - TS_last
    IPGw50  = (50 * IPGw50 + 50 * IPG_c)/100
    IPGw80  = (80 * IPGw80 + 20 * IPG_c)/100
    IPGw99  = (99 * IPGw99 +  1 * IPG_c)/100
    IPGw999 = (999 * IPGw999 + 1 * IPG_c)/1000

    flow_tp_state50 = self.setFlowState(IPGw50, windowsize, hh_threhsold)
    flow_tp_state80 = self.setFlowState(IPGw50, windowsize, hh_threhsold)
    flow_tp_state99 = self.setFlowState(IPGw50, windowsize, hh_threhsold)
    flow_tp_state999 = self.setFlowState(IPGw50, windowsize, hh_threhsold)

    if (tableFlowId == flowId):
        timeInterval = TSc - TSwt
        if (timeInterval >= WRAPTIME):
           flow_duration = TSc - TSinit
           speed = (PktCounts * 1000 * 8) / flow_duration
           TSwt = TSc
           tau_hh50 += self.setFlowState(IPGw50, windowsize, hh_threhsold)
           tau_hh80 += self.setFlowState(IPGw80, windowsize, hh_threhsold)
           tau_hh99 += self.setFlowState(IPGw99, windowsize, hh_threhsold)
           tau_hh999 += self.setFlowState(IPGw999, windowsize, hh_threhsold)
           IPGw50_wt = IPGw50
           IPGw80_wt = IPGw80
           IPGw99_wt = IPGw99
           IPGw9999_wt = IPGw999

           '''
           if (1 <= speed <= 5):
               tp = 'PacketId_1to5'
               self.csv_file.write("%d, %s,%d, %d, %d, %d, %d, %d, %d, %d \n" \
               % (PktCounts, tp, IPGw50, IPGw80, IPGw99, IPGw999, \
               tau_hh50, tau_hh80, tau_hh99, tau_hh999))
           elif (6 <= speed <= 10):
               tp = 'PacketId_6to10'
               self.csv_file.write("%d, %s,%d, %d, %d, %d, %d, %d, %d, %d \n" \
               % (PktCounts, tp, IPGw50, IPGw80, IPGw99, IPGw999, \
               tau_hh50, tau_hh80, tau_hh99, tau_hh999))
           '''
           #if (speed >= 30):
           #if (20 <= speed <=30):
           if (1<= speed <=5):
               tp = 'PacketId_11'
               self.csv_file.write("%f,%f, %f, %f, %f, %f, %f, %f, %f \n" \
               % (PktCounts, IPGw50, IPGw80, IPGw99, IPGw999, \
               tau_hh50, tau_hh80, tau_hh99, tau_hh999))


        self.flowTables[0][tableSlot] = tableFlowId, IPGw50, IPGw80, IPGw99, IPGw999, TSc, \
        TSinit, TSwt, tau_hh50, tau_hh80, tau_hh99, tau_hh999, PktCounts

        return None

    elif (tableFlowId == 0):

        # Insert new entry
        self.flowTables[0][tableSlot] = flowId,  HH_IPG_TH, HH_IPG_TH, HH_IPG_TH, HH_IPG_TH, TSc, \
        TSc, TSc, 0, 0, 0, 0, 1
        return None
