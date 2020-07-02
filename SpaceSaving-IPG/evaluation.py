#!/bin/bash

from flowCount import flowPktCounts
from SpaceSavingSIM import SpaceSavingSimulator
import numpy as np

ISP_file = '../Path/Caida/CSV_file'

'''
Initialize Table with 'l' number of slots
'''
l=20000
Table = np.zeros((1, l), dtype=(float,50000))
'''
Need to do the prior settings to define the threshold of
flow length and number of packets in a flow to define as HH 
'''
memorySlots = 8400
Th_Counts = 800
Th_FL = 8388608
Th_IPG = Th_FL/Th_Counts

def computePerformance(SS_SIM, totalFlows):

  simulatedHH = SS_SIM.getHeavyHitters()
  FC = flowPktCounts(ISP_file)

  flows, Counts = FC.getPktCounts()
  j = 0
  for i in range(len(Counts)):
      if Counts[i] >= Th_Counts:
         j += 1
      else:
         break

  FC.IPG_Tbl(ISP_file, flows[:j], Table)
  trueHH = []

  for i in range(0,j):
    FL = Table[0][i][3] - Table[0][i][2]
    Table[0][i][1] = FL
    if Table[0][i][1] >= Th_FL:
        if (Table[0][i][1]/Counts[i]) <= Th_IPG:
            trueHH.append(flows[i])

  trueHH = set(trueHH)

  print ("Number of Simulated HH %d" % len(simulatedHH))
  print ("Number of True HH %d" % len(trueHH))

  falsePositives = len(simulatedHH - trueHH)
  falseNegatives = len(trueHH - simulatedHH)

  falsePositiveRate = float(falsePositives) / float(totalFlows - len(trueHH))
  falseNegativeRate = float(falseNegatives) / float(len(trueHH))

  print ("False positive rate: %f" % falsePositiveRate)
  print ("False negative rate: %f" % falseNegativeRate)

  return None

def main():
   print ("Start Processing")
   FC = flowPktCounts(ISP_file)
   totalFlows = FC.get_total_flows()
   print ("total number of flows : %f" % totalFlows)
   print ("Start Simulator, calculating performance ..." )
   SS_SIM = SpaceSavingSimulator(ISP_file, memorySlots)
   computePerformance(SS_SIM,totalFlows)
   print ("Done!")


if __name__ == '__main__':
  main()
