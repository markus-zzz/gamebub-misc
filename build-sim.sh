#!/bin/bash

set -x
set -e

verilator -Wall --Wno-fatal --cc --top-module top \
          reg_map_pkg.sv ila.sv spi_slow.sv top.sv spram.v \
          --exe tb_top.cpp --trace-fst \
          -CFLAGS '`pkg-config --cflags gtk+-3.0`' \
          -LDFLAGS '`pkg-config --libs gtk+-3.0`'

make -C obj_dir -f Vtop.mk Vtop
