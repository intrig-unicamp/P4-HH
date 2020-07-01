# Heavy-Hitter Detection using Inter Packt Gap (IPG)
In this project, we take a completely different direction to detect Heavy-Hitter flows: keep track of per-flow Inter Packet Gap (IPG) metrics instead of packet counts. 
HH flows can be characterized by small IPG metrics calculated as a function (e.g. weighted average) of the inter-packet time intervals. 
The ``heaviness'' (i.e. throughput over time) of a packet flow can be approximated by relating the average packet size to the observed IPG values. 
This approach does not require a measurement interval to be set upfront, thus eliminating common shortfalls of windows-based algorithms. 

## Implementation in TNA P4_16
The complete TNA P4_16 code can be find in "P4-TNA-HeavyHitter" folder. The code is succesfullfy compiled on Tofino Wedge100BF-32X switch. This version has been succesfully tested to detect heavy-hitter flows with CAIDA traces 2016 (10 Gbps link) using TRex Realistic Traffic Generator.  


### Exponential Weighted Moving Average (EWMA) of IPG vs flow throughuts for different size of Time-Windows using CAIDA traffic Trace (2016)
For 1 Sec Time-Window:

<img src="Figures/Throughput_vs_IPGw/1Sec_TW_001.png" alt="alt text" width="300" height="270"> <img src="Figures/Throughput_vs_IPGw/1Sec_TW_002.png" alt="alt text" width="300" height="270"> 

For 5 Secs Time-Window

<img src="Figures/Throughput_vs_IPGw/5Secs_TW_001.png" alt="alt text" width="300" height="270"> <img src="Figures/Throughput_vs_IPGw/5Secs_TW_002.png" alt="alt text" width="300" height="270">

For 10 Secs Time-Window

<img src="Figures/Throughput_vs_IPGw/10Secs_TW_001.png" alt="alt text" width="300" height="270"> <img src="Figures/Throughput_vs_IPGw/10Secs_TW_002.png" alt="alt text" width="300" height="270">

### EWMA of IPG with two different values of degree of weighting decrease vs Simple Moving Average for different number of flows using CAIDA traffic Trace (2016)

<img src="Figures/SMA_EMA/f1.png" alt="alt text" width="300" height="270"> <img src="Figures/SMA_EMA/f2.png" alt="alt text" width="300" height="270"> <img src="Figures/SMA_EMA/f3.png" alt="alt text" width="300" height="270"> <img src="Figures/SMA_EMA/f4.png" alt="alt text" width="300" height="270"> <img src="Figures/SMA_EMA/f5.png" alt="alt text" width="300" height="270"> <img src="Figures/SMA_EMA/f6.png" alt="alt text" width="300" height="270">

