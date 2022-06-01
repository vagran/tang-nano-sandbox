cmake_minimum_required(VERSION 3.10)
project(sample_app)

set(CMAKE_VERBOSE_MAKEFILE ON)

find_package(verilator HINTS /opt/verilator)

file(GLOB_RECURSE SOURCES "src/*.cpp")

add_executable(simulation ${SOURCES})

verilate(simulation SOURCES "${CMAKE_SOURCE_DIR}/../test/riscv_core_test.sv"
         INCLUDE_DIRS "${CMAKE_SOURCE_DIR}/../src")
