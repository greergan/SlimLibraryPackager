# ---------------------------------------------------------------------------
# _set_git_repo(<NAME>)  [internal]
# ---------------------------------------------------------------------------
function(_set_git_repo NAME)
    meta_set(MODULE "${NAME}" git_repo  "${_SLIM_GIT_BASE}/${NAME}.git")
    meta_get(MODULE "${NAME}" git_repo _repo_url)

    find_program(_CURL_EXEC curl)
    if(NOT _CURL_EXEC)
        message(FATAL_ERROR "_set_git_repo: curl not found, '${NAME}'")
    endif()

    execute_process(
        COMMAND "${_CURL_EXEC}"
            --silent --output /dev/null --write-out "%{http_code}"
            --max-time 5 "${_repo_url}"
        OUTPUT_VARIABLE _http_code
        OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_QUIET
    )

    if("${_http_code}" EQUAL 301)
        meta_set(MODULE "${NAME}" git_repo_found "ON")
    else()
        message(FATAL_ERROR "_set_git_repo: '${_repo_url}' returned ${_http_code}, expected 301")
    endif()

    _set_git_tag("${NAME}")  
    _set_git_repo_latest_tag("${NAME}")

    _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_git_tag(<NAME>)  [internal] — primary module only
# ---------------------------------------------------------------------------
function(_set_git_tag NAME)

    meta_get(MODULE "${NAME}" primary _primary)

    if(SLIM_USE_LOCAL_SOURCE)
        if(_primary)
            meta_set(MODULE "${NAME}" git_tag  "0.0.0")
            meta_set(MODULE "${NAME}" git_hash "local-src")
        else()
            meta_set(MODULE "${NAME}" git_tag  "0.0.0")
            meta_set(MODULE "${NAME}" git_hash "pkg-config")
        endif()
        _propagate_module("${NAME}")
        return()
    endif()

    meta_get(MODULE "${NAME}" git_repo _repo_url)

    execute_process(
        COMMAND git ls-remote --tags --sort=-v:refname "${_repo_url}"
        OUTPUT_VARIABLE _tags_raw
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _result
        ERROR_VARIABLE  _error
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "_set_get_git_tag: git ls-remote failed for '${_repo_url}'\n${_error}")
    endif()

    string(REGEX MATCH "refs/tags/([^\^\\n]+)" _ "${_tags_raw}")
    set(_tag "${CMAKE_MATCH_1}")

    execute_process(
        COMMAND git ls-remote "${_repo_url}" "refs/tags/${_tag}"
        OUTPUT_VARIABLE _hash_raw
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _result
        ERROR_VARIABLE  _error
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "_set_get_git_tag: git ls-remote failed for '${_repo_url}' refs/tags/${_tag}\n${_error}")
    endif()

    string(REGEX MATCH "^([a-f0-9]+)" _ "${_hash_raw}")
    set(_hash "${CMAKE_MATCH_1}")
    string(SUBSTRING "${_hash}" 0 7 _hash)

    meta_set(MODULE "${NAME}" git_tag  "${_tag}")
    meta_set(MODULE "${NAME}" git_hash "${_hash}")
    _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_git_repo_latest_tag(<NAME>)  [internal] — auto-loaded modules
# ---------------------------------------------------------------------------
function(_set_git_repo_latest_tag NAME)
    meta_get(MODULE "${NAME}" git_repo_found _repo_found)
    if(NOT _repo_found)
        message(FATAL_ERROR "_set_git_repo_latest_tag: _repo_found not found, for '${NAME}'")
    endif()

    meta_get(MODULE "${NAME}" git_repo _repo_url)

    find_program(_GIT_EXEC git)
    if(NOT _GIT_EXEC)
        message(FATAL_ERROR "_set_git_repo_latest_tag: git not found, skipping tag fetch for '${NAME}'")
    endif()

    execute_process(
        COMMAND "${_GIT_EXEC}" ls-remote --tags --sort=-version:refname "${_repo_url}"
        OUTPUT_VARIABLE _tag_output
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _result
        ERROR_VARIABLE  _error
    )
    if(NOT _result EQUAL 0)
        message(FATAL_ERROR "_set_get_git_repo_latest_tag: git ls-remote failed for '${_repo_url}'\n${_error}")
    endif()

    string(REGEX MATCH "refs/tags/([^\n^]+)" _ "${_tag_output}")
    meta_set(MODULE "${NAME}" git_latest_tag "${CMAKE_MATCH_1}")
    _propagate_module("${NAME}")
endfunction()