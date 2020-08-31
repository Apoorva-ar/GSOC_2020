# Scheduling Layer
The main idea behind scheduling is to ensure that high priority tasks get served before lower priority tasks. The input command is captured from software via AXI lite register. 
- Based on the priority of the service mentioned in the scheduler, the data latch FSM stores the command word in respective priority FIFO and the subsequent data is further stored in relevant FIFO based on the priority. 
- The master user FSM concurrently checks availability of data in command FIFOs based on priority (hence the command from higher priority is parsed first). After extracting and latching in the command, the burst information, read/write transaction information as well as data (from relevant FIFO) is passed on the packet layer to continue the transaction. </br>

`Scheduler_Layer/Scheduler_Master.vhd` : VHDL code for scheduling tasks (command and data words) and controlling internal FIFO banks as well as lower Master Packet layer to perform transactions based on service priority.
`Scheduler_Layer/Scheduler_Master_tb.vhd` : VHDL testbench code for functional Unit tests. 
### Dependencies :- 
- All files in ../PHY_Layer
- All files in ../Packet_Layer
