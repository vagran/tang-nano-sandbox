#ifndef INCLUDE_RISCV_CORE_H
#define INCLUDE_RISCV_CORE_H

#include <cstdint>


class RiscvCore {
public:
    enum State {
        INSN_FETCH,
        INSN_EXECUTE
    };

};

using PhysAddress = uint16_t;

constexpr PhysAddress PROG_START = 0x2000,
                      PROG_SIZE = 0x2000,
                      DATA_START = 0x0000,
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

#endif /* INCLUDE_RISCV_CORE_H */
