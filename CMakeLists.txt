cmake_minimum_required(VERSION 3.20)

cmake_path(GET CMAKE_SOURCE_DIR FILENAME SLIM_LIB)
string(TOLOWER "${SLIM_LIB}" SLIM_LIB_LOWER)

if(DEFINED CPACK_OUTPUT_FILE_PREFIX)
    if("${CPACK_OUTPUT_FILE_PREFIX}" STREQUAL ".")
	    set(CPACK_OUTPUT_FILE_PREFIX ${CMAKE_SOURCE_DIR})
    endif()
else()
	message(FATAL_ERROR "CPACK_OUTPUT_FILE_PREFIX is not set")
endif()

include(FetchContent)

set(SLIM_USE_LOCAL_SOURCE OFF CACHE BOOL "Use local library source instead of git")

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

    FetchContent_Populate(SlimLibrarySrc)

    execute_process(
        COMMAND git rev-parse --short HEAD
        OUTPUT_VARIABLE SLIMLIB_GIT_HASH
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )
endif()

project(${SLIM_LIB} VERSION ${GIT_TAG} LANGUAGES CXX)
set(SLIMLIB_CXX_STANDARD 23)

if(${SLIM_LIB} MATCHES "^SlimCommon")
    set(SLIM_INCLUDE_DIR "include/slim/common")
    string(REGEX REPLACE "^slimcommon" "" HEADER_FILE_PREFIX "${SLIM_LIB_LOWER}")
else(${SLIM_LIB} MATCHES "^Slim")
    set(SLIM_INCLUDE_DIR "include/slim")
    string(REGEX REPLACE "^slim" "" HEADER_FILE_PREFIX "${SLIM_LIB_LOWER}")
endif()
set(SLIM_METADATA_FILE_OUT "${SLIM_LIB_LOWER}.pc")

set(HPP_IN_FILE "${slimlibrarysrc_SOURCE_DIR}/${SLIM_INCLUDE_DIR}/${SLIM_LIB}.hpp.in")
set(H_IN_FILE "${slimlibrarysrc_SOURCE_DIR}/${SLIM_INCLUDE_DIR}/${HEADER_FILE_PREFIX}.h.in")

set(HPP_OUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_INCLUDE_DIR}/${SLIM_LIB}.hpp")
set(H_OUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_INCLUDE_DIR}/${HEADER_FILE_PREFIX}.h")

set(HPP_HEADER_ONLY OFF)

if(EXISTS ${HPP_IN_FILE})
    set(HPP_HEADER_ONLY)
    set(SLIM_LIB_DESCRIPTION "${SLIM_LIB} header-only C++ library")
    set(SLIM_METADATA_FILE_IN "slim_header_lib.pc.in")
else()
    set(SLIM_LIB_DESCRIPTION "${SLIM_LIB} C++ library")
    set(SLIM_METADATA_FILE_IN "slim_common_lib.pc.in")
endif()

if(NOT SLIM_INCLUDE_DIR)
    message(FATAL_ERROR "empty SLIM_INCLUDE_DIR")
endif()
if(NOT HEADER_FILE_PREFIX)
    message(FATAL_ERROR "empty HEADER_FILE_PREFIX")
endif()
if(NOT SLIM_METADATA_FILE_OUT)
    message(FATAL_ERROR "empty SLIM_METADATA_FILE_OUT")
endif()

set(SLIMLIB_VERSION ${GIT_TAG})
set(SLIMLIB_VERSION_FULL "${SLIMLIB_VERSION}+${SLIMLIB_GIT_HASH}")

execute_process(
	COMMAND git config --get user.name
	OUTPUT_VARIABLE GIT_USER_NAME
	OUTPUT_STRIP_TRAILING_WHITESPACE
	ERROR_QUIET
)

if(NOT GIT_USER_NAME)
	set(GIT_USER_NAME "unknown")
endif()

execute_process(
	COMMAND git config --get user.email
	OUTPUT_VARIABLE GIT_USER_EMAIL
	OUTPUT_STRIP_TRAILING_WHITESPACE
	ERROR_QUIET
)

if(NOT GIT_USER_EMAIL)
	set(GIT_USER_EMAIL "unknown")
endif()

