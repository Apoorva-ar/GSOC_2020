# FPGA based Bidirectional Packet protocol design (GSOC-2020)

This protocol is designed for extending IO services of main board (XILINX-ZYNQ) to external routing fabric (Lattice-MACHXO2) over single high speed LVDS link.

## Project
Aim of the project is to design a packet based bidirectional protocol over single LVDS link that can fully utilize the available band width based on priority based task scheduling.</br >

### System Architecture
- The Scheduler accepts user commands including address as well as bursts size. Based on the priority of the service, a specific FIFO is used to store the data of corresponding service (address). 
- The scheduler then redirects specific command as well as FIFO link to the packet layer which parses the command to generate the required packets.
  - First packet transferred over the LVDS link is command packet which specifies IO address as well as burst size.
  - Then based on the command either data is written to the LVDS link or is read from it. The schedulers on both the master as well as slave sides ensures that there is no bus contention.
- The physical layer PHY acts as bidirectional SERDES. The master PHY produces both clock and data while slave PHY produces/receives data on the clock provided by master.

#### ZYNQ-AXI Sub system Layer

#### Scheduling Layer
The main idea behind scheduling is to ensure that high priority tasks get served before lower priority tasks. The input command is captured from software via AXI lite register. 
- Based on the priority of the service mentioned in the scheduler, the data latch FSM stores the command word in respective priority FIFO and the subsequent data is further stored in relevant FIFO based on the priority. 
- The master user FSM concurrently checks availability of data in command FIFOs based on priority (hence the command from higher priority is parsed first). After extracting and latching in the command, the burst information, read/write transaction information as well as data (from relevant FIFO) is passed on the packet layer to continue the transaction. </br>

`Scheduler_Master.vhd` : VHDL code for scheduling tasks (command and data words) and controlling internal FIFO banks as well as lower Master Packet layer to perform transactions based on service priority.
#### Packet Layer
This layer accepts commands from upper layers namely scheduling layer in order to control data flow of the physical layer.</br>
- The command contain virtual address, burst length and read/write information.
- The packet layer FSM ensures a ”command packet” is first transmitted over the LVDS serial link so that the 
data flow between master and slave devices is synchronised and controlled. </br>
- The master packet layer FSM decodes the command in order to generate/receive data packets (burst).
- The slave packet layer on the other hand reads command packet and then demands/produces data from/to the slave peripheral. </br>

`Packet_Layer_Master.vhd` : VHDL code for generating/receiving packets as well as controlling read/write transactions as well as burst cycle of the lower PHY Master layer.

`Packet_Layer_Slave.vhd` : VHDL code for generating/receving packets as well as controlling read/write transactions as well as burst cycle of the lower PHY Slave layer.

#### PHY Layer
This layer acts as bidirectional SERDES for the user. There are two major modules involved mainly master and slave. </br>
- Master produces clock while slave transmits and receives data on that clock.
Both master as well as slave FSMs are initiated on write/read transaction enable signals from upper layers (in this case the packet layer). Hence, the upper layer has full control over the SERDES in terms of avoiding any possible cross-talks.</br>
- Xilinx primitive `IOBUFDS` is used for connecting single ended bidirectional port of the design with differential LVDS IO physical port of the ZYNQ_SoC (Microzed-7Z020)</br>

`PHY_Master_controller.vhd` : VHDL Controller for controlling PHY Master </br>
  - `PHY_Master.vhd: VHDL` code for Master PHY layer -> SERDES that controls clock as well as data. </br>
    - `PHY_Data_Path.vhd` : VHDL code for controlling SERDES data path.</br>
    - `PHY_sclk_gen.vhd`  : VHDL code for controlling LVDS clock.</br>
    
`PHY_Slave_Controller.vhd` : VHDL Controller for controlling PHY Slave  </br>
  - `PHY_Slave.vhd: VHDL` code for Slave PHY layer -> Slave SERDES. </br>

## Running the application on Apertus AXIOM Beta
The application runs on ZYNQ-SOC as Master and MACHXO2 as Slave. In order to access as well as flash the bitstreams on the ZYNQ-PL(Programmable logic) as well as MACHXO2 from linux running on ZYNQ-PS. Following steps are followed.

### Flashing Bit file on ZYNNQ-PL
Access the terminal of linux running on ZYNQ-PL of AXIOM-Beta and run the following commands to flash the bit file on ZYNQ-PL(FPGA).
- Transfer the bit file to `/boot` directory.
- The uboot system requires bin file instead of bit file. Hence we need to convert the bit file to binary either via Xiinx Vivado itself or via the script `/opt/axiom-firmware/makefiles/in-chroot/to_war_bitstream.py -f /boot/my_bitfile.bit /boot/my_binfile.bin`.
Inorder to place the bin file in system memory, we need to access uboot bootloader. during the boot session, stop the process and run the following commands.
- `fatload mmc 0 0x20000000 my_binfile.bin`. This will load the bin file pointing to address 0x20000000 insystem memory. The output will be the total bytes written to the memory.
- `fpga load 0 0x20000000 <bytes>`. This will flash the binary file of size <bytes> to the FPGA.
  
### Flashing Bit file on MACHXO2
Access the terminal of linux running on ZYNQ-PL of AXIOM-Beta and run the following commands to flash the bit file on ZYNQ-PL(FPGA).
- Transfer the bit file to `/lib/firmware` directory.
- The linux device driver as well as all the required scripts are placed in user->operator's rfdev-stuff directory.
- Enter the rfdev-stuff directory `cd /home/operator/rfdev-stuff`.
- run the script `./do_all`. This script will power ON the MACHXO2, PIC microcontroller (which pragrams MACHXO2 via JTAG) as well as establish i2c link between ZYNQ and PIC.
- load the device driver module into linux kernel space by `insmod /home/operator/rfdev.ko`.
- Change the directory to `cd /sys/class/fpga_manager/fpga1`.
- run `echo my_bit_file.bit>firmware`. This will load the bitstrem into MACHXO2.
- inorder to cheack the sucess of hte operation run `cat statstr`.

## Testing
Following VHDL testbenches were used to perform software based unit tests of individual modules.
### Running loopback test on ZYNQ.
Following steps are followed for running loopback test on ZYNQ in order to perform hardware based functional verification. </br>
Two Major transactions were performed - Writing data to a virtual address at Slave and Reading data from a virtual address of Slave.

#### Loop Back test - Write transaction  
Both Master as well as Slave modules are flashed onto ZYNQ PL in order to perform loopback tests </br>
This tests performs write transaction (Master--> Slave --> AXI) over packet layer. </br>
The command `(16 bit)` : where `15th bit` (MSB) is write/read operation (`1`= Write/ `0` = Read); `Bit (14 - 8)` is the burst length; `Bits (7 - 0)` is the slave peripheral address.

##### AXI based tests
- Inorder to perform this tests build the system using `axiom_test_V1.tcl` script.
- Flash the `top.bit` file to the ZYNQ PL
- Command is written at AXI address `0x40000000` on `bits (15 to 0)`.
- Slave data and command is read back on AXI address `0x40000008` with `bits(31 to 816)` being command received by receiver and `bits(15 to 0)` being data received by receiver.
- Open linux terminal on ZYNQ PL and write `devmem2 0x40000000 w 0x00008121`. This will command the master to perform write transaction with 1 word transfer at virtual address `0x21`.
- Write the data word to master by `devmem2 0x40000004 w 0x0000ffff`. This writes `0xffff` to the master data_in register.
- To read the command as well as data received by the Slave in loopback mode write `devmem2 0x40000008 w`.









