# Heavy-Hitter Detection using Inter Packet Gap (IPG)
In this project, we take a completely different approach to detect Heavy-Hitter flows, keep track of per-flow Inter Packet Gap (IPG) metrics instead of packet counts. HH flows can be characterized by small IPG metrics calculated as a function (e.g. weighted average) of the inter-packet time intervals.


## Implementation in TNA P4-16
Our proposed IPG based HH detection can be fit with most of the existing packet count based data structures to detect HH. For HH implementation on Tofino hardware (HW) switch using IPG instead of packet count, we leverage the HeavyKeeper(HK) algorithm, you can find HK paper <a href="https://www.usenix.org/conference/atc18/presentation/gong">here</a>, which is amenable to programmable HW. The complete TNA P4-16 code can be find in "P4-TNA-HeavyHitter" folder. In HK-IPG-Method1.p4, where all the HH flows are treated as same. In HK-IPG-Method2.p4, we added 'flowTransition' table which is used to update the tau metric based on IPG value. Using Method2, we can report the HH flows to the controller as soon as possible based on their behavior. In our paper, we evaluated the results with Method2. The code is successfully compiled on Tofino Wedge100BF-32X switch. This version has been successfully tested to detect heavy-hitter flows with CAIDA traces 2016 (10 Gbps link) using TReX Realistic Traffic Generator.


## How to test HH algorithm using Simulator
To test our algorithm on simulator, we develop a python based simulator to run our HH algorithm using real traces. The steps are as follows.

1. Clone the repository

```git clone https://github.com/intrig-unicamp/P4-HH.git``` 

2. Then, go to the folder ```HH-IPG-Simulator ``` 

```
cd HH-IPG-Simulator
```

3. There are some parameters, which we need to set before performing the tests.   

```
pythonw results.py --help
usage: results.py [-h] [--flow_definition FLOW_DEFINITION]
                  [--windowsize WINDOWSIZE] [--hh_threhsold HH_THREHSOLD]
                  [--weighting_decrease WEIGHTING_DECREASE]

optional arguments:
  -h, --help            show this help message and exit
  --flow_definition FLOW_DEFINITION
                        choose 1 for 5 Tuple, 2 for IP source, 3 for IP
                        destination, 4 for IP source and destination.
                        (default: 1)
  --windowsize WINDOWSIZE
                        size of time window in sec to measure the Heavy-Hitter
                        flows (default: 1)
  --hh_threhsold HH_THREHSOLD
                        define Heavy-Hitter threshold in Mbps (default: 5)
  --weighting_decrease WEIGHTING_DECREASE
                        degree of weighting decrease in percentage for EWMA
                        calculation (default: 98)
```
We can set the ```flow definition``` for HH detection. For e.g., if we choose 1, the algorithm will set the flow Id based on 5 tuple. By default, algorithm set 1 for flow definition. Aonother parameter is ```wondow size```. Window size inidicates the measuring time interval in seconds. By default, the window size is set as 1 Sec. 


Also, for ```HH threshold```, we can set this in Mbps and by default the setting is 5 Mbps. We use Exponential Weighting Moving Average (EWMA) of IPG values of a flow, the degree of weighting decrease can be set, which impact on oeverall accuracy. The default value is 98. The best accuracy can be analyzed by setting  ```weighting decrease``` as 98 or 99. However, for lower HH threhsold, such as 1 Mbps or below, we need to consider ```weighting decrease``` around between 90-95.           

Example:

```
pythonw results.py --hh_threhsold 10 --weighting_decrease 99 --windowsize 1

Example Outputs:
Total flows : 3931
Number of true HH : 84
False positives for HK-IPG: 3
False negatives for HK-IPG: 7
Precision: 0.962500
Recall: 0.916667
f1score: 0.939024
False positive rate: 0.000780
False negative rate: 0.083333
```


4. For some quick evaluation tests, we downloaded some WIDE backbone traces from <a href="https://mawi.wide.ad.jp/mawi/ditl/ditl2020-G/">MAWI20</a>. You can find the CSV files as follows: 

```cd HH-IPG-Simulator/OUTPUT_DATASET/1_SEC_MAWI_CSV/ ```

5. To gnerate the new CSV files from PCAP traces, we can use the file ```dataset.sh``` by passing three arguments:

```
   DURATION : provide integer value to denote the time-window size in sec
   INFILE   : locate the path of main PCAP file
   OUTFILE  : mention the output pcap name
```
Example:

```./dataset.sh 1 locate/pcap/file file_name.pcap ```


## Tests

As mentioned above for performing accruacy test to get F1 Score, Recall and Precision. There are two other tests which we can performed using file 
```results.py```.

1. The first test can be performed to analyze the correlation between ```weighted IPG or Tau metric``` and ```Flow Size```. The following function can be 
called:

```
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

```

The file ```corr_dataset.py``` for prearinf data set to analyze correlation. 

2. The second test is used to anaylze the missed heavy hitter (or hidden heavy hitters) due to the disjoint time window. 
We can call the function ```resultMissedHHFlows``` using ```results.py``` to perform the test.  



---------
