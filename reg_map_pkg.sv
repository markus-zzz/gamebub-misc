package reg_map_pkg;

localparam logic [31:0] R_RESET_CTRL = 32'hf800_0000;

/////////////////////////////////////
// Integrated Logic Analyzer (ILA) //
/////////////////////////////////////
localparam logic [31:0] BASE_ILA          = 32'hf810_0000;
localparam logic [31:0] BASE_ILA_RAM      = 32'hf810_0000; // The sample RAM (though the sampling RAM may be narrower than 32 bits it is always accessed as 32 bits from the bus)
localparam logic [31:0] R_ILA_INFO        = 32'hf818_0000; // Contains info about the instantiated ILA such as width and depth
localparam logic [31:0] R_ILA_CTRL_STATUS = 32'hf818_0004; // Bits to control like start, stop etc

/////////////////////////////////////
// Scratch RAM                     //
/////////////////////////////////////
localparam logic [31:0] BASE_SCRATCH_RAM  = 32'hf820_0000;

endpackage
