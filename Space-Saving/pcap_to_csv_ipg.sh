tshark -r ../CAIDA_PCAP_location/caida.pcap -Y "tcp" -T fields -E separator=, -e ip.src -e ip.dst -e ip.proto -e tcp.srcport -e tcp.dstport -e frame.time_relative >> xyz.csv
