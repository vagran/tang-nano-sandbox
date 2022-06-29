#ifndef INCLUDE_TEST_RUNNER_H
#define INCLUDE_TEST_RUNNER_H

#include <test_instance.h>
#include <sstream>

class TestException: public std::runtime_error {
public:
    const char * const file;
    const int line;

    TestException(const char *file, int line, const std::string &msg):
        std::runtime_error(msg),
        file(file),
        line(line)
    {}
};


#define FAIL(__msg) throw TestException(__FILE__, __LINE__, __msg);

#define ASSERT(__condition) do { \
    if (!(__condition)) { \
        FAIL( "Assert failed: " # __condition); \
    } \
} while (false)

#define ASSERT_EQUAL(__v1, __v2) do { \
    if ((__v1) != (__v2)) { \
        std::stringstream ss; \
        ss << "Assert failed: " # __v1 "(" << (__v1) << ") != " # __v2 "(" << (__v2) << ")"; \
        FAIL(ss.str()); \
    } \
} while (false)

class TestCase {
public:
    using Factory = std::function<std::shared_ptr<TestCase>(TestInstance &)>;

    TestCase(TestInstance &test):
        test(test)
    {}

    virtual
    ~TestCase() = default;

    virtual void
    Run() = 0;

protected:
    TestInstance &test;
};


using TestFunc = std::function<void(TestInstance &)>;


class SimpleTestCase: public TestCase {
public:
    SimpleTestCase(TestInstance &test, const TestFunc &func):
        TestCase(test),
        func(func)
    {}

    void
    Run() override
    {
        func(test);
    }

private:
    TestFunc func;
};


void
RegisterTestCase(const std::string &name, const TestCase::Factory &tc);

void
RegisterTestCaseFunc(const std::string &name, const TestFunc &tc);


struct TestCaseRegisterHelper {
    TestCaseRegisterHelper(const std::string &name, const TestCase::Factory &tc)
    {
        RegisterTestCase(name, tc);
    }
};

struct TestCaseFuncRegisterHelper {
    TestCaseFuncRegisterHelper(const std::string &name, const TestFunc &tc)
    {
        RegisterTestCaseFunc(name, tc);
    }
};

#define T_CONCAT2(__x, __y) __x ## __y
#define T_CONCAT(__x, __y) T_CONCAT2(__x, __y)

#define REGISTER_TEST(__name, __tc) \
    static TestCaseRegisterHelper T_CONCAT(__tcr_, __COUNTER__)(__name, __tc)

#define REGISTER_TEST_CLASS(__name, __cls) \
    REGISTER_TEST(__name, [](TestInstance &ti){ return std::make_shared<__cls>(ti); })

#define REGISTER_TEST_FUNC(__name, __tc) \
    static TestCaseFuncRegisterHelper T_CONCAT(__tcr_, __COUNTER__)(__name, __tc)


void
RunTests(int argc, const char **argv);

void
RunTest(int argc, const char **argv, const std::string &testName);

#endif /* INCLUDE_TEST_RUNNER_H */
