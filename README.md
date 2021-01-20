# Heavy-Hitter Detection using Inter Packt Gap (IPG)
In this project, we take a completely different direction to detect Heavy-Hitter flows: keep track of per-flow Inter Packet Gap (IPG) metrics instead of packet counts. HH flows can be characterized by small IPG metrics calculated as a function (e.g. weighted average) of the inter-packet time intervals.

---------

## Implementation in TNA P4_16
Our proposed IPG based HH detection can be fit with most of the existing packet count based data structures to detect HH. For HH implementation on Tofino hardware (HW) switch using IPG instead of packet count, we leverage the HeavyKeeper(HK) algorithm, you can find HK paper <a href="https://www.usenix.org/conference/atc18/presentation/gong">here</a>, which is amenable to programmable HW. The complete TNA P4_16 code can be find in "P4-TNA-HeavyHitter" folder. In HK-IPG-Method1.p4, where all the HH flows are treated as same. In HK-IPG-Method2.p4, we added 'flowTransition' table which is used to update the tau metric based on IPG value. Using Method2, we can report the HH flows to the controller as soon as possible based on their behavior. In our paper, we evaluated the results with Method2. The code is successfully compiled on Tofino Wedge100BF-32X switch. This version has been successfully tested to detect heavy-hitter flows with CAIDA traces 2016 (10 Gbps link) using TReX Realistic traffic tenerator.


## Implementation of SpaceSaving Algorithm using IPG instead of Packet Count
We also implement our proposed idea using SpaceSaving Algorithm. SpaceSaving is a well known algorithm to detect top-k flows, you can find the paper <a href="https://dl.acm.org/doi/10.1007/978-3-540-30570-5_27">here</a>. However, in this algorithm, packet count is the basic idea to find HH. We use this algorithm with IPG instead of packet count. As we know, due to the entire table scanning for each incoming packet, implement this algorithm on the programmable data plane can be difficult. Therefore, we implement this on python based simulator to validate our idea. The complete code can be find "Space-Saving" folder.


---------
