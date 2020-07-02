#!/bin/bash

from collections import Counter
from utils import ip2long
import numpy as np
import pdb

class flowPktCounts:

  def __init__(self, filename):
    self.counts = Counter()
    with open(filename, 'r') as f:
      for line in f:
        fields = line.split(',')
        ipSrc     = fields[0]
        ipDst     = fields[1]
        tcpSrcP   = fields[3]
        tcpDstP   = fields[4]
        ipsource  = ip2long(ipSrc)
        ipdest    = ip2long(ipDst)
        flowId    = (ipsource + ipdest + int(tcpSrcP) + int(tcpDstP))

        if len(fields) != 6 or not ipSrc:
          continue

        self.counts[flowId] += 1

  def get_total_flows(self):
    return len(self.counts)

  def getPktCounts(self):
    count = self.counts.values()
    count = np.array(count)
    flow = self.counts.keys()
    flow = np.array(flow)
    flow = flow[np.argsort(count)]
    count = np.sort(count)
    count = np.flipud(count)
    flow = np.flipud(flow)
    return (flow, count)


  def IPG_Tbl(self, filename, trueHeavyHitters, Table):
    i = 0
    l = 1
    with open(filename, 'r') as f:
       for line in f:
           fields = line.split(',')
           TSc = float(fields[5])*1000000
           TS_c = int(TSc)
           ipSrc     = fields[0]
           ipDst     = fields[1]
           tcpSrcP   = fields[3]
           tcpDstP   = fields[4]
           ipsource  = ip2long(ipSrc)
           ipdest    = ip2long(ipDst)
           flowId    = (ipsource + ipdest + int(tcpSrcP) + int(tcpDstP))

           if len(fields) != 6 or not ipSrc:
                continue
           if TS_c == 0:
               continue
           if (flowId not in trueHeavyHitters) is True:
               continue
           else:
               n = np.asarray(np.where(trueHeavyHitters == flowId))
               n = n[0][0]
               if Table[0][n][3] == 0:
                   i  = 0
               if (TS_c - Table[0][n][3]) > 1000000:    # ToDo ...
                   pass
               else:
                   Table[0][n][3] = TS_c
               if i == 0:
                  Table[0][n][2] = TS_c
               i = i + 1
