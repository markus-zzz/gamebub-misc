module top(
	input wire clk_50mhz,
	inout wire [3:0] pmod
);
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
endmodule

