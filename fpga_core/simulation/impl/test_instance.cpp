#include <test_instance.h>
#include <sstream>

namespace {

/** Read little-endian 32-bits word. */
uint32_t
ReadWord32(const uint8_t *location)
{
    return location[0] | (location[1] << 8) | (location[2] << 16) | location[3] << 24;
}

void
WriteWord32(uint8_t *location, uint32_t data)
{
    location[0] = data & 0xff;
    location[1] = (data >> 8) & 0xff;
    location[2] = (data >> 16) & 0xff;
    location[3] = (data >> 24) & 0xff;
}

} /* anonymous namespace */

void
TestInstance::HandleMemory()
{
    if (!module->memStrobe) {
        if (memDelay) {
            TEST_FAIL("memStrobe de-asserted before ready");
        }
        module->memReady = 0;
        memStrobeLow = true;
        return;
    }
    if (!memStrobeLow) {
        return;
    }
    if (memDelay < (module->memWriteEnable ? memWriteDelay : memReadDelay)) {
        memDelay++;
        return;
    } else {
        memDelay = 0;
    }
    PhysAddress address = module->memAddress;
    if (IsProgAddress(address)) {
        if (module->memWriteEnable) {
            TEST_FAIL("Attempting to write to program memory address "
                      << std::hex << address << "h");
        }
        module->memDataRead = *(progMem.data() + address - PROG_START);

    } else if (IsDataAddress(address)) {
        if (address == 0) {
            // x0 register
            module->memDataRead = 0;
        } else if (module->memWriteEnable) {
            *(dataMem.data() + address - DATA_START) = module->memDataWrite;
        } else {
            module->memDataRead = *(dataMem.data() + address - DATA_START);
        }

    } else {
        TEST_FAIL("Attempting to access (" << (module->memWriteEnable ? "write" : "read")
                                           << ") invalid address " << std::hex
                                           << address << "h");
    }
    module->memReady = 1;
    memStrobeLow = false;
}


void
TestInstance::Fail(const char *file, int line, const char *msg)
{
    std::stringstream ss;
    ss << "[" << file << ":" << line << "] Failure in test `" << name << "`: " << msg;
    throw TestFailException(ss.str());
}

void
TestInstance::LoadProgram(const std::vector<uint8_t> &data, PhysAddress address)
{
    uint8_t *p = progMem.data() + address - PROG_START;
    for (uint8_t b: data) {
        *p++ = b;
    }
}

void
TestInstance::LoadData(const std::vector<uint8_t> &data, PhysAddress address)
{
    uint8_t *p = dataMem.data() + address - DATA_START;
    for (uint8_t b: data) {
        *p++ = b;
    }
}

uint32_t
TestInstance::GetReg(int idx) const
{
    return ReadWord32(dataMem.data() + idx * sizeof(uint32_t));
}

uint32_t
TestInstance::GetDataMem32(PhysAddress address)
{
    return ReadWord32(dataMem.data() + address);
}

void
TestInstance::WaitInstructions(int n)
{
    int prevState = 0;
    do {
        Clock();
        if (module->dbgState != prevState) {
            prevState = module->dbgState;
            if (prevState == RiscvCore::State::INSN_FETCH) {
                n--;
            }
        }
    } while (n);
}

