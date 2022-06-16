`include "riscv_core.sv"
`include "memory.sv"


interface IDebugHw;
    logic red, green, blue;
    logic [7:0] bits;
    logic btnA, btnB;
endinterface


module main(input btnA, btnB,
            output red, green, blue, [7:0] bits);

parameter ADDRESS_SIZE = 16;
parameter TRAP_SIZE = 3;

IDebugHw debugHw();
assign debugHw.btnA = btnA;
assign debugHw.btnB = btnB;
assign red = debugHw.red;
assign green = debugHw.green;
assign blue = debugHw.blue;
assign bits = debugHw.bits;

IMemoryBus #(.ADDRESS_SIZE(ADDRESS_SIZE)) memoryBus();
ICpu cpuSignals();

RiscvCore riscvCore(
    .memoryBus(memoryBus.ext),
    .cpuSignals(cpuSignals.cpu));

//XXX
assign cpuSignals.clock = debugHw.btnA;
assign cpuSignals.reset = !debugHw.btnB;

reg [7:0] sink;
reg [7:0] drain;

always @(posedge btnA) begin
    debugHw.bits = sink[7:0];
    sink <= {sink[0], sink[7:1]} ^
        memoryBus.dataWrite ^ memoryBus.writeEnable ^ memoryBus.strobe ^ memoryBus.address[15:8] ^
        memoryBus.address[7:0];
    drain <= {drain[30:0], btnB};
end

assign cpuSignals.interruptReq = drain[1:0];

assign memoryBus.ready = drain[0];
assign memoryBus.dataRead = drain;

// assign debugHw.bits[4] = ~memoryBus.writeEnable;
// assign debugHw.bits[5] = ~memoryBus.strobe;
// assign debugHw.bits[6] = ~memoryBus.ready;

// Memory memory(.memoryBus(memoryBus.mem));

//XXX
//assign debugHw.bits[0] = debugHw.btnA;
//assign debugHw.bits[1] = debugHw.btnB;

//wire [31:0] dout_o;
//Gowin_SP bsram(
//        .dout(dout_o), //output [31:0] dout
//        .clk(btnA), //input clk
//        .oce(oce_i), //input oce
//        .ce(ce_i), //input ce
//        .reset(reset_i), //input reset
//        .wre(wre_i), //input wre
//        .ad(ad_i), //input [10:0] ad
//        .din(din_i) //input [31:0] din
//    );

//assign debugHw.bits = dout_o[7:0] ^ dout_o[15:8] ^ dout_o[23:16] ^ dout_o[31:24];

//wire [7:0] dout_o;
//Gowin_SP bsram(
//        .dout(dout_o), //output [7:0] dout
//        .clk(btnA), //input clk
//        .oce(oce_i), //input oce
//        .ce(ce_i), //input ce
//        .reset(reset_i), //input reset
//        .wre(wre_i), //input wre
//        .ad(ad_i), //input [10:0] ad
//        .din(din_i) //input [31:0] din
//    );

//assign debugHw.bits = dout_o;

// reg [7:0] cnt;
// assign debugHw.bits = ~cnt;
// always @(negedge debugHw.btnA) begin
//     if (cnt == 0) begin
//         cnt = 1;
//     end else begin
//         cnt <= cnt << 1;
//     end
// end

endmodule