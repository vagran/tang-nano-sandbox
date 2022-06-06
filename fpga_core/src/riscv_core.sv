`include "riscv_insn_decompressor.sv"

interface IMemoryBus
    // Number of address lines for addressing 32-bits words.
    #(parameter ADDRESS_SIZE);

    wire [ADDRESS_SIZE-1:0] address;
    wire [31:0] data;
    // Write if 1 (data should be set as well), read if 0
    wire writeEnable;
    // `Address`, `data` (if writing) and `writeEnable` are set, start memory access.
    wire strobe;
    // Signalled by memory block that operation is complete. `Data` can be read (if reading),
    // `enable` can be de-asserted after that.
    wire ready;

    modport mem(input address, writeEnable, strobe, inout data, output ready);
    modport ext(output address, writeEnable, strobe, inout data, input ready);

endinterface

// Common CPU signals.
interface ICpu
    #(parameter TRAP_SIZE = 2);

    // Most actions on rising edge.
    wire clock;
    // Reset signal, active level - low. The CPU should start with reset signal low, then set it
    // high when ready.
    wire reset;
    // Interrupt request. No request when all ones, interrupt index otherwise.
    wire [1:0] interruptReq;
    // Trap indication. No trap if all ones, trap index otherwise.
    wire [TRAP_SIZE-1:0] trap;

    modport cpu(input clock, reset, interruptReq, output trap);
    modport ext(output clock, reset, interruptReq, input trap);
endinterface

// Used for testing in simulation. Debugging code is only compiled if `DEBUG` symbol is defined.
interface ICpuDebug;
    // Fetched and decompressed (if necessary) instruction code.
    wire [31:0] insnCode;

endinterface

typedef enum reg[2:0] {
    // Halt instruction encountered. Also halted after power off until reset if all registers are
    // initialized to zero.
    HALT,
    // Unsupported instruction code encountered.
    ILLEGAL_INSN,
    // Memory access to unaligned location requested.
    UNALIGNED_ACCESS,
    // Internal inconsistency, most probably design bug
    INTERNAL_ERROR
} TrapIndex;

// RISC-V core minimal implementation.
module RiscvCore
    // Program counter value after reset (byte address)
    #(parameter RESET_PC_ADDRESS = 0)

    (IMemoryBus memoryBus, ICpu cpuSignals

    `ifdef DEBUG
        , ICpuDebug debug
    `endif
    );

    typedef enum reg[1:0] {
        // Instruction fetching
        S_INSN_FETCH,
        // Executing instruction XXX may split into mem read, mem write, alu
        S_INSN_EXECUTE
    } State;

    localparam TRAP_NONE = (1 << cpuSignals.TRAP_SIZE) - 1;

    // Main registers file, x1-x15.
    reg x[31:0][15];
    // Program counter. Since it cannot point to unaligned location, it is counted in 16-bits words.
    // At the same time ADDRESS_SIZE corresponds to number of adressable 32-bits words, so the
    // register has ADDRESS_SIZE+1 bits.
    reg [memoryBus.ADDRESS_SIZE:0] pc;

    // Instruction codes are fetched into this buffer. It may contain 16 bits half of previously
    // fetched instruction, in such case next 32 bits are concatenaed there. Little-endian memory
    // layout allows simplifying this concatenation logic.
    reg [47:0] insnBuf;
    // `insnBuf` contains 16 bits of next instruction code when true during instruction fetch stage.
    // Otherwise the buffer is empty.
    reg hasHalfInsn;

    // Instruction has 32 bits code if two LSB are set.
    wire isInsn32 = insnBuf[1:0] == 2'b11;
    // Size of data in instruction buffer after fetching stage.
    // 16 bits in instruction buffer if no leftover chunk and unaligned code fetched.
    wire isInsnBuf16 = !hasHalfInsn && pc[0];
    // 32 bits if either leftover chunk concatenated with unaligned code or empty buffer filled with
    // aligned code.
    wire isInsnBuf32 = (hasHalfInsn && pc[0]) || (!hasHalfInsn && !pc[0]);
    // 48 bits if leftover chunk concatenated with aligned code.
    wire isInsnBuf48 = hasHalfInsn & !pc[0];

    wire [31:0] decompressedInsn;
    RiscvInsnDecompressor insnDcmp(.compressed(insnBuf[15:0]), .decompressed(decompressedInsn));
    // Full 32 bits instruction view. Either decompressed or initial full size instruction.
    wire [31:0] insn32 = isInsn32 ? insnBuf[31:0] : decompressedInsn;
    `ifdef DEBUG
        assign debug.insnCode = insn32;
    `endif

    // Current trap if any, TRAP_NONE if no trap.
    reg [cpuSignals.TRAP_SIZE-1:0] trap;

    assign cpuSignals.trap = trap;

    // Current state.
    State state;

    // Memory interface buffers
    reg [memoryBus.ADDRESS_SIZE-1:0] memAddr;
    reg memStrobe;
    reg memWriteEnable;

    assign memoryBus.address = memAddr;
    assign memoryBus.writeEnable = memWriteEnable;
    assign memoryBus.strobe = memStrobe;


    always @(posedge cpuSignals.clock) begin

        //XXX
        if (cpuSignals.reset) begin
            // Do only minimal intialization to save some resources. Software should not assume
            // zeros in general purpose registers after reset (it is usualy true anyway).
            pc <= RESET_PC_ADDRESS >> 1;
            hasHalfInsn <= 0;
            state <= S_INSN_FETCH;
            trap <= TRAP_NONE;
            memStrobe <= 0;
            memWriteEnable <= 0;

        end else if (trap == TRAP_NONE) begin
            case (state)

            S_INSN_FETCH: begin
                if (memoryBus.ready) begin
                    if (pc[0]) begin
                        // Unaligned code required, discard low word.
                        if (hasHalfInsn) begin
                            insnBuf[31:16] <= memoryBus.data[31:16];
                        end else begin
                            insnBuf[15:0] <= memoryBus.data[31:16];
                        end
                    end else begin
                        if (hasHalfInsn) begin
                            insnBuf[47:16] <= memoryBus.data;
                        end else begin
                            insnBuf[31:0] <= memoryBus.data;
                        end
                    end

                    memStrobe <= 0;

                    if (isInsn32 && isInsnBuf16) begin
                        // Buffer contains half of the instruction code, fetch next one.
                        hasHalfInsn <= 1;
                        pc <= pc + 1;

                    end else begin
                        state <= S_INSN_EXECUTE;
                    end

                end else begin
                    memAddr <= pc[memoryBus.ADDRESS_SIZE:1];
                    memWriteEnable <= 0;
                    memStrobe <= 1;
                end
            end

            S_INSN_EXECUTE: begin

                // shift insnBuf when done, increment pc
            end

            default: begin
                trap <= INTERNAL_ERROR;
            end

            endcase;
        end

    end


endmodule