message(STATUS "OS: ${CMAKE_SYSTEM_NAME} ${CMAKE_SYSTEM_VERSION}")
message(STATUS "Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "Project dir: ${CMAKE_SOURCE_DIR}")
message(STATUS "Build dir:   ${CMAKE_BINARY_DIR}")
message(STATUS "Dist dir: ${CPACK_OUTPUT_FILE_PREFIX}")
message(STATUS "Local INSTALL_PREFIX: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "slim library name: ${SLIM_LIB}")
message(STATUS "slim include path: ${SLIM_INCLUDE_DIR}")
if(HPP_HEADER_ONLY)
    message(STATUS "install .hpp only: ${HPP_HEADER_ONLY}")
    message(STATUS ".hpp.in file: ${HPP_IN_FILE}")
    message(STATUS ".hpp file: ${HPP_OUT_FILE}")
endif()
message(STATUS "version tag: ${GIT_TAG}")
message(STATUS "version hash: ${SLIMLIB_GIT_HASH}")
message(STATUS "full version: ${SLIMLIB_VERSION_FULL}")
message(STATUS "Package maintainer: ${GIT_USER_NAME} <${GIT_USER_EMAIL}>")

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

if(HPP_HEADER_ONLY)
    configure_file("${HPP_IN_FILE}" "${HPP_OUT_FILE}" @ONLY)
else()
    configure_file("${H_IN_FILE}" "${H_OUT_FILE}" @ONLY)
endif()

add_library(slim_shared SHARED
    ${slimlibrarysrc_SOURCE_DIR}/src/main.cpp
)

set_target_properties(slim_shared PROPERTIES
    OUTPUT_NAME ${SLIM_LIB_LOWER}
    VERSION ${GIT_TAG}
    SOVERSION ${GIT_TAG}
)

add_library(slim_static STATIC
    ${slimlibrarysrc_SOURCE_DIR}/src/main.cpp
)
set_target_properties(slim_static PROPERTIES OUTPUT_NAME ${SLIM_LIB_LOWER})

if(SLIMVALUE_FOUND)
    target_include_directories(slim_shared PRIVATE ${SLIMVALUE_INCLUDE_DIRS})
    target_link_libraries(slim_shared PRIVATE ${SLIMVALUE_LIBRARIES})
    target_include_directories(slim_static PRIVATE ${SLIMVALUE_INCLUDE_DIRS})
    target_link_libraries(slim_static PRIVATE ${SLIMVALUE_LIBRARIES})
    message(STATUS "SlimValue found via pkg-config")
else()
    message(FATAL_ERROR "SlimValue not found via pkg-config")
endif()

foreach(t slim_shared slim_static)
    target_include_directories(${t}
        PUBLIC
            $<BUILD_INTERFACE:${slimlibrarysrc_SOURCE_DIR}/include>
            $<BUILD_INTERFACE:${CMAKE_CURRENT_BINARY_DIR}/include>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    )

    target_compile_features(${t} PUBLIC cxx_std_23)
endforeach()

add_library(slim ALIAS slim_shared)

add_custom_command(TARGET slim_shared POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Shared lib: $<TARGET_FILE_NAME:slim_shared>"
)

add_custom_command(TARGET slim_static POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E echo "Static lib: $<TARGET_FILE_NAME:slim_static>"
)

if(NOT SHARED_OUT)
    set(SHARED_OUT "${CMAKE_BINARY_DIR}/lib${SLIM_LIB_LOWER}.so.${GIT_TAG}")
endif()

if(NOT STATIC_OUT)
    set(STATIC_OUT "${CMAKE_BINARY_DIR}/lib${SLIM_LIB_LOWER}.a")
endif()

if(EXISTS "${SHARED_OUT}")
    message(STATUS "Shared lib: ${SHARED_OUT}")
else()
    message(STATUS "Shared lib missing: lib${SLIM_LIB_LOWER}.so.${GIT_TAG}")
endif()

if(EXISTS "${STATIC_OUT}")
    message(STATUS "Static lib: ${STATIC_OUT}")
else()
    message(STATUS "Static lib missing: lib${SLIM_LIB_LOWER}.a")
endif()

set(TEST_CPP "${CMAKE_CURRENT_SOURCE_DIR}/src/test.cpp")

if(EXISTS "${TEST_CPP}")
    add_executable(slim_test "${TEST_CPP}")
    target_link_libraries(slim_test PRIVATE slim_shared)
    message(STATUS "Testing: with src/test.cpp")
    add_custom_command(TARGET slim_test POST_BUILD
        COMMAND slim_test
        COMMENT "Running slim_test"
    )
endif()

set(SLIM_BUILD_TESTS OFF)
if(EXISTS "${slimlibrarysrc_SOURCE_DIR}/tests")
    set(SLIM_BUILD_TESTS ON)
    message(STATUS "Cathc2 Testing: enabled")
else()
    set(SLIM_BUILD_TESTS OFF)
    message(STATUS "Cathc2 Testing: disabled")
    message(STATUS "Cathc2 Testing: no tests directory found")
endif()

if(SLIM_BUILD_TESTS)
    FetchContent_Declare(
        Catch2
        GIT_REPOSITORY https://github.com/catchorg/Catch2.git
        GIT_TAG v3.5.0
    )

    FetchContent_MakeAvailable(Catch2)

    enable_testing()

    add_executable(slim_tests
        ${slimlibrarysrc_SOURCE_DIR}/tests/main.cpp
    )

    target_link_libraries(slim_tests
        PRIVATE slim Catch2::Catch2WithMain
    )

    include(CTest)
    include(Catch)
    catch_discover_tests(slim_tests)
endif()

install(TARGETS slim_shared slim_static
    EXPORT SlimTargets
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

if(HPP_HEADER_ONLY)
    install(FILES "${HPP_OUT_FILE}" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/slim)
else()
    install(FILES "${H_OUT_FILE}" DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/slim)
endif()

install(EXPORT SlimTargets
    FILE SlimTargets.cmake
    NAMESPACE Slim::
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${SLIM_LIB}
)

write_basic_package_version_file(
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}ConfigVersion.cmake"
    VERSION ${GIT_TAG}
    COMPATIBILITY AnyNewerVersion
)

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}Config.cmake"
"include(\"\${CMAKE_CURRENT_LIST_DIR}/SlimTargets.cmake\")\n")

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}Config.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_LIB}ConfigVersion.cmake"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/${SLIM_LIB}
)

