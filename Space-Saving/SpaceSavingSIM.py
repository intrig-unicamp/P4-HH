#!/bin/bash

from utils import ip2long
import numpy as np
import pdb
HH = []

'''
define flow length (i.e., tau metric) threshold to define HH flows
here we set Th_FL accroding to the 5 Secs measuring time interval
we can modify Th_FL as per the requirments
'''
WrapTime = 524288
Th_FL = (3000000/WrapTime)
Th_IPG = 9000


class SpaceSavingSimulator:
  def __init__(self, filename, m):
    self.FlowTable = np.zeros((1,m), dtype=(int,4))
    i = 1
    k = 0
    TS_test = 0
    with open(filename, 'r') as f:
      for line in f:
        fields    = line.split(',')
        ipSrc     = fields[0]
        ipDst     = fields[1]
        tcpSrcP   = fields[3]
        tcpDstP   = fields[4]
        ipsource  = ip2long(ipSrc)
        ipdest    = ip2long(ipDst)
		
        '''
        here we set the flow ID defintion
        '''
        #flowId    = int(str(ipsource) + str(ipdest) + str(int(tcpSrcP)) + str(int(tcpDstP)))
        #flowId    = (ipsource + ipdest + int(tcpSrcP) + int(tcpDstP))
        flowId    = ipsource + ipdest

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

        '''
		Update IPGw values in every 100000 microseconds to remove the outdated information
        '''
        if (TS_c - TS_test) > 100000:
            TS_test = TS_c
            test = 1
        else:
            test = 0

        # Calling main table
        self.MainTable(flowId, TS_c, m, test)


  def MainTable(self, flowId, TS_c, m, test):

    self.flowId_m, self.IPG_w_m, self.TS_l_m, self.NClocks = np.split(self.FlowTable, 4, axis=2)
    self.flowId_m = self.flowId_m.flatten()

    if test == 1:
        for i in range(0,16000):
            FlowId_test, IPG_w_test, TS_l_test, NClocks_test = self.FlowTable[0][i]
            if IPG_w_test > 0:
               if TS_c > TS_l_test:
                   IPG_c_test = TS_c - TS_l_test
               else:
                   IPG_c_test = (524288 - TS_l_test) + TS_c
               IPG_w_test_new = (IPG_w_test * 99 +  IPG_c_test)/100
               self.FlowTable[0][i][1] = IPG_w_test_new

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
            self.FlowTable[0][index[0]] = flowId, Th_IPG, TS_c, 0
            return None

    else:
       '''
       Case II : If flowId already present in the hash table, update the corresponding entry
       '''
       indx = np.where(self.flowId_m == flowId)[0]
       tableFlowId, IPG_w, TS_l, NClocks = self.FlowTable[0][indx[0]]

       ###################################
       '''
       check that the flow satisfy the HH requirements
       '''
	   #if IPG_w <= Th_IPG and NClocks >= Th_FL:
       if NClocks == Th_FL:
            '''
            add flow as HH
            '''
            HH.append(tableFlowId)
            '''
			resset NClocks or tau metric
            '''
            NClocks = 0

       ####################################

       if TS_c < TS_l:
           IPG_c = (524287 - TS_l) + TS_c
		   
           if IPG_w <= Th_IPG:
              NClocks += 1

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
    self.FlowTable[0][indx] = flowId, Th_IPG, TS_c, 0
    return None


  def getHeavyHitters(self):
    return set(HH)
