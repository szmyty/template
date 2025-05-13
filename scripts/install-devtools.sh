#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# install-devtools.sh
#
# A universal installer for setting up ASDF + Taskfile dev environments.
# Supports --local for .cache/ isolation and --fresh to clear cache before setup.
#
# Usage:
#   ./install-devtools.sh
#   ./install-devtools.sh --local
#   ./install-devtools.sh --local --fresh
# ------------------------------------------------------------------------------

# Utility functions

# Exit on unhandled error with full context
on_error() {
    local exit_code=$?
    local line_no=$1
    log "❌ Error on line $line_no. Exit code: $exit_code"
    exit "$exit_code"
}

# @file Terminal
# @brief Set of useful terminal functions.

# @description Check if script is run in terminal.
#
# @noargs
#
# @exitcode 0  If script is run on terminal.
# @exitcode 1 If script is not run on terminal.
terminal::is_term() {
    [[ -t 1 || -z ${TERM} ]] && return 0 || return 1
}

date::now() {
    declare now
    now="$(date --universal +%s)" || return $?
    printf "%s" "${now}"
}

# --------------------------------------------------------------------
# Color Codes
# --------------------------------------------------------------------

log::__color() {
    case "$1" in
    red) echo '\033[1;31m' ;;
    green) echo '\033[1;32m' ;;
    yellow) echo '\033[1;33m' ;;
    blue) echo '\033[1;34m' ;;
    gray) echo '\033[0;90m' ;;
    none | reset | *) echo '\033[0m' ;;
    esac
}

log::__print() {
    local level="$1"
    local emoji="$2"
    local color="$3"
    local message="$4"

    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local prefix="${emoji} ${level^^}:"

    local log_line_console log_line_file

    if terminal::is_term; then
        log_line_console=$(printf "%s %b%-12s%b %s" "$timestamp" "$(log::__color "$color")" "$prefix" "$(log::__color reset)" "$message")
    else
        log_line_console=$(printf "%s %-12s %s" "$timestamp" "$prefix" "$message")
    fi

    log_line_file=$(printf "%s %-12s %s" "$timestamp" "$prefix" "$message")

    # Print to console and append to file if defined
    echo -e "$log_line_console" >&2
    [[ -n "${LOG_FILE:-}" ]] && echo "$log_line_file" >>"$LOG_FILE"
}

# --------------------------------------------------------------------
# Public Logging API
# --------------------------------------------------------------------

log::info() { log::__print "info" "🔹" blue "$*"; }
log::warn() { log::__print "warn" "⚠️ " yellow "$*"; }
log::error() { log::__print "error" "❌" red "$*"; }
log::success() { log::__print "success" "✅" green "$*"; }
log::debug() { log::__print "debug" "🐞" gray "$*"; }

log() { log::info "$@"; }

ensure_log_dir() {
    mkdir --parents "$DEVTOOLS_LOGS"
    if [[ ! -d "$DEVTOOLS_LOGS" ]]; then
        log "❌ Failed to create logs directory: $DEVTOOLS_LOGS"
        exit 1
    fi
    log "✅ Logs directory created: $DEVTOOLS_LOGS"
}

# ------------------------------------------------------------------------------
# Globals & Configuration
# ------------------------------------------------------------------------------

USE_LOCAL=false
FRESH_INSTALL=false

DEVTOOLS_LOGS="${DEVTOOLS_LOGS:-./logs}"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"

ensure_log_dir
LOG_FILE="$(cd "$DEVTOOLS_LOGS" && pwd)/asdf-install-${TIMESTAMP}.log"
log "📁 Logs will be written to $LOG_FILE"

ROOT_DIR="$(pwd)"

ASDF_VERSION="v0.16.7"
TASKFILE_VERSION="latest"

declare -A KNOWN_PLUGINS=(
    [nodejs]=node
    [python]=python3
    [poetry]=poetry
    [pnpm]=pnpm
    [ruby]=ruby
    [go]=go
    [java]=java
    [rust]=rustc
)

# ------------------------------------------------------------------------------
# CLI Argument Parsing
# ------------------------------------------------------------------------------

for arg in "$@"; do
    case "$arg" in
    --local) USE_LOCAL=true ;;
    --fresh) FRESH_INSTALL=true ;;
    *) echo "❌ Unknown argument: $arg" && exit 1 ;;
    esac
done

# ------------------------------------------------------------------------------
# Local Directory Setup
# ------------------------------------------------------------------------------

if [[ "$USE_LOCAL" == true ]]; then
    export ASDF_DIR="${ROOT_DIR}/.cache/asdf"
    export ASDF_DATA_DIR="${ASDF_DIR}/data"
    export ASDF_CONFIG_FILE="${ROOT_DIR}/.asdfrc"
    export ASDF_SHIMS_DIR="${ASDF_DATA_DIR}/shims"
    export TASKFILE_HOME_DIR="${ROOT_DIR}/.cache/taskfile"
    export PATH="${ASDF_DIR}/bin:${ASDF_SHIMS_DIR}:${TASKFILE_HOME_DIR}:${PATH}"

    if [[ "$FRESH_INSTALL" == true ]]; then
        echo "🧼 Fresh install requested — deleting .cache/"
        rm -rf "${ROOT_DIR}/.cache"
    fi
