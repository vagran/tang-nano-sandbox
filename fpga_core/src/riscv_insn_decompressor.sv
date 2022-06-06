// Decompresses 16 bits instruction code into full 32 bits code.
module RiscvInsnDecompressor(input wire [15:0] compressed, output reg [31:0] decompressed);

//XXX
// assign decompressed = {compressed, compressed};

always @(compressed) begin

    case (compressed[1:0])

    // Quadrant 0
    2'b00: begin
        case (compressed[15:13])

        // C.ADDI4SPN => ADDI rd', x2, nzuimm[9:2]
        3'b000: begin
            decompressed = {
                2'b00,

                compressed[10:7], // nzuimm
                compressed[12:11],
                compressed[5],
                compressed[6],

                2'b00,
                5'b00010, // x2
                3'b000,

                2'b01,           // rd'
                compressed[4:2], // rd'

                7'b0010011};
        end

        //XXX
        default:
            decompressed = 0;

        endcase
    end

    default:
        decompressed = 0;

    endcase
end

endmodule