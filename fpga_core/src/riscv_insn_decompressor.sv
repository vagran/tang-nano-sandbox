// Decompresses 16 bits instruction code into full 32 bits code.
module RiscvInsnDecompressor(input wire [15:0] compressed, output wire [31:0] decompressed);

//XXX
assign decompressed = {compressed, compressed};

endmodule;