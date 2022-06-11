#include <test_runner.h>
#include <riscv_core.h>


class DecompressionTestCase: public TestCase {
public:
    DecompressionTestCase(TestInstance &test,
                          const std::vector<uint8_t> &insn16, const std::vector<uint8_t> &insn32):
        TestCase(test),
        insn16(insn16),
        insn32(insn32)
    {}

    void
    Run() override
    {
        test.progMem[0] = insn16[1];
        test.progMem[1] = insn16[0];
        test.Reset();
        ASSERT(test.module->dbgState == RiscvCore::State::INSN_FETCH);
        test.Tick();
        test.Tick();
        test.Tick();
        test.Tick();
        ASSERT(test.module->dbgState == RiscvCore::State::INSN_EXECUTE);
        uint32_t opcode = (insn32[0] << 24) | (insn32[1] << 16) | (insn32[2] << 8) | insn32[3];
        ASSERT(test.module->dbgInsnCode == opcode);
    }

private:
    std::vector<uint8_t> insn16, insn32;
};


#define MAKE_VECTOR(...) std::vector<uint8_t>{__VA_ARGS__}

#define TEST_CASE(__name, __insn16, __insn32) \
    REGISTER_TEST("Instruction decompression: " __name, [](TestInstance &test){ \
        return std::make_shared<DecompressionTestCase>(test, \
            MAKE_VECTOR __insn16, MAKE_VECTOR __insn32); \
    });


#include "generated/decompressor_test_data.inc"
