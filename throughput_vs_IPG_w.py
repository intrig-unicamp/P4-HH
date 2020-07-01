#!/bin/bash

ISP_file = '/path/of/CAIDA/xyz.csv'

import csv
from matplotlib import pyplot as plt
from collections import Counter
from collections import defaultdict
from utils import ip2long, flow2IP
import numpy as np
import pandas as pd
from scipy.interpolate import spline
import array as arr
import ast
import pdb


FL_HH = 4900000
k=10000
table_1 = np.zeros((1, k), dtype=(float,10))
table_2 = np.zeros((1, k), dtype=(float,10))


class flows_with_pktCounts:

  def __init__(self, filename):
    self.counts = Counter()

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

  def get_total_flows(self):
    return len(self.counts)

  def getPktCounts(self):
    counts = self.counts.values()
    counts = np.array(counts)
    flows = self.counts.keys()
    flows = np.array(flows)
    flows = flows[np.argsort(counts)]
    counts = np.sort(counts)
    counts = np.flipud(counts)
    flows = np.flipud(flows)
    return (flows, counts)

'''
find flows with their pkt counts
'''
FC = flows_with_pktCounts(ISP_file)
totalFlows = FC.get_total_flows()
print ("Total no. of flows: %d" % totalFlows)
flows, pktCounts = FC.getPktCounts()


def IPGw_Tbl(ISP_file):

    i = 0
    with open(ISP_file, 'r') as f:
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

           '''
           check for top k flows
           '''
           if (flowId not in flows[:k]) is True:
               continue
           else:
               n = np.asarray(np.where(flows[:k] == flowId))
               n = n[0][0]
               IPG_w_last = table_1[0][n][1]
               TS_l  = table_1[0][n][2]
               if TS_l == 0:
                   i = 0
               table_1[0][n][2] = TS_c
               if TS_l == 0:
                    IPG_w = 100
               else:
                    IPG_c = TS_c  -  TS_l
                    if IPG_c == 0 :
                        continue

                    IPG_w = ((99 * IPG_w_last) + 1 * IPG_c)/100

               table_1[0][n][1] = IPG_w
               table_2[0][n][1] = IPG_w
               table_2[0][n][3] = TS_c

               if i == 0:
                  table_2[0][n][2] = TS_c
               i = i + 1


'''
EWMA (IPGw) for top k flows
'''
IPGw_Tbl(ISP_file)


j = 0
flowsIPGw = []
Counts = []
for i in range(0,k):
    '''
    condier only flows which equal to or greater than pre-defined FL_HH
    '''
    FL = table_2[0][i][3] - table_2[0][i][2]
    if FL >= FL_HH:
        flowsIPGw.append((table_2[0][i][1])/1000)
        Counts.append((float(pktCounts[i]))/1000)
        j = j+1


'''
Plot Graphs
'''

fig, (ax1) = plt.subplots()
ax2 = ax1.twinx()

x = np.arange(1, (j+1), 1)
ax1.bar( x,(Counts[:j]), color="lightblue", edgecolor = "lightblue", label='no. of packets')

p = np.poly1d(np.polyfit(x, flowsIPGw, 3))
t = np.linspace(1, j, 2000)
lines1 = ax2.plot(x, (flowsIPGw), '.', color='darkgreen')
lines2 = ax2.plot(t, p(t), '-', linewidth = 4, color='red')

ax1.legend(loc="upper left", prop={'size': 18}, frameon=False)
ax2.legend(['$IPG_w$','Polynomial \nRegression'], loc="upper right", prop={'size': 18}, frameon=False, bbox_to_anchor=(1.0,0.4))

ax1.set_xlim(0,2000)

ax1.set_xlabel('Flow ID', fontsize= 22)
ax1.set_ylabel('Packets per Flow (in K)', fontsize=22)
ax2.set_ylabel('EWMA in ms ($IPG_w$)', fontsize=22)

ax1.tick_params(axis="x", labelsize=22)
ax1.tick_params(axis="y", labelsize=22)
ax2.tick_params(axis="y", labelsize=22)


plt.show()
