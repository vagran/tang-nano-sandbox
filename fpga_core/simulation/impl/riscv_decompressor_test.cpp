#include <test_runner.h>

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
        //XXX
        FAIL("test");
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
