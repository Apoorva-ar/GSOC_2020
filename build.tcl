
prj_project new -name "Bidirectional_LVDS_Packet_proj" -impl "impl1" -dev LCMXO2-1200HC-5TG144C -synthesis "lse"
prj_src add "/Packet_layer_tb.vhd" "/Packet_layer_SPI_tb.vhd" "/PHY_top_tb.vhd"
"/PHY_clock_gen.vhd" "/PHY_Data_path.vhd" "/PHY_Master_Controller.vhd" "/PHY_Master.vhd"
"/PHY_Slave.vhd" "/PHY_Slave_Controller.vhd" "/Packet_layer_Master.vhd"
"/Packet_layer_Slave.vhd" "/Debug_core_Master.vhd" "/gray_counter.vhd" 
"/asyn_fifo.vhd" "/sclk_gen.vhd" "/spi_data_path.vhd" "/spi_master.vhd" "/PHY_master.lpf"
prj_project save
prj_run Synthesis -impl impl1
prj_run PAR -impl impl1
