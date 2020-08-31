
prj_project new -name "Bidirectional_LVDS_Packet_proj" -impl "impl1" -dev LCMXO2-1200HC-6TG100C -synthesis "lse"
prj_src add 
"/PHY_Slave.vhd" "/PHY_Slave_Controller.vhd"
"/Packet_layer_Slave.vhd" "/bd_Slave_impl1.lpf"
prj_project save
prj_run Synthesis -impl impl1
prj_run PAR -impl impl1
prj_run Export -impl impl1
