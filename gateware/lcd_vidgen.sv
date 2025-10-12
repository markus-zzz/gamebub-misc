`default_nettype none

import reg_map_pkg::*;

module lcd_vidgen(
  input wire clk_50mhz,
  input wire rst,
  output logic clk_en_12_5mhz,
  output logic dotclk,
  output logic vsync,
  output logic hsync,
  output logic data_en,
  output logic [9:0] x,
  output logic [9:0] y
);
  //
  // Everything is in the 50MHz clock domain but for display activities we
  // generate a clock enable pulse every four cycles to get 12.5MHz
  //
  logic [1:0] clkdiv;
  assign clk_en_12_5mhz = (clkdiv == 2'b00);
  always_ff @(posedge clk_50mhz) begin
    if (rst) clkdiv <= 0;
    else clkdiv <= clkdiv + 1;
  end


  // Horizontal Synchronization
  localparam H_Low = 30;
  // Horizontal Back Porch
  localparam HBP = 29;
  // Horizontal Front Porch
  localparam HFP = 29;
  // Horizontal Address
  localparam HACT = 320;
  // Vertical Synchronization
  localparam V_Low = 8;
  // Vertical Back Porch
  localparam VBP = 7;
  // Vertical Front Porch
  localparam VFP = 7;
  // Vertical Address
  localparam VACT = 480;

  localparam HACT_start = H_Low + HBP;
  localparam VACT_start = V_Low + VBP;
  localparam HACT_end = HACT_start + HACT;
  localparam VACT_end = VACT_start + VACT;

  logic [9:0] hpos;
  logic [9:0] vpos;
  // Note: The RGB input signal, when set to the BYPASS mode, the Hsync low >= 3, HBP >= 3, HFP >= 10

  always_ff @(posedge clk_50mhz) begin
    if (rst) begin
      hpos <= 0;
      vpos <= 0;
    end
    else if (clk_en_12_5mhz) begin
      if (hpos == H_Low + HBP + HACT + HFP - 1) begin
        hpos <= 0;
        if (vpos == V_Low + VBP + VACT + VFP - 1) vpos <= 0;
        else vpos <= vpos + 1;
      end
      else begin
        hpos <= hpos + 1;
      end
    end
  end

  assign dotclk = clkdiv[1];
  assign vsync = ~(vpos == 0);
  assign hsync = ~(hpos[9:2] == 0);
  assign data_en = (hpos >= HACT_start) && (hpos < HACT_end) && (vpos >= VACT_start) && (vpos < VACT_end);

  assign x = hpos - HACT_start;
  assign y = vpos - VACT_start;

endmodule

