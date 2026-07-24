#!/usr/bin/env bash
set -euo pipefail

PROJECT="govaishield"
echo "🛡️  Criando estrutura do projeto ${PROJECT}..."

# ═══════════════════════════════════════════════════════════
# ESTRUTURA DE DIRETÓRIOS
# ═══════════════════════════════════════════════════════════
mkdir -p ${PROJECT}/{.github/{workflows,ISSUE_TEMPLATE},docs,scripts,tests/{integration,e2e,load/k6,security/zap}}
mkdir -p ${PROJECT}/src/{api-gateway/{cmd,internal/{config,handlers,middleware,models,repositories,services,dto},api,migrations}}
mkdir -p ${PROJECT}/src/{detection-agent/{cmd,internal/{ebpf,detectors,signatures,reporter},bpf}}
mkdir -p ${PROJECT}/src/{dlp-engine/{src/dlp_engine,tests}}
mkdir -p ${PROJECT}/src/{policy-engine/{policies,tests}}
mkdir -p ${PROJECT}/src/{event-bus/{kafka/schemas,flink/jobs}}
mkdir -p ${PROJECT}/src/{dashboard/{src,public}}
mkdir -p ${PROJECT}/src/{transparency-portal/src}
mkdir -p ${PROJECT}/src/shared/{proto,schemas}
mkdir -p ${PROJECT}/database/{postgresql/{init,backup},clickhouse}
mkdir -p ${PROJECT}/deploy/{openshift,helm/govaishield/templates,kustomize/{base,overlays/{dev,staging,production}}}
mkdir -p ${PROJECT}/monitoring/{prometheus/rules,grafana/{dashboards,datasources},alertmanager}

echo "📁 Diretórios criados."

# ═══════════════════════════════════════════════════════════
# .gitignore
# ═══════════════════════════════════════════════════════════
cat > ${PROJECT}/.gitignore << 'EOF'
# Binaries
*.exe
*.exe~
*.dll
*.so
*.dylib
bin/
dist/

# Go
vendor/
*.test
*.out
coverage.html

# Python
__pycache__/
*.py[cod]
*$py.class
*.egg-info/
.eggs/
.venv/
venv/
env/

# Node
node_modules/
.next/
out/
*.tsbuildinfo

# IDE
.idea/
.vscode/
*.swp
*.swo
*~

# OS
.DS_Store
Thumbs.db

# Environment
.env
.env.local
.env.*.local

# Secrets
*.pem
*.key
*.crt
*.p12
secrets/

# Build
*.o
*.a
*.bpf.o

# Logs
*.log
logs/

# Terraform
.terraform/
*.tfstate*

# Misc
tmp/
temp/
EOF

# ═══════════════════════════════════════════════════════════
# .dockerignore
# ═══════════════════════════════════════════════════════════
cat > ${PROJECT}/.dockerignore << 'EOF'
.git
.github
docs
tests
*.md
.env*
.vscode
.idea
node_modules
vendor
EOF

# ═══════════════════════════════════════════════════════════
# LICENSE (AGPL-3.0 header)
# ═══════════════════════════════════════════════════════════
cat > ${PROJECT}/LICENSE << 'EOF'
                    GNU AFFERO GENERAL PUBLIC LICENSE
                       Version 3, 19 November 2007

 Copyright (C) 2026 GovAI Shield Contributors

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published
 by the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with this program.  If not, see <https://www.gnu.org/licenses/>.

---

Software Público Brasileiro - GovAI Shield
Plataforma de Governança e Combate ao Shadow AI
Licenciado sob AGPL-3.0 para garantir transparência e soberania digital.
EOF

# ═══════════════════════════════════════════════════════════
# Makefile
# ═══════════════════════════════════════════════════════════
cat > ${PROJECT}/Makefile << 'EOF'
.PHONY: help dev infra-up infra-down db-migrate build test lint security deploy-oc clean

SHELL := /bin/bash
GO := go
PYTHON := python3
NODE := node
OC := oc
NAMESPACE := govaishield

help: ## Mostra ajuda
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Desenvolvimento ───────────────────────────────────────
dev: ## Sobe todos os serviços em modo dev
	@echo "🚀 Iniciando serviços em modo desenvolvimento..."
	docker-compose -f deploy/docker-compose.dev.yml up -d

infra-up: ## Sobe infraestrutura (PG, Kafka, ClickHouse, MinIO)
	docker-compose -f deploy/docker-compose.infra.yml up -d
	@echo "⏳ Aguardando serviços..."
	@sleep 10
	@echo "✅ Infraestrutura pronta."

infra-down: ## Derruba infraestrutura
	docker-compose -f deploy/docker-compose.infra.yml down -v

db-migrate: ## Roda migrações PostgreSQL
	@echo "📦 Executando migrações..."
	cd src/api-gateway && $(GO) run cmd/migrate.go up
	@echo "✅ Migrações aplicadas."

