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

########################################
# LCD
########################################
set_property -dict { PACKAGE_PIN E17    IOSTANDARD LVCMOS33 } [get_ports { lcd_dotclk  }];
set_property -dict { PACKAGE_PIN E18    IOSTANDARD LVCMOS33 } [get_ports { lcd_hsync   }];
set_property -dict { PACKAGE_PIN D17    IOSTANDARD LVCMOS33 } [get_ports { lcd_vsync   }];
set_property -dict { PACKAGE_PIN F18    IOSTANDARD LVCMOS33 } [get_ports { lcd_data_en }];
set_property -dict { PACKAGE_PIN T11    IOSTANDARD LVCMOS33 } [get_ports { lcd_te      }];
set_property -dict { PACKAGE_PIN K16    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[0]   }];
set_property -dict { PACKAGE_PIN K15    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[1]   }];
set_property -dict { PACKAGE_PIN J15    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[2]   }];
set_property -dict { PACKAGE_PIN H15    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[3]   }];
set_property -dict { PACKAGE_PIN G16    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[4]   }];
set_property -dict { PACKAGE_PIN F16    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[5]   }];
set_property -dict { PACKAGE_PIN F15    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[6]   }];
set_property -dict { PACKAGE_PIN E16    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[7]   }];
set_property -dict { PACKAGE_PIN E15    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[8]   }];
set_property -dict { PACKAGE_PIN D15    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[9]   }];
set_property -dict { PACKAGE_PIN L18    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[10]  }];
set_property -dict { PACKAGE_PIN K17    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[11]  }];
set_property -dict { PACKAGE_PIN J17    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[12]  }];
set_property -dict { PACKAGE_PIN J18    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[13]  }];
set_property -dict { PACKAGE_PIN H17    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[14]  }];
set_property -dict { PACKAGE_PIN H16    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[15]  }];
set_property -dict { PACKAGE_PIN G18    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[16]  }];
set_property -dict { PACKAGE_PIN G17    IOSTANDARD LVCMOS33 } [get_ports { lcd_db[17]  }];
