#!/usr/bin/env bash
# update_env.sh — Slim library environment scaffolder
# Usage: update_env.sh [OPTIONS]
# Run with --help for full usage.

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
REPO="greergan/SlimLibraryPackager"
BRANCH="master"
RAW_BASE="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
API_BASE="https://api.github.com/repos/${REPO}/git/trees/${BRANCH}?recursive=1"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# Defaults (overridden by flags)
# ---------------------------------------------------------------------------
DEST_DIR="$(pwd)"
OVERWRITE_MODE="ask"       # ask | all | none
SKIP_GIT=false
SKIP_HEADER=false
SKIP_SRC=false
SKIP_CMAKE=false
SKIP_PACKAGES=false
DRY_RUN=false
VERBOSE=false
REMOTE_URL=""              # pre-supply remote URL instead of prompting

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
log_info()    { echo -e "  ${GREEN}${1}:${NC} ${2}"; }
log_skip()    { echo -e "  ${RED}Skipped:${NC} ${1}"; }
log_warn()    { echo -e "  ${YELLOW}Warning:${NC} ${1}"; }
log_error()   { echo -e "${RED}Error:${NC} ${1}" >&2; }
log_verbose() { [[ "${VERBOSE}" == "true" ]] && echo -e "  ${CYAN}[verbose]${NC} ${1}" || true; }

die() { log_error "$1"; exit 1; }

# ---------------------------------------------------------------------------
# Usage
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
${BOLD}Usage:${NC} $(basename "$0") [OPTIONS]

Scaffold or update a Slim library environment in the current directory
(or a directory specified with --dir).

${BOLD}Options:${NC}
  -d, --dir <path>          Target directory (default: current directory)
  -r, --remote <url>        Git remote URL (skips interactive prompt)
  -y, --yes                 Overwrite all existing files without prompting
  -n, --no-overwrite        Skip all existing files without prompting
  --skip-git                Do not initialise or push a git repository
  --skip-header             Do not create the include/ header file
  --skip-src                Do not create src/ translation units
  --skip-cmake              Do not download cmake/ files
  --skip-packages           Do not process required_packages
  --dry-run                 Print what would be done; do not write any files
  -v, --verbose             Print extra diagnostic information
  -h, --help                Show this help and exit

${BOLD}Directory naming convention:${NC}
  The target directory must begin with 'Slim' followed by 1–3 CamelCase words
  that define the include path.  Examples:
    SlimCommon              → shared infrastructure (no header generated)
    SlimLogger              → include/slim/SlimLogger.hpp
    SlimNetHttp             → include/slim/net/http.h
    SlimNetHttpClient       → include/slim/net/http/client.h
EOF
    exit 0
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--dir)          DEST_DIR="$2"; shift 2 ;;
            -r|--remote)       REMOTE_URL="$2"; shift 2 ;;
            -y|--yes)          OVERWRITE_MODE="all"; shift ;;
            -n|--no-overwrite) OVERWRITE_MODE="none"; shift ;;
            --skip-git)        SKIP_GIT=true; shift ;;
            --skip-header)     SKIP_HEADER=true; shift ;;
            --skip-src)        SKIP_SRC=true; shift ;;
            --skip-cmake)      SKIP_CMAKE=true; shift ;;
            --skip-packages)   SKIP_PACKAGES=true; shift ;;
            --dry-run)         DRY_RUN=true; shift ;;
            -v|--verbose)      VERBOSE=true; shift ;;
            -h|--help)         usage ;;
            *) die "Unknown option: $1  (try --help)" ;;
        esac
    done

    # Resolve to absolute path
    DEST_DIR="$(cd "${DEST_DIR}" 2>/dev/null && pwd)" \
        || die "Directory '${DEST_DIR}' does not exist."
}

