# Heavy-Hitter Detection using Inter Packt Gap (IPG)
In this project, we take a completely different direction: keep track of per-flow Inter Packet Gap (IPG) metrics instead of packet counts. 
HH flows can be characterized by small IPG metrics calculated as a function (e.g. weighted average) of the inter-packet time intervals. 
The ``heaviness'' (i.e. throughput over time) of a packet flow can be approximated by relating the average packet size to the observed IPG values. 
This approach does not require a measurement interval to be set upfront, thus eliminating common shortfalls of windows-based algorithms 
