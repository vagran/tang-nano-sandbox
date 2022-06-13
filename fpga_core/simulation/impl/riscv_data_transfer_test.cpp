#include <test_runner.h>
#include <iostream>


REGISTER_TEST_FUNC("LUI", ([](TestInstance &ti){

    /*
    lui x5, 0x4
    */
    ti.LoadProgram({
        // 0: 91 62         lui     t0, 4
        0x91, 0x62
    });
    ti.Reset();
    ti.WaitInstructions();
    ASSERT(ti.GetReg(5) == 4 << 12);
}));

REGISTER_TEST_FUNC("Word memory transfer", ([](TestInstance &ti){

    /*
    li x5, 0x0040
    lw x6, 4(x5)
    */
    ti.LoadProgram({
        // 0: 93 02 00 04   li      t0, 64
        0x93, 0x02, 0x00, 0x04,
        // 4: 03 a3 42 00   lw      t1, 4(t0)
        0x03, 0xa3, 0x42, 0x00
    });
    ti.LoadData({
        0x42, 0x43, 0x44, 0x45,
        0x52, 0x53, 0x54, 0x55
    });
    ti.Reset();
    ti.Clock(20);
}));
