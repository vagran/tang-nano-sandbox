/// Verilator does not support interface ports for top level modules so make this adapter for
// simulation.

`include "riscv_core.sv"

module RiscvCoreTest(
    input clock, reset, [1:0] interruptReq,
    output [TRAP_SIZE-1:0] trap,
    output [31:0] dbgInsnCode);

    parameter ADDRESS_SIZE = 15;
    parameter TRAP_SIZE = 3;

    IMemoryBus #(.ADDRESS_SIZE(ADDRESS_SIZE)) memoryBus();

    ICpu #(.TRAP_SIZE(TRAP_SIZE)) cpuSignals();
    assign cpuSignals.clock = clock;
    assign cpuSignals.reset = reset;
    assign cpuSignals.interruptReq = interruptReq;
    assign trap = cpuSignals.trap;

    ICpuDebug dbg();
    assign dbgInsnCode = dbg.insnCode;

    RiscvCore riscvCore(
        .memoryBus(memoryBus.ext),
        .cpuSignals(cpuSignals.cpu),
        .debug(dbg));

endmodule;