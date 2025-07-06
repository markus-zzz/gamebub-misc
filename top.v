`default_nettype none

module top(
	input wire clk_50mhz,
	inout wire [3:0] pmod,
  input wire mcu_spi_clk,
  inout wire [3:0] mcu_spi_d
);
  wire rst;
  assign rst = mcu_spi_d[3];
	reg [31:0] cntr;
	reg [3:0] r;
	assign pmod = r;
	//assign pmod = (r == 4'b0000 ? 4'b1111 : 4'b0000);
	always @(posedge clk_50mhz) begin
		if (cntr == 50_000) begin
			cntr <= 0;
			r <= r + 1;
		end
		else begin
			cntr <= cntr + 1;
		end
	end

  //
  // SPI - number source (one byte wide numbers)
  //
  reg [2:0] spi_clk_sync;
  reg [7:0] spi_miso_shift;
  reg [11:0] spi_cntr;

  assign mcu_spi_d[1] = spi_miso_shift[7];
  always @(posedge clk_50mhz) begin
    if (rst) begin
      spi_clk_sync <= 0;
      spi_cntr <= 0;
      spi_miso_shift <= 0;
    end
    else begin
      spi_clk_sync <= {mcu_spi_clk, spi_clk_sync[2:1]};
      if (~spi_clk_sync[0] & spi_clk_sync[1]) begin
        spi_cntr <= spi_cntr + 1;
        if (spi_cntr[2:0] == 0) begin
          spi_miso_shift <= spi_cntr[10:3];
        end else begin
          spi_miso_shift <= {spi_miso_shift[6:0], 1'b0};
        end
      end
    end
  end
endmodule

/*
module tb;
  reg clk;
  reg clk_spi;

  always #5 clk = ~clk;
  always #40 clk_spi = ~clk_spi;

  top u_top(
    .clk_50mhz(clk),
    .mcu_spi_clk(clk_spi)
  );

  initial begin
    $dumpfile("dump.vcd"); // Output VCD file name
    $dumpvars;

    clk = 0;
    clk_spi = 0;
    #100000;
    $finish;
  end
endmodule
*/
