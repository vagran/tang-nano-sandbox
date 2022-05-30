ENTRY(Start)

# XXX temporal layout, separate text/rodata and the rest between flash and ram
SECTIONS {
    . = LOAD_ADDRESS;
    .text . : {
        *(.text)
        *(.text.*)
    } :text

    . = ALIGN(4);
    _etext = ABSOLUTE(.);

    .rodata . : {
        *(.rodata*)

        /* place global constructors list in .rodata section */
        . = ALIGN(4);
        _ctro_list = .;
        *(SORT(.init_array))
        _ctor_end = .;
    } :rodata

    . = ALIGN(4);
    _erodata = ABSOLUTE(.);

    .data . : {
        *(.sdata)
    } :data

    . = ALIGN(4);
    _edata = ABSOLUTE(.);

    .bss . : {
        *(.sbss)
    } :data

    . = ALIGN(4);
    _end = ABSOLUTE(.);
}