#include <test_runner.h>

#include <iostream>

namespace {

std::map<std::string, TestCase::Factory> *tests = nullptr;
using TestEntry = std::remove_reference_t<decltype(*tests->begin())>;

/** Find option in CLI arguments.
 * @param optionName Option name to find.
 * @param hasArg True if option has argument.
 * @return Option argument if hasArg is true, non-null value otherwise. Default value if option not
 *  found.
 */
const char *
FindOption(int argc, const char **argv, const std::string &optionName, bool hasArg,
           const char *defaultValue = nullptr)
{
    std::string pattern("--");
    pattern += optionName;
    for(; argc; argc--, argv++) {
        if (pattern == *argv) {
            if (hasArg) {
                if (argc < 2) {
                    throw std::runtime_error("Mission option argument");
                }
                return argv[1];
            } else {
                return "1";
            }
        }
    }
    return defaultValue;
}

} /* anonymous namespace */

void
RegisterTestCase(const std::string &name, const TestCase::Factory &tc)
{
    if (!tests) {
        tests = new std::map<std::string, TestCase::Factory>();
    }
    if (!tests->emplace(name, tc).second) {
        throw std::runtime_error(std::string("Duplicated test name: ") + name);
    }
}

void
RegisterTestCaseFunc(const std::string &name, const TestFunc &tc)
{
    RegisterTestCase(name,
                     [tc](TestInstance &ti) { return std::make_shared<SimpleTestCase>(ti, tc); });
}

static bool
RunTest(int argc, const char **argv, const TestEntry &te)
{
    const std::string &name = te.first;
    try {
        TestInstance ti(name, std::stoi(FindOption(argc, argv, "memReadDelay", true, "0")),
                        std::stoi(FindOption(argc, argv, "memWriteDelay", true, "0")));
        ti.ctx.traceEverOn(true);
        ti.ctx.commandArgs(argc, argv);
        auto tcPtr = te.second(ti);
        tcPtr->Run();
        return true;

    } catch (TestException &e) {
        std::cout << "Test failure in test `" << name << "` at [" << e.file << ":" << e.line
                    << "]: " << e.what() << "\n";

    } catch (std::exception &e) {
        std::cout << "Exception in test `" << name << "`: " << e.what() << "\n";
    }
    return false;
}

void
RunTests(int argc, const char **argv)
{
    int numFailed = 0;
    for (auto &e: *tests) {
        if (!RunTest(argc, argv, e)) {
            numFailed++;
        }
    }

    if (numFailed) {
        throw std::runtime_error(std::to_string(numFailed) + " tests failed");
    } else {
        std::cout << "All tests passed (" << tests->size() << ")\n";
    }
}

void
RunTest(int argc, const char **argv, const std::string &testName)
{
    std::cout << "Running test `" << testName << "`\n";
    auto it = tests->find(testName);
    if (it == tests->end()) {
        throw std::runtime_error("Test not found");
    }
    RunTest(argc, argv, *it);
}