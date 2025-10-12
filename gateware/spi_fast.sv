`default_nettype none

module spi_slave (
	input wire clk,
  input wire spi_cs_n,
  input wire spi_clk,
  inout wire [3:0] spi_d,
  output wire [31:0] bus_addr,
  output wire [31:0] bus_wdata,
  output wire bus_wen
);

    typedef enum logic [2:0] {
        SPI_CMD,
        SPI_ADDR,
        SPI_DUMMY_0,
        SPI_WDATA,
        SPI_DUMMY_1
    } state_t;

    state_t state;
    logic [5:0] cntr;

    logic [15:0] reg_cmd;
    logic [31:0] reg_addr;
    logic [31:0] reg_data;

    always_ff @(posedge spi_clk or posedge spi_cs_n) begin
        if (spi_cs_n) begin
            state <= SPI_CMD;
            cntr <= 0;
        end else begin
            cntr <= cntr + 1;
            case (state)
              SPI_CMD: begin
                reg_cmd <= {reg_cmd[14:0], spi_d[0]};
                if (cntr == 15) begin
                  cntr <= 0;
                  state <= SPI_ADDR;
                end
              end
              SPI_ADDR: begin
                reg_addr <= {reg_addr[30:0], spi_d[0]};
                if (cntr == 31) begin
                  cntr <= 0;
                  state <= SPI_DUMMY_0;
                end
              end
              SPI_DUMMY_0: begin
                if (cntr == 7) begin
                  cntr <= 0;
                  state <= SPI_WDATA;
                end
              end
              SPI_WDATA: begin
                reg_data <= {reg_data[30:0], spi_d[0]};
                if (cntr == 31) begin
                  cntr <= 0;
                  state <= SPI_DUMMY_1;
                end
              end
              SPI_DUMMY_1: begin
                // Wait for spi_cs_n to go get deasserted (as it will trigger a reset of the FSM)
              end
            endcase
        end
    end

    // Data is held in 'reg_addr' and 'reg_data' now synchronize write enable to
    // 'clk' domain.
    logic [2:0] sync;
    always_ff @(posedge clk) begin
      sync <= {sync[1:0], (state == SPI_DUMMY_1) ? 1'b1 : 1'b0};
    end

    assign bus_addr = reg_addr;
    assign bus_wdata = reg_data;
    assign bus_wen = ~sync[2] & sync[1];

    // Note that 8 dummy bits must be appended to the write data

endmodule
