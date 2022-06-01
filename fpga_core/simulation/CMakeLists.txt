cmake_minimum_required(VERSION 3.10)
project(sample_app)

set(CMAKE_VERBOSE_MAKEFILE ON)

find_package(verilator HINTS /opt/verilator)

add_executable(simulation sim_main.cpp)

verilate(simulation SOURCES "${CMAKE_SOURCE_DIR}/../src/main.sv"
         INCLUDE_DIRS "${CMAKE_SOURCE_DIR}/../src/main")
