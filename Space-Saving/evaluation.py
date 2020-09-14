#!/bin/bash

from SpaceSavingSIM import SpaceSavingSimulator
import numpy as np
import pandas as pd

ISP_file = '/path/of/CAIDAtrace in csv format/'

'''
Set memory slots
'''
memorySlots = 16000

def HeavyHitterDetection(SS_SIM):

  simulatedHH = SS_SIM.getHeavyHitters()
  print simulatedHH

  return None

def main():
   print ("Start Simulator, detecting Heavy Hitter flows ..." )
   SS_SIM = SpaceSavingSimulator(ISP_file, memorySlots)
   HeavyHitterDetection(SS_SIM)

   print ("Done!")


if __name__ == '__main__':
  main()
