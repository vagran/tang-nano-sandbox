#include <verilated_vcd_c.h>

#include <test_runner.h>

#include <iostream>


int
main(int argc, char **argv, char **)
{
    std::cout << "\n================= Simulation =================\n";

    // RunTests(argc, argv);
    //XXX
    RunTest(argc, argv, "Byte memory transfer");

    return 0;
}
