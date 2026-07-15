set(_EMPTY_SENTINEL "__EMPTY__")

include(SlimMetaFunctions)
include(SlimGitFunctions)
include(SlimLoadRequiredPackages)
include(SlimExternalPackages)

# ---------------------------------------------------------------------------
# apply_module_flags(<TARGET>)
# Iterates MODULE_NAMES and applies pkg_CFLAGS, pkg_LDFLAGS, pkg_INCLUDE_DIRS,
# and pkg_LIBRARIES from each non-primary module to the given target.
# ---------------------------------------------------------------------------
function(apply_module_flags TARGET)
  foreach(_name IN LISTS MODULE_NAMES)
    meta_get(MODULE "${_name}" primary _is_primary)
    if(_is_primary)
      continue()
    endif()

    meta_get(MODULE "${_name}" pkg_CFLAGS      _cflags)
    meta_get(MODULE "${_name}" pkg_LDFLAGS     _ldflags)
    meta_get(MODULE "${_name}" pkg_INCLUDE_DIRS _inc_dirs)
    meta_get(MODULE "${_name}" pkg_LIBRARIES   _libs)

    if(_cflags)
      target_compile_options(${TARGET} PRIVATE ${_cflags})
    endif()

    if(_inc_dirs)
      target_include_directories(${TARGET} PRIVATE ${_inc_dirs})
    endif()

    if(_ldflags OR _libs)
      target_link_options(${TARGET} PRIVATE ${_ldflags})
      target_link_libraries(${TARGET} PRIVATE ${_libs})
    endif()
  endforeach()
endfunction()

# ---------------------------------------------------------------------------
# get_primary_module(<OUT_VAR>)
# Returns the name of the primary module, or empty string if none found.
# ---------------------------------------------------------------------------
function(get_primary_module OUT_VAR)
  foreach(_name IN LISTS MODULE_NAMES)
    meta_get(MODULE "${_name}" primary _is_primary)
    if(_is_primary)
      set(${OUT_VAR} "${_name}" PARENT_SCOPE)
      return()
    endif()
  endforeach()
  set(${OUT_VAR} "" PARENT_SCOPE)
endfunction()

# ---------------------------------------------------------------------------
# _derive_module_type(<NAME> <OUT_TYPE>)  [internal]
# ---------------------------------------------------------------------------
function(_derive_module_type NAME OUT_TYPE)
  if("${NAME}" STREQUAL "SlimCommon")
    set(${OUT_TYPE} "SlimCommon" PARENT_SCOPE)

  elseif("${NAME}" MATCHES "^SlimCommon[A-Z]")
    string(REGEX REPLACE "^SlimCommon" "" _suffix "${NAME}")
    string(REGEX MATCHALL "[A-Z][a-z0-9]*" _words "${_suffix}")
    list(LENGTH _words _word_count)
    if(_word_count LESS 1)
      message(FATAL_ERROR "define_module: '${NAME}' must have at least 1 word after 'SlimCommon' (got ${_word_count}).")
    endif()
    set(${OUT_TYPE} "SlimCommonOtherlibSublib" PARENT_SCOPE)

  elseif("${NAME}" MATCHES "^Slim[A-Z]")
    string(REGEX REPLACE "^Slim" "" _suffix "${NAME}")
    string(REGEX MATCHALL "[A-Z][a-z0-9]*" _words "${_suffix}")
    list(LENGTH _words _word_count)
    if(NOT _word_count EQUAL 1)
      message(FATAL_ERROR "define_module: '${NAME}' must have exactly 1 word after 'Slim' (got ${_word_count}).")
    endif()
    set(${OUT_TYPE} "SlimLib" PARENT_SCOPE)

  else()
    message(FATAL_ERROR "define_module: '${NAME}' does not match any known module type. Must start with 'Slim'.")
  endif()
endfunction()

# ---------------------------------------------------------------------------
# _install_module_package(<NAME>)  [internal]
# Downloads and installs the .deb package for a module that was not found
# via pkg_check_modules, using the module's git_latest_tag as the version.
# Builds the download URL from SLIM_GIT_URL / SLIM_GIT_REPO_OWNER, e.g.:
#   ${SLIM_GIT_URL}/api/packages/${SLIM_GIT_REPO_OWNER}/generic/${NAME}/
#       ${version}/${lower}-${tag}-${arch}.deb
# Installs via 'dpkg -i' (no sudo — expected to run as root in a container),
# then deletes the downloaded .deb regardless of install success or failure.
# Fatal on download failure, missing dpkg, or a non-zero dpkg exit code.
# Requires _set_git_repo(<NAME>) to have already run, since it depends on
# the module's git_latest_tag metadata.
# ---------------------------------------------------------------------------

