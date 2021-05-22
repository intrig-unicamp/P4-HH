#!/bin/bash

from collections import Counter
from utils import ip2long
import numpy as np

import pdb

DEFAULT_PKT_SIZE = 1000 ## in bytes

class FlowCounter:

  def __init__(self, filename, flow_definition, windowsize, hh_threhsold):

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

        self.counts[flowId] += 1


  def getNumFlows(self):
    return len(self.counts)

  def getHeavyHitters(self, windowsize, hh_threhsold):
    hh_th_pkts = (int(hh_threhsold) * 1000000 * int(windowsize))/ (DEFAULT_PKT_SIZE * 8)
    count = self.counts.values()
    count = np.array(count)
    flow = self.counts.keys()
    flow = np.array(flow)
    flow = flow[np.argsort(count)]
    count = np.sort(count)
    count = np.flipud(count)
    #print (sum(count)*1000*8)/(int(windowsize)*1000000)
    flow = np.flipud(flow)

    index = [i for i,v in enumerate(count) if v >=(hh_th_pkts)]

    flows = (flow[index])
    return flows
