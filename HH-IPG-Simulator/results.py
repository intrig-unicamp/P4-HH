#!/bin/bash

import pdb
import numpy as np
import argparse
import pandas as pd
import seaborn as sns

import matplotlib.pyplot as plt
from flowCounter import FlowCounter
from slidingWindowHH import SlidingWindowHH
from IPG_HeavyKeeper import SimulatorIPG
from corr_dataset import CorrDataset


memorySlots = 1000

# locate the pcap file
#ISP_file = 'OUTPUT_DATASET/1_SEC_MAWI_CSV/1sec_00000_20200408010000.pcap.csv'
#ISP_file = 'OUTPUT_DATASET/1_SEC_MAWI_CSV/1sec_00001_20200408010001.pcap.csv'
#ISP_file = 'OUTPUT_DATASET/1_SEC_MAWI_CSV/1sec_00002_20200408010002.pcap.csv'
ISP_file = 'OUTPUT_DATASET/1_SEC_MAWI_CSV/1sec_00003_20200408010003.pcap.csv'

def get_args():
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("--flow_definition", type=int, default=1,
                        help="choose 1 for 5 Tuple, 2 for IP source, \
                        3 for IP destination, 4 for IP source and destination.")
    parser.add_argument("--windowsize", type=int, default=1,
                        help="size of time window in sec to measure the Heavy-Hitter flows")
    parser.add_argument("--hh_threhsold", type=int, default=5,
                        help="define Heavy-Hitter threshold in Mbps")
    parser.add_argument("--weighting_decrease", type=int, default=98,
                        help="degree of weighting decrease in percentage for EWMA calculation")
    return parser.parse_args()


args = get_args()


def computeHeavyHitters(inputFile, trueCounter):

  trueHeavyHitters = trueCounter.getHeavyHitters(str(args.windowsize), str(args.hh_threhsold))
  print ("Number of true HH : %d" % len(trueHeavyHitters))

  trueHeavyHitters = set(trueHeavyHitters)

  HH_IPG = SimulatorIPG(inputFile, memorySlots, str(args.flow_definition), \
               str(args.windowsize), str(args.hh_threhsold), str(args.weighting_decrease))
  HH_HK_IPG   = HH_IPG.getHeavyHitters()

  return (HH_HK_IPG, trueHeavyHitters)


def slidinWindowAlgo(inputFile, trueCounter):
  SlidingWindow_HH = trueCounter.getHeavyHitterSW()
  return (SlidingWindow_HH)


def resultMissedHHFlows():
    trueCounter1 = FlowCounter(ISP_file1, str(args.flow_definition), str(args.windowsize), \
                      str(args.hh_threhsold))
    totalFlows1 = trueCounter1.getNumFlows()
    print ("Total flows for trace 1: %d" % totalFlows1)

    trueCounter2 = FlowCounter(ISP_file2, str(args.flow_definition), str(args.windowsize), \
                      str(args.hh_threhsold))
    totalFlows2 = trueCounter2.getNumFlows()
    print ("Total flows for trace 2: %d" % totalFlows2)

    trueCounter3 = FlowCounter(ISP_file3, str(args.flow_definition), str(args.windowsize), \
                      str(args.hh_threhsold))
    totalFlows3 = trueCounter3.getNumFlows()
    print ("Total flows for trace 3: %d" % totalFlows3)

    HH_HK_IPG1, trueHH1 = computeHeavyHitters(ISP_file1, trueCounter1)
    HH_HK_IPG2, trueHH2 = computeHeavyHitters(ISP_file2, trueCounter2)
    HH_HK_IPG3, trueHH3 = computeHeavyHitters(ISP_file3, trueCounter3)

    trueCounterSW = SlidingWindowHH(ISP_file3, str(args.flow_definition), str(args.windowsize), \
                      str(args.hh_threhsold))
    SlidingWindow_HH = slidinWindowAlgo(ISP_file3, trueCounterSW)

    trueHH = (trueHH1 | trueHH2)

    true_missed_HH = SlidingWindow_HH - trueHH
    missed_HH_HK_IPG = true_missed_HH - HH_HK_IPG3

    print ("True HH: %d" % len(SlidingWindow_HH))
    print ("True missed HH: %d" % len(true_missed_HH))
    print ("Missed HH using HK IPG : %d" % len(missed_HH_HK_IPG))

    falsePositives_HK_IPG = len(HH_HK_IPG3 - SlidingWindow_HH)
    falseNegatives_HK_IPG = len(SlidingWindow_HH - HH_HK_IPG3)

    print ("True HH in two windows: %d" % len(trueHH))
    print ("True HH using sliding window: %d" % len(SlidingWindow_HH))
    print ("False positives for HK-IPG: %d" % falsePositives_HK_IPG)
    print ("False negatives for HK-IPG: %d" % falseNegatives_HK_IPG)


def resultAccuracy():
    trueCounter = FlowCounter(ISP_file, str(args.flow_definition), str(args.windowsize), str(args.hh_threhsold))
    totalFlows = trueCounter.getNumFlows()
    print ("Total flows : %d" % totalFlows)

    HH_HK_IPG, trueHH = computeHeavyHitters(ISP_file, trueCounter)

    # Performace calculation for proposed IPG based algorithm
    falsePositives = len(HH_HK_IPG - trueHH)
    falseNegatives = len(trueHH - HH_HK_IPG)
    print ("False positives for HK-IPG: %d" % falsePositives)
    print ("False negatives for HK-IPG: %d" % falseNegatives)

    truePositive      =  len(HH_HK_IPG) - falsePositives
    precision         =  float(truePositive)/float(truePositive + falsePositives)
    recall            =  float(truePositive)/float(truePositive + falseNegatives)
    f1score           =  2*float(recall*precision)/float(recall+precision)
    falsePositiveRate =  float(falsePositives) / float(totalFlows - len(trueHH))
    falseNegativeRate =  float(falseNegatives) / float(len(trueHH))

    print ("Precision: %f" % precision)
    print ("Recall: %f" % recall)
    print ("f1score: %f" % f1score)
    print ("False positive rate: %f" % falsePositiveRate)
    print ("False negative rate: %f" % falseNegativeRate)


def graphCorrFeatures(ax=None):

    CorrDataset(ISP_file, str(args.flow_definition), memorySlots, str(args.windowsize), str(args.hh_threhsold))
    data = pd.read_csv("CorrDataset.csv")
    fig,ax=plt.subplots(figsize=(10,8))
    #corr = data.corr(method='pearson')
    corr = data.corr(method='spearman')
    cmap = sns.diverging_palette(20, 220, n=200)

    ans=sns.heatmap(corr, vmin=-1, vmax=1, linewidths=2, cmap=cmap, center=0, square=False, \
    annot=True,annot_kws={"fontsize":18}, xticklabels=False, yticklabels=False, cbar=False, ax=ax)
    print corr
    plt.show()


def main():
  ## call the function to check the accuracy
  #  of IPG based HH detection
  resultAccuracy()
  print ("All done!")


if __name__ == '__main__':
  main()
