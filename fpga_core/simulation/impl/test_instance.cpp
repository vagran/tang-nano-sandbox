#include <test_instance.h>
#include <sstream>

namespace {

/** Read little-endian 32-bits word. */
uint32_t
ReadWord32(const uint8_t *location)
{
    return location[0] | (location[1] << 8) | (location[2] << 16) | location[3] << 24;
}

} /* anonymous namespace */

void
TestInstance::HandleMemory()
{
    if (!module->memStrobe) {
        module->memReady = 0;
        return;
    }
    PhysAddress address = module->memAddress << 2;
    if (IsProgAddress(address)) {
        if (module->memWriteEnable) {
            TEST_FAIL("Attempting to write to program memory address "
                      << std::hex << address << "h");
        }
        module->memData = ReadWord32(progMem.data() + address - PROG_START);

    } else if (IsDataAddress(address)) {
        if (module->memWriteEnable) {
            //XXX
        } else {
            module->memData = ReadWord32(dataMem.data() + address - DATA_START);
        }

    } else {
        TEST_FAIL("Attempting to access (" << (module->memWriteEnable ? "write" : "read")
                                           << ") invalid address " << std::hex
                                           << address << "h");
    }
    module->memReady = 1;
}

void
TestInstance::Fail(const char *file, int line, const char *msg)
{
    std::stringstream ss;
    ss << "[" << file << ":" << line << "] Failure in test `" << name << "`: " << msg;
    throw TestFailException(ss.str());
}

void
TestInstance::CheckTrap()
{
    //XXX allow expected trap
    if (module->trap != TRAP_NONE) {
        TEST_FAIL("Unexpected trap: " << std::to_string(module->trap));
    }
}