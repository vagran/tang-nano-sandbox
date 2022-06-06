/opt/clang-riscv/bin/clang -c --target=riscv32 -march=rv32ec -mno-relax -mlittle-endian $1 \
    -o build/assembled.o
/opt/clang-riscv/bin/llvm-objdump --disassemble build/assembled.o
/opt/clang-riscv/bin/clang -c --target=riscv32 -march=rv32e -mno-relax -mlittle-endian $1 \
    -o build/assembled-no-comp.o
/opt/clang-riscv/bin/llvm-objdump --disassemble build/assembled-no-comp.o
