extern "C" int
__cxa_atexit(void (*func [[maybe_unused]])(void *), void *arg [[maybe_unused]],
             void *dso_handle [[maybe_unused]])
{
    // XXX
    return 0;
}

void
Main();

extern "C" void
Start()
{
    //XXX zero bss, copy data, call constructors
    Main();
    //XXX halt
}