configure_file(
    "${slimlibrarysrc_SOURCE_DIR}/${SLIM_METADATA_FILE_IN}"
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_METADATA_FILE_OUT}"
    @ONLY
)

install(FILES
    "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_METADATA_FILE_OUT}"
    DESTINATION ${CMAKE_INSTALL_LIBDIR}/pkgconfig
)

string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" ARCH)
if(ARCH MATCHES "x86_64|amd64")
    set(ARCH_NAME "amd64")
elseif(ARCH MATCHES "i386|i686")
    set(ARCH_NAME "x86")
elseif(ARCH MATCHES "aarch64|arm64")
    set(ARCH_NAME "arm64")
elseif(ARCH MATCHES "armv7|arm")
    set(ARCH_NAME "arm")
else()
    set(ARCH_NAME "unknown")
endif()

set(CPACK_GENERATOR "DEB;RPM")

set(CPACK_PACKAGE_NAME ${SLIM_LIB_LOWER})
set(CPACK_PACKAGE_VERSION ${GIT_TAG})
set(CPACK_PACKAGE_CONTACT "${GIT_USER_NAME} <${GIT_USER_EMAIL}>")
set(CPACK_PACKAGE_FILE_NAME "${PROJECT_NAME}-${PROJECT_VERSION}-${ARCH_NAME}")

set(CPACK_DEBIAN_PACKAGE_MAINTAINER ${GIT_USER_NAME})
set(CPACK_DEBIAN_PACKAGE_SECTION "devel")
set(CPACK_DEBIAN_PACKAGE_PRIORITY "optional")
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE ${ARCH_NAME})
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")

set(CPACK_RPM_PACKAGE_NAME ${SLIM_LIB_LOWER})
set(CPACK_RPM_PACKAGE_VERSION ${GIT_TAG})
set(CPACK_RPM_PACKAGE_RELEASE "1")
set(CPACK_RPM_PACKAGE_LICENSE "MIT")
set(CPACK_RPM_PACKAGE_GROUP "Development/Libraries")
set(CPACK_RPM_PACKAGE_SUMMARY ${SLIM_LIB_DESCRIPTION})
set(CPACK_RPM_PACKAGE_ARCHITECTURE ${ARCH_NAME})
set(CPACK_RPM_PACKAGE_PREFIX "${CMAKE_INSTALL_PREFIX}")

include(CPack)