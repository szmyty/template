#!/usr/bin/env bash
set -euo pipefail

# Constants
DOCKER_GROUP="docker"
USER_TO_MODIFY="vscode"
DAEMON_JSON="/etc/docker/daemon.json"
DOCKER_CONFIG="${HOME}/.docker/config.json"
DOCKER_LOG="/var/log/dockerd.log"
DOCKER_SOCK="/var/run/docker.sock"

PROXY_URL="http://your.proxy:port"
NO_PROXY_LIST="localhost,127.0.0.1"
DNS_SERVERS='["your.corp.dns.server", "8.8.8.8"]'

#######################################
# Ensure SSH directory exists and fix permissions for the vscode user
take_ssh_ownership() {
  local ssh_dir="/home/vscode/.ssh"

  echo "[INFO] Ensuring SSH directory exists and has secure permissions..."

  # Create the directory if it doesn't exist
  if [ ! -d "$ssh_dir" ]; then
    echo "[INFO] Creating $ssh_dir"
    sudo mkdir -p "$ssh_dir"
    sudo touch "$ssh_dir/known_hosts"  # Optional: pre-create known_hosts
  fi

  # Fix ownership and permissions
  sudo chown -R vscode:vscode "$ssh_dir"
  sudo chmod 700 "$ssh_dir"
  find "$ssh_dir" -type f -exec sudo chmod 600 {} \;

  echo "[INFO] SSH ownership and permissions configured at $ssh_dir"
}

#######################################
# Ensure Docker group exists and user is added
setup_user_permissions() {
  echo "[INFO] Adding user '${USER_TO_MODIFY}' to docker group if not already"
  if ! getent group ${DOCKER_GROUP} >/dev/null; then
    sudo groupadd ${DOCKER_GROUP}
  fi

  sudo usermod -aG ${DOCKER_GROUP} ${USER_TO_MODIFY}
  sudo chgrp ${DOCKER_GROUP} ${DOCKER_SOCK}
  echo "[INFO] Switching to new group..."
  exec newgrp ${DOCKER_GROUP}
}

#######################################
# Configure /etc/docker/daemon.json if not present
setup_docker_daemon_config() {
  if [ ! -f "${DAEMON_JSON}" ]; then
    echo "[INFO] Creating ${DAEMON_JSON} with DNS and proxy settings"
    sudo mkdir -p "$(dirname "${DAEMON_JSON}")"
    sudo tee "${DAEMON_JSON}" >/dev/null <<EOF
{
  "dns": ${DNS_SERVERS},
  "proxies": {
    "default": {
      "httpProxy": "${PROXY_URL}",
      "httpsProxy": "${PROXY_URL}",
      "noProxy": "${NO_PROXY_LIST}"
    }
  }
}
EOF
  else
    echo "[INFO] ${DAEMON_JSON} already exists, skipping."
  fi
}

#######################################
# Restart Docker daemon
restart_dockerd() {
  echo "[INFO] Restarting Docker daemon..."
  sudo pkill dockerd || true
  nohup dockerd --host=tcp://127.0.0.1:2375 > "${DOCKER_LOG}" 2>&1 &
  sleep 3
  docker info || echo "[WARN] docker info failed after restart"
}

#######################################
# Merge proxy config into ~/.docker/config.json using jq
setup_docker_cli_config() {
  echo "[INFO] Updating Docker CLI config at ${DOCKER_CONFIG}"
  mkdir -p "$(dirname "${DOCKER_CONFIG}")"

  if [ ! -f "${DOCKER_CONFIG}" ]; then
    echo '{}' > "${DOCKER_CONFIG}"
  fi

  UPDATED_JSON=$(jq \
    --arg http "$PROXY_URL" \
    --arg https "$PROXY_URL" \
    --arg no "$NO_PROXY_LIST" \
    '.proxies.default.httpProxy //= $http |
     .proxies.default.httpsProxy //= $https |
     .proxies.default.noProxy //= $no' \
     "${DOCKER_CONFIG}")

  echo "${UPDATED_JSON}" > "${DOCKER_CONFIG}"
}

#######################################
# Main
#######################################
main() {
  take_ssh_ownership
  setup_user_permissions
  setup_docker_daemon_config
  restart_dockerd
  setup_docker_cli_config
}

main
