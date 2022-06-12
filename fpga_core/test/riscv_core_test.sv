/// Verilator does not support interface ports for top level modules so make this adapter for
// simulation.

`include "riscv_core.sv"

module RiscvCoreTest(
    input clock,
    input reset,
    input [1:0] interruptReq,
    input memReady,
    input reg [31:0] memDataRead,
    output [TRAP_SIZE-1:0] trap,
    output [ADDRESS_SIZE-1:0] memAddress,
    output memStrobe,
    output memWriteEnable,
    output reg [31:0] memDataWrite,
    output [31:0] dbgInsnCode,
    output [2:0] dbgState);

    parameter ADDRESS_SIZE = 15;
    parameter TRAP_SIZE = 3;

    IMemoryBus #(.ADDRESS_SIZE(ADDRESS_SIZE)) memoryBus();
    assign memoryBus.ready = memReady;
    assign memAddress = memoryBus.address;
    assign memStrobe = memoryBus.strobe;
    assign memoryBus.dataRead = memDataRead;
    assign memDataWrite = memoryBus.dataWrite;
    assign memWriteEnable = memoryBus.writeEnable;

    ICpu #(.TRAP_SIZE(TRAP_SIZE)) cpuSignals();
    assign cpuSignals.clock = clock;
    assign cpuSignals.reset = reset;
    assign cpuSignals.interruptReq = interruptReq;
    assign trap = cpuSignals.trap;

    ICpuDebug dbg();
    assign dbgInsnCode = dbg.insnCode;
    assign dbgState = dbg.state;

    RiscvCore #(.RESET_PC_ADDRESS(16'h2000)) riscvCore
    (
        .memoryBus(memoryBus.ext),
        .cpuSignals(cpuSignals.cpu),
        .debug(dbg));

    initial begin
        $dumpfile("build/dump.vcd");
        $dumpvars();
    end

endmodule;