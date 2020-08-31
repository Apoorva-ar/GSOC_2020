# PHY Layer
This layer acts as bidirectional SERDES for the user. There are two major modules involved mainly master and slave. </br>
- Master produces clock while slave transmits and receives data on that clock.
Both master as well as slave FSMs are initiated on write/read transaction enable signals from upper layers (in this case the packet layer). Hence, the upper layer has full control over the SERDES in terms of avoiding any possible cross-talks.</br>
- Xilinx primitive `IOBUFDS` is used for connecting single ended bidirectional port of the design with differential LVDS IO physical port of the ZYNQ_SoC (Microzed-7Z020)</br>

`PHY_Layer/PHY_Master_controller.vhd` : VHDL Controller for controlling PHY Master </br>
  - `PHY_Layer/PHY_Master.vhd: VHDL` code for Master PHY layer -> SERDES that controls clock as well as data. </br>
    - `PHY_Layer/PHY_Data_Path.vhd` : VHDL code for controlling SERDES data path.</br>
    - `PHY_Layer/PHY_sclk_gen.vhd`  : VHDL code for controlling LVDS clock.</br>
    
`PHY_Layer/PHY_Slave_Controller.vhd` : VHDL Controller for controlling PHY Slave  </br>
  - `PHY_Layer/PHY_Slave.vhd: VHDL` code for Slave PHY layer -> Slave SERDES. </br>
