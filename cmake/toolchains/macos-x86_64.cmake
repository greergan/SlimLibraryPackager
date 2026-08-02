# ---------------------------------------------------------------------------
# Toolchain: macOS x86_64
# Method:    osxcross (Clang cross-compiler targeting macOS)
#
# Prerequisites
#   1. osxcross built and installed
#   2. macOS SDK inside osxcross (see osxcross/tools/gen_sdk_package.sh)
#
# Configuration
#   OSXCROSS_ROOT  — env var or CMake cache var
#                   (default: /usr/local/osxcross)
#   DARWIN_TRIPLE  — CMake cache var, target triple
#                   (default: x86_64-apple-darwin23)
# ---------------------------------------------------------------------------
set(CMAKE_SYSTEM_NAME      Darwin)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# --- osxcross root ---------------------------------------------------------
if(DEFINED ENV{OSXCROSS_ROOT})
    set(_osxcross_root "$ENV{OSXCROSS_ROOT}")
else()
    set(_osxcross_root "/usr/local/osxcross")
endif()
set(OSXCROSS_ROOT "${_osxcross_root}" CACHE PATH "osxcross installation root")

set(DARWIN_TRIPLE "x86_64-apple-darwin23" CACHE STRING "osxcross target triple")

if(NOT EXISTS "${OSXCROSS_ROOT}")
    message(FATAL_ERROR
        "macos-x86_64 toolchain: OSXCROSS_ROOT not found: '${OSXCROSS_ROOT}'\n"
        "Build osxcross and set OSXCROSS_ROOT to its installation directory.")
endif()

# --- Compilers -------------------------------------------------------------
set(CMAKE_C_COMPILER            "${OSXCROSS_ROOT}/bin/${DARWIN_TRIPLE}-clang")
set(CMAKE_CXX_COMPILER          "${OSXCROSS_ROOT}/bin/${DARWIN_TRIPLE}-clang++")
set(CMAKE_AR                    "${OSXCROSS_ROOT}/bin/${DARWIN_TRIPLE}-ar")
set(CMAKE_RANLIB                "${OSXCROSS_ROOT}/bin/${DARWIN_TRIPLE}-ranlib")
set(CMAKE_STRIP                 "${OSXCROSS_ROOT}/bin/${DARWIN_TRIPLE}-strip")
set(CMAKE_INSTALL_NAME_TOOL     "${OSXCROSS_ROOT}/bin/${DARWIN_TRIPLE}-install_name_tool")

# --- SDK sysroot -----------------------------------------------------------
# osxcross exposes a MacOSX.sdk symlink pointing to the active SDK version.
set(CMAKE_SYSROOT "${OSXCROSS_ROOT}/SDK/MacOSX.sdk")

set(CMAKE_FIND_ROOT_PATH "${OSXCROSS_ROOT}/SDK/MacOSX.sdk")
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
