include(FetchContent)
set(SLIMLIB_CXX_STANDARD 23)
cmake_path(GET CMAKE_SOURCE_DIR FILENAME SLIM_LIB)
string(TOLOWER "${SLIM_LIB}" SLIM_LIB_LOWER)

if(SLIM_USE_LOCAL_SOURCE)
    set(GIT_TAG 0.0.0)
    set(SLIMLIB_GIT_HASH "none")
else()
    execute_process(
        COMMAND git ls-remote --tags --sort=-v:refname https://github.com/greergan/${SLIM_LIB}.git
        OUTPUT_VARIABLE TAGS_RAW
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    string(REGEX MATCH "refs/tags/([^\\^\\n]+)" _ "${TAGS_RAW}")
    set(GIT_TAG ${CMAKE_MATCH_1})
endif()

if(SLIM_USE_LOCAL_SOURCE)
    set(slimlibrarysrc_SOURCE_DIR ${CMAKE_CURRENT_SOURCE_DIR})
    message(STATUS "using LOCAL source (${slimlibrarysrc_SOURCE_DIR})")
else()
    FetchContent_Declare(
        SlimLibrarySrc
        GIT_REPOSITORY https://github.com/greergan/${SLIM_LIB}.git
        GIT_TAG        ${GIT_TAG}
    )

    message(STATUS "using GIT source (tag: ${GIT_TAG})")
    message(STATUS "fetched from https://github.com/greergan/${SLIM_LIB}.git")

    FetchContent_MakeAvailable(SlimLibrarySrc)

    execute_process(
        COMMAND git rev-parse --short HEAD
        OUTPUT_VARIABLE SLIMLIB_GIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
endif()