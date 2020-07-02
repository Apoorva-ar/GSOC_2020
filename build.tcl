
prj_project new -name "Bidirectional_LVDS_Packet_proj" -impl "impl1" -dev LCMXO2-1200HC-5TG144C -synthesis "lse"
prj_src add "/packet_layer_tb.vhd" "/packet_layer_testbench.vhd" "/PHY_top_tb.vhd" 
"/clock_gen.vhd" "/data_path.vhd" "/PHY_controller.vhd" "/PHY_Master.vhd"
"/PHY_slave.vhd" "/PHY_slave_controller.vhd" "/packet_layer_Master.vhd"
"/packet_layer_SLave.vhd" "/Debug_core_Master.vhd" "/gray_counter.vhd" 
"/asyn_fifo.vhd" "/sclk_gen.vhd" "/spi_data_path.vhd" "/spi_master.vhd" "/PHY_master.lpf"
prj_project save
prj_run Synthesis -impl impl1
prj_run PAR -impl impl1
