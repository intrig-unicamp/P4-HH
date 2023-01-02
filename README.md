# Heavy-Hitter Detection using Inter Packet Gap (IPG) 
In this project, we take a completely different approach to detect Heavy-Hitter flows, keep track of per-flow Inter Packet Gap (IPG) metrics instead of packet counts. HH flows can be characterized by small IPG metrics calculated as a function (e.g., weighted average) of the inter-packet time intervals. The related publication of this work in IEEE TNSM can be find <a href="https://ieeexplore.ieee.org/document/9971781">here</a>.


## Implementation in TNA P4-16 using bf-sde-9.3.1
Our proposed IPG based HH detection can fit most of the existing packet count-based data structures to detect HH. For HH implementation on Tofino switch ASIC, we leverage the HeavyKeeper(HK) algorithm. You can find HK paper <a href="https://www.usenix.org/conference/atc18/presentation/gong">here</a>, which is amenable to programmable HW. However, the proposed approach can also be applied for other similar existing algorithms such as <a href="https://dl.acm.org/doi/10.1145/3230543.3230544">Elastic Sketch</a>. The complete TNA P4-16 code can be found in the "P4-IPG-HH" folder. The code is successfully compiled on the Tofino Wedge100BF-32X switch using **bf-sde-9.3.1**. This version has been successfully tested to detect heavy-hitter flows with <a href="https://mawi.wide.ad.jp/mawi/ditl/ditl2020-G/">CAIDA16</a>, <a href="https://www.caida.org/catalog/datasets/passive_dataset/">MAWI20</a> and <a href="http://pages.cs.wisc.edu/~tbenson/IMC10_Data.html/">IMC10</a> real traces using <a href="https://trex-tgn.cisco.com/">TReX</a>, and <a href="http://osnt.org/">OSNT</a> Realistic Traffic Generator.

Also, we performed the experiments using the Tofino switch for 60 Secs, measuring time-interval by considering 1 Sec window-size for HH detection using CAIDA traces. To analyze the accuracy, we use the standard **sliding-window approach** ```HH-IPG-Simulator/slidingWindowHH.py``` to get the true HHs and compared them with our IPG based approach. As a result, we get more than **90% accuracy**.    

There are some pre-defined parameters, which we need to set before the HH evaluation. The current parameter settings can be found in ```P4-IPG-HH/include/constants.p4```.

```
const bit<16>  IPG_INIT  = 1600;  // for 5 Mbps HH threhsold
const bit<16>  CONST     = 20;    // contant rate linear increase of weighted IPG 
const bit<16>  TAU_TH    = 300;   // tau threshold to decide HHs 
const bit<16>  WRAPTIME  = 4096;  // in microseconds
```
We consider the ```IPG_INIT``` value the same as the HH threshold. To convert the HH threhsold in-terms of IPG, we can use the simple calculation ```HH_IPG_TH = (DEFAULT_PKT_SIZE * 8)/HH threshold)```, here the default packet size is 1000 Bytes. More details about the calculation can be found in ```HH-IPG-Simulator/IPG_HeavyKeeper.py```.   

To push the required entries for updating the ```Tau``` metric within the switch, we can consider the <a href="https://github.com/p4lang/p4runtime-shell/">P4Runtime shell</a>. If you use the docker image for the P4Runtime shell, you can use the ```P4-IPG-HH/p4rt/start_p4runtime.sh``` script for pushing the entries to the switch. 

```
docker run -it --rm --entrypoint "" \
     -v P4-IPG-HH:/workspace \
     -w /workspace p4lang/p4runtime-sh:latest bash \
     -c "source /p4runtime-sh/venv/bin/activate; \
     export PYTHONPATH=/p4runtime-sh:/p4runtime-sh/py_out; \
     python3 -c 'import p4runtime_sh.shell as sh'; \
     python3 p4rt/p4rt.py" \
```
For file ```P4-IPG-HH/p4rt/p4rt.py```, we require ```pipeline_config.pb.bin```, which we can generate using ```P4-IPG-HH/genPipeConf.sh```.  In this file, first, we compile the P4 code as follows:

```
docker run --rm -v "${output_dir}:${output_dir}" -w "${output_dir}" BFSDE_P4C_COMPILER_IMG \
     bf-p4c --arch tna -g --create-graphs \
     --verbose 2 -o output_dir --p4runtime-files output_dir/p4info.txt \
     --p4runtime-force-std-externs IPG-HH.p4 \
     $@
```

The above command gets all the compiler outputs to the folder name ```output_dir```. Then we can use the ```IPG-HH.conf``` to generate ```pipeline_config.pb.bin```. 

```
docker run --rm -v "${output_dir}/output_dir:${output_dir}/output_dir" -w "${output_dir}/output_dir" \
     ${PIPELINE_CONFIG_BUILDER_IMG} \
     -p4c_conf_file=./IPG-HH.conf \
     -bf_pipeline_config_binary_file=./pipeline_config.pb.bin
```
 More detail can be found in <a href="https://github.com/stratum/stratum/blob/main/stratum/hal/bin/barefoot/README.pipeline.md">Stratum</a> and <a href="https://github.com/p4lang/p4runtime-shell">P4Runtime-shell</a>. 


## How to test IPG based HH detection using Simulator
To test our algorithm on the simulator, we develop a python-based simulator to run our HH algorithm using real traces. The steps are as follows.

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
We can set the ```flow definition``` for HH detection. E.g., if we choose 1, the algorithm will set the flow Id based on 5-tuple. By default, the algorithm set 1 for flow definition. Another parameter is ```window size```—window size indicates the measuring time interval in seconds. By default, the window size is set as 1 Sec. 


Also, for the ```HH threshold```, we can set this in Mbps, and by default, the setting is 5 Mbps. We use Exponential Weighting Moving Average (EWMA) of IPG values of a flow, the degree of weighting decrease can be set, which impact on overall accuracy. The default value is 98. The best accuracy can be analyzed by setting  ```weighting decrease``` as 98 or 99. However, for lower HH threshold, such as 1 Mbps or below, we need to consider ```weighting decrease``` around between 90-95.           

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

5. To generate the new CSV files from PCAP traces, we can use the file ```dataset.sh``` by passing three arguments:

```
   DURATION : provide integer value to denote the time-window size in sec
   INFILE   : locate the path of main PCAP file
   OUTFILE  : mention the output pcap name
```
Example:

```./dataset.sh 1 locate/pcap/file file_name.pcap ```


## Tests

As mentioned above for performing accuracy test to get F1 Score, Recall and Precision. There are two other tests, which we can performed using the file 
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

The file ```corr_dataset.py``` for analyzing the correlation. 

2. The second test is used to anaylze the missed HHs (or hidden heavy hitters) due to the disjoint time window. 
We can call the function ```resultMissedHHFlows``` using ```results.py``` to perform the test.  



--------- 
