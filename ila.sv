`default_nettype none

import reg_map_pkg::*;

module ila #(
  parameter logic [7:0] WIDTH = 32,
  parameter int DEPTH = 1024
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
    .addr(running ? sample_widx : bus_addr[$clog2(DEPTH)-1:0]),
    .din(sample_in),
    .dout(ram_do)
  );

  always_ff @(posedge clk) begin
    if (rst) sample_widx <= 0;
    else if (running) sample_widx <= sample_widx + 1;
  end

  always_ff @(posedge clk) begin
    if (rst) trigger_idx <= 0;
    else if (trigger_in) trigger_idx <= sample_widx;
  end

  always_ff @(posedge clk) begin
    if (running & trigger_in) sample_cntr <= 0; //r_ila_trig_post_samples; // XXX: This could be same register i.e. sw reloads every time
    else if (running & triggered) sample_cntr <= sample_cntr - 1;
  end

  always_ff @(posedge clk) begin
    if (rst) running <= 0;
    else if (bus_addr == R_ILA_CTRL && bus_wen && bus_wdata[0]) running <= 1;
    else if (sample_cntr == 0) running <= 0;
  end

  always_ff @(posedge clk) begin
    if (rst) triggered <= 0;
    else if (running & trigger_in) triggered <= 1;
  end

  always_comb begin
    case (bus_addr)
      R_ILA_INFO: bus_rdata = {WIDTH};
      R_ILA_CTRL: bus_rdata = 0;
      R_ILA_STATUS: bus_rdata = 0;
      R_ILA_TRIG_POST_SAMPLES: bus_rdata = 0;
      R_ILA_TRIG_IDX: bus_rdata = trigger_idx;
      default: bus_rdata = ram_do;
    endcase
  end

endmodule
