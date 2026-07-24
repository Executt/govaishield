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
