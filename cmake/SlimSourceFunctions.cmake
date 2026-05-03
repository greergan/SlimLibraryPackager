function(generate_main_cpp)
    get_primary_module(_primary)
    if(NOT _primary)
        message(FATAL_ERROR "generate_main_cpp: no primary module defined")
    endif()

    if(NOT "${_primary}" STREQUAL "SlimCommon")
        message(STATUS "generate_main_cpp: skipped (primary module is '${_primary}', not 'SlimCommon')")
        return()
    endif()

    if(NOT SLIM_USE_LOCAL_SOURCE)
        message(STATUS "generate_main_cpp: skipped (SLIM_USE_LOCAL_SOURCE is OFF)")
        return()
    endif()

    meta_get(MODULE "${_primary}" src_dir _src_dir)

    set(_includes "")
    foreach(_name IN LISTS MODULE_NAMES)
        meta_get(MODULE "${_name}" primary _is_primary)
        if(_is_primary)
            continue()
        endif()

        meta_get(MODULE "${_name}" header_file_out _hdr)
        if(NOT _hdr)
            message(WARNING "generate_main_cpp: module '${_name}' has no header_file_out, skipping")
            continue()
        endif()

        string(REGEX REPLACE "^include/" "" _hdr_rel "${_hdr}")
        list(APPEND _includes "#include <${_hdr_rel}>")
    endforeach()

    if(NOT _includes)
        message(WARNING "generate_main_cpp: no sub-module headers found, aborting")
        return()
    endif()

    list(JOIN _includes "\n" _includes_block)

    # --- Generate the header file (header_file_in for SlimCommon) --------
    meta_get(MODULE "${_primary}" header_file_in _hdr_in)
    if(NOT _hdr_in)
        message(WARNING "generate_main_cpp: primary module '${_primary}' has no header_file_in, skipping header generation")
    else()
        meta_get(MODULE "${_primary}" git_tag  _git_tag)
        meta_get(MODULE "${_primary}" git_hash _git_hash)
        meta_get(MODULE "${_primary}" upper    _module)

        set(_hdr_in_content
"#pragma once\n\
#ifndef SLIM__COMMON__H\n\
#define SLIM__COMMON__H\n\
\n\
${_includes_block}\n\
\n\
#define ${_module}_VERSION \"${_git_tag}\"\n\
#define ${_module}_GIT_HASH \"${_git_hash}\"\n\
\n\
#endif // SLIM__COMMON__H\n")

        file(WRITE "${_hdr_in}" "${_hdr_in_content}")
        message(STATUS "generate_main_cpp: wrote ${_hdr_in}")
    endif()

    # --- Generate main.cpp -----------------------------------------------
    set(_out_src "${_src_dir}/src/main.cpp")
    file(WRITE "${_out_src}" "${_includes_block}\n")
    message(STATUS "generate_main_cpp: wrote ${_out_src}")

    # --- Optionally git commit the generated files ------------------------
    find_program(_GIT_EXEC git)
    if(NOT _GIT_EXEC)
        message(WARNING "generate_main_cpp: git not found, skipping auto-commit")
        return()
    endif()

    set(_files_changed FALSE)

    execute_process(
        COMMAND "${_GIT_EXEC}" diff --quiet HEAD -- src/main.cpp
        RESULT_VARIABLE _git_diff_result
    )
    if(NOT _git_diff_result EQUAL 0)
        set(_files_changed TRUE)
    endif()

    if(_hdr_in)
        execute_process(
            COMMAND "${_GIT_EXEC}" diff --quiet HEAD -- "${_hdr_in}"
            RESULT_VARIABLE _git_diff_hdr_result
        )
        if(NOT _git_diff_hdr_result EQUAL 0)
            set(_files_changed TRUE)
        endif()
    endif()

    if(NOT _files_changed)
        message(STATUS "generate_main_cpp: no files changed, skipping commit prompt")
        return()
    endif()

    message(STATUS "generate_main_cpp: files were regenerated")
    message(STATUS "")
    if(NOT AUTO_CHECK_IN)
        message(STATUS "  Commit src/main.cpp with message: 'automated: regenerate src/main.cpp'?")
        message(STATUS "  Press [Enter] to continue, or Ctrl+C to abort.")
        message(STATUS "")

        execute_process(
            COMMAND bash -c "read -r _reply < /dev/tty && [[ \"$_reply\" =~ ^[yY]([eE][sS])?$ ]]"
            RESULT_VARIABLE _read_result
        )
        if(NOT _read_result EQUAL 0)
            message(STATUS "generate_main_cpp: skipping commit")
            return()
        endif()
    endif()

    # --- Stage src/main.cpp ----------------------------------------------
    execute_process(
        COMMAND "${_GIT_EXEC}" add src/main.cpp
        RESULT_VARIABLE _git_add_result
        ERROR_VARIABLE  _git_add_error
    )
    if(NOT _git_add_result EQUAL 0)
        message(WARNING "generate_main_cpp: git add src/main.cpp failed\n${_git_add_error}")
        return()
    endif()

    # --- Stage header file -----------------------------------------------
    if(_hdr_in)
        execute_process(
            COMMAND "${_GIT_EXEC}" add "${_hdr_in}"
            RESULT_VARIABLE _git_add_hdr_result
            ERROR_VARIABLE  _git_add_hdr_error
        )
        if(NOT _git_add_hdr_result EQUAL 0)
            message(WARNING "generate_main_cpp: git add ${_hdr_in} failed\n${_git_add_hdr_error}")
            return()
        endif()
    endif()

    # --- Commit all staged files -----------------------------------------
    execute_process(
        COMMAND "${_GIT_EXEC}" commit -m "automated: regenerate src/main.cpp and ${_hdr_in}"
        RESULT_VARIABLE _git_commit_result
        ERROR_VARIABLE  _git_commit_error
    )
    if(NOT _git_commit_result EQUAL 0)
        message(WARNING "generate_main_cpp: git commit failed\n${_git_commit_error}")
    else()
        message(STATUS "generate_main_cpp: committed src/main.cpp and ${_hdr_in}")
    endif()
endfunction()