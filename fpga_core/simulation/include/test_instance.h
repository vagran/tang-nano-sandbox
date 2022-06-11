#ifndef INCLUDE_TEST_INSTANCE_H
#define INCLUDE_TEST_INSTANCE_H

#include <verilated.h>
#include <Vriscv_core_test.h>

using PhysAddress = uint16_t;

constexpr PhysAddress PROG_START = 0x2000,
                      PROG_SIZE = 0x2000,
                      DATA_START = 0x4000,
                      DATA_SIZE = 0x2000;

constexpr uint32_t TRAP_NONE = (1 << 3) - 1;

constexpr inline bool
IsProgAddress(PhysAddress addr)
{
    return addr >= PROG_START && addr < PROG_START + PROG_SIZE;
}

constexpr inline bool
IsDataAddress(PhysAddress addr)
{
    return addr >= DATA_START && addr < DATA_START + DATA_SIZE;
}


class TestFailException: public std::runtime_error {
public:
    using std::runtime_error::runtime_error;
};


class TestInstance {
public:
    VerilatedContext ctx;
    const std::string name;
    std::unique_ptr<Vriscv_core_test> module;
    std::vector<uint8_t> progMem, dataMem;

    TestInstance(const std::string &name):
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
        module->eval();
        module->clock = 1;
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
        module->eval();
        CheckTrap();
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

protected:
    int clock = 0;

    void
    HandleMemory();

    void
    CheckTrap();

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
