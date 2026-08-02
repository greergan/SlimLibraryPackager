# ---------------------------------------------------------------------------
# Toolchain: Windows x86_64
# Method:    clang-cl (LLVM) + lld-link + xwin (MSVC CRT + Windows SDK)
#
# Prerequisites
#   1. LLVM installed: clang-cl, lld-link, llvm-lib, llvm-rc in PATH
#   2. xwin fetched and splat:
#        cargo install xwin
#        xwin --accept-license splat --output <XWIN_ROOT>
#      Default output path: ~/.xwin-cache/splat
#
# Configuration
#   XWIN_ROOT — env var or CMake cache var
#               (default: $HOME/.xwin-cache/splat)
# ---------------------------------------------------------------------------
set(CMAKE_SYSTEM_NAME      Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# --- Compilers -------------------------------------------------------------
set(CMAKE_C_COMPILER   clang-cl)
set(CMAKE_CXX_COMPILER clang-cl)
set(CMAKE_AR           llvm-lib)
set(CMAKE_RC_COMPILER  llvm-rc)

# Declare MSVC frontend so set_compiler_flags() emits /W4 style flags
# rather than -Wall style flags (see SlimCompilerFunctions.cmake).
set(CMAKE_C_COMPILER_FRONTEND_VARIANT   MSVC)
set(CMAKE_CXX_COMPILER_FRONTEND_VARIANT MSVC)

# Target triple — produces native Windows PE/COFF linked against MSVC CRT
set(CMAKE_C_COMPILER_TARGET   x86_64-pc-windows-msvc)
set(CMAKE_CXX_COMPILER_TARGET x86_64-pc-windows-msvc)

# Use lld-link as the linker
set(CMAKE_LINKER lld-link)

# --- xwin sysroot ----------------------------------------------------------
if(DEFINED ENV{XWIN_ROOT})
    set(_xwin_root "$ENV{XWIN_ROOT}")
else()
    set(_xwin_root "$ENV{HOME}/.xwin-cache/splat")
endif()
set(XWIN_ROOT "${_xwin_root}" CACHE PATH "xwin splat output directory")

if(NOT EXISTS "${XWIN_ROOT}")
    message(FATAL_ERROR
        "windows-x86_64 toolchain: XWIN_ROOT not found: '${XWIN_ROOT}'\n"
        "Install xwin (cargo install xwin) then run:\n"
        "  xwin --accept-license splat --output ${XWIN_ROOT}")
endif()

# xwin splat directory layout:
#   crt/include/                   — MSVC CRT headers
#   crt/lib/x86_64/               — MSVC CRT import libs
#   sdk/include/{shared,ucrt,um}/  — Windows SDK headers
#   sdk/lib/{ucrt,um}/x86_64/     — Windows SDK import libs
set(_xwin_includes
    "${XWIN_ROOT}/crt/include"
    "${XWIN_ROOT}/sdk/include/shared"
    "${XWIN_ROOT}/sdk/include/ucrt"
    "${XWIN_ROOT}/sdk/include/um"
)
set(_xwin_libdirs
    "${XWIN_ROOT}/crt/lib/x86_64"
    "${XWIN_ROOT}/sdk/lib/ucrt/x86_64"
    "${XWIN_ROOT}/sdk/lib/um/x86_64"
)

# Inject include paths as /imsvc (not /I) so clang-cl treats them as system
# headers and suppresses warnings originating in SDK/CRT headers.
set(_include_flags "")
foreach(_inc IN LISTS _xwin_includes)
    string(APPEND _include_flags " /imsvc \"${_inc}\"")
endforeach()
set(CMAKE_C_FLAGS_INIT   "${_include_flags}")
set(CMAKE_CXX_FLAGS_INIT "${_include_flags}")

# Inject library search paths into all linker invocations.
set(_libpath_flags "")
foreach(_lib IN LISTS _xwin_libdirs)
    string(APPEND _libpath_flags " /libpath:\"${_lib}\"")
endforeach()
set(CMAKE_EXE_LINKER_FLAGS_INIT    "${_libpath_flags}")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "${_libpath_flags}")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "${_libpath_flags}")

# --- Find root paths -------------------------------------------------------
set(CMAKE_FIND_ROOT_PATH
    "${XWIN_ROOT}/crt"
    "${XWIN_ROOT}/sdk"
)
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
