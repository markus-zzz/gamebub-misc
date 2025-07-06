set_property BITSTREAM.GENERAL.COMPRESS True [current_design]

set_property -dict { PACKAGE_PIN E3     IOSTANDARD LVCMOS33 } [get_ports { clk_50mhz }];
create_clock -add -name sys_clk_pin -period 20.00 -waveform {0 10} [get_ports { clk_50mhz }];
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets clk_in_50mhz]

set_property -dict { PACKAGE_PIN M14    IOSTANDARD LVCMOS33 } [get_ports { pmod[0] }];
set_property -dict { PACKAGE_PIN N14    IOSTANDARD LVCMOS33 } [get_ports { pmod[1] }];
set_property -dict { PACKAGE_PIN P14    IOSTANDARD LVCMOS33 } [get_ports { pmod[2] }];
set_property -dict { PACKAGE_PIN M13    IOSTANDARD LVCMOS33 } [get_ports { pmod[3] }];

########################################
# MCU Communication
########################################
set_property -dict { PACKAGE_PIN F4     IOSTANDARD LVCMOS33 } [get_ports { mcu_spi_clk  }];
set_property -dict { PACKAGE_PIN K1     IOSTANDARD LVCMOS33 } [get_ports { mcu_spi_cs_n }];
set_property -dict { PACKAGE_PIN J2     IOSTANDARD LVCMOS33 } [get_ports { mcu_spi_d[0] }];
set_property -dict { PACKAGE_PIN H1     IOSTANDARD LVCMOS33 } [get_ports { mcu_spi_d[1] }];
set_property -dict { PACKAGE_PIN H2     IOSTANDARD LVCMOS33 } [get_ports { mcu_spi_d[2] }];
set_property -dict { PACKAGE_PIN K2     IOSTANDARD LVCMOS33 } [get_ports { mcu_spi_d[3] }];
set_property -dict { PACKAGE_PIN J3     IOSTANDARD LVCMOS33 } [get_ports { mcu_irq_n    }];
