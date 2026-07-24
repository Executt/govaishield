#!/usr/bin/env bash
set -uo pipefail
echo "Subindo infra local..."
docker compose -f deploy/docker-compose.infra.yml up -d
echo "Aguardando PostgreSQL..."
until docker compose -f deploy/docker-compose.infra.yml exec -T postgres pg_isready -U govaishield >/dev/null 2>&1; do sleep 1; done
echo "✅ Infra pronta. Rode o gateway: cd src/api-gateway && go run ./cmd/main.go"