# ---------------------------------------------------------------------------
# Directory name → naming components
# ---------------------------------------------------------------------------
derive_naming() {
    DIR_NAME="$(basename "${DEST_DIR}")"

    [[ "${DIR_NAME}" =~ ^Slim ]] \
        || die "Directory '${DIR_NAME}' does not begin with 'Slim'. Aborting."

    AFTER_SLIM="${DIR_NAME#Slim}"
    # Split CamelCase → array of words
    readarray -t WORDS < <(echo "${AFTER_SLIM}" | sed 's/\([A-Z]\)/ \1/g' | xargs -n1)
    WORD_COUNT=${#WORDS[@]}

    case "${WORD_COUNT}" in
        0)
            # bare "Slim" — treat like SlimCommon
            IS_COMMON=true
            HEADER_DIR="" HEADER_FILE="" INCLUDE_FILE="" INCLUDE_PATH=""
            ;;
        1)
            IS_COMMON=false
            if [[ "${DIR_NAME}" == "SlimCommon" ]]; then
                IS_COMMON=true
                HEADER_DIR="" HEADER_FILE="" INCLUDE_FILE="" INCLUDE_PATH=""
            else
                HEADER_DIR="${DEST_DIR}/include/slim"
                HEADER_FILE="${DIR_NAME}.hpp.in"
                INCLUDE_FILE="${DIR_NAME}.hpp"
                INCLUDE_PATH="slim/${INCLUDE_FILE}"
            fi
            ;;
        2)
            IS_COMMON=false
            local sub; sub="$(echo "${WORDS[0]}" | tr '[:upper:]' '[:lower:]')"
            local base; base="$(echo "${WORDS[1]}" | tr '[:upper:]' '[:lower:]')"
            HEADER_DIR="${DEST_DIR}/include/slim/${sub}"
            HEADER_FILE="${base}.h.in"
            INCLUDE_FILE="${base}.h"
            INCLUDE_PATH="slim/${sub}/${INCLUDE_FILE}"
            ;;
        3)
            IS_COMMON=false
            local sub; sub="$(echo "${WORDS[0]}" | tr '[:upper:]' '[:lower:]')"
            local sub2; sub2="$(echo "${WORDS[1]}" | tr '[:upper:]' '[:lower:]')"
            local base; base="$(echo "${WORDS[2]}" | tr '[:upper:]' '[:lower:]')"
            HEADER_DIR="${DEST_DIR}/include/slim/${sub}/${sub2}"
            HEADER_FILE="${base}.h.in"
            INCLUDE_FILE="${base}.h"
            INCLUDE_PATH="slim/${sub}/${sub2}/${INCLUDE_FILE}"
            ;;
        *)
            die "Directory '${DIR_NAME}' has an unsupported format. Expected 'Slim' + 1–3 words."
            ;;
    esac

    # .pc template selection
    if [[ "${IS_COMMON}" == "false" && "${WORD_COUNT}" -eq 1 ]]; then
        PC_FILE="slim_header_lib.pc.in"
    else
        PC_FILE="slim_common_lib.pc.in"
    fi

    # Header guard
    local all_words=("Slim" "${WORDS[@]}")
    local ext="${INCLUDE_FILE##*.}"
    HEADER_GUARD=""
    for w in "${all_words[@]}"; do
        [[ -n "${HEADER_GUARD}" ]] && HEADER_GUARD+="__"
        HEADER_GUARD+="$(echo "${w}" | tr '[:lower:]' '[:upper:]')"
    done
    HEADER_GUARD+="__$(echo "${ext}" | tr '[:lower:]' '[:upper:]')"

    log_verbose "DIR_NAME=${DIR_NAME}  WORD_COUNT=${WORD_COUNT}  IS_COMMON=${IS_COMMON}"
    log_verbose "PC_FILE=${PC_FILE}  HEADER_GUARD=${HEADER_GUARD}"
}

# ---------------------------------------------------------------------------
# File download helpers
# ---------------------------------------------------------------------------

# Decide whether to overwrite an existing file; returns 0=proceed, 1=skip
should_overwrite() {
    local rel_path="$1"
    case "${OVERWRITE_MODE}" in
        all)  return 0 ;;
        none) log_skip "${rel_path}"; return 1 ;;
        ask)
            echo -en "${YELLOW}File '${rel_path}' already exists. Overwrite? [y/N]: ${NC}"
            local ans; read -r ans < /dev/tty
            [[ "${ans}" =~ ^[Yy]$ ]] && return 0
            log_skip "${rel_path}"; return 1
            ;;
    esac
}

