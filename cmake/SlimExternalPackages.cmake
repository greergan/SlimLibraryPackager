# ---------------------------------------------------------------------------
# _load_external_dependencies(<FILE>)  [internal]
# Reads an optional 'external_dependencies' file and installs each listed
# package directly from the GIT_URL package registry.
# File format:
#   # comment
#   PackageName [minVersion [maxVersion]]
# Silently does nothing when the file is absent.
# ---------------------------------------------------------------------------
function(_load_external_dependencies FILE)
  if(NOT EXISTS "${FILE}")
    message(STATUS "_load_external_dependencies: '${FILE}' not found, skipping")
    return()
  endif()
  message(STATUS "_load_external_dependencies: processing file '${FILE}'")

  find_program(_EXT_CURL curl)
  find_program(_EXT_DPKG dpkg)

  if(NOT _EXT_CURL)
    message(FATAL_ERROR "_load_external_dependencies: curl not found")
  endif()
  if(NOT _EXT_DPKG)
    message(FATAL_ERROR "_load_external_dependencies: dpkg not found")
  endif()

  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
  if(_arch MATCHES "x86_64|amd64")
    set(_arch_name "amd64")
  elseif(_arch MATCHES "aarch64|arm64")
    set(_arch_name "arm64")
  else()
    set(_arch_name "${_arch}")
  endif()

  file(STRINGS "${FILE}" _dep_lines REGEX "^[^#\n]")
  foreach(_line IN LISTS _dep_lines)
    string(STRIP "${_line}" _line)
    if("${_line}" STREQUAL "")
      continue()
    endif()

    string(REGEX MATCHALL "[^ \t]+" _tokens "${_line}")
    list(GET _tokens 0 _pkg)
    list(LENGTH _tokens _token_count)

    set(_min_version "")
    set(_max_version "")
    if(_token_count GREATER 1)
      list(GET _tokens 1 _min_version)
    endif()
    if(_token_count GREATER 2)
      list(GET _tokens 2 _max_version)
    endif()

    # --- Query registry for available versions -----------------------
    set(_api_url "${SLIM_GIT_URL}/api/v1/packages/${SLIM_GIT_REPO_OWNER}?type=generic&q=${_pkg}&limit=50")
    message(STATUS "_load_external_dependencies: querying registry for '${_pkg}' at '${_api_url}'")

    execute_process(
            COMMAND "${_EXT_CURL}" --silent --max-time 10 "${_api_url}"
            OUTPUT_VARIABLE _api_response
            OUTPUT_STRIP_TRAILING_WHITESPACE
            RESULT_VARIABLE _curl_result
            ERROR_VARIABLE  _curl_error
        )
    if(NOT _curl_result EQUAL 0)
      message(FATAL_ERROR "_load_external_dependencies: registry query failed for '${_pkg}': ${_curl_error}")
    endif()

    # --- Parse versions from JSON response ---------------------------
    # Response is a JSON array; each element has "name" and "version" fields.
    string(JSON _pkg_count ERROR_VARIABLE _json_err LENGTH "${_api_response}")
    if(_json_err OR "${_pkg_count}" STREQUAL "0")
      message(FATAL_ERROR "_load_external_dependencies: no packages found in registry for '${_pkg}'")
    endif()

    set(_best_version "")
    math(EXPR _last_idx "${_pkg_count} - 1")
    foreach(_idx RANGE ${_last_idx})
      string(JSON _entry      ERROR_VARIABLE _json_err GET "${_api_response}" ${_idx})
      string(JSON _entry_name ERROR_VARIABLE _json_err GET "${_entry}" "name")
      string(JSON _entry_ver  ERROR_VARIABLE _json_err GET "${_entry}" "version")

      if(NOT "${_entry_name}" STREQUAL "${_pkg}")
        continue()
      endif()

      if(_min_version AND "${_entry_ver}" VERSION_LESS "${_min_version}")
        continue()
      endif()
      if(_max_version AND "${_entry_ver}" VERSION_GREATER "${_max_version}")
        continue()
      endif()

      if("${_best_version}" STREQUAL "" OR "${_entry_ver}" VERSION_GREATER "${_best_version}")
        set(_best_version "${_entry_ver}")
      endif()
    endforeach()

    if("${_best_version}" STREQUAL "")
      if(_min_version OR _max_version)
        message(FATAL_ERROR "_load_external_dependencies: no version of '${_pkg}' satisfies [${_min_version}, ${_max_version}]")
      else()
        message(FATAL_ERROR "_load_external_dependencies: no versions found in registry for '${_pkg}'")
      endif()
    endif()

    message(STATUS "_load_external_dependencies: resolved '${_pkg}' to version '${_best_version}'")

    # --- Download and install ----------------------------------------
    set(_filename "${_pkg}-${_best_version}-${_arch_name}.deb")
    set(_url "${SLIM_GIT_URL}/api/packages/${SLIM_GIT_REPO_OWNER}/generic/${_pkg}/${_best_version}/${_filename}")
    set(_dest "${CMAKE_BINARY_DIR}/_pkg_downloads/${_filename}")

    message(STATUS "_load_external_dependencies: downloading '${_url}'")
    file(DOWNLOAD "${_url}" "${_dest}" STATUS _dl_status)
    list(GET _dl_status 0 _dl_code)
    if(NOT _dl_code EQUAL 0)
      list(GET _dl_status 1 _dl_msg)
      message(FATAL_ERROR "_load_external_dependencies: download failed for '${_url}': ${_dl_msg}")
    endif()

    execute_process(
            COMMAND "${_EXT_DPKG}" -i "${_dest}"
            RESULT_VARIABLE _dpkg_result
            ERROR_VARIABLE  _dpkg_error
        )
    file(REMOVE "${_dest}")

    if(NOT _dpkg_result EQUAL 0)
      message(FATAL_ERROR "_load_external_dependencies: dpkg -i failed for '${_filename}'\n${_dpkg_error}")
    endif()

    message(STATUS "_load_external_dependencies: installed '${_filename}'")
  endforeach()
endfunction()
