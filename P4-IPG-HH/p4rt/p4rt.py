import p4runtime_sh.shell as sh

import argparse

# set parameters to calculate the tau value
IPG_INIT         = 1600   # for 5 Mbps HH threshold
windowsize       = 1      # in sec
hh_threhsold     = 5      # in Mbps
DEFAULT_PKT_SIZE = 1000   # in Bytes
FLOW_TP_STATE_TH = 300    # Tau threshold
WRAPTIME         = 4096   # in microseconds

pkts = (windowsize * hh_threhsold * 1000000) / (DEFAULT_PKT_SIZE * 8)

sh.setup(
        device_id=1,
        grpc_addr='IPAddr:9559',
        election_id=(0, 1), # (high, low)
        config=sh.FwdPipeConfig('/workspace/output_dir/p4info.txt', '/workspace/output_dir/pipeline_config.pb.bin')
        )

for i in range(1, IPG_INIT):
    te = sh.TableEntry('SwitchIngress.storeFlowTPState')(action='SwitchIngress.setTau')
    k= str(i)
    te.match['IPGw'] = k
    num_wraptime    = int((pkts * int(i)) / WRAPTIME)
    if num_wraptime == 0:
         num_wraptime = 2
    tau_value = int(FLOW_TP_STATE_TH / num_wraptime)
    if tau_value<1:
       tau_value = 1
    tau_value1 = str(tau_value)
    te.action['tau'] = tau_value1
    print (te)
    print (i, tau_value1)
    te.insert()

sh.teardown()
