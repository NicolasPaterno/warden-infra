#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(dirname "$SCRIPT_DIR")"
LOCAL_DIR="$INFRA_DIR/local"

echo "==> Starting Warden local infrastructure..."
docker compose -f "$LOCAL_DIR/docker-compose.yml" up -d

echo "==> Waiting for PostgreSQL to be ready..."
until docker exec warden-postgres pg_isready -U postgres > /dev/null 2>&1; do
  sleep 1
done

echo "==> Waiting for NATS to be ready..."
until docker exec warden-nats wget -qO- http://localhost:8222/healthz > /dev/null 2>&1; do
  sleep 1
done

echo ""
echo "  PostgreSQL : localhost:5432"
echo "    warden_gateway_db — used by warden-gateway"
echo "    warden_engine_db  — used by warden-engine"
echo "    warden_brain_db   — used by warden-brain"
echo "  NATS       : localhost:4222  (monitoring: localhost:8222)"
echo "  Redis      : localhost:6379"
echo ""
echo "  Copy local/.env.example to each service's .env before running services."
echo ""
echo "==> Done."
