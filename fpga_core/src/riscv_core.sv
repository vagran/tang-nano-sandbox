interface IMemoryBus
    // Number of address lines for addressing 32-bits words.
    #(parameter ADDRESS_SIZE = 15);

    wire [ADDRESS_SIZE-1:0] address;
    wire [31:0] dataWrite;
    wire [31:0] dataRead;
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


// Decoded instruction info
interface IInsnDecoder;
    // Load instruction (LB, LBU, LH, LHU, LW)
    wire isLoad,
    // Store instruction (SB, SH, SW)
         isStore;
    // Trasnfer size for load or store instruction.
    wire transferByte, transferHalfWord, transferWord;
    // Extend sign bits when loading byte or half-word.
    wire loadSigned;
    // Immediate value if any.
    reg [31:0] immediate;
    wire isLui;
    wire [3:0] rs1Idx, rs2Idx, rdIdx;

endinterface


// Decodes instruction opcode, two LSB always are 11 for 32 bit instruction, so do not use them
module RiscvInsnDecoder(input [31:2] insn32, IInsnDecoder result);

    assign result.isLoad = insn32[6:2] == 5'b00000;
    assign result.isStore = insn32[6:2] == 5'b01000;
    assign result.loadSigned = insn32[14];
    assign result.transferByte = insn32[13:12] == 2'b00;
    assign result.transferHalfWord = insn32[13:12] == 2'b01;
    assign result.transferWord = insn32[13:12] == 2'b10;
    assign result.isLui = insn32[6:2] == 5'b01101;
    assign result.rs1Idx = insn32[18:15];
    assign result.rs2Idx = insn32[23:20];
    assign result.rdIdx = insn32[10:7];

    always @(insn32) begin
        if (insn32[6:2] == 5'b11001 || insn32[6:2] == 5'b00000 || insn32[6:2] == 5'b00100) begin
            // I-type
            result.immediate = {{21{insn32[31]}}, insn32[30:20]};
        end else if (insn32[6] == 0 && insn32[4:2] == 3'b101) begin
            // U-type
            result.immediate = {insn32[31:12], {12{1'b0}}};
        end else begin
            //XXX
            result.immediate = 0;
        end
    end

endmodule

`define IS_INSN32(opcode)  (2'(opcode) == 2'b11)

// RISC-V core minimal implementation.
module RiscvCore
    // Program counter value after reset (byte address)
    #(parameter RESET_PC_ADDRESS = 0)

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
        // Fetching data from memory
        S_DATA_FETCH,
        // Storing data into memory
        S_DATA_STORE,

        // Instruction execution complete, adjust PC and shift opcode buffer
        S_INSN_DONE
    } State;

    // Main registers file, x1-x15.
    reg [31:0] regFile[15];
    // Program counter. Since it cannot point to unaligned location, it is counted in 16-bits words.
    // At the same time ADDRESS_SIZE corresponds to number of adressable 32-bits words, so the
    // register has ADDRESS_SIZE+1 bits.
    reg [memoryBus.ADDRESS_SIZE:0] pc;
    wire [memoryBus.ADDRESS_SIZE:0] nextPc = (memoryBus.ADDRESS_SIZE + 1)'(pc + 1'b1);

    // Instruction codes are fetched into this buffer. It may contain 16 bits half of previously
    // fetched instruction, in such case next 32 bits are concatenaed there. Little-endian memory
    // layout allows simplifying this concatenation logic.
    reg [47:0] insnBuf;
    // Before instruction fetch:
    // `insnBuf[15:0]` contains 16 bits of next instruction code when true, otherwise the buffer is
    // empty.
    // After instruction fetch:
    // `insnBuf[47:32]` contains 16 bits of next instruction code and current instruction is 32
    // bits, `insnBuf[31:16]` contains 16 bits of next instruction code and current instruction is
    // 16 bits when true. `insnBuf` contains only current instruction code when false.
    reg hasHalfInsn;

    wire [31:2] decompressedInsn;
    RiscvInsnDecompressor insnDcmp(.insn16(insnBuf[15:0]), .insn32(decompressedInsn));
    // Full 32 bits instruction view. Either decompressed or initial full size instruction.
    wire [31:2] insn32 = `IS_INSN32(insnBuf) ? insnBuf[31:2] : decompressedInsn;
    `ifdef DEBUG
        assign debug.insnCode = {insn32, 2'b11};
    `endif

    // Current state.
    State state;

    `ifdef DEBUG
        assign debug.state = state;
    `endif

    // Memory interface buffers
    reg [memoryBus.ADDRESS_SIZE-1:0] memAddr;
    reg memStrobe;
    reg memWriteEnable;
    reg [31:0] memData;

    assign memoryBus.address = memAddr;
    assign memoryBus.writeEnable = memWriteEnable;
    assign memoryBus.strobe = memStrobe;
    assign memoryBus.dataWrite = memData;

    IInsnDecoder decoded();
    RiscvInsnDecoder insnDecoder(.insn32(insn32[31:2]), .result(decoded));

    //XXX may use ALU, check later which approach uses less resources
    // wire [memoryBus.ADDRESS_SIZE+1:0] dataFetchStoreAddr =
    //     rs1[memoryBus.ADDRESS_SIZE+1:0] + decoded.immediate[memoryBus.ADDRESS_SIZE+1:0];

    always @(posedge cpuSignals.clock) begin

        //XXX
        if (cpuSignals.reset) begin
            // Do only minimal intialization to save some resources. Software should not assume
            // zeros in general purpose registers after reset (it is usualy true anyway).
            pc <= RESET_PC_ADDRESS >> 1;
            hasHalfInsn <= 0;
            memStrobe <= 0;
            memWriteEnable <= 0;
            state <= S_INSN_FETCH;

        end else begin
            case (state)

            S_INSN_FETCH: begin
                if (memoryBus.ready) begin
                    if (pc[0]) begin
                        // Unaligned code required, discard low word.
                        // Assuming buffer is empty (otherwise it should not reach this place).
                        insnBuf[15:0] <= memoryBus.dataRead[31:16];
                        if (`IS_INSN32(memoryBus.dataRead[31:16])) begin
                            hasHalfInsn <= 1;
                        end else begin
                            state <= S_INSN_FETCHED;
                        end
                    end else begin
                        if (hasHalfInsn) begin
                            // Assuming 32-bits instruction
                            insnBuf[47:16] <= memoryBus.dataRead;
                        end else begin
                            insnBuf[31:0] <= memoryBus.dataRead;
                            if (!`IS_INSN32(memoryBus.dataRead)) begin
                                hasHalfInsn <= 1;
                            end
                        end
                        state <= S_INSN_FETCHED;
                    end
                    pc <= nextPc;
                    memStrobe <= 0;

                end else begin
                    memAddr <= pc[memoryBus.ADDRESS_SIZE:1];
                    memStrobe <= 1;
                end
            end

            S_INSN_FETCHED: begin

                // First stage of instruction processing
                if (decoded.isLoad || (decoded.isStore && !decoded.transferWord)) begin

                    // memAddr <= dataFetchStoreAddr[memoryBus.ADDRESS_SIZE+1:2];
                    // memStrobe <= 1;
                    // state <= S_DATA_FETCH;

                end else if (decoded.isStore) begin
                    //XXX
                    // memAddr <= dataFetchStoreAddr[memoryBus.ADDRESS_SIZE+1:2];
                    // memData <= rs2;
                    // memWriteEnable <= 1;
                    // memStrobe <= 1;
                    // state <= S_DATA_STORE;

                end else if (decoded.isLui) begin
                    //XXX
                    // rd <= decoded.immediate;
                    // rdWrite <= 1;
                    // state <= S_INSN_DONE;
                end
                //XXX
            end

            // S_DATA_FETCH: begin
            //     if (decoded.isLoad) begin
            //         if (decoded.transferByte) begin
            //             //XXX
            //         end else if (decoded.transferHalfWord) begin
            //             //XXX
            //         end else begin
            //             rd <= memoryBus.dataRead;
            //             rdWrite <= 1;
            //         end
            //         state <= S_INSN_DONE;
            //     end else begin
            //         // Fetch before store
            //         //XXX
            //     end
            // end

            /* Assuming S_INSN_DONE */
            default: begin
                if (hasHalfInsn) begin
                    pc <= nextPc;
                    if (`IS_INSN32(insnBuf)) begin
                        insnBuf[15:0] <= insnBuf[47:32];
                        if (`IS_INSN32(insnBuf[47:32])) begin
                            state <= S_INSN_FETCH;
                        end else begin
                            state <= S_INSN_FETCHED;
                            hasHalfInsn <= 0;
                        end
                    end else begin
                        insnBuf[15:0] <= insnBuf[31:16];
                        if (`IS_INSN32(insnBuf[31:16])) begin
                            state <= S_INSN_FETCH;
                        end else begin
                            state <= S_INSN_FETCHED;
                            hasHalfInsn <= 0;
                        end
                    end
                end else begin
                    state <= S_INSN_FETCH;
                end
            end

            endcase;
        end

    end


endmodule