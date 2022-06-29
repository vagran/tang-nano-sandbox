#include <test_runner.h>


class AluTestCase: public TestCase {
public:
    enum Op {
        ADD,
        SUB,
        SLL,
        SLT,
        SLTU,
        XOR,
        SRL,
        SRA,
        OR,
        AND
    };

    std::map<Op, std::vector<uint8_t>> opCodes;
    const Op op;
    const uint32_t arg1, arg2;

    AluTestCase(TestInstance &test, Op op, uint32_t arg1, uint32_t arg2):
        TestCase(test),
        op(op),
        arg1(arg1),
        arg2(arg2)
    {
        InitOpCodes();
    }

    void
    InitOpCodes();

    void
    Run() override;

    static uint32_t
    ExpectedResult(Op op, uint32_t arg1, uint32_t arg2);

    uint32_t
    ExpectedResult()
    {
        return ExpectedResult(op, arg1, arg2);
    }
};

#define OP_CODE(__op, ...) opCodes.emplace(Op::__op, std::vector<uint8_t>{__VA_ARGS__});

void
AluTestCase::InitOpCodes()
{
    // op x5, x6, x7
    OP_CODE(ADD, 0xb3, 0x02, 0x73, 0x00)
    OP_CODE(SUB, 0xb3, 0x02, 0x73, 0x40)
    OP_CODE(SLL, 0xb3, 0x12, 0x73, 0x00)
    OP_CODE(SLT, 0xb3, 0x22, 0x73, 0x00)
    OP_CODE(SLTU, 0xb3, 0x32, 0x73, 0x00)
    OP_CODE(XOR, 0xb3, 0x42, 0x73, 0x00)
    OP_CODE(SRL, 0xb3, 0x52, 0x73, 0x00)
    OP_CODE(SRA, 0xb3, 0x52, 0x73, 0x40)
    OP_CODE(OR, 0xb3, 0x62, 0x73, 0x00)
    OP_CODE(AND, 0xb3, 0x72, 0x73, 0x00)
}

void
AluTestCase::Run()
{
    test.SetReg(5, 0xcccccccc);
    test.SetReg(6, arg1);
    test.SetReg(7, arg2);
    test.LoadProgram(opCodes.at(op));
    test.Reset();
    test.WaitInstructions();
    ASSERT_EQUAL(test.GetReg(5), ExpectedResult());
}

uint32_t
AluTestCase::ExpectedResult(AluTestCase::Op op, uint32_t arg1, uint32_t arg2)
{
    switch (op) {
    case Op::ADD:
        return arg1 + arg2;
    case Op::SUB:
        return arg1 - arg2;
    case Op::SLL:
        return arg1 << arg2;
    case Op::SLT:
        return (static_cast<int32_t>(arg1) < static_cast<int32_t>(arg2)) ? 1 : 0;
    case Op::SLTU:
        return arg1 < arg2 ? 1 : 0;
    case Op::XOR:
        return arg1 ^ arg2;
    case Op::SRL:
        return arg1 >> arg2;
    case Op::SRA:
        return static_cast<int32_t>(arg1) >> arg2;
    case Op::OR:
        return arg1 | arg2;
    case Op::AND:
        return arg1 & arg2;
    }
    throw std::runtime_error("Invalid operation");
}


#define ALU_TEST(__op, __arg1, __arg2) \
    REGISTER_TEST("ALU " # __op " " # __arg1 ", " # __arg2, \
    [](TestInstance &ti){ return std::make_shared<AluTestCase>(ti, AluTestCase::Op::__op, \
                                                               __arg1, __arg2); });

ALU_TEST(ADD, 0x42, 0x53)
ALU_TEST(ADD, 0x53, 0x42)
ALU_TEST(ADD, 0x0, 0x53)
ALU_TEST(ADD, 0x42, 0x0)
ALU_TEST(ADD, 0xffffffcc, 0x53)
ALU_TEST(ADD, 0xffffffcc, 0xffff4243)

ALU_TEST(SUB, 0x42, 0x53)
ALU_TEST(SUB, 0x53, 0x42)
ALU_TEST(SUB, 0x53, 0x53)
ALU_TEST(SUB, 0x0, 0x53)
ALU_TEST(SUB, 0x42, 0x0)
ALU_TEST(SUB, 0xffffffcc, 0x53)
ALU_TEST(SUB, 0xffffffcc, 0xffff4243)

ALU_TEST(SLT, 0x42, 0x53)
ALU_TEST(SLT, 0x53, 0x42)
ALU_TEST(SLT, 0x53, 0x53)
ALU_TEST(SLT, 0xffffff42, 0xffffff53)
ALU_TEST(SLT, 0xffffff53, 0xffffff42)
ALU_TEST(SLT, 0xffffff53, 0xffffff53)
ALU_TEST(SLT, 0xffffff53, 0x53)
ALU_TEST(SLT, 0x53, 0xffffff53)

ALU_TEST(SLTU, 0x42, 0x53)
ALU_TEST(SLTU, 0x53, 0x42)
ALU_TEST(SLTU, 0x53, 0x53)
ALU_TEST(SLTU, 0xffffff42, 0xffffff53)
ALU_TEST(SLTU, 0xffffff53, 0xffffff42)
ALU_TEST(SLTU, 0xffffff53, 0xffffff53)
ALU_TEST(SLTU, 0xffffff53, 0x53)
ALU_TEST(SLTU, 0x53, 0xffffff53)

ALU_TEST(XOR, 0x42, 0x53)
ALU_TEST(XOR, 0x53, 0x42)
ALU_TEST(XOR, 0x53, 0x53)
ALU_TEST(XOR, 0x0, 0x42)
ALU_TEST(XOR, 0xffffffff, 0x42)
ALU_TEST(XOR, 0x0, 0x0)
ALU_TEST(XOR, 0xffffffff, 0xffffffff)

ALU_TEST(OR, 0x42, 0x53)
ALU_TEST(OR, 0x53, 0x42)
ALU_TEST(OR, 0x53, 0x53)
ALU_TEST(OR, 0x0, 0x42)
ALU_TEST(OR, 0xffffffff, 0x42)
ALU_TEST(OR, 0x0, 0x0)
ALU_TEST(OR, 0xffffffff, 0xffffffff)

ALU_TEST(AND, 0x42, 0x53)
ALU_TEST(AND, 0x53, 0x42)
ALU_TEST(AND, 0x53, 0x53)
ALU_TEST(AND, 0x0, 0x42)
ALU_TEST(AND, 0xffffffff, 0x42)
ALU_TEST(AND, 0x0, 0x0)
ALU_TEST(AND, 0xffffffff, 0xffffffff)