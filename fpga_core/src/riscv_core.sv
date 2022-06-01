/*

memory interface
    addr 15
    data 32
    we
    clk

cpu interface
    clock
    reset (as interrupt 0?)
    traps
    interrupt

*/

interface IMemoryBus
    #(parameter ADDRESS_SIZE);

    logic [ADDRESS_SIZE-1:0] address;
    logic [31:0] data;
    // Write if 1 (data should be set as well), read if 0
    logic writeEnable;
    // `Address`, `data` (if writing) and `writeEnable` are set, start memory access.
    logic enable;
    // Signalled by memory block that operation is complete. `Data` can be read (if reading),
    // `enable` can be de-asserted after that.
    logic ready;

    modport mem(input address, writeEnable, enable, inout data, output ready);
    modport ext(output address, writeEnable, enable, inout data, input ready);

endinterface

interface ICpu;
    // Most actions on rising edge.
    logic clock;
    // Reset signal, active level - low. The CPU should start with reset signal low, then set it
    // high when ready.
    logic reset;
    // Interrupt request. No request when all ones, interrupt index otherwise.
    logic [1:0] interruptReq;
    // Trap indication. No trap if all ones, trap index otherwise.
    logic [1:0] trap;

    modport cpu(input clock, reset, interruptReq, output trap);
    modport ext(output clock, reset, interruptReq, input trap);
endinterface

module RiscvCore
    #(parameter ADDRESS_SIZE)
    (IMemoryBus memoryBus, ICpu cpuSignals);

    reg x[31:0][15];
    reg pc[ADDRESS_SIZE-1:0];

    always @(posedge cpuSignals.clock) begin

        //XXX
        if (cpuSignals.reset) begin
            pc <= 0;
        end

    end


endmodule