else
    if [[ "$FRESH_INSTALL" == true ]]; then
        echo "⚠️  Ignoring --fresh: only valid with --local"
        FRESH_INSTALL=false
    fi

    export ASDF_DIR="${ASDF_DIR:-$HOME/.asdf}"
    export ASDF_DATA_DIR="${ASDF_DATA_DIR:-$ASDF_DIR/data}"
    export ASDF_CONFIG_FILE="${ASDF_CONFIG_FILE:-$ASDF_DIR/.asdfrc}"
    export ASDF_SHIMS_DIR="${ASDF_SHIMS_DIR:-$ASDF_DATA_DIR/shims}"
    export TASKFILE_HOME_DIR="${TASKFILE_HOME_DIR:-/usr/local/bin}"
fi

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

# ------------------------------------------------------------------------------
# Tool Verification
# ------------------------------------------------------------------------------

verify_installation() {
    local cmd=$1
    local name=${2:-$cmd}
    local expected_path=""
    local resolved_cmd=""

    if [[ "$USE_LOCAL" == true ]]; then
        case "$name" in
        asdf) expected_path="${ASDF_DIR}/bin/asdf" ;;
        task) expected_path="${TASKFILE_HOME_DIR}/task" ;;
        *) expected_path="${ASDF_SHIMS_DIR}/${cmd}" ;;
        esac

        if [[ -x "$expected_path" ]]; then
            resolved_cmd="$expected_path"
        else
            log "❌ $name not found in expected local path: $expected_path"
            exit 1
        fi
    else
        resolved_cmd="$(command -v "$cmd" || true)"
        if [[ -z "$resolved_cmd" ]]; then
            log "❌ $name is not installed or not on global PATH."
            exit 1
        fi
    fi

    local version
    version=$("$resolved_cmd" --version 2>/dev/null || "$resolved_cmd" -v 2>/dev/null || echo "Version info not available")
    log "✅ $name is available at $resolved_cmd: $version"
}

# ------------------------------------------------------------------------------
# OS/Arch Detection
# ------------------------------------------------------------------------------

detect_os_arch() {
    OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
    ARCH="$(uname -m)"
    case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    *) log "❌ Unsupported architecture: $ARCH" && exit 1 ;;
    esac
    log "🖥️  OS: $OS, Arch: $ARCH"
}

is_debian() {
    [[ -f /etc/debian_version ]]
}

# ------------------------------------------------------------------------------
# ASDF Installation
# ------------------------------------------------------------------------------

has_asdf_plugin() {
    grep -q "^$1\$" < <(asdf plugin list 2>/dev/null)
}

install_asdf() {
    local binary_path="${ASDF_DIR}/bin/asdf"
    if [[ -x "$binary_path" ]]; then
        log "✅ ASDF already installed at $binary_path"
        return
    fi

    log "📥 Downloading asdf $ASDF_VERSION..."
    curl --fail --silent --show-error --location \
        "https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/asdf-${ASDF_VERSION}-${OS}-${ARCH}.tar.gz" \
        --output asdf.tar.gz

    tar -xzf asdf.tar.gz
    mkdir --parents "$(dirname "$binary_path")"
    chmod +x asdf
    mv asdf "$binary_path"
    rm -f asdf.tar.gz

    log "✅ ASDF installed to $binary_path"
}

# ------------------------------------------------------------------------------
# Plugin Installation
# ------------------------------------------------------------------------------
install_asdf_plugin() {
    local plugin_name=$1

    if ! has_asdf_plugin "$plugin_name"; then
        log "📥 Adding plugin: $plugin_name"
        # if ! asdf plugin add "$plugin_name"; then
        #     log "❌ Failed to add plugin: $plugin_name"
        #     return 1
        # fi
        log "✅ Plugin added: $plugin_name"
    else
        log "🔁 Plugin already exists: $plugin_name"
    fi
}

install_asdf_versions() {
    log "📦 Installing tool versions from all .tool-versions files..."

    local tool_files
    mapfile -t tool_files < <(find . -type f -name ".tool-versions" -not -path "*/.*/*")

    for file in "${tool_files[@]}"; do
        local dir
        dir="$(dirname "$file")"
        log "📁 Installing in: $dir"

        pushd "$dir" >/dev/null
        if asdf install; then
            log "✅ Installed all versions from: $file"
            asdf current || log "⚠️ Could not show versions for: $file"
        else
            log "❌ Failed to install tools in: $file"
        fi
        popd >/dev/null
    done
}

