interface IMemoryBus
    // Number of address lines for bytes addressing.
    #(parameter ADDRESS_SIZE = 16);

    wire [ADDRESS_SIZE-1:0] address;
    wire [7:0] dataWrite;
    wire [7:0] dataRead;
    // Write if 1 (data should be set as well), read if 0
    wire writeEnable;
    // `Address`, `dataWrite` (if writing) and `writeEnable` are set, start memory access.
    wire strobe;
    // Signalled by memory block that operation is complete. `dataRead` can be read (if reading),
    // `enable` can be de-asserted after that.
    wire ready;

    modport mem(input address, writeEnable, strobe, dataWrite, output dataRead, ready);
    modport ext(output address, writeEnable, strobe, dataWrite, input dataRead, ready);

endinterface

// Common CPU signals.
interface ICpu;

    // Most actions on rising edge.
    wire clock;
    // Reset signal, active level - low. The CPU should start with reset signal low, then set it
    // high when ready.
    wire reset;
    // Interrupt request. No request when all ones, interrupt index otherwise.
    wire [1:0] interruptReq;

    modport cpu(input clock, reset, interruptReq);
    modport ext(output clock, reset, interruptReq);
endinterface

// Used for testing in simulation. Debugging code is only compiled if `DEBUG` symbol is defined.
interface ICpuDebug;
    // Fetched and decompressed (if necessary) instruction code.
    wire [31:0] insnCode;
    // Pipeline state
    wire [2:0] state;
endinterface


// Decompresses 16 bits instruction code into full 32 bits code (assume two LSB ix 2'b11)
module RiscvInsnDecompressor(input wire [15:0] insn16, output reg [31:2] insn32);

always @(insn16) begin
// Implementation is in a generated file
`include "generated/riscv_insn_decompressor_impl.sv"
end

endmodule

typedef enum [3:0] {
    // Values are direct bits mappings from an opcode.
    OP_ADD = 4'b0000,
    OP_SUB = 4'b1000,
    OP_SLL = 4'b0001,
    OP_SLT = 4'b0010,
    OP_SLTU = 4'b0011,
    OP_XOR = 4'b0100,
    OP_SRL = 4'b0101,
    OP_SRA = 4'b1101,
    OP_OR = 4'b0110,
    OP_AND = 4'b0111
} AluOp;

// Decoded instruction info
interface IInsnDecoder;
    // Load instruction (LB, LBU, LH, LHU, LW)
    wire isLoad,
    // Store instruction (SB, SH, SW)
         isStore;
    // Trasnfer size for load or store instruction.
    wire transferByte, transferHalfWord, transferWord;
    // Extend sign bits when loading byte or half-word.
    wire isLoadSigned;
    // Immediate value if any.
    reg [31:0] immediate;
    wire isLui;
    wire [3:0] rs1Idx, rs2Idx, rdIdx;
    // ALU operation.
    wire isAluOp;
    // ALU operation code if isAluOp is true.
    wire AluOp aluOp;
    // True operation with rs1 and immediate value, false if operation on rs1 and rs2.
    wire isAluImmediate;

endinterface


// Decodes instruction opcode, two LSB always are 11 for 32 bit instruction, so do not use them
module RiscvInsnDecoder(input [31:2] insn32, IInsnDecoder result);

    assign result.isLoad = insn32[6:2] == 5'b00000;
    assign result.isStore = insn32[6:2] == 5'b01000;
    assign result.isLoadSigned = !insn32[14];
    assign result.transferByte = insn32[13:12] == 2'b00;
    assign result.transferHalfWord = insn32[13:12] == 2'b01;
    assign result.transferWord = insn32[13:12] == 2'b10;

    assign result.rs1Idx = insn32[18:15];
    assign result.rs2Idx = insn32[23:20];
    assign result.rdIdx = insn32[10:7];

    always @(insn32) begin
        if (insn32[6:2] == 5'b11001 || insn32[6:2] == 5'b00000 || insn32[6:2] == 5'b00100) begin
            // I-type
            result.immediate = {{20{insn32[31]}}, insn32[31:20]};
        end else if (insn32[6] == 0 && insn32[4:2] == 3'b101) begin
            // U-type
            result.immediate = {insn32[31:12], {12{1'b0}}};
        end else if (insn32[6:2] == 5'b01000) begin
            // S-type
            result.immediate = {{20{insn32[31]}}, insn32[31:25], insn32[11:7]};
        end else begin
            //XXX
            result.immediate = 0;
        end
    end

    assign result.isLui = insn32[6:2] == 5'b01101;

    assign result.isAluOp = insn32[6] == 1'b0 && insn32[4:2] == 3'b100;
    assign result.isAluImmediate = !insn32[5];
    // Ignore bit 30 (set to zero in the result) when immediate operation (bit 5 is zero), bit 30 is
    // part of immediate value in such case. SRAI is exception,
    assign result.aluOp =
        AluOp'({(insn32[5] || insn32[14:12] == 3'b101) && insn32[30], insn32[14:12]});

endmodule

`define IS_INSN32(opcode)  (2'(opcode) == 2'b11)