db-seed: ## Popula dados iniciais
	psql -h localhost -U govaishield -d govaishield -f database/postgresql/init/008-seed.sql

# ─── Build ─────────────────────────────────────────────────
build: build-gateway build-agent build-dlp ## Build todos os serviços

build-gateway: ## Build API Gateway
	cd src/api-gateway && CGO_ENABLED=0 $(GO) build -o ../../bin/api-gateway ./cmd/main.go

build-agent: ## Build Detection Agent
	cd src/detection-agent && $(GO) build -o ../../bin/detection-agent ./cmd/main.go

build-dlp: ## Build DLP Engine
	cd src/dlp-engine && $(PYTHON) -m build

build-dashboard: ## Build Dashboard
	cd src/dashboard && npm ci && npm run build

# ─── Testes ────────────────────────────────────────────────
test: test-unit test-integration ## Roda todos os testes

test-unit: ## Testes unitários
	cd src/api-gateway && $(GO) test ./... -v -coverprofile=coverage.out
	cd src/dlp-engine && $(PYTHON) -m pytest tests/ -v --cov=dlp_engine

test-integration: ## Testes de integração
	cd tests/integration && $(GO) test ./... -v -tags=integration

test-e2e: ## Testes E2E
	cd tests/e2e && npx playwright test

test-load: ## Testes de carga (k6)
	k6 run tests/load/k6/detection-events.js

# ─── Qualidade ─────────────────────────────────────────────
lint: ## Linters
	cd src/api-gateway && golangci-lint run ./...
	cd src/dlp-engine && ruff check . && mypy .
	cd src/dashboard && npm run lint

security: ## Scans de segurança
	trivy fs . --severity HIGH,CRITICAL
	cd src/api-gateway && gosec ./...
	cd src/dlp-engine && bandit -r src/
	npx audit-ci --high

# ─── Deploy OpenShift ──────────────────────────────────────
deploy-oc: ## Deploy completo no OpenShift
	$(OC) apply -f deploy/openshift/00-namespace.yaml
	$(OC) apply -f deploy/openshift/01-imagestreams.yaml
	$(OC) apply -f deploy/openshift/02-configmaps.yaml
	$(OC) apply -f deploy/openshift/03-secrets.yaml
	$(OC) apply -f deploy/openshift/04-buildconfigs.yaml
	$(OC) apply -f deploy/openshift/05-deploymentconfigs.yaml
	$(OC) apply -f deploy/openshift/06-services.yaml
	$(OC) apply -f deploy/openshift/07-routes.yaml
	$(OC) apply -f deploy/openshift/08-networkpolicies.yaml
	$(OC) apply -f deploy/openshift/09-hpa.yaml
	$(OC) apply -f deploy/openshift/10-pvc.yaml
	$(OC) apply -f deploy/openshift/11-cronjobs.yaml
	$(OC) apply -f deploy/openshift/12-servicemonitors.yaml
	@echo "✅ Deploy concluído no namespace $(NAMESPACE)"

undeploy-oc: ## Remove do OpenShift
	$(OC) delete project $(NAMESPACE) --ignore-not-found

# ─── Utilitários ───────────────────────────────────────────
generate-certs: ## Gera certificados para dev
	./scripts/generate-certs.sh

clean: ## Limpa artefatos
	rm -rf bin/ dist/ node_modules/ .next/ __pycache/ *.egg-info
	find . -name "*.pyc" -delete
EOF

# ═══════════════════════════════════════════════════════════
# .env.example
# ═══════════════════════════════════════════════════════════
cat > ${PROJECT}/.env.example << 'EOF'
# ═══════════════════════════════════════════════════════════
# GovAI Shield - Variáveis de Ambiente
# ⚠️ NUNCA commitar o .env real!
# ═══════════════════════════════════════════════════════════

# ─── Aplicação ─────────────────────────────────────────────
APP_NAME=govaishield
APP_ENV=development
APP_PORT=8080
APP_LOG_LEVEL=debug
APP_LOG_FORMAT=json

# ─── PostgreSQL ────────────────────────────────────────────
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_DB=govaishield
POSTGRES_USER=govaishield
POSTGRES_PASSWORD=CHANGE_ME_STRONG_PASSWORD
POSTGRES_SSLMODE=disable
POSTGRES_MAX_CONNS=50
POSTGRES_MIN_CONNS=5

# ─── ClickHouse ────────────────────────────────────────────
CLICKHOUSE_HOST=localhost
CLICKHOUSE_PORT=8123
CLICKHOUSE_DB=govaishield_metrics
CLICKHOUSE_USER=default
CLICKHOUSE_PASSWORD=CHANGE_ME

# ─── Kafka ─────────────────────────────────────────────────
KAFKA_BROKERS=localhost:9092
KAFKA_TOPIC_DETECTION=detection.events
KAFKA_TOPIC_POLICY=policy.decisions
KAFKA_TOPIC_DLP=dlp.results
KAFKA_TOPIC_AUDIT=audit.log
KAFKA_TOPIC_ALERTS=alerts
KAFKA_CONSUMER_GROUP=govaishield-api

