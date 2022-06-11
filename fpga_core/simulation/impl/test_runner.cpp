#include <test_runner.h>

#include <iostream>

namespace {

std::map<std::string, TestCase::Factory> *tests = nullptr;

} /* anonymous namespace */

void
RegisterTestCase(const std::string &name, const TestCase::Factory &tc)
{
    if (!tests) {
        tests = new std::map<std::string, TestCase::Factory>();
    }
    tests->emplace(name, tc);
}

void
RunTests(int argc, char **argv)
{
    int numFailed = 0;
    for (auto &e: *tests) {
        const std::string &name = e.first;

        try {
            TestInstance ti(name);
            ti.ctx.commandArgs(argc, argv);
            auto tcPtr = e.second(ti);
            tcPtr->Run();

        } catch (TestException &e) {
            std::cout << "Test failure in test `" << name << "` at [" << e.file << ":" << e.line
                      << "]: " << e.what() << "\n";
            numFailed++;

        } catch (std::exception &e) {
            std::cout << "Exception in test `" << name << "`: " << e.what() << "\n";
            numFailed++;
        }
    }

    if (numFailed) {
        throw std::runtime_error(std::to_string(numFailed) + " tests failed");
    }
}