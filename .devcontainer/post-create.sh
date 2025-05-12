#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# post-create.sh
#
# Used as a DevContainer post-creation script.
# This script performs Docker and SSH setup, including:
#   - Setting up SSH directory and secure permissions for vscode user
#   - Ensuring Docker group exists and adding vscode user to it
#   - Creating Docker daemon proxy config (if PROXY_URL is defined)
#   - Restarting the Docker daemon with custom options
#   - Merging proxy config into Docker CLI config (~/.docker/config.json)
#
# IMPORTANT: This script must be run as root.
# ------------------------------------------------------------------------------

set -euo pipefail
trap 'on_error $LINENO' ERR

# ------------------------------------------------------------------------------
# Ensure the script is run as root
# ------------------------------------------------------------------------------

if [[ "$EUID" -ne 0 ]]; then
    echo "❌ This script must be run as root. Use 'sudo' or run as root user."
    exit 1
fi

# ------------------------------------------------------------------------------
# Logging Setup
# ------------------------------------------------------------------------------

LOG_FILE="/var/log/devcontainer-post-create.log"
mkdir --parents "$(dirname "$LOG_FILE")"

log() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf "%s 🔹 %s\n" "$timestamp" "$1" | tee --append "$LOG_FILE"
}

on_error() {
    local exit_code=$?
    log "❌ Error on line $1. Exit code: $exit_code"
    exit "$exit_code"
}

# ------------------------------------------------------------------------------
# Configuration Variables
# ------------------------------------------------------------------------------

DOCKER_GROUP="docker"
USER_TO_MODIFY="vscode"

DAEMON_JSON="/etc/docker/daemon.json"
DOCKER_CONFIG="/home/${USER_TO_MODIFY}/.docker/config.json"
DOCKER_LOG="/var/log/dockerd.log"
DOCKER_SOCK="/var/run/docker.sock"

# Environment-supplied values (optional)
PROXY_URL="${PROXY_URL:-}" # Leave empty to disable proxy config
NO_PROXY_LIST="${NO_PROXY_LIST:-localhost,127.0.0.1}"
DNS_SERVERS='["8.8.8.8", "1.1.1.1"]'

# ------------------------------------------------------------------------------
# Step 1: SSH Directory Setup
# ------------------------------------------------------------------------------

take_ssh_ownership() {
    local ssh_dir="/home/${USER_TO_MODIFY}/.ssh"

    log "🔐 Ensuring secure SSH setup for user: ${USER_TO_MODIFY}..."

    # Create directory and known_hosts if they don't exist
    mkdir --parents "$ssh_dir"
    touch "$ssh_dir/known_hosts"

    # Apply secure ownership and permissions
    chown --recursive "${USER_TO_MODIFY}:${USER_TO_MODIFY}" "$ssh_dir"
    chmod 700 "$ssh_dir"
    find "$ssh_dir" -type f -exec chmod 600 {} \;

    log "✅ SSH directory is ready: $ssh_dir"
}

# ------------------------------------------------------------------------------
# Step 2: Add User to Docker Group
# ------------------------------------------------------------------------------

setup_user_permissions() {
    log "👤 Ensuring user '${USER_TO_MODIFY}' is in the '${DOCKER_GROUP}' group..."

    # Create docker group if it doesn't already exist
    if ! getent group "$DOCKER_GROUP" >/dev/null; then
        groupadd "$DOCKER_GROUP"
        log "📦 Created group: $DOCKER_GROUP"
    fi

    # Add user to group using long-form flags
    usermod --append --groups "$DOCKER_GROUP" "$USER_TO_MODIFY"

    # Adjust socket ownership to match docker group
    chgrp "$DOCKER_GROUP" "$DOCKER_SOCK"

    log "🔄 Group setup complete — restarting group context..."
    exec newgrp "$DOCKER_GROUP"
}

# ------------------------------------------------------------------------------
# Step 3: Create /etc/docker/daemon.json (if proxy is defined)
# ------------------------------------------------------------------------------

setup_docker_daemon_config() {
    if [[ -z "$PROXY_URL" ]]; then
        log "⚠️  No PROXY_URL provided — skipping Docker daemon proxy config"
        return
    fi

    if [[ ! -f "$DAEMON_JSON" ]]; then
        log "⚙️  Creating Docker daemon config at $DAEMON_JSON..."
        mkdir --parents "$(dirname "$DAEMON_JSON")"

        tee "$DAEMON_JSON" >/dev/null <<EOF
{
  "dns": $DNS_SERVERS,
  "proxies": {
    "default": {
      "httpProxy": "$PROXY_URL",
      "httpsProxy": "$PROXY_URL",
      "noProxy": "$NO_PROXY_LIST"
    }
  }
}
EOF
        log "✅ Created daemon.json with proxy and DNS config"
    else
        log "ℹ️  $DAEMON_JSON already exists — skipping"
    fi
}

# ------------------------------------------------------------------------------
# Step 4: Restart Docker Daemon (non-blocking)
# ------------------------------------------------------------------------------

restart_dockerd() {
    log "🔁 Restarting Docker daemon using built-in init script..."

    # Gracefully kill existing Docker and containerd processes if they exist
    pkill --exact dockerd || true
    pkill --exact containerd || true

    # Re-run the Docker-in-Docker init script provided by the base image
    if [[ -x /usr/local/share/docker-init.sh ]]; then
        bash /usr/local/share/docker-init.sh
        log "✅ Docker daemon restarted via docker-init.sh"
    else
        log "❌ docker-init.sh not found at /usr/local/share/docker-init.sh"
        exit 1
    fi

    # Validate Docker is running
    if docker info >/dev/null 2>&1; then
        log "✅ Docker daemon is healthy and responsive"
    else
        log "⚠️ docker info failed — Docker may not have fully started yet"
    fi
}

# ------------------------------------------------------------------------------
# Step 5: Configure Docker CLI Proxy (~/.docker/config.json)
# ------------------------------------------------------------------------------

setup_docker_cli_config() {
    if [[ -z "$PROXY_URL" ]]; then
        log "⚠️  No PROXY_URL provided — skipping Docker CLI proxy config"
        return
    fi

    log "🔧 Updating Docker CLI proxy config for $USER_TO_MODIFY"

    mkdir --parents "$(dirname "$DOCKER_CONFIG")"
    [[ ! -f "$DOCKER_CONFIG" ]] && echo '{}' >"$DOCKER_CONFIG"

    # Update JSON proxy fields
    UPDATED_JSON=$(jq \
        --arg http "$PROXY_URL" \
        --arg https "$PROXY_URL" \
        --arg no "$NO_PROXY_LIST" \
        '.proxies.default.httpProxy //= $http |
         .proxies.default.httpsProxy //= $https |
         .proxies.default.noProxy //= $no' \
        "$DOCKER_CONFIG")

    echo "$UPDATED_JSON" >"$DOCKER_CONFIG"
    chown "${USER_TO_MODIFY}:${USER_TO_MODIFY}" "$DOCKER_CONFIG"

    log "✅ Docker CLI config updated with proxy"
}

# ------------------------------------------------------------------------------
# Main Execution Entry Point
# ------------------------------------------------------------------------------

main() {
    log "🚀 Starting DevContainer post-create setup..."

    take_ssh_ownership
    setup_user_permissions
    setup_docker_daemon_config
    restart_dockerd
    setup_docker_cli_config

    log "🎉 post-create.sh completed successfully!"
}

main "$@"
