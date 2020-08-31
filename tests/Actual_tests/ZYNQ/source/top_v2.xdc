# create_clock -period 10.000 -name clk_100 -waveform {0.000 5.000} [get_signals clk_100]
create_clock -period 10.000 -name clk_100 -waveform {0.000 5.000} [get_pins {*/PS7_inst/FCLKCLK[0]}]
set_property PACKAGE_PIN R19 [get_ports LVDS_clk_top]
set_property IOSTANDARD LVCMOS25 [get_ports LVDS_clk_top]
set_property PACKAGE_PIN P14 [get_ports LVDS_IO_top_p]
set_property IOSTANDARD BLVDS_25 [get_ports LVDS_IO_top_p]

set_property PACKAGE_PIN R14 [get_ports LVDS_IO_top_n]
set_property IOSTANDARD BLVDS_25 [get_ports LVDS_IO_top_n]