function(_install_module_package NAME)
  meta_get(MODULE "${NAME}" lower           _lower)
  meta_get(MODULE "${NAME}" git_latest_tag  _tag)

  if(NOT _tag)
    message(FATAL_ERROR "_install_module_package: no git_latest_tag for '${NAME}'")
  endif()

  # Path segment uses the bare semver; filename keeps the 'v' prefix as published.
  string(REGEX REPLACE "^v" "" _version "${_tag}")

  # Arch detection — mirrors make_packages()
  string(TOLOWER "${CMAKE_SYSTEM_PROCESSOR}" _arch)
  if(_arch MATCHES "x86_64|amd64")
    set(_arch_name "amd64")
  elseif(_arch MATCHES "aarch64|arm64")
    set(_arch_name "arm64")
  else()
    set(_arch_name "${_arch}")
  endif()

  set(_filename "${_lower}-${_tag}-${_arch_name}.deb")
  set(_url "${SLIM_GIT_URL}/api/packages/${SLIM_GIT_REPO_OWNER}/generic/${NAME}/${_version}/${_filename}")
  set(_dest "${CMAKE_BINARY_DIR}/_pkg_downloads/${_filename}")

  message(STATUS "_install_module_package: downloading '${_url}'")
  file(DOWNLOAD "${_url}" "${_dest}" STATUS _dl_status)
  list(GET _dl_status 0 _dl_code)
  if(NOT _dl_code EQUAL 0)
    list(GET _dl_status 1 _dl_msg)
    message(FATAL_ERROR "_install_module_package: download failed for '${_url}': ${_dl_msg}")
  endif()

  find_program(_DPKG_EXEC dpkg)
  if(NOT _DPKG_EXEC)
    message(FATAL_ERROR "_install_module_package: dpkg not found")
  endif()

  execute_process(
        COMMAND "${_DPKG_EXEC}" -i "${_dest}"
        RESULT_VARIABLE _dpkg_result
        ERROR_VARIABLE  _dpkg_error
    )

  file(REMOVE "${_dest}")

  if(NOT _dpkg_result EQUAL 0)
    message(FATAL_ERROR "_install_module_package: dpkg -i failed for '${_dest}'\n${_dpkg_error}")
  endif()

  message(STATUS "_install_module_package: installed '${_filename}'")
endfunction()

