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

always_comb begin
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
    wire isSlt, isSltu;

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

    always_comb begin
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
    assign result.isSlt = result.aluOp == OP_SLT;
    assign result.isSltu = result.aluOp == OP_SLTU;

endmodule

`define IS_INSN32(opcode)  (2'(opcode) == 2'b11)

module RiscvAlu(input AluOp op, input x, input y, input cIn, output reg cOut, output reg result);

    always_comb begin
        case (op)
        OP_ADD: begin
            {cOut, result} = x + y + cIn;
        end
        OP_SUB: begin
            {cOut, result} = 2'(x) - 2'(y) - 2'(cIn);
        end
        OP_AND: begin
            result = x & y;
            cOut = 0;
        end
        OP_OR: begin
            result = x | y;
            cOut = 0;
        end
        OP_XOR: begin
            result = x ^ y;
            cOut = 0;
        end
        // Shifts are handled outside of ALU
        // Assuming SLT or SLTU.
        default: begin
            // Same as for substraction but result is discarded, only carry is needed
            result = 0;
            cOut = (!x && (y || cIn)) || (y && cIn);
        end

        endcase
    end

endmodule


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
    `define REG_ADDR(regIdx) {{memoryBus.ADDRESS_SIZE-6{1'b0}}, regIdx, 2'b00}
    // Take bits corresponding to address bus width
    `define ADDR_BITS(value) value[memoryBus.ADDRESS_SIZE-1:0]

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
    // Triggers shift starting when counter is zero.
    reg shiftStart;
    wire isShiftDone = isShiftZero && !shiftStart;
    // Byte boundary reached by the shifter
    wire isByteShiftDone = shiftCounter[2:0] == 3'b000;
    // Shift counter is incremented with each shift when true, decremented when false.
    reg shiftIncrement;
    wire [4:0] nextShiftCounter = shiftIncrement ? shiftCounter + 5'd1 : shiftCounter - 5'd1;
    wire isNextShiftZero = nextShiftCounter == 5'b00000;
    reg shiftEnable;
    // MSB of X register is set from ALU when true, set to LSB when false.
    reg shiftXFromAlu;
    // MSB of Y register is set from ALU when true, set to LSB when false.
    reg shiftYFromAlu;
    // MSB of Y register is set from X LSB when true, set to Y LSB when false.
    reg shiftYFromX;
    // Sign extension is enabled when shifting. X[7] is replicated or zeroed depending on
    // signExtMode.
    reg enableSignExt;
    // X[7] is replicated for each shift round when true, zeroed when false.
    reg signExtSigned;
    // Shift until byte boundary. Set shiftStart to continue when reached.
    reg shiftByte;
    // Stores sign bit of X and Y registers when shifting last bit.
    reg xSign, ySign;

    // Memory interface buffers
    reg [memoryBus.ADDRESS_SIZE-1:0] memAddr;
    wire [memoryBus.ADDRESS_SIZE-1:0] nextMemAddr = memoryBus.ADDRESS_SIZE'(memAddr + 1'b1);
    reg memStrobe;
    reg memWriteEnable;

    assign memoryBus.address = memAddr;
    assign memoryBus.writeEnable = memWriteEnable;
    assign memoryBus.strobe = memStrobe;
    assign memoryBus.dataWrite = x[7:0];

    wire aluOut, aluCarryOut;
    reg aluCarry;
    RiscvAlu alu(.op(decoded.isAluOp ? decoded.aluOp : OP_ADD), .x(x[0]), .y(y[0]),
                     .cIn(aluCarry), .cOut(aluCarryOut), .result(aluOut));

    always_ff @(posedge cpuSignals.clock) begin

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
            shiftXFromAlu <= 0;
            shiftYFromAlu <= 0;
            shiftYFromX <= 0;
            aluCarry <= 0;
            enableSignExt <= 0;

        end else begin

            if (shiftEnable) begin
                if (!memWriteEnable && memoryBus.ready && isByteShiftDone &&
                    (isShiftZero || !shiftStart)) begin

                    memStrobe <= 0;
                    x[7:0] <= memoryBus.dataRead;

                end else if ((shiftStart || !(isShiftZero || (shiftByte && isByteShiftDone))) &&
                    (!memStrobe ||
                     // Do not shift if memory write is in progress
                     (memWriteEnable && memoryBus.ready) ||
                     // Do not shift if memory read is in progress for the first byte
                     (!memWriteEnable && (!isShiftZero || memoryBus.ready)))) begin

                    shiftStart <= 0;
                    shiftCounter <= nextShiftCounter;

                    x[31] <= shiftXFromAlu ? aluOut : x[0];
                    x[30:8] <= x[31:9];
                    x[7] <= enableSignExt ? (signExtSigned ? x[7] : 1'b0) : x[8];
                    x[6:0] <= x[7:1];

                    y[31] <= shiftYFromAlu ? aluOut : (shiftYFromX ? x[0] : y[0]);
                    y[30:0] <= y[31:1];

                    if (isNextShiftZero) begin
                        xSign <= x[0];
                        ySign <= y[0];
                    end

                    aluCarry <= shiftXFromAlu ? aluCarryOut : 0;

                end
            end

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
                    //XXX to Y, then through ALU, takeY op
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

                end else if (decoded.isLoad || decoded.isStore) begin
                    //XXX check resources consumption for blocking assignment to x and move to y
                    y <= decoded.immediate;
                    memAddr <= `REG_ADDR(decoded.rs1Idx);
                    memStrobe <= 1;
                    shiftXFromAlu <= 1;
                    shiftYFromAlu <= decoded.isStore;
                    signExtSigned <= decoded.isLoadSigned;
                    shiftEnable <= 1;
                    shiftByte <= 1;
                    shiftStart <= 1;
                    state <= S_REG_FETCH;

                end else if (decoded.isAluOp) begin
                    if (decoded.isAluImmediate) begin
                        y <= decoded.immediate;
                        shiftXFromAlu <= 1;
                        memAddr <= `REG_ADDR(decoded.rs1Idx);
                    end else begin
                        memAddr <= `REG_ADDR(decoded.rs2Idx);
                        shiftYFromX <= 1;
                    end
                    memStrobe <= 1;
                    shiftEnable <= 1;
                    shiftByte <= 1;
                    shiftStart <= 1;
                    state <= S_REG_FETCH;
                end
            end

            S_REG_FETCH: begin

                if (!memStrobe && isByteShiftDone && !isShiftDone) begin
                    // Next byte received
                    if (!isShiftZero) begin
                        shiftStart <= 1;
                    end
                    if (decoded.isLoad && !shiftXFromAlu &&
                        (decoded.transferByte ||
                        (decoded.transferHalfWord && (shiftCounter[4] || shiftCounter[3])))) begin

                        // Set before 24 bits shifted, unset on last byte shifting
                        enableSignExt <= shiftCounter[4:3] != 2'b11;
                    end else if (!(shiftCounter[4] && shiftCounter[3])) begin
                        // If not 24 bits shifted (otherwise last byte is already read)
                        memStrobe <= 1;
                        memAddr <= nextMemAddr;
                    end

                end else if (isShiftDone && !memStrobe) begin
                    // All bytes received and shifted
                    aluCarry <= 0;
                    //XXX
                    if (decoded.isLoad) begin

                        if (shiftXFromAlu) begin
                            // It was value rs1 fetching and address calculation, begin value
                            // fetching
                            shiftXFromAlu <= 0;
                            // Preset for byte loading
                            if (decoded.isLoad && decoded.transferByte) begin
                                enableSignExt <= 1;
                            end
                            memAddr <= `ADDR_BITS(x);
                            memStrobe <= 1;
                            shiftStart <= 1;

                        end else begin
                            memAddr <= `REG_ADDR(decoded.rdIdx);
                            memStrobe <= 1;
                            memWriteEnable <= 1;
                            // Preload with value 8 to shift 24 bits
                            shiftCounter[3] <= 1;
                            shiftStart <= 1;
                            state <= S_REG_STORE;

                            // Start shifting after byte read
                        end

                    end else if (decoded.isStore) begin

                        if (shiftXFromAlu) begin
                            // It was value rs1 fetching and address calculation, begin value
                            // fetching
                            shiftXFromAlu <= 0;
                            shiftYFromAlu <= 0;
                            memAddr <= `REG_ADDR(decoded.rs2Idx);
                            memStrobe <= 1;
                            shiftStart <= 1;

                        end else begin
                            memAddr <= `ADDR_BITS(y);
                            memStrobe <= 1;
                            memWriteEnable <= 1;
                            if (decoded.transferWord) begin
                                // Preload with value 8 to shift 24 bits
                                shiftCounter[3] <= 1;
                                shiftStart <= 1;
                            end else if (decoded.transferHalfWord) begin
                                // Preload with value 24 to shift 8 bits
                                shiftCounter[4] <= 1;
                                shiftCounter[3] <= 1;
                                shiftStart <= 1;
                            end
                            // Shifting is not started if transferring 8 bits
                            state <= S_REG_STORE;
                        end

                    end else if (decoded.isAluOp) begin
                        if (shiftXFromAlu) begin
                            // ALU operation complete, store result
                            if (decoded.isSltu) begin
                                x[0] <= aluCarry;
                            end else if (decoded.isSlt) begin
                                x[0] <= (xSign ^ ySign) ? xSign : aluCarry;
                            end
                            shiftXFromAlu <= 0;
                            memAddr <= `REG_ADDR(decoded.rdIdx);
                            memWriteEnable <= 1;
                            // Preload with value 8 to shift 24 bits
                            shiftCounter[3] <= 1;
                            state <= S_REG_STORE;
                        end else begin
                            // Second operand fetched, fetch the first one simultaneously
                            // calculating result.
                            shiftYFromX <= 0;
                            memAddr <= `REG_ADDR(decoded.rs1Idx);
                            shiftXFromAlu <= 1;
                        end
                        memStrobe <= 1;
                        shiftStart <= 1;
                    end
                end
            end

            S_REG_STORE: begin
                // It is always the last operation
                if (memoryBus.ready) begin
                    memStrobe <= 0;
                    if (isShiftDone) begin
                        shiftEnable <= 0;
                        memWriteEnable <= 0;
                        shiftByte <= 0;
                        isInsn32 <= 0;
                        state <= S_INSN_FETCH;
                    end
                end else if (!memStrobe && isByteShiftDone) begin
                    memStrobe <= 1;
                    memAddr <= nextMemAddr;
                    if (!isShiftDone) begin
                        shiftStart <= 1;
                    end
                end
            end

            //XXX
            default: begin
            end

            endcase;
        end

    end


endmodule