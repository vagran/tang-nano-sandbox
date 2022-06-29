#include <verilated_vcd_c.h>

#include <test_runner.h>

#include <iostream>


int
main(int argc, const char **argv, char **)
{
    std::cout << "\n================= Simulation =================\n";

    RunTests(argc, argv);
    //XXX
    // RunTest(argc, argv, "LUI");
    // RunTest(argc, argv, "ADD 0x42, 0x53");

    return 0;
}