# ─── Redis ─────────────────────────────────────────────────
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=
REDIS_DB=0

# ─── MinIO (Object Storage WORM) ──────────────────────────
MINIO_ENDPOINT=localhost:9000
MINIO_ACCESS_KEY=minioadmin
MINIO_SECRET_KEY=CHANGE_ME
MINIO_BUCKET_AUDIT=govaishield-audit
MINIO_USE_SSL=false
MINIO_OBJECT_LOCK_RETENTION_DAYS=1825

# ─── OPA (Policy Engine) ──────────────────────────────────
OPA_URL=http://localhost:8082
OPA_BUNDLE_PATH=./src/policy-engine/policies
OPA_DECISION_PATH=govaishield/ai_policy/allow

# ─── DLP Engine ────────────────────────────────────────────
DLP_ENGINE_URL=http://localhost:8081
DLP_BLOCK_THRESHOLD=0.85
DLP_ANONYMIZE_THRESHOLD=0.50
DLP_LANGUAGE=pt

# ─── Autenticação (Gov.br / Keycloak) ─────────────────────
AUTH_PROVIDER=keycloak
KEYCLOAK_URL=http://localhost:8085
KEYCLOAK_REALM=govaishield
KEYCLOAK_CLIENT_ID=govaishield-api
KEYCLOAK_CLIENT_SECRET=CHANGE_ME
JWT_ISSUER=http://localhost:8085/realms/govaishield
JWT_AUDIENCE=govaishield-api
JWT_SECRET=CHANGE_ME_256BIT_SECRET

# ─── mTLS / ICP-Brasil ────────────────────────────────────
MTLS_ENABLED=false
MTLS_CA_CERT_PATH=./certs/ca.crt
MTLS_SERVER_CERT_PATH=./certs/server.crt
MTLS_SERVER_KEY_PATH=./certs/server.key

# ─── Observabilidade ───────────────────────────────────────
PROMETHEUS_PORT=9090
GRAFANA_PORT=3002
LOKI_URL=http://localhost:3100
TEMPO_URL=http://localhost:3200
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317

# ─── Detection Agent ───────────────────────────────────────
AGENT_REPORT_INTERVAL=5s
AGENT_BATCH_SIZE=100
AGENT_EBPF_ENABLED=true
AGENT_JA4_ENABLED=true
AGENT_DNS_MONITOR=true

# ─── Rate Limiting ─────────────────────────────────────────
RATE_LIMIT_REQUESTS_PER_MINUTE=1000
RATE_LIMIT_BURST=50
RATE_LIMIT_PUBLIC_PER_MINUTE=100
EOF

# ═══════════════════════════════════════════════════════════
# README.md
# ═══════════════════════════════════════════════════════════
cat > ${PROJECT}/README.md << 'READMEEOF'
# 🛡️ GovAI Shield

## Plataforma Pública de Governança e Combate ao Shadow AI

[![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](LICENSE)
[![OpenShift](https://img.shields.io/badge/OpenShift-4.14+-red.svg)](https://www.openshift.com/)
[![Go](https://img.shields.io/badge/Go-1.22+-00ADD8.svg)](https://go.dev/)
[![Python](https://img.shields.io/badge/Python-3.12+-3776AB.svg)](https://python.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-336791.svg)](https://postgresql.org/)

---

## 📋 Sumário

- [Visão Geral](#visão-geral)
- [Problema](#problema)
- [Solução](#solução)
- [Arquitetura](#arquitetura)
- [Componentes](#componentes)
- [Stack Tecnológica](#stack-tecnológica)
- [Quick Start](#quick-start)
- [Deploy no OpenShift](#deploy-no-openshift)
- [Documentação](#documentação)
- [Contribuição](#contribuição)
- [Licença](#licença)

---

## Visão Geral

O **GovAI Shield** é uma plataforma de software público, aberta e soberana para
**detecção, monitoramento, governança e auditoria** do uso de ferramentas de
Inteligência Artificial em organizações públicas brasileiras.

Nasce como resposta ao avanço do **Shadow AI** — o uso não autorizado de IAs
(ChatGPT, Claude, Copilot, Cursor, agentes autônomos, etc.) por servidores
públicos, expondo dados de 215 milhões de cidadãos a riscos de vazamento,
violação da LGPD e descumprimento do Marco Legal da IA (Lei 14.879/2024).

## Problema

| Risco | Impacto |
|-------|---------|
| Exfiltração de dados via prompts | Vazamento de CPF, CNPJ, dados de saúde |
| Agentes autônomos sem supervisão | Ações irreversíveis em sistemas gov |
| Modelos locais sem patch | Vulnerabilidades exploráveis |
| Sem trilha de auditoria | Impossibilidade de accountability |
| Violação LGPD | Multas de até R$ 50M |
| TLS 1.3/QUIC | DLP tradicional ineficaz |

## Solução

