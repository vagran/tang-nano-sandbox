
interface debugHw;
    logic red, green, blue;
    logic [7:0] bits;
    logic btnA, btnB;
endinterface


module main(input btnA, btnB,
            output red, green, blue, [7:0] bits);

debugHw debugHw();
assign debugHw.btnA = btnA;
assign debugHw.btnB = btnB;
assign red = debugHw.red;
assign green = debugHw.green;
assign blue = debugHw.blue;
assign bits = debugHw.bits;

//XXX
assign debugHw.bits[0] = debugHw.btnA;
assign debugHw.bits[1] = debugHw.btnB;


endmodule