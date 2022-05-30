cmake_minimum_required(VERSION 3.10)
project(sample_app)

set(CMAKE_VERBOSE_MAKEFILE ON)

include_directories("include")

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} --target=riscv32 -march=rv32ec -mno-relax \
    -Wall -Werror -Wextra")

string(TOLOWER "${CMAKE_BUILD_TYPE}" CMAKE_BUILD_TYPE)
# Debug build options
if(CMAKE_BUILD_TYPE MATCHES "debug")
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -O0 -fno-omit-frame-pointer")
    add_definitions(-DDEBUG)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -gfull -gdwarf-4")
else()
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Os")
endif()

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions -fno-rtti -nostdlib")

add_compile_options("-nostdinc")

set(LOAD_ADDRESS 0x1000)
set(LINKER_SCRIPT "${CMAKE_SOURCE_DIR}/link.lds")
set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fuse-ld=lld -T ${LINKER_SCRIPT} \
     -Wl,--defsym=LOAD_ADDRESS=${LOAD_ADDRESS} -Wl,--gc-sections")

file(GLOB_RECURSE SOURCES "impl/*.cpp")

add_executable(${CMAKE_PROJECT_NAME} ${SOURCES})
set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES LINK_DEPENDS ${LINKER_SCRIPT})
