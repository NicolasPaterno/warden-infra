#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_DIR="$(dirname "$SCRIPT_DIR")/local"

echo "==> Stopping Warden local infrastructure..."
docker compose -f "$LOCAL_DIR/docker-compose.yml" down

if [[ "${1:-}" == "--volumes" ]]; then
  echo "==> Removing volumes (all data will be lost)..."
  docker compose -f "$LOCAL_DIR/docker-compose.yml" down -v
fi

echo "==> Done."
