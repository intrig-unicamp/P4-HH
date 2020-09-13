#!/bin/bash

from utils import ip2long
import numpy as np
import pdb
HH = []
'''
define flow length threshold to define HH flowsIPGs
'''
FL = 10

class SpaceSavingSimulator:
  def __init__(self, filename, m):
    self.FlowTable = np.zeros((1,m), dtype=(int,4))
    i = 1
    k = 0
    with open(filename, 'r') as f:
      for line in f:
        fields    = line.split(',')
        ipSrc     = fields[0]
        ipDst     = fields[1]
        tcpSrcP   = fields[3]
        tcpDstP   = fields[4]
        ipsource  = ip2long(ipSrc)
        ipdest    = ip2long(ipDst)
        flowId    = (ipsource + ipdest + int(tcpSrcP) + int(tcpDstP))

        if len(fields) != 6 or not ipSrc :
          continue

        if (flowId < 0):
          continue

        TSc = float(fields[5])*1000000
        if TSc > (i+1)*524288:
            i += 1
        if TSc > i*524288:
            TSc = TSc - i*524288
        TS_c = int(TSc)

        # Calling main table
        self.MainTable(flowId, TS_c, m)


    self.flowID, self.IPG_W, self.TS_C, self.Clocks = np.split(self.FlowTable, 4, axis=2)
    self.flowID = self.flowID.flatten()
    self.IPG_W = self.IPG_W.flatten()
    self.Clocks = self.Clocks.flatten()

  def MainTable(self, flowId, TS_c, m):

    self.flowId_m, self.IPG_w_m, self.TS_l_m, self.NClocks = np.split(self.FlowTable, 4, axis=2)
    self.flowId_m = self.flowId_m.flatten()

    '''
    Check the flowId present in the hash table
    '''
    if (flowId not in self.flowId_m) is True:
        if np.count_nonzero(self.flowId_m) == m:
            pass
        else:
            '''
            Case I : insert the new entry and initialize IPGw
            '''
            index = np.where(self.flowId_m == 0)[0]
            '''
            IPGw initailization can be vary b/w 0-10000, but higher value can affect the accuracy
            specially for SpaceSaving Algo.
            '''
            self.FlowTable[0][index[0]] = flowId, 1000, TS_c, 0
            return None

    else:
       '''
       Case II : If flowId already present in the hash table, update the corrsponding entry
       '''
       indx = np.where(self.flowId_m == flowId)[0]
       tableFlowId, IPG_w, TS_l, NClocks = self.FlowTable[0][indx[0]]

       ###################################
       '''
       check that the flow satisfy the HH requirements
       '''
       if IPG_w <= 15000 and NClocks == FL:
            '''
            add flow as HH
            '''
            HH.append(tableFlowId)

       ####################################

       if TS_c < TS_l:
           IPG_c = (524287 - TS_l) + TS_c
           
           NClocks += 1
           
           '''
           # another stratgy to apply for select HH as persistent in time
           if IPG_w <= 15000:
              NClocks += 1
           '''
           if NClocks > FL:
              NClocks = FL
       else:
           IPG_c = TS_c - TS_l

       IPG_w = (99 * IPG_w + 1 * IPG_c)/100
       self.FlowTable[0][indx] = flowId, IPG_w, TS_c, NClocks
       return None

    ''' Case III : If flowId does not present in the hash table, remove
     the entry which has highest IPG_w value and insert the new entry '''
    self.IPG_w_m = self.IPG_w_m.flatten()
    indx = np.argmax(self.IPG_w_m)
    tableFlowId, IPG_w, TS_l, NClocks = self.FlowTable[0][indx]
    self.FlowTable[0][indx] = flowId, IPG_w, TS_c, 0
    return None


  def getHeavyHitters(self):
    return set(HH)
