`default_nettype none

import reg_map_pkg::*;

module top(
	input wire clk_50mhz,
	output wire [3:0] pmod,
  // MCU SPI
  input wire mcu_spi_cs_n,
  input wire mcu_spi_clk,
  input wire mcu_spi_mosi,
  output wire mcu_spi_miso,
  // LCD
  output logic        lcd_dotclk,
  output logic        lcd_hsync,
  output logic        lcd_vsync,
  output logic        lcd_data_en,
  output logic [17:0] lcd_db,
  input wire        lcd_te,
  // Buttons
  input  wire        btn_a,
  input  wire        btn_b,
  input  wire        btn_x,
  input  wire        btn_y,
  input  wire        btn_up,
  input  wire        btn_down,
  input  wire        btn_left,
  input  wire        btn_right,
  input  wire        btn_l,
  input  wire        btn_r,
  input  wire        btn_start,
  input  wire        btn_select
);

  logic rst;
  logic [31:0] bus_addr;
  logic [31:0] bus_rdata;
  logic [31:0] bus_wdata;
  logic bus_ren;
  logic bus_wen;

  logic [17:0] border;

  assign pmod = {mcu_spi_mosi, mcu_spi_cs_n, mcu_spi_clk};
  logic [31:0] ram_0_do;

  spi_slave spi_slave_0(
	  .clk(clk_50mhz),
    .spi_cs_n(mcu_spi_cs_n),
    .spi_clk(mcu_spi_clk),
    .spi_miso(mcu_spi_miso),
    .spi_mosi(mcu_spi_mosi),
    .bus_addr(bus_addr),
    .bus_rdata(bus_rdata),
    .bus_wdata(bus_wdata),
    .bus_ren(bus_ren),
    .bus_wen(bus_wen)
  );

  /////////////////////
  // BUS ADDRESS MAP //
  /////////////////////
  //
  // ----------------------------------------------------
  // 0x0000_0000 - 0xf7ff_ffff -- Forwarded to user
  // ----------------------------------------------------
  // 0xf800_0000 - 0xffff_ffff -- Reserved for framework
  // ----------------------------------------------------
  //
  //   0xf800_0000 - 0xf800_0003 -- Reset control

  spram ram_0(
    .clk(clk_50mhz),
    .rst(rst),
    .ce(1'b1),
    .we({bus_addr[31:20], 20'h0} == BASE_SCRATCH_RAM && bus_wen),
    .oe(1'b1),
    .addr(bus_addr[31:2]),
    .din(bus_wdata),
    .dout(ram_0_do)
  );

  logic [31:0] ila_rdata;
  ila u_ila(
    .clk(clk_50mhz),
    .rst(rst),
    // Sampling interface
    .trigger_in(~btn_right),
    .sample_in({btn_right, vpos[9:0], hpos[9:0]}),
    // Bus interface
    .bus_addr(bus_addr),
    .bus_wen(bus_wen),
    .bus_ren(bus_ren),
    .bus_wdata(bus_wdata),
    .bus_rdata(ila_rdata)
  );

  //
  // SPI read mux
  //
  always_comb begin
    case ({bus_addr[31:20], 20'h0})
      BASE_ILA: bus_rdata = ila_rdata;
      BASE_OVERLAY_RAM: bus_rdata = ovl_rdata;
      BASE_SCRATCH_RAM: bus_rdata = ram_0_do;
      default: bus_rdata = 32'hdead_dead;
    endcase
  end

  always_ff @(posedge clk_50mhz) begin
    if (bus_wen && (bus_addr == R_RESET_CTRL)) begin
      rst <= bus_wdata[0];
    end

    if (bus_wen && (bus_addr == 32'hf800_1010)) begin
      border <= bus_wdata;
    end
  end

  logic dotclk;
  logic vsync;
  logic hsync;
  logic data_en;
  logic [9:0] hpos;
  logic [9:0] vpos;

  logic clk_en_12_5mhz;

  lcd_vidgen lcd_vidgen_0(
    .clk_50mhz(clk_50mhz),
    .rst(rst),
    .clk_en_12_5mhz(clk_en_12_5mhz),
    .dotclk(dotclk),
    .vsync(vsync),
    .hsync(hsync),
    .data_en(data_en),
    .x(hpos),
    .y(vpos)
  );

  logic ovl_en;
  logic [31:0] ovl_rdata;

  overlay ovl_0(
    .clk_50mhz(clk_50mhz),
    .rst(rst),
    .clk_en_12_5mhz(clk_en_12_5mhz),
    // Bus signals
    .bus_addr(bus_addr),
    .bus_rdata(ovl_rdata),
    .bus_wdata(bus_wdata),
    .bus_ren(bus_ren),
    .bus_wen(bus_wen),
    // Display signals
    .hsync(hsync),
    .vsync(vsync),
    .disp_en(data_en),
    .ovl_out(ovl_en)
  );

  logic [8:0] image_pos_x;
  logic [8:0] image_pos_y;
  logic [8:0] image_dir_x;
  logic [8:0] image_dir_y;

  logic [17:0] rgb_array [0:128*128-1];
  logic [13:0] rgb_array_idx;
  logic [6:0] rgb_idx_h;
  logic [6:0] rgb_idx_v;
  logic [17:0] rgb_data;
  assign rgb_idx_v = image_pos_y - vpos;
  assign rgb_idx_h = image_pos_x - hpos;
  assign rgb_data = rgb_array[rgb_array_idx];


  //
  // All outputs towards LCD are registered
  //
  always_ff @(posedge clk_50mhz) begin
    rgb_array_idx <= {rgb_idx_v, rgb_idx_h};

    lcd_dotclk <= dotclk;
    lcd_vsync <= vsync;
    lcd_hsync <= hsync;
    lcd_data_en <= data_en;
/*
    if ((hpos == 0) || (hpos == 320 - 1) || (vpos == 0) || (vpos == 480 - 1)) begin
      // Draw white border
      lcd_db <= border;
    end
    else */ if (ovl_en) begin
      lcd_db <= 18'h3ffff;
    end
    else if ((vpos > image_pos_y) && (vpos <= image_pos_y + 128) && (hpos > image_pos_x) && (hpos <= image_pos_x + 128)) begin
      // Draw image
      lcd_db <= {rgb_data[5:0], rgb_data[11:6], rgb_data[17:12]};
    end
    else begin
      lcd_db <= 0;
    end
  end

  //
  // Crap code to bounce image
  //
  always_ff @(posedge clk_50mhz) begin
    if (rst) begin
      image_pos_x <= 0;
      image_pos_y <= 0;
      image_dir_x <= 1;
      image_dir_y <= 1;
    end
    else if (clk_en_12_5mhz && hpos == 0 && vpos == 0) begin
      if (image_dir_x == 1 && image_pos_x >= 320 - 128) image_dir_x <= -1;
      else if ($signed(image_dir_x) == -1 && image_pos_x == 0) image_dir_x <= 1;
      else image_pos_x <= image_pos_x + image_dir_x;

      if (image_dir_y == 1 && image_pos_y >= 480 - 128) image_dir_y <= -1;
      else if ($signed(image_dir_y) == -1 && image_pos_y == 0) image_dir_y <= 1;
      else image_pos_y <= image_pos_y + image_dir_y;

    end
  end

  initial begin
    $readmemh("image.dat", rgb_array);
  end

endmodule

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
  logic hsync_fall;
  logic hsync_rise;
  assign hsync_fall = hsync_prev & ~hsync;
  assign hsync_rise = ~hsync_prev & hsync;
  always_ff @(posedge clk_50mhz) hsync_prev <= hsync;

  logic vsync_prev;
  logic vsync_fall;
  logic vsync_rise;
  assign vsync_fall = vsync_prev & ~vsync;
  assign vsync_rise = ~vsync_prev & vsync;
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
    if (hsync_fall) htoggle <= 0;
    else if (clk_en_12_5mhz & disp_en) htoggle <= ~htoggle;
  end

  logic vtoggle;
  always_ff @(posedge clk_50mhz) begin
    if (vsync_fall) vtoggle <= 0;
    else if (hsync_fall) vtoggle <= ~vtoggle;
  end

  logic [4:0] pixel_idx;
  always_ff @(posedge clk_50mhz) begin
    if (vsync_fall) pixel_idx <= 0;
    else if (clk_en_12_5mhz & disp_en & htoggle) pixel_idx <= pixel_idx + 1;
  end

  logic [31:0] pixels_reg;
  logic [15:0] overlay_addr;
  always_ff @(posedge clk_50mhz) begin
    if (vsync_fall) overlay_addr <= 0;
    else if (overlay_ren) overlay_addr <= overlay_addr + 1;
  end

  logic overlay_ren, overlay_ren_prev;
  assign overlay_ren = vsync_rise || (clk_en_12_5mhz && disp_en && htoggle && (pixel_idx == 30));
  always_ff @(posedge clk_50mhz) overlay_ren_prev <= overlay_ren;

  always_ff @(posedge clk_50mhz) begin
    if (clk_en_12_5mhz) begin
      if (htoggle && pixel_idx == 31) pixels_reg <= ram_do_latch;
      else if (disp_en & htoggle) pixels_reg <= {1'b0, pixels_reg[31:1]}; // XXX: Maybe better not not shift after all
    end
  end

  logic [31:0] ram_do_latch;
  always_ff @(posedge clk_50mhz) if (overlay_ren_prev) ram_do_latch <= ram_do;

  assign ovl_out = pixels_reg[0];
endmodule

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
