// Decompresses 16 bits instruction code into full 32 bits code.
module RiscvInsnDecompressor(input wire [15:0] insn16, output reg [31:0] insn32);

always @(insn16) begin
// Implementation is in a generated file
`include "generated/riscv_insn_decompressor_impl.sv"
end

endmodule