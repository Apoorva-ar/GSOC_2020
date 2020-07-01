# GSOC_2020

PHY controller acts as controller for PHY Master SERDES. PHY slave controller acts as controller FSM for slave PHY
PHY Master (ZYNQ) acts as a bidirectional  with clock gerenation capabilities
PHY Slave (MACHXO2) acts as a bidirectional SERDES.
packet_layer_master/slave acts as packet layer for gerenerating and receiving burst of data.
top_tb: testbench to verify functionality of PHY.
packet_layer_tb : testbench to verify functionality of packet layer
