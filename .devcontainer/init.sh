#!/usr/bin/env bash
set -euo pipefail

# Check if the network exists
if ! docker network inspect shared_net >/dev/null 2>&1; then
  echo "🔧 Creating shared network..."
  docker network create --driver bridge shared_net
else
  echo "✅ shared_net already exists"
fi