# ---------------------------------------------------------------------------
# _set_check_module(<NAME> <MIN_VERSION> <MAX_VERSION>)  [internal]
# ---------------------------------------------------------------------------
function(_set_check_module NAME MIN_VERSION MAX_VERSION)
  get_primary_module(_primary_module)
  meta_get(MODULE "${NAME}" primary _is_primary)
  if(_is_primary)
    return()
  endif()
  if(${_primary_module} STREQUAL "SlimCommon" AND NOT SLIM_USE_LOCAL_SOURCE)
    return()
  endif()

  find_package(PkgConfig REQUIRED)

  meta_get(MODULE "${NAME}" lower _pkg_name)

  set(_constraints "")
  if(NOT "${MIN_VERSION}" STREQUAL "${_EMPTY_SENTINEL}" AND NOT "${MIN_VERSION}" STREQUAL "")
    list(APPEND _constraints "${_pkg_name}>=${MIN_VERSION}")
  endif()
  if(NOT "${MAX_VERSION}" STREQUAL "${_EMPTY_SENTINEL}" AND NOT "${MAX_VERSION}" STREQUAL "")
    list(APPEND _constraints "${_pkg_name}<=${MAX_VERSION}")
  endif()

  if(_constraints)
    pkg_check_modules("${NAME}" ${_constraints})
  else()
    pkg_check_modules("${NAME}" "${_pkg_name}")
  endif()

  if(NOT ${NAME}_FOUND)
    message(STATUS "_set_check_module: '${_pkg_name}' not found, installing from package registry")
    _install_module_package("${NAME}")

    if(_constraints)
      pkg_check_modules("${NAME}" REQUIRED ${_constraints})
    else()
      pkg_check_modules("${NAME}" REQUIRED "${_pkg_name}")
    endif()
  endif()

  find_program(_PKG_CONFIG_EXEC pkg-config)
  if(_PKG_CONFIG_EXEC)
    execute_process(
            COMMAND "${_PKG_CONFIG_EXEC}" --modversion "${_pkg_name}"
            OUTPUT_VARIABLE "${NAME}_RESOLVED_VERSION"
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
  endif()

  foreach(KEY IN ITEMS CFLAGS LDFLAGS LIBRARIES INCLUDE_DIRS LIBRARY_DIRS VERSION)
    meta_set(MODULE "${NAME}" "pkg_${KEY}" "${${NAME}_${KEY}}")
  endforeach()

  meta_set(MODULE "${NAME}" found_version "${${NAME}_RESOLVED_VERSION}")
  _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_dist_directory(<NAME>)
# Sets dist_dir on the given module to a 'dist' directory that lives next
# to the build directory.
# ---------------------------------------------------------------------------
function(_set_dist_directory NAME)
  meta_get(MODULE "${NAME}" primary _is_primary)
  if(NOT _is_primary)
    return()
  endif()

  cmake_path(GET CMAKE_BINARY_DIR PARENT_PATH _build_parent)
  meta_set(MODULE "${NAME}" dist_dir "${_build_parent}/dist")
  _propagate_module("${NAME}")

  message(STATUS "_set_dist_directory: ${NAME}.dist_dir=${_build_parent}/dist")
endfunction()

# ---------------------------------------------------------------------------
# _set_metadata_file(<NAME>)  [internal]
# ---------------------------------------------------------------------------
function(_set_metadata_file NAME)
  meta_get(MODULE "${NAME}" hpp_only _hpp_only)
  meta_get(MODULE "${NAME}" lower    _metadata_file_name)

  if(_hpp_only)
    meta_set(MODULE "${NAME}" metadata_file_in "cmake/slim_header_lib.pc.in")
  else()
    meta_set(MODULE "${NAME}" metadata_file_in "cmake/slim_common_lib.pc.in")
  endif()
  meta_set(MODULE "${NAME}" metadata_file_out "${_metadata_file_name}.pc")
  _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_module_headers(<NAME>)  [internal]
# ---------------------------------------------------------------------------
function(_set_module_headers NAME)
  _derive_module_type("${NAME}" _type)

  if("${_type}" STREQUAL "SlimCommon")
    meta_set(MODULE "${NAME}" header_prefix "common")
    meta_set(MODULE "${NAME}" header_file_in  "include/slim/common.h.in")
    meta_set(MODULE "${NAME}" header_file_out "include/slim/common.h")
    meta_set(MODULE "${NAME}" include_dir     "include/slim")

  elseif("${_type}" STREQUAL "SlimLib")
    meta_set(MODULE "${NAME}" hpp_only ON)
    set(_hdr_in "include/slim/${NAME}.hpp.in")
    string(REGEX REPLACE "\.in$" "" _hdr_out "${_hdr_in}")
    meta_set(MODULE "${NAME}" header_prefix   "${NAME}")
    meta_set(MODULE "${NAME}" header_file_in  "${_hdr_in}")
    meta_set(MODULE "${NAME}" header_file_out "${_hdr_out}")
    meta_set(MODULE "${NAME}" include_dir     "include/slim")

  elseif("${_type}" STREQUAL "SlimCommonOtherlibSublib")
    string(REGEX REPLACE "^SlimCommon" "" _suffix "${NAME}")
    string(REGEX MATCHALL "[A-Z][a-z0-9]*" _words "${_suffix}")
    list(LENGTH _words _word_count)

    # Lowercase every word, e.g. for SlimCommonHttpUrlSearchParams:
    #   _words = Http;Url;Search;Params  ->  http;url;search;params
    set(_lower_words "")
    foreach(_w IN LISTS _words)
      string(TOLOWER "${_w}" _w_lower)
      list(APPEND _lower_words "${_w_lower}")
    endforeach()

    # All words but the last form the directory path under include/slim/common;
    # the last word is the header filename and header_prefix, e.g.:
    #   1 word  (Http):                       include/slim/common/http.h.in
    #   2 words (Http, Cookie):                include/slim/common/http/cookie.h.in
    #   3 words (Http, Cookie, Store):         include/slim/common/http/cookie/store.h.in
    #   4 words (Http, Url, Search, Params):   include/slim/common/http/url/search/params.h.in
    math(EXPR _last_index "${_word_count} - 1")
    list(GET _lower_words ${_last_index} _last_word)

    set(_dir_words "${_lower_words}")
    list(REMOVE_AT _dir_words ${_last_index})

    set(_inc_dir "include/slim/common")
    foreach(_dw IN LISTS _dir_words)
      string(APPEND _inc_dir "/${_dw}")
    endforeach()

    set(_hdr_in    "${_inc_dir}/${_last_word}.h.in")
    set(_extra_dir "${_inc_dir}/${_last_word}")
    meta_set(MODULE "${NAME}" header_prefix "${_last_word}")
    string(REGEX REPLACE "\.in$" "" _hdr_out "${_hdr_in}")
    meta_set(MODULE "${NAME}" header_file_in  "${_hdr_in}")
    meta_set(MODULE "${NAME}" header_file_out "${_hdr_out}")
    meta_set(MODULE "${NAME}" include_dir     "${_inc_dir}")

    # --- Secondary directory of header files ---------------------------
    # In addition to the single header_file_in above, a module may keep
    # multiple headers in a same-named subdirectory, e.g. for
    # SlimCommonHttp:       include/slim/common/http/*.h.in
    # SlimCommonHttpCookie: include/slim/common/http/cookie/*.h.in
    # This check is optional: if the directory doesn't exist, or contains
    # no '*.h.in' files, it is silently skipped and header_file_in remains
    # as set above (and required, as before).
    # NOTE: when the primary module is SlimCommon and SLIM_USE_LOCAL_SOURCE
    # is OFF, sub-module sources are not yet fetched at this point.
    # The extra header glob is deferred to _set_source_info in that case.
    set(_extra_hdr_in  "")
    set(_extra_hdr_out "")
    set(_extra_dir_full "${CMAKE_SOURCE_DIR}/${_extra_dir}")
    if(EXISTS "${_extra_dir_full}")
      file(GLOB _extra_hdr_matches RELATIVE "${CMAKE_SOURCE_DIR}" "${_extra_dir_full}/*.h.in")
      list(SORT _extra_hdr_matches)
      foreach(_match IN LISTS _extra_hdr_matches)
        string(REGEX REPLACE "\.in$" "" _match_out "${_match}")
        list(APPEND _extra_hdr_in  "${_match}")
        list(APPEND _extra_hdr_out "${_match_out}")
      endforeach()
    endif()

    if(_extra_hdr_in)
      message(STATUS "_set_module_headers: '${NAME}' found ${_extra_dir}/*.h.in: ${_extra_hdr_in}")
    endif()

    meta_set(MODULE "${NAME}" extra_header_files_in  "${_extra_hdr_in}")
    meta_set(MODULE "${NAME}" extra_header_files_out "${_extra_hdr_out}")

    # When the secondary directory supplied at least one header, the
    # primary single header_file_in becomes optional rather than required.
    if(_extra_hdr_in)
      meta_set(MODULE "${NAME}" header_file_in_optional ON)
    endif()

  endif()

  _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_package_info(<NAME>)  [internal]
# ---------------------------------------------------------------------------
function(_set_package_info NAME)
  string(TOUPPER "${NAME}" _upper)
  string(TOLOWER "${NAME}" _lower)
  meta_set(MODULE "${NAME}" upper "${_upper}")
  meta_set(MODULE "${NAME}" lower "${_lower}")

  if(ARGC GREATER 3 AND "${ARGV3}" STREQUAL "ON")
    meta_set(MODULE "${NAME}" primary ON)
  endif()

  if(ARGC GREATER 1 AND NOT "${ARGV1}" STREQUAL "")
    meta_set(MODULE "${NAME}" min_version   "${ARGV1}")
  endif()
  if(ARGC GREATER 2 AND NOT "${ARGV2}" STREQUAL "")
    meta_set(MODULE "${NAME}" max_version   "${ARGV2}")
  endif()
  _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_project_description(<NAME> <DESCRIPTION>)
# Sets the project description on the given module, with different handling
# for hpp-only vs compiled modules. Fails if NAME is not provided.
# ---------------------------------------------------------------------------
function(_set_project_description NAME)
  if("${NAME}" STREQUAL "")
    message(FATAL_ERROR "_set_project_description: NAME must be provided.")
  endif()

  meta_get(MODULE "${NAME}" hpp_only _hpp_only)

  if(_hpp_only)
    meta_set(MODULE "${NAME}" description "${NAME} Header Only Library")
  else()
    meta_set(MODULE "${NAME}" description "${NAME} C++ Library")
  endif()

  _propagate_module("${NAME}")
endfunction()

# ---------------------------------------------------------------------------
# _set_source_info(<NAME>)  [internal]
# ---------------------------------------------------------------------------
function(_set_source_info NAME)
  meta_get(MODULE "${NAME}" primary _primary)

  if(_primary)
    if(SLIM_USE_LOCAL_SOURCE)
      meta_set(MODULE "${NAME}" using_local_src "ON")
      meta_set(MODULE "${NAME}" src_dir "${CMAKE_SOURCE_DIR}")
    else()
      meta_get(MODULE "${NAME}" git_repo       _repo_url)
      meta_get(MODULE "${NAME}" git_latest_tag _git_tag)

      include(FetchContent)
      FetchContent_Declare(
                "${NAME}"
                GIT_REPOSITORY "${_repo_url}"
                GIT_TAG        "${_git_tag}"
            )
      FetchContent_MakeAvailable("${NAME}")

      string(TOLOWER "${NAME}" _lower)
      meta_set(MODULE "${NAME}" src_dir "${${_lower}_SOURCE_DIR}")

      # Accumulate slim_flags from fetched primary source
      set(_slim_flags_file "${${_lower}_SOURCE_DIR}/slim_flags")
      if(EXISTS "${_slim_flags_file}")
        message(STATUS "_set_source_info: reading slim_flags for '${NAME}': '${_slim_flags_file}'")
        file(STRINGS "${_slim_flags_file}" _sf_lines REGEX "^[^#\n]")
        set(_new_cpp "")
        set(_new_ld  "")
        foreach(_sf_line IN LISTS _sf_lines)
          string(STRIP "${_sf_line}" _sf_line)
          if("${_sf_line}" STREQUAL "")
            continue()
          endif()
          if(_sf_line MATCHES "^CPP_FLAGS[ \t]+(.*)")
            string(STRIP "${CMAKE_MATCH_1}" _sf_val)
            separate_arguments(_sf_tokens UNIX_COMMAND "${_sf_val}")
            list(APPEND _new_cpp ${_sf_tokens})
          elseif(_sf_line MATCHES "^LD_FLAGS[ \t]+(.*)")
            string(STRIP "${CMAKE_MATCH_1}" _sf_val)
            separate_arguments(_sf_tokens UNIX_COMMAND "${_sf_val}")
            list(APPEND _new_ld ${_sf_tokens})
          endif()
        endforeach()
        list(APPEND _new_cpp ${SLIM_EXTRA_CPP_FLAGS})
        list(APPEND _new_ld  ${SLIM_EXTRA_LD_FLAGS})
        list(REMOVE_DUPLICATES _new_cpp)
        list(REMOVE_DUPLICATES _new_ld)
        set(SLIM_EXTRA_CPP_FLAGS "${_new_cpp}" CACHE INTERNAL "")
        set(SLIM_EXTRA_LD_FLAGS  "${_new_ld}"  CACHE INTERNAL "")
        message(STATUS "_set_source_info: '${NAME}' SLIM_EXTRA_CPP_FLAGS = ${SLIM_EXTRA_CPP_FLAGS}")
        message(STATUS "_set_source_info: '${NAME}' SLIM_EXTRA_LD_FLAGS  = ${SLIM_EXTRA_LD_FLAGS}")
      endif()

      # Accumulate external_dependencies from fetched primary source
      set(_ext_dep_file "${${_lower}_SOURCE_DIR}/external_dependencies")
      if(EXISTS "${_ext_dep_file}")
        message(STATUS "_set_source_info: reading external_dependencies for '${NAME}': '${_ext_dep_file}'")
        file(STRINGS "${_ext_dep_file}" _ext_lines REGEX "^[^#\n]")
        foreach(_ext_line IN LISTS _ext_lines)
          string(STRIP "${_ext_line}" _ext_line)
          if("${_ext_line}" STREQUAL "")
            continue()
          endif()
          string(REGEX MATCHALL "[^ \t]+" _ext_tokens "${_ext_line}")
          list(GET _ext_tokens 0 _ext_pkg)
          if("${_ext_pkg}" IN_LIST SLIM_INSTALLED_EXTERNAL_DEPS)
            message(STATUS "_set_source_info: skipping already-installed external dep '${_ext_pkg}'")
            continue()
          endif()
          set(_ext_tmp "${CMAKE_BINARY_DIR}/_ext_dep_tmp/${_ext_pkg}.txt")
          file(WRITE "${_ext_tmp}" "${_ext_line}\n")
          _load_external_dependencies("${_ext_tmp}")
          list(APPEND SLIM_INSTALLED_EXTERNAL_DEPS "${_ext_pkg}")
          set(SLIM_INSTALLED_EXTERNAL_DEPS "${SLIM_INSTALLED_EXTERNAL_DEPS}" CACHE INTERNAL "")
          message(STATUS "_set_source_info: installed external dep '${_ext_pkg}'")
        endforeach()
      endif()
    endif()
  else()
    if(NOT SLIM_USE_LOCAL_SOURCE)
      meta_get(MODULE "${NAME}" git_repo       _repo_url)
      meta_get(MODULE "${NAME}" git_latest_tag _git_tag)

      include(FetchContent)
      FetchContent_Declare(
                "${NAME}"
                GIT_REPOSITORY "${_repo_url}"
                GIT_TAG        "${_git_tag}"
            )
      FetchContent_MakeAvailable("${NAME}")

      string(TOLOWER "${NAME}" _lower)
      meta_set(MODULE "${NAME}" src_dir "${${_lower}_SOURCE_DIR}")

      # Accumulate slim_flags from fetched sub-module source
      set(_slim_flags_file "${${_lower}_SOURCE_DIR}/slim_flags")
      if(EXISTS "${_slim_flags_file}")
        message(STATUS "_set_source_info: reading slim_flags for '${NAME}': '${_slim_flags_file}'")
        file(STRINGS "${_slim_flags_file}" _sf_lines REGEX "^[^#\n]")
        set(_new_cpp "")
        set(_new_ld  "")
        foreach(_sf_line IN LISTS _sf_lines)
          string(STRIP "${_sf_line}" _sf_line)
          if("${_sf_line}" STREQUAL "")
            continue()
          endif()
          if(_sf_line MATCHES "^CPP_FLAGS[ \t]+(.*)")
            string(STRIP "${CMAKE_MATCH_1}" _sf_val)
            separate_arguments(_sf_tokens UNIX_COMMAND "${_sf_val}")
            list(APPEND _new_cpp ${_sf_tokens})
          elseif(_sf_line MATCHES "^LD_FLAGS[ \t]+(.*)")
            string(STRIP "${CMAKE_MATCH_1}" _sf_val)
            separate_arguments(_sf_tokens UNIX_COMMAND "${_sf_val}")
            list(APPEND _new_ld ${_sf_tokens})
          endif()
        endforeach()
        list(APPEND _new_cpp ${SLIM_EXTRA_CPP_FLAGS})
        list(APPEND _new_ld  ${SLIM_EXTRA_LD_FLAGS})
        list(REMOVE_DUPLICATES _new_cpp)
        list(REMOVE_DUPLICATES _new_ld)
        set(SLIM_EXTRA_CPP_FLAGS "${_new_cpp}" CACHE INTERNAL "")
        set(SLIM_EXTRA_LD_FLAGS  "${_new_ld}"  CACHE INTERNAL "")
        message(STATUS "_set_source_info: '${NAME}' SLIM_EXTRA_CPP_FLAGS = ${SLIM_EXTRA_CPP_FLAGS}")
        message(STATUS "_set_source_info: '${NAME}' SLIM_EXTRA_LD_FLAGS  = ${SLIM_EXTRA_LD_FLAGS}")
      endif()

      # Accumulate external_dependencies from fetched sub-module source
      set(_ext_dep_file "${${_lower}_SOURCE_DIR}/external_dependencies")
      if(EXISTS "${_ext_dep_file}")
        message(STATUS "_set_source_info: reading external_dependencies for '${NAME}': '${_ext_dep_file}'")
        file(STRINGS "${_ext_dep_file}" _ext_lines REGEX "^[^#\n]")
        foreach(_ext_line IN LISTS _ext_lines)
          string(STRIP "${_ext_line}" _ext_line)
          if("${_ext_line}" STREQUAL "")
            continue()
          endif()
          string(REGEX MATCHALL "[^ \t]+" _ext_tokens "${_ext_line}")
          list(GET _ext_tokens 0 _ext_pkg)
          if("${_ext_pkg}" IN_LIST SLIM_INSTALLED_EXTERNAL_DEPS)
            message(STATUS "_set_source_info: skipping already-installed external dep '${_ext_pkg}'")
            continue()
          endif()
          set(_ext_tmp "${CMAKE_BINARY_DIR}/_ext_dep_tmp/${_ext_pkg}.txt")
          file(WRITE "${_ext_tmp}" "${_ext_line}\n")
          _load_external_dependencies("${_ext_tmp}")
          list(APPEND SLIM_INSTALLED_EXTERNAL_DEPS "${_ext_pkg}")
          set(SLIM_INSTALLED_EXTERNAL_DEPS "${SLIM_INSTALLED_EXTERNAL_DEPS}" CACHE INTERNAL "")
          message(STATUS "_set_source_info: installed external dep '${_ext_pkg}'")
        endforeach()
      endif()

      # Re-run extra header glob now that src_dir is known.
      # _set_module_headers ran before fetch so could only glob CMAKE_SOURCE_DIR;
      # for fetched sub-modules the headers live under their own src_dir.
      _derive_module_type("${NAME}" _type)
      if("${_type}" STREQUAL "SlimCommonOtherlibSublib")
        meta_get(MODULE "${NAME}" include_dir   _inc_dir)
        meta_get(MODULE "${NAME}" header_prefix _last_word)

        set(_extra_dir      "${_inc_dir}/${_last_word}")
        set(_extra_dir_full "${${_lower}_SOURCE_DIR}/${_extra_dir}")

        if(EXISTS "${_extra_dir_full}")
          file(GLOB _extra_hdr_matches RELATIVE "${${_lower}_SOURCE_DIR}" "${_extra_dir_full}/*.h.in")
          list(SORT _extra_hdr_matches)

          set(_extra_hdr_in  "")
          set(_extra_hdr_out "")
          foreach(_match IN LISTS _extra_hdr_matches)
            string(REGEX REPLACE "\.in$" "" _match_out "${_match}")
            list(APPEND _extra_hdr_in  "${_match}")
            list(APPEND _extra_hdr_out "${_match_out}")
          endforeach()

          if(_extra_hdr_in)
            meta_set(MODULE "${NAME}" extra_header_files_in  "${_extra_hdr_in}")
            meta_set(MODULE "${NAME}" extra_header_files_out "${_extra_hdr_out}")
            meta_set(MODULE "${NAME}" header_file_in_optional ON)
            message(STATUS "_set_source_info: '${NAME}' found extra headers: ${_extra_hdr_in}")
          endif()
        endif()
      endif()
    endif()
  endif()

  _propagate_module("${NAME}")
endfunction()

# -------------------------------------------------------------------------------
# define_module([NAME] [min_version] [max_version] [ON])
#   No args: derives name from CMAKE_SOURCE_DIR and auto-loads required_packages
#            and external_dependencies.
# -------------------------------------------------------------------------------
function(define_module)
  # ------------------------------------------------------------------
  # No-arg branch: primary module derived from CMAKE_SOURCE_DIR
  # ------------------------------------------------------------------
  if(ARGC EQUAL 0)
    cmake_path(GET CMAKE_SOURCE_DIR FILENAME NAME)

    define_module("${NAME}" "${_EMPTY_SENTINEL}" "${_EMPTY_SENTINEL}" ON)
    _load_required_packages("${CMAKE_SOURCE_DIR}/required_packages")
    _load_external_dependencies("${CMAKE_SOURCE_DIR}/external_dependencies")
    _propagate_module("${NAME}")
    return()
  endif()

  # ---------------------------------------------------------------------
  # Re-entrant branch: compute and store all derived fields incrementally
  # ---------------------------------------------------------------------
  _set_package_info("${ARGV0}" ${ARGV1} ${ARGV2} ${ARGV3})
  _set_module_headers("${ARGV0}") # keep this call high
  _set_git_repo("${ARGV0}")
  _set_check_module("${ARGV0}" "${ARGV1}" "${ARGV2}")
  _set_dist_directory("${ARGV0}")
  _set_metadata_file("${ARGV0}")
  _set_project_description("${ARGV0}")
  _set_source_info("${ARGV0}")
  _propagate_module("${ARGV0}")
endfunction()
