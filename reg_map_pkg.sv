package reg_map_pkg;

localparam logic [31:0] R_RESET_CTRL = 32'hf800_0000;

/////////////////////////////////////
// Integrated Logic Analyzer (ILA) //
/////////////////////////////////////
localparam logic [31:0] R_ILA_BASE   = 32'hf810_0000;
localparam logic [31:0] R_ILA_INFO = 32'hf810_0000; // Contains info about the instantiated ILA such as width and depth
localparam logic [31:0] R_ILA_CTRL = 32'hf810_0000; // Bits to control like start, stop etc
localparam logic [31:0] R_ILA_STATUS = 32'hf810_0000; // Status bits, is running, has triggered etc
localparam logic [31:0] R_ILA_TRIG_POST_SAMPLES = 32'hf810_0000; // Number of samples to record after trigger condition has occurred
localparam logic [31:0] R_ILA_TRIG_IDX = 32'hf810_0000; // Index of the sample wh
localparam logic [31:0] R_ILA_RAM = 32'hf810_0000; // The sample RAM (though the sampling RAM may be narrower than 32 bits it is always accessed as 32 bits from the bus)

endpackage

