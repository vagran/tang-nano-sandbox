cmake_minimum_required(VERSION 3.10)
project(sample_app)

set(CMAKE_VERBOSE_MAKEFILE ON)

set(CMAKE_CXX_STANDARD 20)

set(CMAKE_CXX_FLAGS_DEBUG "-O0 -fno-omit-frame-pointer -gfull -gdwarf-4 -gdwarf64")

find_package(verilator HINTS /opt/verilator)

file(GLOB_RECURSE SOURCES "impl/*.cpp")

include_directories("include")

add_executable(simulation ${SOURCES})

verilate(simulation SOURCES "${CMAKE_SOURCE_DIR}/../test/riscv_core_test.sv"
         INCLUDE_DIRS "${CMAKE_SOURCE_DIR}/../src"
         VERILATOR_ARGS --default-language 1800-2017 +define+DEBUG=1 --trace
         --top-module RiscvCoreTest)
