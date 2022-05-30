#include <tmp.h>

const int x = 43;
int y = 0, z = 44;

class A {
public:
    A()
    {
        Tmp();
    }

    ~A()
    {
        Tmp();
    }
};

A a;

int
Tmp()
{
    return 42;
}