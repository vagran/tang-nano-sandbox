#include <tmp.h>

void
Main()
{
    volatile int *p = reinterpret_cast<int *>(8);
    *p = Tmp() + x + y + z;
}