/*
 * Copyright (C) 2018-2020 Markus Lavin (https://www.zzzconsulting.se/)
 *
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 */

`default_nettype none

module spram(clk, rst, ce, we, oe, addr, din, dout);
	//
	// Default address and data buses width (1024*32)
	//
	parameter aw = 10; //number of address-bits
	parameter dw = 32; //number of data-bits

	//
	// Generic synchronous single-port RAM interface
	//
	input wire          clk;  // Clock, rising edge
	input wire          rst;  // Reset, active high
	input wire          ce;   // Chip enable input, active high
	input wire          we;   // Write enable input, active high
	input wire          oe;   // Output enable input, active high
	input wire [aw-1:0] addr; // address bus inputs
	input wire [dw-1:0] din;  // input data bus
	output reg [dw-1:0] dout; // output data bus

	//
	// Module body
	//

	reg [dw-1:0] mem [(1<<aw) -1:0] /* verilator public */;
	reg [aw-1:0] ra;
	reg oe_r;

	always @(posedge clk)
		oe_r <= oe;

	always @*
//		if (oe_r)
			dout = mem[ra];

	// read operation
	always @(posedge clk)
	  if (ce)
	    ra <= addr;     // read address needs to be registered to read clock

	// write operation
	always @(posedge clk) begin
	  if (we && ce) begin
	    mem[addr] <= din;
            // $display("mem[%h] <= %h\n", addr, din);
          end
        end

endmodule
