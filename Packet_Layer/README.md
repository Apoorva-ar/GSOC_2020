# Packet Layer
This layer accepts commands from upper layers namely scheduling layer in order to control data flow of the physical layer.</br>
- The command contain virtual address, burst length and read/write information.
- The packet layer FSM ensures a ”command packet” is first transmitted over the LVDS serial link so that the 
data flow between master and slave devices is synchronised and controlled. </br>
- The master packet layer FSM decodes the command in order to generate/receive data packets (burst).
- The slave packet layer on the other hand reads command packet and then demands/produces data from/to the slave peripheral. </br>

`Packet_Layer/Packet_Layer_Master.vhd` : VHDL code for generating/receiving packets as well as controlling read/write transactions as well as burst cycle of the lower PHY Master layer. </br>

`Packet_Layer/Packet_Layer_Slave.vhd` : VHDL code for generating/receving packets as well as controlling read/write transactions as well as burst cycle of the lower PHY Slave layer. </br>

`Packet_Layer/Packet_Layer_tb.vhd` : VHDL testbench code for functional Unit tests. 

### Denpendecies: 
- All files in ../PHY_Layer
