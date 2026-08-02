# ---------------------------------------------------------------------------
# Toolchain: Linux x86_64
# Default compiler: GCC
# Opt-in:    cmake -DSLIM_USE_CLANG=ON ... -DCMAKE_TOOLCHAIN_FILE=...
# ---------------------------------------------------------------------------
set(CMAKE_SYSTEM_NAME      Linux)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

if(SLIM_USE_CLANG)
    set(CMAKE_C_COMPILER   clang)
    set(CMAKE_CXX_COMPILER clang++)
else()
    set(CMAKE_C_COMPILER   gcc)
    set(CMAKE_CXX_COMPILER g++)
endif()
