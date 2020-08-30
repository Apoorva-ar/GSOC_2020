
# create_clock -period 10.000 -name clk_100 -waveform {0.000 5.000} [get_signals clk_100]

# create_clock -period 10.000 -name clk_100 -waveform {0.000 5.000} [get_pins {*/PS7_inst/FCLKCLK[0]}]
# create_clock -period 8.000 -name lvds_clk_125 -waveform {0.000 4.000} [get_port cmv_lvds_outclk_*]


set_property IOSTANDARD LVCMOS25 [get_ports LVDS_clk_top]
set_property PACKAGE_PIN P14 [get_ports LVDS_IO_top]
set_property IOSTANDARD LVDS_25 [get_ports LVDS_IO_top]
set_property PACKAGE_PIN R19 [get_ports LVDS_clk_top]
