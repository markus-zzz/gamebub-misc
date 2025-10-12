`default_nettype none

import reg_map_pkg::*;

module overlay(
  input wire clk_50mhz,
  input wire rst,
  input wire clk_en_12_5mhz,
  // Bus signals
  input wire [31:0] bus_addr,
  output logic [31:0] bus_rdata,
  input wire [31:0] bus_wdata,
  input wire bus_ren,
  input wire bus_wen,
  // Display signals
  input wire hsync,
  input wire vsync,
  input wire disp_en,
  output logic ovl_out
);

  logic hsync_prev;
  logic [3:0] hsync_shift;
  always_ff @(posedge clk_50mhz) begin
    hsync_prev <= hsync;
    hsync_shift <= {hsync_shift[2:0], hsync_prev & ~hsync};
  end

  logic vsync_prev;
  logic vsync_fall;
  assign vsync_fall = vsync_prev & ~vsync;
  always_ff @(posedge clk_50mhz) vsync_prev <= vsync;

  logic ram_we;
  logic [31:0] ram_do;

  logic bus_ren_pend, bus_ren_pend_prev;
  logic bus_wen_pend;

  always_ff @(posedge clk_50mhz) begin
    bus_ren_pend_prev <= bus_ren_pend;
    if (bus_ren) bus_ren_pend <= 1;
    else if (bus_ren_pend & ~overlay_ren) bus_ren_pend <= 0;
   end

  always_ff @(posedge clk_50mhz) begin
    if (bus_wen) bus_wen_pend <= 1;
    else if (bus_wen_pend & ~overlay_ren) bus_wen_pend <= 0;
  end

  always_ff @(posedge clk_50mhz) begin
    if (bus_ren_pend_prev) bus_rdata <= ram_do;
  end

  assign ram_we = {bus_addr[31:20], 20'h0} == BASE_OVERLAY_RAM && (bus_wen_pend & ~overlay_ren);

  spram #(
    .aw(13),
    .dw(32)
  ) ram_0(
    .clk(clk_50mhz),
    .rst(rst),
    .ce(1'b1),
    .we(ram_we),
    .oe(1'b1),
    .addr(overlay_ren ? overlay_addr : bus_addr[31:2]),
    .din(bus_wdata),
    .dout(ram_do)
  );

  logic htoggle;
  always_ff @(posedge clk_50mhz) begin
    if (hsync_shift[0]) htoggle <= 0;
    else if (clk_en_12_5mhz & disp_en) htoggle <= ~htoggle;
  end

  logic [31:0] pixels_reg;
  logic [15:0] overlay_addr, overlay_addr_prev;
  logic vtoggle;

  always_ff @(posedge clk_50mhz) begin
    if (vsync_fall) begin
      overlay_addr <= 0;
      overlay_addr_prev <= 0;
      vtoggle <= 1;
    end else if (hsync_shift[0]) begin
      if (vtoggle) overlay_addr <= overlay_addr_prev;
      vtoggle <= ~vtoggle;
      overlay_addr_prev <= overlay_addr;
    end else if (clk_en_12_5mhz && disp_en && htoggle && (pixel_idx == 29)) begin
      overlay_addr <= overlay_addr + 1;
    end
  end

  logic [4:0] pixel_idx;
  always_ff @(posedge clk_50mhz) begin
    if (vsync_fall) pixel_idx <= 0;
    else if (clk_en_12_5mhz & disp_en & htoggle) pixel_idx <= pixel_idx + 1;
  end

  logic overlay_ren, overlay_ren_prev;
  assign overlay_ren = hsync_shift[1] || (clk_en_12_5mhz && disp_en && htoggle && (pixel_idx == 30));
  always_ff @(posedge clk_50mhz) overlay_ren_prev <= overlay_ren;

  always_ff @(posedge clk_50mhz) begin
    if (hsync_shift[3]) pixels_reg <= ram_do_latch;
    else if (clk_en_12_5mhz) begin
      if (htoggle && pixel_idx == 31) pixels_reg <= ram_do_latch;
      else if (disp_en & htoggle) pixels_reg <= {1'b0, pixels_reg[31:1]}; // XXX: Maybe better not not shift after all
    end
  end

  logic [31:0] ram_do_latch;
  always_ff @(posedge clk_50mhz) if (overlay_ren_prev) ram_do_latch <= ram_do;

  assign ovl_out = pixels_reg[0];
endmodule

