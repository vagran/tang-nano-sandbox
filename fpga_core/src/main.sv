`include "riscv_core.sv"


interface IDebugHw;
    logic red, green, blue;
    logic [7:0] bits;
    logic btnA, btnB;
endinterface


module main(input btnA, btnB,
            output red, green, blue, [7:0] bits);

parameter ADDRESS_SIZE = 15;
parameter TRAP_SIZE = 3;

IDebugHw debugHw();
assign debugHw.btnA = btnA;
assign debugHw.btnB = btnB;
assign red = debugHw.red;
assign green = debugHw.green;
assign blue = debugHw.blue;
assign bits = debugHw.bits;

IMemoryBus #(.ADDRESS_SIZE(ADDRESS_SIZE)) memoryBus();
ICpu #(.TRAP_SIZE(TRAP_SIZE)) cpuSignals();

RiscvCore riscvCore(
    .memoryBus(memoryBus.ext),
    .cpuSignals(cpuSignals.cpu));

//XXX
assign cpuSignals.clock = btnA;
assign cpuSignals.reset = !btnB;
assign bits[2:0] = cpuSignals.trap;

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

endmodule