#ifndef INCLUDE_TEST_INSTANCE_H
#define INCLUDE_TEST_INSTANCE_H

#include <verilated.h>
#include <Vriscv_core_test.h>
#include <riscv_core.h>


class TestFailException: public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};


class TestInstance {
public:
    const int memReadDelay, memWriteDelay;
    VerilatedContext ctx;
    const std::string name;
    std::unique_ptr<Vriscv_core_test> module;
    std::vector<uint8_t> progMem, dataMem;

    TestInstance(const std::string &name, int memReadDelay = 0, int memWriteDelay = 0):
        memReadDelay(memReadDelay),
        memWriteDelay(memWriteDelay),
        ctx(),
        name(name),
        module(std::make_unique<Vriscv_core_test>(&ctx)),
        progMem(PROG_SIZE),
        dataMem(DATA_SIZE)
    {}

    virtual
    ~TestInstance()
    {
        module->final();
    }

    void
    Reset()
    {
        module->reset = 1;
        module->clock = 0;
        ctx.timeInc(1);
        module->eval();
        module->clock = 1;
        ctx.timeInc(1);
        module->eval();
        module->reset = 0;
        clock = 1;
    }

    void
    Tick()
    {
        clock = !clock;
        module->clock = clock;
        HandleMemory();
        ctx.timeInc(1);
        module->eval();
    }

    void
    Clock(int n = 1)
    {
        while (n) {
            Tick();
            if (clock) {
                n--;
            }
        }
    }

    uint32_t
    GetReg(int idx) const;

    uint32_t
    GetDataMem32(PhysAddress address);

    /** Run until the specified number of instructions complete. */
    void
    WaitInstructions(int n = 1);

    void
    LoadProgram(const std::vector<uint8_t> &data, PhysAddress address = PROG_START);

    void
    LoadData(const std::vector<uint8_t> &data, PhysAddress address = USER_DATA_START);

protected:
    int clock = 0;
    bool memStrobeLow = false;
    int memDelay = 0;

    void
    HandleMemory();

    void
    Fail(const char *file, int line, const char *msg);
};

#define TEST_FAIL(__msg) \
    do { \
        std::stringstream __ss; \
        __ss << __msg; \
        Fail(__FILE__, __LINE__, __ss.str().c_str()); \
    } while (false)

#endif /* INCLUDE_TEST_INSTANCE_H */
