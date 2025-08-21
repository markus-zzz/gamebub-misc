set outputDir ./out
file mkdir $outputDir

read_verilog -sv reg_map_pkg.sv
read_verilog -sv top.sv
read_verilog -sv spi_slow.sv
read_verilog -sv ila.sv
read_verilog spram.v
read_xdc io.xdc

synth_design -top top -part xc7a100tcsg324-2
write_checkpoint -force $outputDir/post_synth.dcp
report_utilization -file $outputDir/post_synth_util.rpt

opt_design
place_design
write_checkpoint -force $outputDir/post_place.dcp
route_design
write_checkpoint -force $outputDir/post_route.dcp
write_bitstream -force $outputDir/pmod.bit
quit
