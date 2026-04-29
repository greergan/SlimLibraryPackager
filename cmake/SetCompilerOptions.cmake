set(SLIM_CXX_FLAGS "")
list(APPEND SLIM_CXX_FLAGS ${SLIM_CXX_STANDARD})
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang|AppleClang")
    list(APPEND SLIM_CXX_FLAGS
        -Wall
        -Wextra
        -Wpedantic
        -Wshadow
        -Wconversion
        -Wsign-conversion
    )
    if(CMAKE_BUILD_TYPE STREQUAL "RELEASE")
        list(APPEND SLIM_CXX_FLAGS -O2 -DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "COMPACT")
        list(APPEND SLIM_CXX_FLAGS -O3)
    elseif(CMAKE_BUILD_TYPE STREQUAL "DEBUG")
        list(APPEND SLIM_CXX_FLAGS -g -O0)
    endif()
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC")
    list(APPEND SLIM_CXX_FLAGS
        /W4
        /WX-
        /permissive-
    )
    if(CMAKE_BUILD_TYPE STREQUAL "RELEASE")
        list(APPEND SLIM_CXX_FLAGS /O2 /DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "COMPACT")
        list(APPEND SLIM_CXX_FLAGS /O1 /DNDEBUG)
    elseif(CMAKE_BUILD_TYPE STREQUAL "DEBUG")
        list(APPEND SLIM_CXX_FLAGS /Od /Zi)
    endif()
else()
    message(WARNING "Unknown compiler '${CMAKE_CXX_COMPILER_ID}' — no flags set")
endif()

# ---------------------------------------------------------------------------
# dump_target_properties(<TARGET>)
# Prints all common target properties to STATUS output.
# ---------------------------------------------------------------------------
function(dump_target_properties TARGET)
    if(NOT TARGET ${TARGET})
        message(WARNING "dump_target_properties: '${TARGET}' is not a valid target")
        return()
    endif()

    set(_props
        TYPE
        OUTPUT_NAME
        VERSION
        SOVERSION
        COMPILE_OPTIONS
        COMPILE_DEFINITIONS
        COMPILE_FEATURES
        INCLUDE_DIRECTORIES
        LINK_LIBRARIES
        LINK_OPTIONS
        LINK_DIRECTORIES
        INTERFACE_INCLUDE_DIRECTORIES
        INTERFACE_LINK_LIBRARIES
        INTERFACE_COMPILE_OPTIONS
        INTERFACE_COMPILE_DEFINITIONS
        POSITION_INDEPENDENT_CODE
    )

    message(STATUS "  === Target: ${TARGET} ===")
    foreach(_prop IN LISTS _props)
        get_target_property(_val ${TARGET} ${_prop})
        if(NOT _val MATCHES "NOTFOUND$")
            message(STATUS "    ${_prop}: ${_val}")
        endif()
    endforeach()
endfunction()
