#!/bin/bash

set -eu -o pipefail

DURATION=$1
INFILE=$2
OUTFILE=$3

## run this script by passing three arguments:
## DURATION : provide integer value to denote the time-window size in sec
## INFILE   : locate the path of main PCAP file
## OUTFILE  : mention the output pcap name

## how to run this script:
## ./script_name DURATION INFILE OUTFILE
## e.g., ./dataset.sh 1 ../../../data/MAWI20/mawi1.pcap 1sec.pcap


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUT_DIR_PCAP="OUTPUT_DATASET/${DURATION}_SEC_IMCDC10_UNIV2_PCAP"
OUT_DIR_CSV="OUTPUT_DATASET/${DURATION}_SEC_IMCDC10_UNIV2_CSV"
INFILE_NAME=${DIR}/${INFILE}
SPLIT_PCAP_CMD="editcap -i ${DURATION} ${INFILE_NAME} ${OUTFILE}"


mkdir -p $OUT_DIR_PCAP $OUT_DIR_CSV
cd $OUT_DIR_PCAP
echo "*** Split PCAP file into ${DURATION} sec time window"
$SPLIT_PCAP_CMD
echo "*** Done"

echo "*** Start converting each ${DURATION} sec PCAP in CSV with the required parameters"
for filename in *.pcap; #get the list of files
do
    tshark -r $filename -Y "udp" -T fields -E separator=, -e ip.src \
    -e ip.dst -e ip.proto -e udp.srcport -e udp.dstport \
    -e frame.time_relative >> ${DIR}/${OUT_DIR_CSV}/${filename}.csv

done

echo "*** Done \ Ready for testing"