# bulk ask at start — sets OVERWRITE_MODE to all/none if user picks bulk action
bulk_overwrite_prompt() {
    local -a existing=()
    for f in CMakeLists.txt Makefile LICENSE "${PC_FILE}"; do
        [[ -e "${DEST_DIR}/${f}" ]] && existing+=("${f}")
    done
    [[ ${#existing[@]} -eq 0 ]] && return
    [[ "${OVERWRITE_MODE}" != "ask" ]] && return   # already set by flag

    echo -en "${YELLOW}Some files already exist. Skip all existing files? [y/N]: ${NC}"
    local ans; read -r ans < /dev/tty
    if [[ "${ans}" =~ ^[Yy]$ ]]; then
        OVERWRITE_MODE="none"
    else
        OVERWRITE_MODE="all"
    fi
    echo ""
}

download_file() {
    local relative_path="$1"
    local dest="${DEST_DIR}/${relative_path}"
    local dest_dir; dest_dir="$(dirname "${dest}")"

    if [[ -e "${dest}" ]]; then
        should_overwrite "${relative_path}" || return 0
    fi

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_info "Would download" "${relative_path}"; return 0
    fi

    mkdir -p "${dest_dir}"
    if curl -fsSL "${RAW_BASE}/${relative_path}" -o "${dest}"; then
        log_info "Downloaded" "${relative_path}"
    else
        log_warn "Failed to download: ${relative_path}"
    fi
}

# ---------------------------------------------------------------------------
# cmake/ discovery and download
# ---------------------------------------------------------------------------
download_cmake_files() {
    [[ "${SKIP_CMAKE}" == "true" ]] && { log_verbose "Skipping cmake/ (--skip-cmake)"; return; }

    echo ""
    echo "Fetching cmake/ directory listing from GitHub..."

    local api_response
    api_response="$(curl -fsSL "${API_BASE}")" \
        || die "Failed to reach GitHub API."

    local cmake_files
    cmake_files="$(python3 -c "
import sys, json
data = json.load(sys.stdin)
for item in data.get('tree', []):
    if item['path'].startswith('cmake/') and item['type'] == 'blob':
        print(item['path'])
" <<< "${api_response}" 2>/dev/null)"

    if [[ -z "${cmake_files}" ]]; then
        log_warn "No files found under cmake/ in ${REPO}@${BRANCH}."
        return
    fi

    echo ""
    while IFS= read -r f; do
        download_file "${f}"
    done <<< "${cmake_files}"
}

# ---------------------------------------------------------------------------
# required_packages — download + parse
# ---------------------------------------------------------------------------
download_required_packages() {
    [[ "${SKIP_PACKAGES}" == "true" ]] && { log_verbose "Skipping required_packages (--skip-packages)"; return; }

    if [[ ! -e "${DEST_DIR}/required_packages" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would download" "required_packages"
        elif curl -fsSL "${RAW_BASE}/required_packages" -o "${DEST_DIR}/required_packages"; then
            log_info "Downloaded" "required_packages"
        else
            log_warn "Failed to download required_packages"
        fi
    else
        log_skip "required_packages (already exists)"
    fi
}

derive_slim_include() {
    local pkg_name="$1"
    local after="${pkg_name#Slim}"

    [[ -z "${after}" || "${pkg_name}" == "SlimCommon" ]] && return

    local pkg_words
    readarray -t pkg_words < <(echo "${after}" | sed 's/\([A-Z]\)/ \1/g' | xargs -n1)
    local pkg_count=${#pkg_words[@]}

    local inc_path
    case "${pkg_count}" in
        1)
            inc_path="slim/${pkg_name}.hpp"
            ;;
        2)
            local d1; d1="$(echo "${pkg_words[0]}" | tr '[:upper:]' '[:lower:]')"
            local b;  b="$(echo "${pkg_words[1]}"  | tr '[:upper:]' '[:lower:]')"
            inc_path="slim/${d1}/${b}.h"
            ;;
        3)
            local d1; d1="$(echo "${pkg_words[0]}" | tr '[:upper:]' '[:lower:]')"
            local d2; d2="$(echo "${pkg_words[1]}" | tr '[:upper:]' '[:lower:]')"
            local b;  b="$(echo "${pkg_words[2]}"  | tr '[:upper:]' '[:lower:]')"
            inc_path="slim/${d1}/${d2}/${b}.h"
            ;;
        *) return ;;
    esac

    echo "#include <${inc_path}>"
}

# Populates SLIM_INCLUDES and OTHER_INCLUDES arrays (globals)
parse_required_packages() {
    SLIM_INCLUDES=()
    OTHER_INCLUDES=()

    [[ "${SKIP_PACKAGES}" == "true" ]] && return
    [[ ! -f "${DEST_DIR}/required_packages" ]] && return

    echo ""
    echo "Processing required_packages..."
    echo ""

    while IFS= read -r line || [[ -n "${line}" ]]; do
        [[ -z "${line}" || "${line}" == \#* ]] && continue
        local pkg_name="${line%% *}"
        [[ -z "${pkg_name}" ]] && continue

        if [[ "${pkg_name}" == Slim* ]]; then
            local inc; inc="$(derive_slim_include "${pkg_name}")"
            if [[ -n "${inc}" ]]; then
                SLIM_INCLUDES+=("${inc}")
                log_info "Resolved" "${pkg_name} → ${inc}"
            else
                log_skip "${pkg_name} (no include derived)"
            fi
        else
            log_skip "${pkg_name} (non-Slim package)"
        fi
    done < "${DEST_DIR}/required_packages"

    IFS=$'\n' SLIM_INCLUDES=($(sort <<< "${SLIM_INCLUDES[*]}")); unset IFS
    IFS=$'\n' OTHER_INCLUDES=($(sort <<< "${OTHER_INCLUDES[*]}")); unset IFS
}

# ---------------------------------------------------------------------------
# Include injection
# ---------------------------------------------------------------------------
inject_includes() {
    local filepath="$1"
    local mode="$2"   # new | existing

    local -a all_slim=()
    local -a all_other=()

    classify_include() {
        local inc="$1"
        if [[ "${inc}" =~ ^#include\ \<slim/ ]]; then
            all_slim+=("${inc}")
        else
            all_other+=("${inc}")
        fi
    }

    for inc in "${OTHER_INCLUDES[@]+"${OTHER_INCLUDES[@]}"}"; do classify_include "${inc}"; done
    for inc in "${SLIM_INCLUDES[@]+"${SLIM_INCLUDES[@]}"}";  do classify_include "${inc}"; done

    if [[ "${mode}" == "existing" ]]; then
        while IFS= read -r inc_line; do
            classify_include "${inc_line}"
        done < <(grep '^#include ' "${filepath}" || true)
    fi

    IFS=$'\n' all_slim=($(  printf '%s\n' "${all_slim[@]+"${all_slim[@]}"}"  | sort -u)); unset IFS
    IFS=$'\n' all_other=($( printf '%s\n' "${all_other[@]+"${all_other[@]}"}" | sort -u)); unset IFS

    local merged_block=""
    for inc in "${all_other[@]+"${all_other[@]}"}"; do merged_block+="${inc}"$'\n'; done
    if [[ ${#all_slim[@]} -gt 0 ]]; then
        [[ -n "${merged_block}" ]] && merged_block+=$'\n'
        for inc in "${all_slim[@]}"; do merged_block+="${inc}"$'\n'; done
    fi

    [[ -z "${merged_block}" ]] && return

    if [[ "${DRY_RUN}" == "true" ]]; then
        log_verbose "Would inject includes into ${filepath##*/}"
        return
    fi

    if [[ "${mode}" == "new" ]]; then
        local body; body="$(cat "${filepath}")"
        printf '%s\n%s' "${merged_block}" "${body}" > "${filepath}"
    else
        local remainder
        remainder="$(grep -v '^#include ' "${filepath}" | sed '/./,$!d')"
        printf '%s\n%s\n' "${merged_block}" "${remainder}" > "${filepath}"
    fi
}

# ---------------------------------------------------------------------------
# Header file creation
# ---------------------------------------------------------------------------
create_header() {
    [[ "${SKIP_HEADER}" == "true" ]] && { log_verbose "Skipping header (--skip-header)"; return; }
    [[ -z "${INCLUDE_PATH:-}" ]] && { log_verbose "No header needed for ${DIR_NAME}"; return; }

    echo ""
    if [[ ! -d "${HEADER_DIR}" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would create dir" "${HEADER_DIR#${DEST_DIR}/}/"
        else
            mkdir -p "${HEADER_DIR}"
            log_info "Created" "${HEADER_DIR#${DEST_DIR}/}/"
        fi
    else
        log_skip "${HEADER_DIR#${DEST_DIR}/}/ (already exists)"
    fi

    local header_path="${HEADER_DIR}/${HEADER_FILE}"
    if [[ ! -e "${header_path}" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would create" "${header_path#${DEST_DIR}/}"
        else
            cat > "${header_path}" <<EOF
#pragma once
#ifndef ${HEADER_GUARD}
#define ${HEADER_GUARD}

#endif // ${HEADER_GUARD}
EOF
            log_info "Created" "${header_path#${DEST_DIR}/}"
        fi
    else
        log_skip "${header_path#${DEST_DIR}/} (already exists)"
    fi
}

# ---------------------------------------------------------------------------
# src/ creation / updating
# ---------------------------------------------------------------------------
create_src() {
    [[ "${SKIP_SRC}" == "true" ]] && { log_verbose "Skipping src/ (--skip-src)"; return; }

    echo ""
    if [[ ! -d "${DEST_DIR}/src" ]]; then
        if [[ "${DRY_RUN}" == "true" ]]; then
            log_info "Would create" "src/"
        else
            mkdir -p "${DEST_DIR}/src"
            log_info "Created" "src/"
        fi
    else
        log_skip "src/ (already exists)"
    fi

    for tu in main.cpp test.cpp; do
        local tu_path="${DEST_DIR}/src/${tu}"
        if [[ ! -e "${tu_path}" ]]; then
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "Would create" "src/${tu}"; continue
            fi
            if [[ "${tu}" == "test.cpp" ]]; then
                printf '\nint main() {\n\n    return 0;\n}\n' > "${tu_path}"
            else
                printf '\n' > "${tu_path}"
            fi
            inject_includes "${tu_path}" "new"
            log_info "Created" "src/${tu}"
        else
            if [[ "${DRY_RUN}" == "true" ]]; then
                log_info "Would update" "src/${tu} (includes)"
            else
                inject_includes "${tu_path}" "existing"
                log_info "Updated" "src/${tu} (includes refreshed)"
            fi
        fi
    done
}

# ---------------------------------------------------------------------------
# Git initialisation
# ---------------------------------------------------------------------------
init_git() {
    [[ "${SKIP_GIT}" == "true" ]] && { log_verbose "Skipping git (--skip-git)"; return; }
    [[ "${DRY_RUN}" == "true" ]] && { log_info "Would init" "git repository"; return; }

    echo ""
    if [[ -d "${DEST_DIR}/.git" ]]; then
        log_skip "git repository (already exists)"; return
    fi

    git -C "${DEST_DIR}" init
    log_info "Initialized" "git repository"

    cat > "${DEST_DIR}/.gitignore" <<EOF
# CMake
CMakeLists.txt.user
CMakeCache.txt
CMakeFiles/
CMakeScripts/
Testing/
Makefile
cmake_install.cmake
install_manifest.txt
compile_commands.json
CTestTestfile.cmake
_deps/
CMakeUserPresets.json
build*/

# IDE
.idea/
.vscode/
.vs/
.cache/
cmake-build-*/

# OS
.DS_Store

# Build artifacts
*.o
*.a
*.so
*.dylib
*.dll
*.deb
*.rpm

# Downloaded files
CMakeLists.txt
Makefile
cmake/
${PC_FILE}
EOF
    log_info "Created" ".gitignore"

    # Remote URL — flag or interactive prompt
    if [[ -z "${REMOTE_URL}" ]]; then
        while true; do
            echo -en "${YELLOW}Enter remote URL: ${NC}"
            read -r REMOTE_URL < /dev/tty
            [[ -n "${REMOTE_URL}" ]] && break
            log_error "Remote URL is required."
        done
    fi

    git -C "${DEST_DIR}" remote add origin "${REMOTE_URL}"
    log_info "Remote added" "${REMOTE_URL}"

    git -C "${DEST_DIR}" add src/ include/ "${PC_FILE}" required_packages .gitignore 2>/dev/null || true
    git -C "${DEST_DIR}" commit -m "Initial commit: scaffold ${DIR_NAME} library environment"
    log_info "Committed" "initial library scaffold"

    git -C "${DEST_DIR}" push -u origin HEAD
    log_info "Pushed" "initial commit to ${REMOTE_URL}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    parse_args "$@"
    derive_naming

    echo ""
    echo "Updating Slim library environment in: ${DEST_DIR}"
    [[ "${DRY_RUN}" == "true" ]] && echo -e "${YELLOW}(dry-run — no files will be written)${NC}"
    echo ""

    bulk_overwrite_prompt

    # Top-level files
    for f in CMakeLists.txt Makefile LICENSE "${PC_FILE}"; do
        download_file "${f}"
    done

    download_required_packages
    parse_required_packages
    download_cmake_files
    create_header
    create_src
    init_git

    echo ""
    echo -e "${GREEN}Done.${NC}"
    echo ""
}

main "$@"
