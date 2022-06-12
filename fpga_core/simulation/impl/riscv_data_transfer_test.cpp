#include <test_runner.h>
#include <iostream>


REGISTER_TEST_FUNC("Word memory transfer", ([](TestInstance &ti){

    /*
    li x5, 0x4000
    lw x6, 4(x5)
    */
    ti.LoadProgram({
        // 0: 91 62         lui     t0, 4
        0x91, 0x62,
        // 2: 03 a3 42 00   lw      t1, 4(t0)
        0x03, 0xa3, 0x42, 0x00
    });
    ti.LoadData({
        0x42, 0x43, 0x44, 0x45,
        0x52, 0x53, 0x54, 0x55
    });
    ti.Reset();
    ti.Clock(20);
}));
