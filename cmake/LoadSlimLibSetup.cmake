if(${SLIM_LIB} MATCHES "^SlimCommon")
    string(REGEX REPLACE "^SlimCommon" "" SLIM_COMMON_SUFFIX "${SLIM_LIB}")
    string(REGEX REPLACE "([A-Z])" "/\\1" SLIM_COMMON_PATH "${SLIM_COMMON_SUFFIX}")
    string(TOLOWER "${SLIM_COMMON_PATH}" SLIM_COMMON_PATH)
    string(REGEX REPLACE "^/" "" SLIM_COMMON_PATH "${SLIM_COMMON_PATH}")
    string(REGEX MATCH "[^/]+$" HEADER_FILE_PREFIX "${SLIM_COMMON_PATH}")
    string(REGEX REPLACE "/[^/]+$" "" SLIM_COMMON_PARENT "${SLIM_COMMON_PATH}")
    if(SLIM_COMMON_PARENT STREQUAL SLIM_COMMON_PATH)
        set(SLIM_INCLUDE_DIR "include/slim/common")
    else()
        set(SLIM_INCLUDE_DIR "include/slim/common/${SLIM_COMMON_PARENT}")
    endif()
else()
    string(REGEX REPLACE "^slim" "" HEADER_FILE_PREFIX "${SLIM_LIB_LOWER}")
    set(SLIM_INCLUDE_DIR "include/slim")
endif()
set(SLIM_METADATA_FILE_OUT "${SLIM_LIB_LOWER}.pc")

set(HPP_IN_FILE "${slimlibrarysrc_SOURCE_DIR}/${SLIM_INCLUDE_DIR}/${SLIM_LIB}.hpp.in")
set(H_IN_FILE "${slimlibrarysrc_SOURCE_DIR}/${SLIM_INCLUDE_DIR}/${HEADER_FILE_PREFIX}.h.in")

set(HPP_OUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_INCLUDE_DIR}/${SLIM_LIB}.hpp")
set(H_OUT_FILE "${CMAKE_CURRENT_BINARY_DIR}/${SLIM_INCLUDE_DIR}/${HEADER_FILE_PREFIX}.h")

set(HPP_HEADER_ONLY OFF)

if(EXISTS ${HPP_IN_FILE})
    set(HPP_HEADER_ONLY ON)
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