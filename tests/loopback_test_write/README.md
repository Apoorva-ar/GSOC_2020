## Loop Back test - Write transaction
Both Master as well as Slave modules are flashed onto ZYNQ PL in order to perform loopback tests </br>
This tests performs write transaction (Master--> Slave --> AXI) over packet layer. </br>
The command `(16 bit)` : where `15th bit` (MSB) is write/read operation (`1`= Write/ `0` = Read); `Bit (14 - 8)` is the burst length; `Bits (7 - 0)` is the slave peripheral address.

### AXI based tests
- Inorder to perform this tests build the system using `top.tcl` script.
- Flash the `top.bit` file to the ZYNQ PL
- Command is written at AXI address `0x40000000` on `bits (15 to 0)`.
- Slave data and command is read back on AXI address `0x40000008` with `bits(31 to 816)` being command received by receiver and `bits(15 to 0)` being data received by receiver.
- Open linux terminal on ZYNQ PL and write `devmem2 0x40000000 w 0x00008121`. This will command the master to perform write transaction with 1 word transfer at virtual address `0x21`.
- Write the data word to master by `devmem2 0x40000004 w 0x0000ffff`. This writes `0xffff` to the master data_in register.
- To read the command as well as data received by the Slave in loopback mode write `devmem2 0x40000008 w`.


