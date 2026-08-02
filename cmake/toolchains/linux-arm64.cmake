# ---------------------------------------------------------------------------
# Toolchain: Linux arm64 (aarch64)
# Default compiler: GCC aarch64 cross-compiler
# Opt-in:    cmake -DSLIM_USE_CLANG=ON ... -DCMAKE_TOOLCHAIN_FILE=...
#            Uses clang with --target=aarch64-linux-gnu instead of GCC cross.
# ---------------------------------------------------------------------------
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR aarch64)

if(SLIM_USE_CLANG)
    set(CMAKE_C_COMPILER          clang)
    set(CMAKE_CXX_COMPILER        clang++)
    set(CMAKE_C_COMPILER_TARGET   aarch64-linux-gnu)
    set(CMAKE_CXX_COMPILER_TARGET aarch64-linux-gnu)
else()
    set(CMAKE_C_COMPILER   aarch64-linux-gnu-gcc)
    set(CMAKE_CXX_COMPILER aarch64-linux-gnu-g++)
endif()

set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
