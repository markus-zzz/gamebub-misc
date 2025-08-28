`default_nettype none

import reg_map_pkg::*;

module top(
	input wire clk_50mhz,
	output wire [3:0] pmod,
  input wire mcu_spi_cs_n,
  input wire mcu_spi_clk,
  input wire mcu_spi_mosi,
  output wire mcu_spi_miso,
  output logic        lcd_dotclk,
  output logic        lcd_hsync,
  output logic        lcd_vsync,
  output logic        lcd_data_en,
  output logic [17:0] lcd_db,
  input wire        lcd_te
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
    .we(bus_wen),
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
    .trigger_in((hpos == 9'd123) ? 1'b1 : 1'b0),
    .sample_in({7'h0, vpos, 7'h0, hpos}),
    // Bus interface
    .bus_addr(bus_addr),
    .bus_wen(bus_wen),
    .bus_ren(bus_ren),
    .bus_wdata(bus_wdata),
    .bus_rdata(ila_rdata)
  );

  always_comb begin
    case ({bus_addr[31:20], 20'h0})
      BASE_ILA: bus_rdata = ila_rdata;
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

  //
  // Everything is in the 50MHz clock domain but for display activities we
  // generate a clock enable pulse every four cycles to get 12.5MHz
  //
  logic [1:0] clkdiv;
  logic clk_en_12_5mhz;
  assign clk_en_12_5mhz = (clkdiv == 2'b00);
  always_ff @(posedge clk_50mhz) begin
    if (rst) clkdiv <= 0;
    else clkdiv <= clkdiv + 1;
  end

  logic [9:0] hpos;
  logic [9:0] vpos;

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

  logic [8:0] image_pos_x;
  logic [8:0] image_pos_y;
  logic [8:0] image_dir_x;
  logic [8:0] image_dir_y;

  logic [17:0] rgb_array [0:128*128-1];
  logic [13:0] rgb_array_idx;
  logic [6:0] rgb_idx_h;
  logic [6:0] rgb_idx_v;
  logic [17:0] rgb_data;
  assign rgb_idx_v = image_pos_y - (vpos - VACT_start);
  assign rgb_idx_h = image_pos_x - (hpos - HACT_start);
  assign rgb_data = rgb_array[rgb_array_idx];

  //
  // All outputs towards LCD are logicistered
  //
  always_ff @(posedge clk_50mhz) begin
    rgb_array_idx <= {rgb_idx_v, rgb_idx_h};

    lcd_dotclk <= clkdiv[1];
    lcd_vsync <= ~(vpos == 0);
    lcd_hsync <= ~(hpos[9:2] == 0);
    lcd_data_en <= (hpos >= HACT_start) && (hpos < HACT_end) && (vpos >= VACT_start) && (vpos < VACT_end);

    if ((hpos == HACT_start) || (hpos == HACT_end - 1) || (vpos == VACT_start) || (vpos == VACT_end - 1)) begin
      // Draw white border
      lcd_db <= border;
    end
    else if ((vpos - VACT_start > image_pos_y) && (vpos - VACT_start <= image_pos_y + 128) && (hpos - HACT_start > image_pos_x) && (hpos - HACT_start <= image_pos_x + 128)) begin
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
      if (image_dir_x == 1 && image_pos_x >= HACT - 128) image_dir_x <= -1;
      else if ($signed(image_dir_x) == -1 && image_pos_x == 0) image_dir_x <= 1;
      else image_pos_x <= image_pos_x + image_dir_x;

      if (image_dir_y == 1 && image_pos_y >= VACT - 128) image_dir_y <= -1;
      else if ($signed(image_dir_y) == -1 && image_pos_y == 0) image_dir_y <= 1;
      else image_pos_y <= image_pos_y + image_dir_y;

    end
  end

  initial begin
    $readmemh("image.dat", rgb_array);
  end

endmodule
