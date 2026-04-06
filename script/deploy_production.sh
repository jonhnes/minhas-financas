#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="$ROOT_DIR/../env/backend.env"
COMPOSE_FILE="$ROOT_DIR/docker-compose.prod.yml"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing production env file at $ENV_FILE" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/../frontend-dist"

set -a
source "$ENV_FILE"
set +a

cd "$ROOT_DIR"

docker compose -f "$COMPOSE_FILE" up -d db redis
docker compose -f "$COMPOSE_FILE" run --rm web bin/rails db:prepare
docker compose -f "$COMPOSE_FILE" run --rm web bin/rails db:seed
docker compose -f "$COMPOSE_FILE" up -d --build web worker
docker compose -f "$COMPOSE_FILE" up -d --force-recreate caddy

for _ in {1..30}; do
  if docker compose -f "$COMPOSE_FILE" exec -T web curl -fsS http://127.0.0.1:3000/up >/dev/null 2>&1; then
    exit 0
  fi

  sleep 2
done

echo "Web service did not become healthy in time" >&2
exit 1
