# ---------------------------------------------------------------------------
# load_slim_flags([FILE <path>])
# Reads an optional 'slim_flags' file and propagates:
#   SLIM_EXTRA_CPP_FLAGS  — tokens following CPP_FLAGS lines
#   SLIM_EXTRA_LD_FLAGS   — tokens following LD_FLAGS lines
# to the caller's scope.  Silently does nothing if the file is absent.
# ---------------------------------------------------------------------------
function(load_slim_flags)
    cmake_parse_arguments(_ARG "" "FILE" "" ${ARGN})
    if(_ARG_FILE)
        set(_flags_file "${_ARG_FILE}")
    else()
        set(_flags_file "${CMAKE_SOURCE_DIR}/slim_flags")
    endif()

    if(NOT EXISTS "${_flags_file}")
        message(STATUS "load_slim_flags: '${_flags_file}' not found, skipping")
        return()
    endif()

    message(STATUS "load_slim_flags: reading '${_flags_file}'")

    set(_cpp_flags "")
    set(_ld_flags  "")

    file(STRINGS "${_flags_file}" _lines REGEX "^[^#\n]")
    foreach(_line IN LISTS _lines)
        string(STRIP "${_line}" _line)
        if("${_line}" STREQUAL "")
            continue()
        endif()

        if(_line MATCHES "^CPP_FLAGS[ \t]+(.*)")
            string(STRIP "${CMAKE_MATCH_1}" _val)
            separate_arguments(_tokens UNIX_COMMAND "${_val}")
            list(APPEND _cpp_flags ${_tokens})

        elseif(_line MATCHES "^LD_FLAGS[ \t]+(.*)")
            string(STRIP "${CMAKE_MATCH_1}" _val)
            separate_arguments(_tokens UNIX_COMMAND "${_val}")
            list(APPEND _ld_flags ${_tokens})

        else()
            message(WARNING "load_slim_flags: unrecognised line, skipping: '${_line}'")
        endif()
    endforeach()

    set(SLIM_EXTRA_CPP_FLAGS "${_cpp_flags}" PARENT_SCOPE)
    set(SLIM_EXTRA_LD_FLAGS  "${_ld_flags}"  PARENT_SCOPE)

    message(STATUS "load_slim_flags: CPP_FLAGS = ${_cpp_flags}")
    message(STATUS "load_slim_flags: LD_FLAGS  = ${_ld_flags}")
endfunction()

function(set_compiler_flags)
    set(flags "")

    if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
        list(APPEND flags
            -Wall
            -Wextra
            -Wpedantic
            -Wshadow
            -Wconversion
            -Wsign-conversion
        )
        if(CMAKE_BUILD_TYPE STREQUAL "RELEASE")
            list(APPEND flags -O2 -DNDEBUG)
        elseif(CMAKE_BUILD_TYPE STREQUAL "COMPACT")
            list(APPEND flags -O3)
        elseif(CMAKE_BUILD_TYPE STREQUAL "DEBUG")
            list(APPEND flags -g -O0)
        endif()

    elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
        list(APPEND flags
            /W4
            /WX-
            /permissive-
        )
        if(CMAKE_BUILD_TYPE STREQUAL "RELEASE")
            list(APPEND flags /O2 /DNDEBUG)
        elseif(CMAKE_BUILD_TYPE STREQUAL "COMPACT")
            list(APPEND flags /O1 /DNDEBUG)
        elseif(CMAKE_BUILD_TYPE STREQUAL "DEBUG")
            list(APPEND flags /Od /Zi)
        endif()

    else()
        message(WARNING "Unknown compiler '${CMAKE_CXX_COMPILER_ID}' — no flags set")
    endif()

    set(SLIM_CXX_FLAGS "${flags}" PARENT_SCOPE)  # propagate to caller
endfunction()