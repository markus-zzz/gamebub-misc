#!/bin/bash

set -x
set -e

verilator -Wall --Wno-fatal --cc -O3 --top-module top \
          gateware/reg_map_pkg.sv \
          gateware/ila.sv \
          gateware/lcd_vidgen.sv \
          gateware/overlay.sv \
          gateware/spi_slow.sv \
          gateware/spram.v \
          gateware/top.sv \
          --exe tb_top.cpp --trace-fst \
          -CFLAGS '`pkg-config --cflags gtk+-3.0`' \
          -LDFLAGS '`pkg-config --libs gtk+-3.0`'

make -C obj_dir -f Vtop.mk Vtop
