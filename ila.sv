`default_nettype none

import reg_map_pkg::*;

// R_ILA_CTRL_STATUS
// -------------------
// bit 0    - running R/W
// bit 1    - triggered RO
// bit 31:8 - Write is post trigger samples, Read is trigger index

module ila #(
  parameter logic [15:0] WIDTH = 32,
  parameter logic [15:0] DEPTH = 1024
)
(
  input wire clk,
  input wire rst,
  // Sampling interface
  input wire trigger_in,
  input wire [WIDTH-1:0] sample_in,
  // Bus interface
  input wire [31:0] bus_addr,
  input wire bus_wen,
  input wire bus_ren,
  input wire [31:0] bus_wdata,
  output logic [31:0] bus_rdata
);

  logic running;
  logic triggered;
  logic [$clog2(DEPTH)-1:0] sample_widx;
  logic [$clog2(DEPTH)-1:0] sample_cntr;
  logic [$clog2(DEPTH)-1:0] trigger_idx;

  logic [WIDTH-1:0] ram_do;

  spram u_ram(
    .clk(clk),
    .rst(rst),
    .ce(1'b1),
    .we(running),
    .oe(1'b1),
    .addr(running ? sample_widx : bus_addr[31:2]),
    .din(sample_in),
    .dout(ram_do)
  );

  always_ff @(posedge clk) begin
    if (rst) sample_widx <= 0;
    else if (running) sample_widx <= sample_widx + 1;
  end

  always_ff @(posedge clk) begin
    if (rst) trigger_idx <= 0;
    else if (trigger_in & ~triggered) trigger_idx <= sample_widx;
  end

  always_ff @(posedge clk) begin
    if (bus_addr == R_ILA_CTRL_STATUS && bus_wen) sample_cntr <= bus_wdata[31:8];
    else if (running & triggered) sample_cntr <= sample_cntr - 1;
  end

  always_ff @(posedge clk) begin
    if (rst) running <= 0;
    else if (bus_addr == R_ILA_CTRL_STATUS && bus_wen) running <= bus_wdata[0];
    else if (triggered && sample_cntr == 0) running <= 0;
  end

  always_ff @(posedge clk) begin
    if (rst) triggered <= 0;
    else if (bus_addr == R_ILA_CTRL_STATUS && bus_wen && bus_wdata[0]) triggered <= 0;
    else if (running & trigger_in) triggered <= 1;
  end

  always_comb begin
    case (bus_addr)
      R_ILA_INFO: bus_rdata = {DEPTH, WIDTH};
      R_ILA_CTRL_STATUS: bus_rdata = {trigger_idx, 6'h0, triggered, running};
      default: bus_rdata = ram_do;
    endcase
  end

endmodule
