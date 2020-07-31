
prj_project new -name "Bidirectional_LVDS_Packet_proj" -impl "impl1" -dev LCMXO2-1200HC-5TG144C -synthesis "lse"
prj_src add "/Packet_layer_tb.vhd" "/Packet_layer_SPI_tb.vhd" "/PHY_top_tb.vhd"
"/PHY_sclk_gen.vhd" "/PHY_Data_path.vhd" "/PHY_Master_Controller.vhd" "/PHY_Master.vhd"
"/PHY_Slave.vhd" "/PHY_Slave_Controller.vhd" "/Packet_layer_Master.vhd"
"/Packet_layer_Slave.vhd" "/PHY_master.lpf" "/FIFOx64.vhd" "/Scheduler_Master.vhd" "/command_fifo_1.vhd"
"/command_fifo_2.vhd" "/command_fifo_3.vhd" "/data_fifo_1.vhd" "/data_fifo_2.vhd" "/data_fifo_3.vhd"
"/fifo_read_1.vhd" "/fifo_read_2.vhd" "/fifo_read_3.vhd"
prj_project save
prj_run Synthesis -impl impl1
prj_run PAR -impl impl1
