#create_clock -period 20.000 -name clk -waveform {0.000 10.000} [get_ports clk]

set_property PACKAGE_PIN E13 [get_ports {lenet_status_led_o_0[1]}]
set_property PACKAGE_PIN E12 [get_ports {lenet_status_led_o_0[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {lenet_status_led_o_0[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {lenet_status_led_o_0[1]}]
