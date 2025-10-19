set outputDir ./out
file mkdir $outputDir

read_verilog -sv gateware/reg_map_pkg.sv
read_verilog -sv gateware/ila.sv
read_verilog -sv gateware/lcd_vidgen.sv
read_verilog -sv gateware/overlay.sv
read_verilog -sv gateware/spi_slow.sv
read_verilog gateware/spram.v
read_verilog -sv gateware/top.sv
read_xdc gateware/io.xdc

# Must not flatten hierarchy for hierarchical references to work (used with ILA)
synth_design -top top -part xc7a100tcsg324-2 -flatten_hierarchy none
write_checkpoint -force $outputDir/post_synth.dcp
report_utilization -file $outputDir/post_synth_util.rpt

opt_design
place_design
write_checkpoint -force $outputDir/post_place.dcp
route_design
write_checkpoint -force $outputDir/post_route.dcp
write_bitstream -force $outputDir/fpga.bit
quit
