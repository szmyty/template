#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined variables, or failed pipes

# Set default asdf version if not set
: "${ASDF_VERSION:=v0.16.4}"
: "${DEVTOOLS_LOGS:=logs}"

LOG_FILE="${DEVTOOLS_LOGS}/asdf-install-$(date '+%Y%m%d_%H%M%S').log"

declare -A PLUGINS=(
  [nodejs]=node
  [pnpm]=pnpm
  [python]=python3
  [poetry]=poetry
)

log() {
  printf "%s 🔹 %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$LOG_FILE"
}

ensure_log_dir() {
  local log_dir
  log_dir=$(dirname "$LOG_FILE")

  if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir"
    log "📁 Created logs directory: $log_dir"
  fi
}

detect_os_arch() {
  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"  # linux or darwin
  ARCH="$(uname -m)"

  case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64 | arm64) ARCH="arm64" ;;
    *)
      log "❌ Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  log "🖥️ Detected OS: $OS, Architecture: $ARCH"
}

install_asdf() {
  if command -v asdf &>/dev/null; then
    log "✅ asdf is already installed: $(asdf --version)"
    return
  fi

  local asdf_tarball="asdf-${ASDF_VERSION}-${OS}-${ARCH}.tar.gz"
  local asdf_url="https://github.com/asdf-vm/asdf/releases/download/${ASDF_VERSION}/${asdf_tarball}"

  log "📥 Downloading asdf ${ASDF_VERSION} for ${OS}/${ARCH}..."
  curl --fail --silent --show-error --location "$asdf_url" --output asdf.tar.gz

  log "📦 Extracting asdf..."
  tar -xzf asdf.tar.gz

  if [[ ! -f "asdf" ]]; then
    log "❌ asdf binary not found in extracted files!"
    exit 1
  fi

  log "🚀 Installing asdf in ${ASDF_DIR:-/usr/local}/bin..."
  chmod +x asdf
  mkdir --parents "${ASDF_DIR:-/usr/local}/bin"
  mv asdf "${ASDF_DIR:-/usr/local}/bin/asdf"

  rm -f asdf.tar.gz
  log "✅ asdf installed successfully!"
}

verify_installation() {
  local cmd=$1
  local name=${2:-$cmd}

  if command -v "${cmd}" &>/dev/null; then
    local version
    version=$(
      "${cmd}" --version 2>/dev/null ||
      "${cmd}" -v 2>/dev/null ||
      "${cmd}" version 2>/dev/null ||
      echo "Version info not available"
    )
    log "✅ ${name} is available: ${version}"
  else
    log "❌ ${name} is not installed or not on PATH."
    exit 1
  fi
}

install_asdf_plugin() {
  local plugin_name=$1
  local command_name=$2

  log "🔧 Installing ${plugin_name} via asdf..."

  if ! command -v asdf &>/dev/null; then
    log "❌ asdf is not installed. Please install it first."
    exit 1
  fi

  if ! asdf plugin list | grep -q "^${plugin_name}$"; then
    log "📥 Adding asdf plugin: ${plugin_name}"
    asdf plugin add "${plugin_name}"
  fi

  log "📦 Installing ${plugin_name} (version from .tool-versions)..."
  asdf install "${plugin_name}"

  verify_installation "${command_name}" "${plugin_name}"
}

install_asdf_plugins() {
  for plugin in "${!PLUGINS[@]}"; do
    install_asdf_plugin "$plugin" "${PLUGINS[$plugin]}"
  done
}

main() {
  trap 'log "❌ An error occurred during execution."' ERR
  ensure_log_dir
  detect_os_arch
  install_asdf
  install_asdf_plugins "${REQUIRED_PLUGINS[@]}"
  log "✅ All requested plugins installed and verified."
}

main "$@"
