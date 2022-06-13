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
    sw x6, 8(x5)
    */
    //XXX negative offset
    ti.LoadProgram({
        // 0: 93 02 00 04   li      t0, 64
        0x93, 0x02, 0x00, 0x04,
        // 4: 03 a3 42 00   lw      t1, 4(t0)
        0x03, 0xa3, 0x42, 0x00,
        // 8: 23 a4 62 00   sw      t1, 8(t0)
        0x23, 0xa4, 0x62, 0x00
    });
    ti.LoadData({
        0x42, 0x43, 0x44, 0x45,
        0x52, 0x53, 0x54, 0x55
    });
    ti.Reset();
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(5), 0x40);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x55545352);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 8), 0x55545352);
}));

REGISTER_TEST_FUNC("Word memory transfer (negative offset)", ([](TestInstance &ti){
    /*
    li x5, 0x0048
    lw x6, -4(x5)
    sw x6, -8(x5)
    */
    //XXX negative offset
    ti.LoadProgram({
        // 0: 93 02 80 04   li      t0, 72
        0x93, 0x02, 0x80, 0x04,
        // 4: 03 a3 c2 ff   lw      t1, -4(t0)
        0x03, 0xa3, 0xc2, 0xff,
        // 8: 23 ac 62 fe   sw      t1, -8(t0)
        0x23, 0xac, 0x62, 0xfe
    });
    ti.LoadData({
        0x42, 0x43, 0x44, 0x45,
        0x52, 0x53, 0x54, 0x55
    });
    ti.Reset();
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(5), 0x48);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x55545352);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START), 0x55545352);
}));

REGISTER_TEST_FUNC("Half-word memory transfer", ([](TestInstance &ti){

    /*
    li x5, 0x0040
    lh x6, 4(x5)
    lh x6, 6(x5)
    lhu x6, 4(x5)
    lhu x6, 6(x5)
    sh x6, 8(x5)
    sh x6, 14(x5)
    */
    ti.LoadProgram({
        // 0: 93 02 00 04   li      t0, 64
        0x93, 0x02, 0x00, 0x04,
        // 4: 03 93 42 00   lh      t1, 4(t0)
        0x03, 0x93, 0x42, 0x00,
        // 8: 03 93 62 00   lh      t1, 6(t0)
        0x03, 0x93, 0x62, 0x00,
        // c: 03 d3 42 00   lhu     t1, 4(t0)
        0x03, 0xd3, 0x42, 0x00,
        // 10: 03 d3 62 00   lhu     t1, 6(t0)
        0x03, 0xd3, 0x62, 0x00,
        // 14: 23 94 62 00   sh      t1, 8(t0)
        0x23, 0x94, 0x62, 0x00,
        // 18: 23 97 62 00   sh      t1, 14(t0)
        0x23, 0x97, 0x62, 0x00
    });
    ti.LoadData({
        0x42, 0x43, 0x44, 0x45,
        0x82, 0x83, 0x84, 0x85,
        0xcc, 0xcc, 0xcc, 0xcc,
        0xcc, 0xcc, 0xcc, 0xcc,
    });
    ti.Reset();
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(5), 0x40);

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0xffff8382);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0xffff8584);

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x00008382);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x00008584);

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 8), 0xcccc8584);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 12), 0x8584cccc);
}));

REGISTER_TEST_FUNC("Byte memory transfer", ([](TestInstance &ti){

    /*
    li x5, 0x0040
    lb x6, 4(x5)
    lb x6, 5(x5)
    lb x6, 6(x5)
    lb x6, 7(x5)
    lbu x6, 4(x5)
    lbu x6, 5(x5)
    lbu x6, 6(x5)
    lbu x6, 7(x5)
    sb x6, 8(x5)
    sb x6, 13(x5)
    sb x6, 18(x5)
    sb x6, 23(x5)
    */
    ti.LoadProgram({
        // 0: 93 02 00 04   li      t0, 64
        0x93, 0x02, 0x00, 0x04,

        // 4: 03 83 42 00   lb      t1, 4(t0)
        0x03, 0x83, 0x42, 0x00,
        // 8: 03 83 52 00   lb      t1, 5(t0)
        0x03, 0x83, 0x52, 0x00,
        // c: 03 83 62 00   lb      t1, 6(t0)
        0x03, 0x83, 0x62, 0x00,
        // 10: 03 83 72 00   lb      t1, 7(t0)
        0x03, 0x83, 0x72, 0x00,

        // 14: 03 c3 42 00   lbu     t1, 4(t0)
        0x03, 0xc3, 0x42, 0x00,
        // 18: 03 c3 52 00   lbu     t1, 5(t0)
        0x03, 0xc3, 0x52, 0x00,
        // 1c: 03 c3 62 00   lbu     t1, 6(t0)
        0x03, 0xc3, 0x62, 0x00,
        // 20: 03 c3 72 00   lbu     t1, 7(t0)
        0x03, 0xc3, 0x72, 0x00,

        // 24: 23 84 62 00   sb      t1, 8(t0)
        0x23, 0x84, 0x62, 0x00,
        // 28: a3 86 62 00   sb      t1, 13(t0)
        0xa3, 0x86, 0x62, 0x00,
        // 2c: 23 89 62 00   sb      t1, 18(t0)
        0x23, 0x89, 0x62, 0x00,
        // 30: a3 8b 62 00   sb      t1, 23(t0)
        0xa3, 0x8b, 0x62, 0x00,
    });
    ti.LoadData({
        0x42, 0x43, 0x44, 0x45,
        0x82, 0x83, 0x84, 0x85,
        0xcc, 0xcc, 0xcc, 0xcc,
        0xcc, 0xcc, 0xcc, 0xcc,
        0xcc, 0xcc, 0xcc, 0xcc,
        0xcc, 0xcc, 0xcc, 0xcc,
    });
    ti.Reset();

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(5), 0x40);

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0xffffff82);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0xffffff83);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0xffffff84);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0xffffff85);

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x82);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x83);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x84);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetReg(6), 0x85);

    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 8), 0xcccccc85);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 12), 0xcccc85cc);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 16), 0xcc85cccc);
    ti.WaitInstructions();
    ASSERT_EQUAL(ti.GetDataMem32(USER_DATA_START + 20), 0x85cccccc);
}));