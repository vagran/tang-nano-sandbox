/// Verilator does not support interface ports for top level modules so make this adapter for
// simulation.

`include "riscv_core.sv"

module RiscvCoreTest(
    input clock, reset, [1:0] interruptReq,
    output [1:0] trap);

    parameter ADDRESS_SIZE = 15;

    IMemoryBus #(.ADDRESS_SIZE(ADDRESS_SIZE)) memoryBus();

    ICpu cpuSignals();
    assign cpuSignals.clock = clock;
    assign cpuSignals.reset = reset;
    assign cpuSignals.interruptReq = interruptReq;
    assign trap = cpuSignals.trap;

    RiscvCore #(.ADDRESS_SIZE(ADDRESS_SIZE)) riscvCore(
        .memoryBus(memoryBus.ext),
        .cpuSignals(cpuSignals.cpu));

endmodule;