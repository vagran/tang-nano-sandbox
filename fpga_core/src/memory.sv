
module Memory(IMemoryBus memoryBus);

//XXX clock and timings
FLASH64KZ flash(
    .XADR(memoryBus.address[4:0]),
    .YADR(memoryBus.address[10:5]),
    .XE(memoryBus.strobe),
    .YE(memoryBus.strobe),
    .SE(memoryBus.strobe),
    .ERASE(0),
    .PROG(0),
    .NVSTR(0),
    .DIN(0),
    .DOUT(memoryBus.dataRead));

assign memoryBus.ready = memoryBus.strobe;

endmodule