sort_plugins_by_known_plugins() {
    local -n input_plugins=$1
    local -a sorted_plugins=()

    # First: install all plugins from KNOWN_PLUGINS in order of declaration
    for plugin in "${!KNOWN_PLUGINS[@]}"; do
        for i in "${!input_plugins[@]}"; do
            if [[ "${input_plugins[$i]}" == "$plugin" ]]; then
                sorted_plugins+=("${input_plugins[$i]}")
                unset 'input_plugins[i]'
            fi
        done
    done

    # Then: install remaining unknown plugins (alphabetically)
    for plugin in "${input_plugins[@]}"; do
        sorted_plugins+=("$plugin")
    done

    input_plugins=("${sorted_plugins[@]}")
}

gather_plugins_from_tool_versions() {
    log "🔍 Searching for .tool-versions files..."

    local tools
    tools=$(find . -type f -name ".tool-versions" -not -path "*/.*/*" || true)

    local plugin_set=()

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        log "📄 Found .tool-versions file: $file"

        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

            local plugin
            plugin=$(awk '{print $1}' <<<"$line")
            local version
            version=$(awk '{print $2}' <<<"$line")

            plugin_set+=("$plugin")

            log "   🔧 Plugin detected: $plugin (version: $version)"
        done <"$file"
    done <<<"$tools"

    local deduped=()
    local seen=()

    for plugin in "${plugin_set[@]}"; do
        if [[ ! " ${seen[*]} " =~ " $plugin " ]]; then
            deduped+=("$plugin")
            seen+=("$plugin")
        fi
    done

    printf "%s\n" "${deduped[@]}"
}

install_asdf_plugins() {
    log "🔍 Gathering plugins from .tool-versions files..."

    local tool_files
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        mapfile -t tool_files < <(git ls-files --cached --others --exclude-standard '*.tool-versions')
    else
        mapfile -t tool_files < <(find . -type f -name ".tool-versions" -not -path "*/.*/*")
    fi

    if [[ ${#tool_files[@]} -eq 0 ]]; then
        log "⚠️ No .tool-versions files found."
        return
    fi
    log "📁 Found ${#tool_files[@]} .tool-versions files."

    local all_plugins=()
    local seen=()

    for file in "${tool_files[@]}"; do
        log "📄 Processing .tool-versions file: $file"

        local dir
        dir="$(dirname "$file")"

        pushd "$dir" >/dev/null
        log "📍 Moved into: $(pwd) to install dependencies from $file"
        popd >/dev/null
    done

    # for file in "${tool_files[@]}"; do
    #     log "📄 Processing .tool-versions file: $file"
    #     # while IFS= read -r line || [[ -n "$line" ]]; do
    #     #     [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue

    #     #     local plugin
    #     #     plugin=$(awk '{print $1}' <<<"$line")

    #     #     if [[ ! " ${seen[*]} " =~ " $plugin " ]]; then
    #     #         seen+=("$plugin")
    #     #         all_plugins+=("$plugin")
    #     #     fi
    #     # done <"$file"
    # done

    # # Sort plugins by known importance first
    # sort_plugins_by_known_plugins all_plugins

    # for plugin in "${all_plugins[@]}"; do
    #     install_asdf_plugin "$plugin"
    # done
}

# ------------------------------------------------------------------------------
# Taskfile Installation
# ------------------------------------------------------------------------------

install_taskfile() {
    local binary_path="${TASKFILE_HOME_DIR}/task"

    if [[ -x "$binary_path" ]]; then
        log "✅ Taskfile already installed at $binary_path"
        return
    fi

    log "📥 Installing Taskfile..."
    mkdir -p "$TASKFILE_HOME_DIR"
    curl --fail --silent --show-error https://taskfile.dev/install.sh | sh -s -- -d -b "$TASKFILE_HOME_DIR"

    verify_installation "task"
}

ensure_python_build_deps() {
    log "🔧 Checking for required Python build dependencies..."

    # Required packages
    local packages=(
        build-essential
        libbz2-dev
        libncursesw5-dev
        libreadline-dev
        libffi-dev
        libsqlite3-dev
        liblzma-dev
        zlib1g-dev
        tk-dev
        libssl-dev
        curl
        git
        ca-certificates
        xz-utils
    )

    # Determine which ones are missing
    local missing=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    # Install only if needed
    if [[ ${#missing[@]} -gt 0 ]]; then
        log "📦 Installing missing packages: ${missing[*]}"
        sudo apt-get update && sudo apt-get install -y "${missing[@]}"
    else
        log "✅ All required packages already installed."
    fi
}

# ------------------------------------------------------------------------------
# Main
# ------------------------------------------------------------------------------

main() {
    detect_os_arch

    if is_debian; then
        log "🧠 Detected Debian-based system"
        ensure_python_build_deps
    else
        log "🚫 Not a Debian-based system — skipping system package setup"
    fi

    if terminal::is_term; then
        log "🖥️ Running in terminal"
    else
        log "🚫 Not running in terminal — some features may be limited"
    fi

    install_asdf
    install_asdf_plugins
    # install_asdf_versions
    # install_taskfile
    log "🎉 Environment setup complete!"
}

main "$@"
