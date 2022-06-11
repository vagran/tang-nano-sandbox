#include <verilated_vcd_c.h>

#include <test_runner.h>

#include <iostream>


int
main(int argc, char **argv, char **)
{
    std::cout << "\n================= Simulation =================\n";

    TestInstance test("basic");
    test.ctx.commandArgs(argc, argv);

    // Verilated::traceEverOn(true);
    // auto trace = std::make_unique<VerilatedVcdC>();

    #ifdef TRACE
        tb->trace(trace, 99);
        trace->open("wave.vcd");
    #endif

    // test.progMem[0] = 0x04;
    // test.progMem[1] = 0x08;
    // test.Reset();
    // //XXX
    // while (!test.ctx.gotFinish()) {

        // top->btnA = 1;
        // top->btnB = 1;
        // top->eval();
        // assert(top->bits & 0b01);
        // assert(top->bits & 0b10);

        // top->btnA = 0;
        // top->btnB = 1;
        // top->eval();
        // assert((top->bits & 0b01) == 0);
        // assert(top->bits & 0b10);

        // top->btnA = 0;
        // top->btnB = 0;
        // top->eval();
        // assert((top->bits & 0b01) == 0);
        // assert((top->bits & 0b10) == 0);

        //XXX
        // test.Tick();
    // }

    #ifdef TRACE
    trace->close();
    #endif

    RunTests(argc, argv);

    std::cout << "All tests passed\n";
    return 0;
}
