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

# set -uo pipefail

# Exit on unhandled error with full context
on_error() {
    local exit_code=$?
    local line_no=$1
    log "❌ Error on line $line_no. Exit code: $exit_code"
    exit "$exit_code"
}

# ------------------------------------------------------------------------------
# Globals & Configuration
# ------------------------------------------------------------------------------

USE_LOCAL=false
FRESH_INSTALL=false

DEVTOOLS_LOGS="./logs"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
LOG_FILE="${DEVTOOLS_LOGS}/asdf-install-${TIMESTAMP}.log"
ROOT_DIR="$(pwd)"

ASDF_VERSION="v0.16.7"
TASKFILE_VERSION="latest"

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
    export TASKFILE_HOME_DIR="/usr/local/bin"
fi

# ------------------------------------------------------------------------------
# Logging
# ------------------------------------------------------------------------------

log() {
    printf "%s 🔹 %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

ensure_log_dir() {
    mkdir --parents "$(dirname "$LOG_FILE")"
    log "📁 Logs will be written to $LOG_FILE"
}

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
    local command_name=$2

    log "🔧 Starting install of asdf plugin: $plugin_name"

    # Confirm which asdf is being used
    local asdf_path
    asdf_path="$(command -v asdf || true)"
    log "🔍 Using asdf at: ${asdf_path:-not found}"
    if [[ "$USE_LOCAL" == true && "$asdf_path" != "$ASDF_DIR/bin/asdf" ]]; then
        log "⚠️  WARNING: Expected asdf from $ASDF_DIR/bin/asdf but found: $asdf_path"
    fi

    # Check and add plugin
    if ! asdf plugin list | grep -q "^${plugin_name}$"; then
        log "📥 Adding plugin: $plugin_name"
        if ! asdf plugin add "$plugin_name"; then
            log "❌ Failed to add plugin: $plugin_name"
            return 1
        fi
    else
        log "🔁 Plugin already exists: $plugin_name"
    fi

    # Install version(s) from .tool-versions
    log "📦 Installing $plugin_name version(s)..."
    if ! asdf install "$plugin_name"; then
        log "❌ Failed to install plugin versions for: $plugin_name"
        return 1
    fi

    # Reshim to generate shims
    if asdf reshim "$plugin_name"; then
        log "🔄 Reshimmed plugin: $plugin_name"
    else
        log "⚠️ Failed to reshim plugin: $plugin_name"
    fi

    # Confirm install
    verify_installation "$command_name" "$plugin_name"
    log "✅ Plugin installed: $plugin_name"
}

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
    local tools
    tools=$(find . -type f -name ".tool-versions" -not -path "*/.*/*" || true)
    local plugin_set=()

    while IFS= read -r file; do
        while IFS= read -r line; do
            [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
            plugin_set+=("$(awk '{print $1}' <<<"$line")")
        done <"$file"
    done <<<"$tools"

    printf "%s\n" "${plugin_set[@]}" | sort -u
}

install_asdf_plugins() {
    log "🔍 Using asdf binary at: $(command -v asdf || echo 'not found') to install asdf plugins..."

    local plugins
    mapfile -t plugins < <(gather_plugins_from_tool_versions)
    sort_plugins_by_known_plugins plugins

    for plugin in "${plugins[@]}"; do
        local cmd="${KNOWN_PLUGINS[$plugin]:-$plugin}"
        install_asdf_plugin "$plugin" "$cmd"
    done
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
    # trap 'on_error $LINENO' ERR
    ensure_log_dir
    detect_os_arch

    if is_debian; then
        log "🧠 Detected Debian-based system"
        ensure_python_build_deps
    else
        log "🚫 Not a Debian-based system — skipping system package setup"
    fi

    install_asdf
    install_asdf_plugins
    install_taskfile
    log "🎉 Environment setup complete!"
}

main "$@"