// module RiscvAlu(input AluOp op, [31:0] x, [31:0] y, output reg [31:0] result);

//     always @(*) begin
//         case (op)
//         OP_ADD:
//             result = x + y;
//         OP_SUB:
//             result = x - y;
//         OP_AND:
//             result = x & y;
//         OP_OR:
//             result = x | y;
//         OP_XOR:
//             result = x ^ y;
//         OP_SLL:
//             result = x << y[4:0];
//         OP_SRL:
//             result = x >> y[4:0];
//         OP_SRA:
//             result = x >>> y[4:0];
//         OP_SLT:
//             result = $signed(x) < $signed(y) ? 32'b1 : 32'b0;
//         /* Assuming SLTU. */
//         default:
//             result = x < y ? 32'b1 : 32'b0;

//         endcase
//     end

// endmodule;


// RISC-V core minimal implementation.
module RiscvCore
    // Program counter value after reset (byte address)
    #(parameter RESET_PC_ADDRESS = 'h2000)

    (IMemoryBus memoryBus, ICpu cpuSignals

    `ifdef DEBUG
        , ICpuDebug debug
    `endif
    );

    typedef enum reg[2:0] {
        // Instruction fetching from memory
        S_INSN_FETCH,
        // Instruction fetched into buffer, execution can be started
        S_INSN_FETCHED,
        S_REG_FETCH,
        S_REG_STORE,
        // Fetching data from memory
        S_DATA_FETCH,
        // ALU operation
        S_ALU
    } State;

    // Address from 4-bits register index.
    `define REG_ADDR(regIdx)  {{memoryBus.ADDRESS_SIZE-6{1'b0}}, regIdx, 2'b00}

    //XXX
    // 32-bits word address from (unaligned) byte address.
    // `define TRIM_ADDR(address) address[memoryBus.ADDRESS_SIZE+1:2]


    // Program counter
    reg [memoryBus.ADDRESS_SIZE-1:0] pc;
    wire [memoryBus.ADDRESS_SIZE-1:0] nextPc = memoryBus.ADDRESS_SIZE'(pc + 1'b1);

    // Instruction codes are fetched into this buffer. Either 16 or 32 bits instruction.address
    // Little-endian memory layout required for distinguishing opcode size.
    reg [31:0] insnBuf;
    // Indicates 32 bits opcode.
    reg isInsn32;
    wire [31:2] decompressedInsn;
    RiscvInsnDecompressor insnDcmp(.insn16(insnBuf[31:16]), .insn32(decompressedInsn));
    // Full 32 bits instruction view. Either decompressed or initial full size instruction.
    wire [31:2] insn32 = isInsn32 ? insnBuf[31:2] : decompressedInsn;
    `ifdef DEBUG
        assign debug.insnCode = {insn32, 2'b11};
    `endif

    // Current state.
    State state;

    `ifdef DEBUG
        assign debug.state = state;
    `endif

    IInsnDecoder decoded();
    RiscvInsnDecoder insnDecoder(.insn32(insn32[31:2]), .result(decoded));

    // Two real registers (and also PC), general purpose registers are placed in RAM. Otherwise
    // not enough resources on FPGA.
    reg [31:0] x, y;
    // Controls scheduled shift amount in X and Y registers. Shift is stopped when the counter is
    // zero allowing both reaching zero and 32.
    reg [4:0] shiftCounter;
    wire isShiftZero = shiftCounter == 5'b00000;
    // Byte boundary reached by the shifter
    wire isShiftByte = shiftCounter[2:0] == 3'b000;
    // Triggers shift starting when counter is zero.
    reg shiftStart;
    wire isShiftDone = isShiftZero && !shiftStart;
    // Shift counter is incremented with each shift when true, decremented when false.
    reg shiftIncrement;
    reg shiftEnable;//XXX is needed?
    // MSB of X register is set from ALU when true, set to LSB when false.
    reg shiftXFromAlu;
    // Sign extension is enabled when shifting. X[7] is replicated or zeroed depending on
    // signExtMode.
    reg enableSignExt;
    // X[7] is replicated for each shift round when true, zeroed when false.
    reg signExtMode;
    // Shift until byte boundary. Set shiftStart to continue when reached.
    reg shiftByte;

    // Memory interface buffers
    reg [memoryBus.ADDRESS_SIZE-1:0] memAddr;
    wire [memoryBus.ADDRESS_SIZE-1:0] nextMemAddr = memoryBus.ADDRESS_SIZE'(memAddr + 1'b1);
    reg memStrobe;
    reg memWriteEnable;

    assign memoryBus.address = memAddr;
    assign memoryBus.writeEnable = memWriteEnable;
    assign memoryBus.strobe = memStrobe;
    assign memoryBus.dataWrite = x[7:0];

    //XXX no ALU yet
    wire aluOut;

    always @(posedge cpuSignals.clock) begin

        if (shiftEnable &&
            (shiftStart || (!isShiftZero && !(shiftByte && isShiftByte))) &&
            !(memStrobe && !memoryBus.ready)) begin

            shiftStart <= 0;
            shiftCounter <= shiftIncrement ? shiftCounter + 1 : shiftCounter - 1;
            x[31] <= shiftXFromAlu ? aluOut : x[0];
            x[30:8] <= x[31:9];
            x[7] <= enableSignExt ? (signExtMode ? x[7] : 1'b0) : x[8];
            x[6:0] <= x[7:1];
            y[31] <= y[0];
            y[30:0] <= y[31:1];
        end

        if (cpuSignals.reset) begin
            // Do only minimal intialization to save some resources. Software should not assume
            // zeros in general purpose registers after reset (it is usualy true anyway).
            pc <= RESET_PC_ADDRESS;
            memStrobe <= 0;
            memWriteEnable <= 0;
            state <= S_INSN_FETCH;
            isInsn32 <= 0;
            shiftCounter <= 0;
            shiftStart <= 0;
            shiftEnable <= 0;
            shiftIncrement <= 1;
            shiftByte <= 0;

        end else begin
            case (state)

            S_INSN_FETCH: begin
                if (memoryBus.ready) begin
                    pc <= nextPc;
                    memStrobe <= 0;
                    insnBuf[7:0] <= insnBuf[15:8];
                    insnBuf[15:8] <= insnBuf[23:16];
                    insnBuf[23:16] <= insnBuf[31:24];
                    insnBuf[31:24] <= memoryBus.dataRead;

                    if (pc[0]) begin
                        // 16 or 32 bits have been read.
                        if (isInsn32 || !`IS_INSN32(insnBuf[31:24])) begin
                            state <= S_INSN_FETCHED;
                        end else  begin
                            isInsn32 <= 1;
                        end
                    end

                end else begin
                    memAddr <= pc;
                    memStrobe <= 1;
                end
            end

            S_INSN_FETCHED: begin

                if (decoded.isLui) begin
                    x <= decoded.immediate;
                    memAddr <= `REG_ADDR(decoded.rdIdx);
                    memStrobe <= 1;
                    memWriteEnable <= 1;
                    shiftEnable <= 1;
                    shiftStart <= 1;
                    shiftByte <= 1;
                    // Preload with value 8 to shift 24 bits
                    shiftCounter[3] <= 1;
                    state <= S_REG_STORE;
                end

                //     // First stage of instruction processing
                //     if (decoded.isLoad || decoded.isStore || decoded.isAluOp) begin
                //         // Fetch source address
                //         memAddr <= `REG_ADDR(decoded.rs1Idx);
                //         memStrobe <= 1;
                //         state <= S_REG_FETCH;

                //     end else if (decoded.isLui) begin
                //         memData <= decoded.immediate;
                //         memAddr <= `REG_ADDR(decoded.rdIdx);
                //         memWriteEnable <= 1;
                //         memStrobe <= 1;
                //         state <= S_REG_STORE;
                //     end

                // end
                //XXX
            end

            // S_REG_FETCH: begin
            //     if (memoryBus.ready) begin
            //         memStrobe <= 0;
            //         fetchRs2 <= 0;
            //         if (decoded.isAluOp) begin
            //             x <= memoryBus.dataRead;//XXX move out
            //             if (decoded.isAluImmediate) begin
            //                 y <= decoded.immediate;
            //                 aluOp <= decoded.aluOp;
            //                 state <= S_ALU;
            //             end else begin
            //                 //XXX
            //             end

            //         end else if (decoded.isLoad || (decoded.isStore && !fetchRs2)) begin
            //             x <= memoryBus.dataRead;
            //             y <= decoded.immediate;
            //             aluOp <= OP_ADD;
            //             state <= S_ALU;

            //         end else if (decoded.isStore) begin
            //             // rs2 fetched, x[1:0] contains address LSB, y - store address, memData -
            //             // previously fetched word.
            //             memAddr <= y[memoryBus.ADDRESS_SIZE-1:0];
            //             if (decoded.transferByte) begin
            //                 case (x[1:0])
            //                 2'b00:
            //                     memData[7:0] <= memoryBus.dataRead[7:0];
            //                 2'b01:
            //                     memData[15:8] <= memoryBus.dataRead[7:0];
            //                 2'b10:
            //                     memData[23:16] <= memoryBus.dataRead[7:0];
            //                 2'b11:
            //                     memData[31:24] <= memoryBus.dataRead[7:0];
            //                 endcase
            //             end else if (decoded.transferHalfWord) begin
            //                 if (x[1]) begin
            //                     memData[31:16] <= memoryBus.dataRead[15:0];
            //                 end else begin
            //                     memData[15:0] <= memoryBus.dataRead[15:0];
            //                 end
            //             end else begin
            //                 memData <= memoryBus.dataRead;
            //             end
            //             memWriteEnable <= 1;
            //             memStrobe <= 1;
            //             // S_REG_STORE can be reused for data store here.
            //             state <= S_REG_STORE;
            //         end
            //         //XXX
            //     end
            // end

            S_REG_STORE: begin
                // It is always the last operation
                if (memoryBus.ready) begin
                    memStrobe <= 0;
                    if (isShiftDone) begin
                        shiftEnable <= 0;
                        memWriteEnable <= 0;
                        state <= S_INSN_FETCH;
                    end
                end else if (!memStrobe && shiftCounter[2:0] == 3'b000) begin
                    memStrobe <= 1;
                    memAddr <= nextMemAddr;
                    if (!isShiftDone) begin
                        shiftStart <= 1;
                    end
                end
            end

            // S_ALU: begin
            //     if (decoded.isAluOp) begin
            //         memData <= alu.result;
            //         memAddr <= `REG_ADDR(decoded.rdIdx);
            //         memWriteEnable <= 1;
            //         memStrobe <= 1;
            //         state <= S_REG_STORE;

            //     end else if (decoded.isLoad || decoded.isStore) begin
            //         // Actually do not need to load before storing full word but make it so to save
            //         // some LUTs.
            //         //XXX check later
            //         memAddr <= `TRIM_ADDR(aluResult);
            //         // Save address LSB for 16-bits and 8-bits loads
            //         x[1:0] <= aluResult[1:0];
            //         memStrobe <= 1;
            //         state <= S_DATA_FETCH;
            //     end
            // end

            // S_DATA_FETCH: begin
            //     if (decoded.isLoad) begin
            //         // x[1:0] contains address LSB
            //         if (decoded.transferByte) begin
            //             case (x[1:0])
            //             2'b00:
            //                 memData[7:0] <= memoryBus.dataRead[7:0];
            //             2'b01:
            //                 memData[7:0] <= memoryBus.dataRead[15:8];
            //             2'b10:
            //                 memData[7:0] <= memoryBus.dataRead[23:16];
            //             2'b11:
            //                 memData[7:0] <= memoryBus.dataRead[31:24];
            //             endcase
            //             if (decoded.isLoadSigned) begin
            //                 memData[31:8] <= {24{memoryBus.dataRead[7]}};
            //             end else begin
            //                 memData[31:8] <= 24'b0;
            //             end
            //         end else if (decoded.transferHalfWord) begin
            //             if (x[1]) begin
            //                 memData[15:0] <= memoryBus.dataRead[31:16];
            //             end else begin
            //                 memData[15:0] <= memoryBus.dataRead[15:0];
            //             end
            //             if (decoded.isLoadSigned) begin
            //                 memData[31:16] <= {16{memoryBus.dataRead[15]}};
            //             end else begin
            //                 memData[31:16] <= 16'b0;
            //             end
            //         end else begin
            //             memData <= memoryBus.dataRead;
            //         end
            //         memAddr <= `REG_ADDR(decoded.rdIdx);
            //         memWriteEnable <= 1;
            //         memStrobe <= 1;
            //         state <= S_REG_STORE;

            //     end else begin
            //         // Fetch before store
            //         memData <= memoryBus.dataRead;
            //         y[memoryBus.ADDRESS_SIZE-1:0] <= memAddr;
            //         memAddr <= `REG_ADDR(decoded.rs2Idx);
            //         memStrobe <= 1;
            //         fetchRs2 <= 1;
            //         state <= S_REG_FETCH;
            //     end
            // end

            //XXX
            default: begin
            end

            endcase;
        end

    end


endmodule