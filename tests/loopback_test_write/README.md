## Loop Back test - Write transaction
Both Master as well as Slave modules are flashed onto ZYNQ PL in order to perform loopback tests </br>
This tests performs write transaction (Master--> Slave --> AXI) over packet layer. </br>
The command (16 bit) : where 15th bit(MSB) is write/read operation (1=Write/0=Read); Bit (14 - 8) is the burst length; Bits (7 - 0) is the slave peripheral address.

### AXI based tests
