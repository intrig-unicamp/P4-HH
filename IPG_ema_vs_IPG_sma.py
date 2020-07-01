#!/bin/bash

ISP_file = '/path/of/CAIDA/xyz.csv'


import csv
from matplotlib import pyplot as plt
from collections import Counter
from collections import defaultdict
from utils import ip2long, flow2IP
import numpy as np
import pandas as pd
import array as arr
import ast
import pdb

i = 0
k=100

Table  = np.zeros((1, k), dtype=(float,500))
Table1 = np.zeros((1, k), dtype=(float,500000))
Table2 = np.zeros((1, k), dtype=(float,500000))
Table3 = np.zeros((1, k), dtype=(float,500000))
Table4 = np.zeros((1, k), dtype=(float,500000))
Table5 = np.zeros((1, k), dtype=(float,500000))
Table6 = np.zeros((1, k), dtype=(float,500000))
Table7 = np.zeros((1, k), dtype=(float,500000))


class flows_with_pktCounts:

  def __init__(self, filename):
    self.counts = Counter()

    global i
    with open(filename, 'r') as f:
      d = defaultdict(list)
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
        i = i + 1

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


FC = flows_with_pktCounts(ISP_file)
totalFlows = FC.get_total_flows()

print ("Total flows: %d" % totalFlows)
print ("Total number of Packets: %d" % i)

flows, pktCounts = FC.getPktCounts()

def IPGw_Tbl(filename):

    i = 0
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

           if (flowId not in flows[:k]) is True:
               continue
           else:
               n = np.asarray(np.where(flows[:k] == flowId))
               n = n[0][0]

               '''
               EMA calcultaion for alpha 0.5
               '''
               IPG_w_last = Table[0][n][1]
               TS_l = Table[0][n][2]
               Table[0][n][2] = TS_c

               if TS_l == 0:
                   IPG_w = 100
                   IPG_c = 0

               else:
                   IPG_c = TS_c  -  TS_l
                   if IPG_c == 0:
                       continue

                   IPG_w = (50 * IPG_w_last + 50 * IPG_c)/100

               '''
               SMA calculation
               '''
               Table[0][n][1] = IPG_w
               ik = int(Table[0][n][3])
               Table1[0][n][ik+6] = IPG_w/1000
               Table2[0][n][ik+6] = IPG_c/1000
               Table3[0][n][6] = Table3[0][n][6] + IPG_c
               Table[0][n][3] = Table[0][n][3] + 1
               Table3[0][n][ik+8] = ((Table3[0][n][6])/Table[0][n][3])/1000

               '''
               EMA calculation for alpha = 0.8
               '''
               IPG_w_last = Table4[0][n][1]
               TS_l = Table4[0][n][2]
               Table4[0][n][2] = TS_c

               if TS_l == 0:
                   IPG_w = 100
                   IPG_c = 0

               else:
                   IPG_c = TS_c  -  TS_l
                   if IPG_c == 0:
                       continue

                   IPG_w = (80 * IPG_w_last + 20 * IPG_c)/100

               Table4[0][n][1] = IPG_w
               ik = int(Table4[0][n][3])
               Table4[0][n][ik+6] = IPG_w
               Table4[0][n][3] = Table4[0][n][3] + 1

               '''
               EMA calcultion for alpha = 0.99
               '''
               IPG_w_last = Table5[0][n][1]
               TS_l = Table5[0][n][2]
               Table5[0][n][2] = TS_c

               if TS_l == 0:
                   IPG_w = 100
                   IPG_c = 0

               else:
                   IPG_c = TS_c  -  TS_l
                   if IPG_c == 0:
                       continue

                   IPG_w = (99 * IPG_w_last + 1 * IPG_c)/100

               Table5[0][n][1] = IPG_w
               ik = int(Table5[0][n][3])
               Table5[0][n][ik+6] = IPG_w/1000
               Table5[0][n][3] = Table5[0][n][3] + 1


IPGw_Tbl(ISP_file)

'''
Plot Graphs
'''

fig, (ax1) = plt.subplots()
x = np.arange(1, (2001), 1)

ax1.plot(Table2[0][4][50:2050], color="y", linewidth=2, linestyle='dashed',label='$IPG$')
ax1.plot(Table1[0][4][50:2050], 'black', linewidth=2, linestyle='dashed', label=r'$IPG_{EMA}$, $\alpha$=0.50')
ax1.plot(Table5[0][4][50:2050], 'dodgerblue', linewidth=3, label=r'$IPG_{EMA}$, $\alpha$=0.99')
ax1.plot(Table3[0][4][50:2050], 'red', linewidth=3, label='$IPG_{SMA}$')

ax1.legend(bbox_to_anchor=(0.5, .9), loc='upper center',
          ncol=1, fancybox=True, fontsize=20)

ax1.set_ylim(-0.1, 4.5)
ax1.set_xlim(0,2000)

ax1.xaxis.set_tick_params(labelsize=22)
ax1.yaxis.set_tick_params(labelsize=22)
ax1.set_xlabel('Packet ID', fontsize=22)
ax1.set_ylabel('$IPG$ in ms', fontsize=22)

plt.show()
