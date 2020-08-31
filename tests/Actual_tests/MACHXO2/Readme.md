# MACHXO2 as LVDS Slave
Slave module is flashed onto MACHXO2 in order to perform loopback tests </br>
This tests performs write transaction (Master--> Slave) and then read transaction (Slave --> Master --> AXI) over packet layer. </br>
The command `(16 bit)` : where `15th bit` (MSB) is write/read operation (`1`= Write/ `0` = Read); `Bit (14 - 8)` is the burst length; `Bits (7 - 0)` is the slave peripheral address.
- Inorder to perform this tests build the system using `/tests/Actual_tests/MACHXO2/build.tcl` script.

## AXI based tests
- Flash the `bd_Slave_impl1.bit` file to the MACHXO2
- Command is written at AXI address `0x40000000` on `bits (15 to 0)`.
- Master received_data is read back on AXI address `0x40000008` with `bits(31 to 16)` being data received by the Master from Slave.
- Open linux terminal on ZYNQ PL and write `devmem2 0x40000000 w 0x00000121`. This will command the master to perform read transaction with 1 word transfer request from the virtual address `0x21`.
- To read the data received by the Master from Slave write `devmem2 0x40000008 w`.

