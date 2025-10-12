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
