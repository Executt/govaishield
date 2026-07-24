#!/usr/bin/env bash
# =============================================================================
# GovAI Shield — setup2.sh  (preenche TODO o conteúdo do projeto)
# Idempotente. Rode DENTRO da raiz do projeto (onde está o README.md).
# =============================================================================
set -uo pipefail   # NOTE: sem -e de propósito (um arquivo não mata os outros)

if [ ! -f README.md ]; then
  echo "❌ Rode este script dentro da raiz do projeto (onde existe README.md)."; exit 1
fi
echo "🛡️  GovAI Shield — gerando conteúdo completo..."

mkdir -p .github/workflows .github/ISSUE_TEMPLATE \
  deploy/openshift \
  database/postgresql/init database/postgresql/backup database/clickhouse \
  src/api-gateway/cmd src/api-gateway/internal/config src/api-gateway/internal/handlers src/api-gateway/api src/api-gateway/migrations \
  src/dlp-engine/src/dlp_engine src/dlp-engine/tests \
  src/policy-engine/policies src/policy-engine/tests \
  src/event-bus/kafka/schemas src/event-bus/flink/jobs \
  src/dashboard/src src/dashboard/public src/transparency-portal/src \
  src/shared/proto src/shared/schemas \
  monitoring/prometheus/rules monitoring/grafana/dashboards monitoring/grafana/datasources monitoring/alertmanager \
  tests/integration tests/e2e tests/load/k6 tests/security/zap scripts

# =============================================================================
# CI / DEVSECOPS
# =============================================================================
cat > .github/workflows/ci.yml <<'YAMLEOF'
name: CI
on:
  push: { branches: [main, develop] }
  pull_request: { branches: [main, develop] }
permissions: { contents: read }
jobs:
  gateway:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: src/api-gateway } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with: { go-version: '1.22' }
      - run: go vet ./...
      - run: go build -o /tmp/api-gateway ./cmd/main.go
      - run: go test ./... -race -coverprofile=cover.out
  dlp:
    runs-on: ubuntu-latest
    defaults: { run: { working-directory: src/dlp-engine } }
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with: { python-version: '3.12' }
      - run: pip install -e ".[test]"
      - run: ruff check . || true
      - run: pytest -q
  policy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: open-policy-agent/setup-opa@v2
        with: { version: '0.64.0' }
      - run: opa test src/policy-engine/policies/ -v
YAMLEOF

cat > .github/workflows/security.yml <<'YAMLEOF'
name: Security
on: { push: { branches: [main] }, pull_request: {}, schedule: [{ cron: '0 6 * * 1' }] }
permissions: { contents: read, security-events: write }
jobs:
  trivy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          severity: 'HIGH,CRITICAL'
          exit-code: '1'
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with: { fetch-depth: 0 }
      - uses: gitleaks/gitleaks-action@v2
        env: { GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
YAMLEOF

cat > .github/CODEOWNERS <<'EOF'
*                       @Executt
/src/api-gateway/       @Executt
/src/dlp-engine/        @Executt
/src/policy-engine/     @Executt
/deploy/openshift/      @Executt
/database/              @Executt
EOF

cat > .github/PULL_REQUEST_TEMPLATE.md <<'MDEOF'
## O que muda?
<!-- descreva -->

## Tipo
- [ ] feat  - [ ] fix  - [ ] docs  - [ ] chore  - [ ] hotfix

## Checklist
- [ ] Testes passam (`make test`)
- [ ] Lint passa (`make lint`)
- [ ] Sem segredos no diff (gitleaks limpo)
- [ ] Docs atualizados (se mudou API/arquitetura)
- [ ] Commits seguem Conventional Commits
- [ ] Assinatura DCO (`git commit -s`)
MDEOF

cat > .github/ISSUE_TEMPLATE/bug_report.md <<'MDEOF'
---
name: Bug report
about: Reporte um defeito
labels: bug
---
**Resumo**
**Passos para reproduzir**
**Comportamento esperado vs. real**
**Versão / commit / ambiente (OpenShift? local?)**
**Logs / trace_id**
MDEOF

cat > .github/ISSUE_TEMPLATE/feature_request.md <<'MDEOF'
---
name: Feature request
about: Proponha uma melhoria
labels: enhancement
---
**Problema / contexto**
**Solução proposta**
**Impacto em LGPD / Marco Legal da IA / transparência**
MDEOF

cat > .pre-commit-config.yaml <<'YAMLEOF'
repos:
  - repo: https://github.com/gitleaks/gitleaks
    rev: v8.18.4
    hooks: [{ id: gitleaks }]
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - { id: end-of-file-fixer }
      - { id: trailing-whitespace }
      - { id: check-yaml }
      - { id: check-json }
      - { id: detect-private-key }
  - repo: https://github.com/dnephin/pre-commit-golang
    rev: v0.5.1
    hooks: [{ id: go-fmt }, { id: go-vet }]
YAMLEOF

cat > .gitleaks.toml <<'EOF'
title = "govaishield gitleaks config"
[extend]
useDefault = true
[allowlist]
paths = ['''(^|/)tests/''', '''\.md$''']
regexes = ['''ghp_[A-Za-z0-9_]{0,3}X+''']   # exemplos mascarados
EOF

# =============================================================================
# DEPLOY — docker-compose (infra + dev)
# =============================================================================
cat > deploy/docker-compose.infra.yml <<'YAMLEOF'
version: "3.9"
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: govaishield
      POSTGRES_USER: govaishield
      POSTGRES_PASSWORD: devpass_change_me
    ports: ["5432:5432"]
    volumes:
      - pgdata:/var/lib/postgresql/data
      - ../database/postgresql/init:/docker-entrypoint-initdb.d:ro
  redis:
    image: redis:7-alpine
    ports: ["6379:6379"]
  kafka:
    image: bitnami/kafka:3.7
    environment:
      KAFKA_CFG_NODE_ID: "1"
      KAFKA_CFG_PROCESS_ROLES: controller,broker
      KAFKA_CFG_CONTROLLER_QUORUM_VOTERS: 1@kafka:9093
      KAFKA_CFG_LISTENERS: PLAINTEXT://:9092,CONTROLLER://:9093
      KAFKA_CFG_ADVERTISED_LISTENERS: PLAINTEXT://kafka:9092
      KAFKA_CFG_CONTROLLER_LISTENER_NAMES: CONTROLLER
      KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP: CONTROLLER:PLAINTEXT,PLAINTEXT:PLAINTEXT
    ports: ["9092:9092"]
  minio:
    image: minio/minio:RELEASE.2024-07-16T23-46-41Z
    command: server /data --console-address ":9001"
    environment:
      MINIO_ROOT_USER: minioadmin
      MINIO_ROOT_PASSWORD: minioadmin123
    ports: ["9000:9000", "9001:9001"]
  clickhouse:
    image: clickhouse/clickhouse-server:24
    ports: ["8123:8123", "9009:9000"]
volumes: { pgdata: {} }
YAMLEOF

cat > deploy/docker-compose.dev.yml <<'YAMLEOF'
version: "3.9"
# Sobe a infra + os serviços da aplicação em modo dev.
# Requer: deploy/docker-compose.infra.yml rodando (ou rode com -f infra -f dev)
services:
  api-gateway:
    build: ../src/api-gateway
    environment:
      APP_PORT: "8080"
      POSTGRES_HOST: postgres
      KAFKA_BROKERS: kafka:9092
      REDIS_HOST: redis
    ports: ["8080:8080"]
    depends_on: [postgres, kafka, redis]
  dlp-engine:
    build: ../src/dlp-engine
    ports: ["8081:8081"]
YAMLEOF

# =============================================================================
# DEPLOY — OPENSHIFT (manifests reais; Deployment, NÃO DeploymentConfig)
# =============================================================================
cat > deploy/openshift/00-namespace.yaml <<'YAMLEOF'
apiVersion: v1
kind: Namespace
metadata:
  name: govaishield
  labels:
    app.kubernetes.io/part-of: govaishield
    pod-security.kubernetes.io/enforce: baseline
YAMLEOF

cat > deploy/openshift/01-scc.yaml <<'YAMLEOF'
# SCC customizado para o Detection Agent (eBPF). Só o ServiceAccount do agente usa.
# Aplique com cluster-admin. Em produção prefira aprovar via processo de mudança.
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: govaishield-ebpf
allowHostDirVolumePlugin: true
allowHostNetwork: true
allowHostPID: true
allowPrivilegedContainer: true
readOnlyRootFilesystem: true
runAsUser: { type: RunAsAny }
seLinuxContext: { type: RunAsAny }
fsGroup: { type: RunAsAny }
supplementalGroups: { type: RunAsAny }
requiredDropCapabilities: [ALL]
allowedCapabilities: [SYS_ADMIN, NET_ADMIN, NET_RAW, BPF, PERFMON, SYS_PTRACE]
volumes: [configMap, secret, emptyDir, hostPath, projected, downwardAPI]
users:
  - system:serviceaccount:govaishield:govaishield-agent
YAMLEOF

cat > deploy/openshift/02-configmaps.yaml <<'YAMLEOF'
apiVersion: v1
kind: ConfigMap
metadata: { name: govaishield-config, namespace: govaishield }
data:
  APP_ENV: "production"
  APP_LOG_FORMAT: "json"
  POSTGRES_HOST: "govaishield-pg-primary.govaishield.svc.cluster.local"
  POSTGRES_PORT: "5432"
  KAFKA_BROKERS: "govaishield-kafka-bootstrap.govaishield.svc.cluster.local:9092"
  REDIS_HOST: "govaishield-redis.govaishield.svc.cluster.local"
  OPA_URL: "http://policy-engine.govaishield.svc.cluster.local:8082"
  DLP_ENGINE_URL: "http://dlp-engine.govaishield.svc.cluster.local:8081"
  MTLS_ENABLED: "true"
YAMLEOF

cat > deploy/openshift/03-secrets-template.yaml <<'YAMLEOF'
# MODELO. Em produção: use External Secrets Operator / HashiCorp Vault. NUNCA commitar valores.
apiVersion: v1
kind: Secret
metadata: { name: govaishield-db-credentials, namespace: govaishield }
type: Opaque
stringData:
  POSTGRES_USER: "govaishield"
  POSTGRES_PASSWORD: "REPLACE_VIA_VAULT"
---
apiVersion: v1
kind: Secret
metadata: { name: govaishield-jwt, namespace: govaishield }
type: Opaque
stringData:
  JWT_SECRET: "REPLACE_VIA_VAULT_256BIT"
YAMLEOF

cat > deploy/openshift/04-imagestreams.yaml <<'YAMLEOF'
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata: { name: api-gateway, namespace: govaishield }
spec: { lookupPolicy: { local: false } }
---
apiVersion: image.openshift.io/v1
kind: ImageStream
metadata: { name: dlp-engine, namespace: govaishield }
spec: { lookupPolicy: { local: false } }
YAMLEOF

cat > deploy/openshift/05-deployments.yaml <<'YAMLEOF'
apiVersion: v1
kind: ServiceAccount
metadata: { name: govaishield-api, namespace: govaishield }
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-gateway
  namespace: govaishield
  labels: { app: api-gateway }
spec:
  replicas: 3
  strategy: { type: RollingUpdate, rollingUpdate: { maxSurge: 1, maxUnavailable: 0 } }
  selector: { matchLabels: { app: api-gateway } }
  template:
    metadata:
      labels: { app: api-gateway }
      annotations:
        checksum/config: "replace-with-hash"
    spec:
      serviceAccountName: govaishield-api
      securityContext:
        runAsNonRoot: true
        seccompProfile: { type: RuntimeDefault }
      containers:
        - name: api-gateway
          image: image-registry.openshift-image-registry.svc:5000/govaishield/api-gateway:latest
          ports: [{ containerPort: 8080, name: http }]
          envFrom:
            - configMapRef: { name: govaishield-config }
            - secretRef: { name: govaishield-db-credentials }
            - secretRef: { name: govaishield-jwt }
          resources:
            requests: { cpu: 200m, memory: 256Mi }
            limits:   { cpu: "1",  memory: 512Mi }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: [ALL] }
          livenessProbe:
            httpGet: { path: /api/v2/health, port: 8080 }
            initialDelaySeconds: 10, periodSeconds: 15
          readinessProbe:
            httpGet: { path: /api/v2/health/ready, port: 8080 }
            initialDelaySeconds: 5, periodSeconds: 10
          startupProbe:
            httpGet: { path: /api/v2/health/startup, port: 8080 }
            failureThreshold: 30, periodSeconds: 5
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dlp-engine
  namespace: govaishield
  labels: { app: dlp-engine }
spec:
  replicas: 2
  selector: { matchLabels: { app: dlp-engine } }
  template:
    metadata: { labels: { app: dlp-engine } }
    spec:
      securityContext: { runAsNonRoot: true, seccompProfile: { type: RuntimeDefault } }
      containers:
        - name: dlp-engine
          image: image-registry.openshift-image-registry.svc:5000/govaishield/dlp-engine:latest
          ports: [{ containerPort: 8081, name: http }]
          envFrom: [{ configMapRef: { name: govaishield-config } }]
          resources:
            requests: { cpu: 200m, memory: 256Mi }
            limits:   { cpu: "1",  memory: 768Mi }
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities: { drop: [ALL] }
          livenessProbe:  { httpGet: { path: /health, port: 8081 }, periodSeconds: 15 }
          readinessProbe: { httpGet: { path: /health, port: 8081 }, periodSeconds: 10 }
---
# Detection Agent: DaemonSet (1 por node) com SCC de eBPF
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: govaishield-agent
  namespace: govaishield
  labels: { app: govaishield-agent }
spec:
  selector: { matchLabels: { app: govaishield-agent } }
  template:
    metadata: { labels: { app: govaishield-agent } }
    spec:
      serviceAccountName: govaishield-agent
      hostPID: true
      hostNetwork: true
      tolerations: [{ operator: Exists }]
      containers:
        - name: agent
          image: image-registry.openshift-image-registry.svc:5000/govaishield/detection-agent:latest
          securityContext:
            privileged: false
            readOnlyRootFilesystem: true
            capabilities: { add: [SYS_ADMIN, NET_ADMIN, NET_RAW, BPF, PERFMON, SYS_PTRACE] }
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits:   { cpu: 500m, memory: 256Mi }
          volumeMounts:
            - { name: bpf, mountPath: /sys/fs/bpf }
            - { name: proc, mountPath: /host/proc, readOnly: true }
      volumes:
        - { name: bpf, hostPath: { path: /sys/fs/bpf, type: DirectoryOrCreate } }
        - { name: proc, hostPath: { path: /proc, type: Directory } }
YAMLEOF

cat > deploy/openshift/06-services.yaml <<'YAMLEOF'
apiVersion: v1
kind: Service
metadata: { name: api-gateway, namespace: govaishield }
spec:
  selector: { app: api-gateway }
  ports: [{ name: http, port: 8080, targetPort: 8080 }]
---
apiVersion: v1
kind: Service
metadata: { name: dlp-engine, namespace: govaishield }
spec:
  selector: { app: dlp-engine }
  ports: [{ name: http, port: 8081, targetPort: 8081 }]
---
apiVersion: v1
kind: Service
metadata: { name: policy-engine, namespace: govaishield }
spec:
  selector: { app: policy-engine }
  ports: [{ name: http, port: 8082, targetPort: 8082 }]
YAMLEOF

cat > deploy/openshift/07-routes.yaml <<'YAMLEOF'
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: api-gateway
  namespace: govaishield
  annotations:
    haproxy.router.openshift.io/hsts_header: "max-age=31536000;includeSubDomains;preload"
spec:
  host: api.govaishield.apps.cluster.example.com
  to: { kind: Service, name: api-gateway }
  port: { targetPort: http }
  tls: { termination: edge, insecureEdgeTerminationPolicy: Redirect }
---
apiVersion: route.openshift.io/v1
kind: Route
metadata: { name: transparency-portal, namespace: govaishield }
spec:
  host: transparencia.govaishield.apps.cluster.example.com
  to: { kind: Service, name: transparency-portal }
  port: { targetPort: http }
  tls: { termination: edge, insecureEdgeTerminationPolicy: Redirect }
YAMLEOF

cat > deploy/openshift/08-networkpolicies.yaml <<'YAMLEOF'
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: default-deny-all, namespace: govaishield }
spec: { podSelector: {}, policyTypes: [Ingress, Egress] }
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-api-gateway, namespace: govaishield }
spec:
  podSelector: { matchLabels: { app: api-gateway } }
  policyTypes: [Ingress, Egress]
  ingress:
    - from: [{ namespaceSelector: { matchLabels: { network.openshift.io/policy-group: ingress } } }]
      ports: [{ protocol: TCP, port: 8080 }]
  egress:
    - to: [{ podSelector: { matchLabels: { app: dlp-engine } } }]
      ports: [{ protocol: TCP, port: 8081 }]
    - to: [{ podSelector: { matchLabels: { app: policy-engine } } }]
      ports: [{ protocol: TCP, port: 8082 }]
    - ports: [{ protocol: TCP, port: 5432 }, { protocol: TCP, port: 9092 }, { protocol: TCP, port: 6379 }, { protocol: UDP, port: 53 }]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: protect-postgres, namespace: govaishield }
spec:
  podSelector: { matchLabels: { postgres-operator.crunchydata.com/cluster: govaishield-pg } }
  policyTypes: [Ingress]
  ingress:
    - from:
        - { podSelector: { matchLabels: { app: api-gateway } } }
        - { podSelector: { matchLabels: { app: audit-service } } }
      ports: [{ protocol: TCP, port: 5432 }]
YAMLEOF

cat > deploy/openshift/09-hpa.yaml <<'YAMLEOF'
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata: { name: api-gateway, namespace: govaishield }
spec:
  scaleTargetRef: { apiVersion: apps/v1, kind: Deployment, name: api-gateway }
  minReplicas: 3
  maxReplicas: 16
  metrics:
    - type: Resource
      resource: { name: cpu, target: { type: Utilization, averageUtilization: 70 } }
    - type: Resource
      resource: { name: memory, target: { type: Utilization, averageUtilization: 75 } }
  behavior:
    scaleDown: { stabilizationWindowSeconds: 300 }
YAMLEOF

cat > deploy/openshift/10-pvc.yaml <<'YAMLEOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata: { name: minio-audit, namespace: govaishield }
spec:
  accessModes: [ReadWriteOnce]
  resources: { requests: { storage: 500Gi } }
  storageClassName: ocs-storagecluster-ceph-rbd   # ajuste ao seu cluster
YAMLEOF

cat > deploy/openshift/11-cronjobs.yaml <<'YAMLEOF'
apiVersion: batch/v1
kind: CronJob
metadata: { name: pg-create-partition, namespace: govaishield }
spec:
  schedule: "0 2 15 * *"   # dia 15 de cada mês cria a partição do mês seguinte
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: psql
              image: postgres:16-alpine
              command: ["sh","-c","psql $DATABASE_URL -c 'SELECT detection.create_monthly_partition();'"]
              env:
                - { name: DATABASE_URL, valueFrom: { secretKeyRef: { name: govaishield-db-credentials, key: DATABASE_URL } } }
YAMLEOF

cat > deploy/openshift/12-servicemonitors.yaml <<'YAMLEOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata: { name: api-gateway, namespace: govaishield, labels: { app: api-gateway } }
spec:
  selector: { matchLabels: { app: api-gateway } }
  endpoints: [{ port: http, path: /metrics, interval: 15s }]
YAMLEOF

# =============================================================================
# DATABASE — PostgreSQL 16
# =============================================================================
cat > database/postgresql/init/001-extensions.sql <<'SQLEOF'
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
SQLEOF

cat > database/postgresql/init/002-schemas.sql <<'SQLEOF'
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS detection;
CREATE SCHEMA IF NOT EXISTS policy;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS dlp;
CREATE SCHEMA IF NOT EXISTS admin;
SQLEOF

cat > database/postgresql/init/003-tables.sql <<'SQLEOF'
CREATE TABLE admin.orgaos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo_siafi VARCHAR(10) UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    sigla VARCHAR(20) UNIQUE NOT NULL,
    esfera VARCHAR(20) NOT NULL CHECK (esfera IN ('FEDERAL','ESTADUAL','MUNICIPAL')),
    poder  VARCHAR(20) NOT NULL CHECK (poder IN ('EXECUTIVO','LEGISLATIVO','JUDICIARIO')),
    cnpj VARCHAR(18), ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE admin.usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    orgao_id UUID NOT NULL REFERENCES admin.orgaos(id),
    cpf_hash VARCHAR(64) UNIQUE NOT NULL,
    nome_hash VARCHAR(64), email VARCHAR(255), cargo VARCHAR(100),
    roles TEXT[] DEFAULT '{}',
    quota_tokens BIGINT DEFAULT 50000, quota_requests INTEGER DEFAULT 100,
    ativo BOOLEAN DEFAULT TRUE, last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE core.ai_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug VARCHAR(100) UNIQUE NOT NULL, display_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    risk_level SMALLINT NOT NULL CHECK (risk_level BETWEEN 1 AND 5),
    approved BOOLEAN DEFAULT FALSE, approved_by UUID REFERENCES admin.usuarios(id),
    approved_at TIMESTAMPTZ, data_residency VARCHAR(100),
    lgpd_adequacy BOOLEAN DEFAULT FALSE, has_dpa BOOLEAN DEFAULT FALSE,
    api_endpoint VARCHAR(500), website VARCHAR(500), description TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE core.detection_signatures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES core.ai_providers(id) ON DELETE CASCADE,
    sig_type VARCHAR(30) NOT NULL CHECK (sig_type IN
      ('DOMAIN','IP_CIDR','JA4','PROCESS','FILE_PATH','PORT','HEADER','TRAFFIC_PATTERN')),
    value VARCHAR(500) NOT NULL, confidence DECIMAL(3,2) DEFAULT 0.90,
    active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE detection.events (
    id BIGSERIAL, event_id UUID NOT NULL DEFAULT uuid_generate_v4(),
    orgao_id UUID NOT NULL, usuario_id UUID, provider_id UUID,
    detection_type VARCHAR(30) NOT NULL,
    source_ip INET, destination_ip INET, destination_port SMALLINT,
    process_name VARCHAR(255), process_cmdline TEXT, container_id VARCHAR(64),
    bytes_sent BIGINT DEFAULT 0, bytes_received BIGINT DEFAULT 0,
    ja4_fingerprint VARCHAR(100), dns_query VARCHAR(500),
    dlp_action VARCHAR(20), dlp_entities JSONB, dlp_max_score DECIMAL(3,2),
    policy_id UUID, policy_decision VARCHAR(20),
    severity SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    status VARCHAR(20) DEFAULT 'NEW' CHECK (status IN
      ('NEW','ACKNOWLEDGED','INVESTIGATING','RESOLVED','FALSE_POSITIVE')),
    raw_metadata JSONB DEFAULT '{}', detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, detected_at)
) PARTITION BY RANGE (detected_at);

CREATE TABLE policy.policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    orgao_id UUID REFERENCES admin.orgaos(id),
    name VARCHAR(255) NOT NULL, slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT, rego_code TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
    active BOOLEAN DEFAULT TRUE, priority SMALLINT DEFAULT 100,
    created_by UUID REFERENCES admin.usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE policy.decisions (
    id BIGSERIAL PRIMARY KEY, event_id UUID NOT NULL,
    policy_id UUID REFERENCES policy.policies(id),
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('ALLOW','DENY','ANONYMIZE','ALERT')),
    reason TEXT, input_snapshot JSONB NOT NULL, evaluated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit.trail (
    sequence BIGSERIAL PRIMARY KEY, event_type VARCHAR(50) NOT NULL,
    orgao_id UUID, actor_type VARCHAR(30) NOT NULL, actor_id VARCHAR(100),
    action VARCHAR(100) NOT NULL, resource_type VARCHAR(50), resource_id VARCHAR(100),
    hash VARCHAR(64) NOT NULL, prev_hash VARCHAR(64) NOT NULL,
    signature VARCHAR(128), minio_key VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dlp.rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL, entity_type VARCHAR(50) NOT NULL,
    pattern_type VARCHAR(30) NOT NULL CHECK (pattern_type IN ('REGEX','NER','KEYWORD','ML')),
    pattern_value TEXT NOT NULL, score_threshold DECIMAL(3,2) DEFAULT 0.85,
    action VARCHAR(20) DEFAULT 'BLOCK', orgao_id UUID REFERENCES admin.orgaos(id),
    active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE admin.config (
    key VARCHAR(100) PRIMARY KEY, value JSONB NOT NULL, description TEXT,
    updated_by UUID REFERENCES admin.usuarios(id), updated_at TIMESTAMPTZ DEFAULT NOW()
);
SQLEOF

cat > database/postgresql/init/004-indexes.sql <<'SQLEOF'
CREATE INDEX idx_usuarios_orgao ON admin.usuarios(orgao_id);
CREATE INDEX idx_usuarios_cpf_hash ON admin.usuarios(cpf_hash);
CREATE INDEX idx_providers_category ON core.ai_providers(category);
CREATE INDEX idx_providers_risk ON core.ai_providers(risk_level);
CREATE INDEX idx_providers_approved ON core.ai_providers(approved) WHERE approved = TRUE;
CREATE INDEX idx_sigs_provider ON core.detection_signatures(provider_id);
CREATE INDEX idx_sigs_type_value ON core.detection_signatures(sig_type, value);
CREATE INDEX idx_events_orgao_date ON detection.events(orgao_id, detected_at DESC);
CREATE INDEX idx_events_severity ON detection.events(severity) WHERE severity >= 4;
CREATE INDEX idx_events_provider ON detection.events(provider_id, detected_at DESC);
CREATE INDEX idx_events_status ON detection.events(status) WHERE status != 'RESOLVED';
CREATE INDEX idx_events_dlp ON detection.events USING GIN(dlp_entities);
CREATE INDEX idx_decisions_event ON policy.decisions(event_id);
CREATE INDEX idx_decisions_date ON policy.decisions(evaluated_at DESC);
CREATE INDEX idx_audit_orgao ON audit.trail(orgao_id, created_at DESC);
CREATE INDEX idx_audit_hash ON audit.trail(hash);
SQLEOF

cat > database/postgresql/init/005-functions.sql <<'SQLEOF'
CREATE OR REPLACE FUNCTION core.update_timestamp() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION detection.create_monthly_partition() RETURNS void AS $$
DECLARE
  next_month DATE := date_trunc('month', NOW()) + INTERVAL '1 month';
  pname TEXT; s TEXT; e TEXT;
BEGIN
  pname := 'detection.events_' || to_char(next_month,'YYYY_MM');
  s := to_char(next_month,'YYYY-MM-DD');
  e := to_char(next_month + INTERVAL '1 month','YYYY-MM-DD');
  EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF detection.events FOR VALUES FROM (%L) TO (%L)', pname, s, e);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit.compute_chain_hash(p_seq BIGINT, p_type VARCHAR, p_action VARCHAR, p_prev VARCHAR)
RETURNS VARCHAR AS $$
BEGIN
  RETURN encode(sha256(convert_to(p_seq::TEXT||'|'||p_type||'|'||p_action||'|'||p_prev||'|'||NOW()::TEXT,'UTF8')),'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;
SQLEOF

cat > database/postgresql/init/006-triggers.sql <<'SQLEOF'
CREATE TRIGGER trg_orgaos_updated BEFORE UPDATE ON admin.orgaos FOR EACH ROW EXECUTE FUNCTION core.update_timestamp();
CREATE TRIGGER trg_providers_updated BEFORE UPDATE ON core.ai_providers FOR EACH ROW EXECUTE FUNCTION core.update_timestamp();
CREATE TRIGGER trg_policies_updated BEFORE UPDATE ON policy.policies FOR EACH ROW EXECUTE FUNCTION core.update_timestamp();
SQLEOF

cat > database/postgresql/init/007-views.sql <<'SQLEOF'
CREATE OR REPLACE VIEW detection.v_high_severity AS
SELECT event_id, orgao_id, provider_id, severity, dlp_action, status, detected_at
FROM detection.events WHERE severity >= 4;

CREATE OR REPLACE VIEW core.v_approved_providers AS
SELECT id, slug, display_name, category, risk_level, data_residency
FROM core.ai_providers WHERE approved = TRUE;
SQLEOF

cat > database/postgresql/init/008-seed.sql <<'SQLEOF'
INSERT INTO admin.orgaos (codigo_siafi, nome, sigla, esfera, poder) VALUES
 ('00001','Agência Nacional de Proteção de Dados','ANPD','FEDERAL','EXECUTIVO'),
 ('00010','Serviço Federal de Processamento de Dados','SERPRO','FEDERAL','EXECUTIVO'),
 ('00020','Receita Federal do Brasil','RFB','FEDERAL','EXECUTIVO')
ON CONFLICT DO NOTHING;

INSERT INTO core.ai_providers (slug, display_name, category, risk_level, approved, data_residency) VALUES
 ('openai-chatgpt','OpenAI ChatGPT','llm_web',4,FALSE,'US'),
 ('anthropic-claude','Anthropic Claude','llm_web',4,FALSE,'US'),
 ('maritaca-mara','Maritaca AI (MARA)','llm_api',1,TRUE,'BR'),
 ('cursor-ide','Cursor IDE','ide_assistant',5,FALSE,'US')
ON CONFLICT DO NOTHING;
SQLEOF

cat > database/postgresql/init/009-partitions.sql <<'SQLEOF'
-- Partições iniciais; as futuras são criadas pelo CronJob (create_monthly_partition).
CREATE TABLE IF NOT EXISTS detection.events_2026_07 PARTITION OF detection.events FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS detection.events_2026_08 PARTITION OF detection.events FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS detection.events_2026_09 PARTITION OF detection.events FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
SQLEOF

cat > database/postgresql/postgresql.conf <<'EOF'
# Tuning para ~256GB RAM / workload OLTP+analytics leve (ajuste ao node)
listen_addresses = '*'
max_connections = 300
shared_buffers = 64GB
effective_cache_size = 192GB
work_mem = 256MB
maintenance_work_mem = 2GB
wal_level = logical
max_wal_senders = 10
synchronous_commit = on
log_min_duration_statement = 500
log_statement = 'ddl'
timezone = 'America/Sao_Paulo'
EOF

cat > database/postgresql/pg_hba.conf <<'EOF'
local   all   all                 peer
host    all   all   127.0.0.1/32  scram-sha-256
host    all   all   10.0.0.0/8    scram-sha-256
hostssl all   all   0.0.0.0/0     scram-sha-256
EOF

cat > database/clickhouse/init.sql <<'SQLEOF'
CREATE DATABASE IF NOT EXISTS govaishield_metrics;
CREATE TABLE IF NOT EXISTS govaishield_metrics.detection_events (
    event_id UUID, orgao_sigla LowCardinality(String),
    provider_slug LowCardinality(String), detection_type LowCardinality(String),
    severity UInt8, dlp_action LowCardinality(String),
    bytes_sent UInt64, bytes_received UInt64,
    detected_at DateTime64(3,'America/Sao_Paulo'),
    detected_date Date DEFAULT toDate(detected_at)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(detected_date)
ORDER BY (orgao_sigla, detected_at, severity)
TTL detected_date + INTERVAL 90 DAY DELETE;
SQLEOF

# =============================================================================
# SOURCE — api-gateway (Go, ZERO dependências externas → build offline)
# =============================================================================
cat > src/api-gateway/go.mod <<'EOF'
module github.com/executt/govaishield/api-gateway

go 1.22
EOF

cat > src/api-gateway/internal/config/config.go <<'GOEOF'
package config

import (
	"os"
	"strings"
)

type Config struct {
	AppEnv string
	Port   string
	PGHost string
	PGPort string
	Kafka  []string
	Redis  string
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func Load() Config {
	return Config{
		AppEnv: get("APP_ENV", "development"),
		Port:   get("APP_PORT", "8080"),
		PGHost: get("POSTGRES_HOST", "localhost"),
		PGPort: get("POSTGRES_PORT", "5432"),
		Kafka:  strings.Split(get("KAFKA_BROKERS", "localhost:9092"), ","),
		Redis:  get("REDIS_HOST", "localhost") + ":" + get("REDIS_PORT", "6379"),
	}
}
GOEOF

cat > src/api-gateway/internal/handlers/health.go <<'GOEOF'
package handlers

import (
	"encoding/json"
	"net"
	"net/http"
	"time"

	"github.com/executt/govaishield/api-gateway/internal/config"
)

// Version é injetado no build via -ldflags.
var Version = "dev"

func Health() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}

// Ready checa dependências com TCP dial (zero dependência de driver).
func Ready(cfg config.Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		checks := map[string]string{
			"postgres": cfg.PGHost + ":" + cfg.PGPort,
			"kafka":    first(cfg.Kafka),
			"redis":    cfg.Redis,
		}
		allOK := true
		result := map[string]string{}
		for name, addr := range checks {
			if addr == "" || addr == ":" {
				result[name] = "not_configured"
				continue
			}
			c, err := net.DialTimeout("tcp", addr, 1500*time.Millisecond)
			if err != nil {
				result[name] = "down"
				allOK = false
			} else {
				_ = c.Close()
				result[name] = "up"
			}
		}
		status := http.StatusOK
		if !allOK {
			status = http.StatusServiceUnavailable
		}
		writeJSON(w, status, map[string]any{"status": boolOK(allOK), "deps": result})
	}
}

func Startup() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "started"})
	}
}

func VersionH() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"version": Version, "service": "api-gateway"})
	}
}

func first(s []string) string {
	if len(s) == 0 {
		return ""
	}
	return s[0]
}
func boolOK(b bool) string {
	if b {
		return "ok"
	}
	return "degraded"
}
func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}
GOEOF

cat > src/api-gateway/cmd/main.go <<'GOEOF'
package main

import (
	"context"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/executt/govaishield/api-gateway/internal/config"
	"github.com/executt/govaishield/api-gateway/internal/handlers"
)

func main() {
	logger := slog.New(slog.NewJSONHandler(os.Stdout, nil))
	slog.SetDefault(logger)
	cfg := config.Load()

	mux := http.NewServeMux() // Go 1.22+ patterns
	mux.HandleFunc("GET /api/v2/health", handlers.Health())
	mux.HandleFunc("GET /api/v2/health/ready", handlers.Ready(cfg))
	mux.HandleFunc("GET /api/v2/health/startup", handlers.Startup())
	mux.HandleFunc("GET /api/v2/version", handlers.VersionH())

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           withMiddleware(mux),
		ReadHeaderTimeout: 5 * time.Second,
		ReadTimeout:       10 * time.Second,
		WriteTimeout:      15 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	go func() {
		logger.Info("api-gateway listening", "port", cfg.Port, "env", cfg.AppEnv)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error("server error", "err", err)
			os.Exit(1)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	logger.Info("shutting down gracefully")
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
}

func withMiddleware(h http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("X-Frame-Options", "DENY")
		w.Header().Set("Strict-Transport-Security", "max-age=31536000; includeSubDomains")
		h.ServeHTTP(w, r)
		slog.Info("request", "method", r.Method, "path", r.URL.Path, "dur_ms", time.Since(start).Milliseconds())
	})
}
GOEOF

cat > src/api-gateway/Dockerfile <<'EOF'
# Multi-stage, non-root, distroless → imagem mínima e segura
FROM golang:1.22-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download || true
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w -X github.com/executt/govaishield/api-gateway/internal/handlers.Version=$(cat /src/VERSION 2>/dev/null || echo dev)" -o /out/api-gateway ./cmd/main.go

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/api-gateway /api-gateway
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/api-gateway"]
EOF

cat > src/api-gateway/api/openapi.yaml <<'YAMLEOF'
openapi: 3.1.0
info: { title: GovAI Shield API, version: 2.0.0 }
servers: [{ url: https://api.govaishield.gov.br/api/v2 }]
paths:
  /health:        { get: { summary: Liveness,  responses: { '200': { description: ok } } } }
  /health/ready:  { get: { summary: Readiness, responses: { '200': { description: ok }, '503': { description: degraded } } } }
  /version:       { get: { summary: Versão,    responses: { '200': { description: ok } } } }
  /detection/events:
    get:
      summary: Listar eventos de detecção
      parameters:
        - { name: orgao, in: query, schema: { type: string } }
        - { name: severity_gte, in: query, schema: { type: integer } }
      responses: { '200': { description: ok }, '401': { description: unauthorized } }
YAMLEOF

# =============================================================================
# SOURCE — dlp-engine (Python/FastAPI, DLP BR com validação real de CPF/CNPJ)
# =============================================================================
cat > src/dlp-engine/pyproject.toml <<'EOF'
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "dlp-engine"
version = "0.1.0"
requires-python = ">=3.12"
dependencies = ["fastapi>=0.111", "uvicorn[standard]>=0.30"]

[project.optional-dependencies]
test = ["pytest>=8", "httpx>=0.27", "ruff>=0.5"]

[tool.setuptools.packages.find]
where = ["src"]
EOF

cat > src/dlp-engine/src/dlp_engine/__init__.py <<'PYEOF'
"""GovAI Shield DLP Engine — regras brasileiras (CPF, CNPJ, processo, sigilo)."""
__version__ = "0.1.0"
PYEOF

cat > src/dlp-engine/src/dlp_engine/rules_br.py <<'PYEOF'
"""Detecção + validação matemática (módulo 11) de CPF/CNPJ e varredura de texto."""
from __future__ import annotations
import re
from dataclasses import dataclass

CPF_RE = re.compile(r"\b(\d{3})\.?(\d{3})\.?(\d{3})-?(\d{2})\b")
CNPJ_RE = re.compile(r"\b(\d{2})\.?(\d{3})\.?(\d{3})/(\d{4})-?(\d{2})\b")
PROCESSO_RE = re.compile(r"\b\d{7}-\d{2}\.\d{4}\.\d\.\d{2}\.\d{4}\b")
CLASSIFICADO = ["ULTRASSECRETO", "SECRETO", "RESERVADO", "SIGILOSO", "USO INTERNO"]


@dataclass
class Finding:
    entity: str
    score: float
    start: int
    end: int
    masked: str


def _mod11(digits: list[int], weights: list[int]) -> int:
    s = sum(d * w for d, w in zip(digits, weights))
    r = (s * 10) % 11
    return 0 if r == 10 else r


def cpf_valid(cpf: str) -> bool:
    d = [int(c) for c in cpf if c.isdigit()]
    if len(d) != 11 or len(set(d)) == 1:
        return False
    w1 = [10, 9, 8, 7, 6, 5, 4, 3, 2]
    w2 = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]
    return _mod11(d[:9], w1) == d[9] and _mod11(d[:10], w2) == d[10]


def cnpj_valid(cnpj: str) -> bool:
    d = [int(c) for c in cnpj if c.isdigit()]
    if len(d) != 14:
        return False
    w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    return _mod11(d[:12], w1) == d[12] and _mod11(d[:13], w2) == d[13]


def scan(text: str) -> list[Finding]:
    out: list[Finding] = []
    for m in CPF_RE.finditer(text):
        if cpf_valid(m.group(0)):
            out.append(Finding("BR_CPF", 0.97, m.start(), m.end(), "***.***.***-**"))
    for m in CNPJ_RE.finditer(text):
        if cnpj_valid(m.group(0)):
            out.append(Finding("BR_CNPJ", 0.96, m.start(), m.end(), "**.***.***/****-**"))
    for m in PROCESSO_RE.finditer(text):
        out.append(Finding("BR_PROCESSO_JUDICIAL", 0.90, m.start(), m.end(), "*******-**.****.*.**.****"))
    up = text.upper()
    for kw in CLASSIFICADO:
        i = up.find(kw)
        if i >= 0:
            out.append(Finding("BR_DADO_CLASSIFICADO", 1.0, i, i + len(kw), "[CLASSIFICADO]"))
    return out


def decide(findings: list[Finding], block_thr: float = 0.85, anon_thr: float = 0.50) -> str:
    if not findings:
        return "ALLOW"
    mx = max(f.score for f in findings)
    if any(f.entity == "BR_DADO_CLASSIFICADO" for f in findings):
        return "BLOCK"
    if mx >= block_thr:
        return "BLOCK"
    if mx >= anon_thr:
        return "ANONYMIZE"
    return "ALLOW"
PYEOF

cat > src/dlp-engine/src/dlp_engine/api.py <<'PYEOF'
from fastapi import FastAPI
from pydantic import BaseModel
from .rules_br import scan, decide

app = FastAPI(title="GovAI Shield DLP Engine", version="0.1.0")


class InspectReq(BaseModel):
    text: str
    block_threshold: float = 0.85
    anonymize_threshold: float = 0.50


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/inspect")
def inspect(req: InspectReq):
    findings = scan(req.text)
    action = decide(findings, req.block_threshold, req.anonymize_threshold)
    return {
        "action": action,
        "entities_found": [
            {"type": f.entity, "score": f.score, "start": f.start, "end": f.end, "masked": f.masked}
            for f in findings
        ],
    }
PYEOF

cat > src/dlp-engine/tests/test_rules_br.py <<'PYEOF'
from dlp_engine.rules_br import cpf_valid, cnpj_valid, scan, decide


def test_cpf_valido_e_invalido():
    assert cpf_valid("529.982.247-25") is True
    assert cpf_valid("111.111.111-11") is False
    assert cpf_valid("123.456.789-00") is False


def test_cnpj_valido():
    assert cnpj_valid("11.222.333/0001-81") is True
    assert cnpj_valid("00.000.000/0000-00") is False


def test_scan_e_decide_block():
    f = scan("Veja o CPF 529.982.247-25 e o documento RESERVADO anexo.")
    types = {x.entity for x in f}
    assert "BR_CPF" in types and "BR_DADO_CLASSIFICADO" in types
    assert decide(f) == "BLOCK"


def test_scan_allow():
    assert scan("Nenhum dado sensivel aqui, apenas texto comum.") == []
PYEOF

cat > src/dlp-engine/Dockerfile <<'EOF'
FROM python:3.12-slim AS build
WORKDIR /app
COPY pyproject.toml ./
COPY src ./src
RUN pip install --no-cache-dir --user .

FROM python:3.12-slim
RUN useradd -r -u 10001 app
COPY --from=build /root/.local /home/app/.local
COPY --from=build /app /app
ENV PATH=/home/app/.local/bin:$PATH PYTHONDONTWRITEBYTECODE=1
USER 10001
WORKDIR /app
EXPOSE 8081
CMD ["uvicorn","dlp_engine.api:app","--host","0.0.0.0","--port","8081"]
EOF

# =============================================================================
# SOURCE — policy-engine (OPA / Rego)
# =============================================================================
cat > src/policy-engine/policies/shadow_ai.rego <<'EOF'
package govaishield.ai_policy

import future.keywords.in

default allow := false

# Modelo nacional homologado e dado não ultrassecreto → permite
allow {
    input.ai_provider in data.approved_providers.nacionais
    input.data_classification != "ULTRASSECRETO"
    input.user_authenticated == true
}

# Bloqueia IA não homologada para dado sensível
deny[msg] {
    input.data_classification in ["DADO_PESSOAL_SENSIVEL", "DADO_SAUDE"]
    not input.ai_provider in data.approved_providers.homologados
    msg := sprintf("IA %s não homologada para dado sensível", [input.ai_provider])
}

# Dados classificados nunca saem da GOVNET
deny[msg] {
    input.data_classification in ["ULTRASSECRETO", "SECRETO", "RESERVADO"]
    input.destination_network != "GOVNET"
    msg := "Dados classificados não podem sair da GOVNET"
}

# Quota
deny[msg] {
    input.daily_tokens_used > input.quota_max_tokens
    msg := "Quota diária de tokens excedida"
}

# Agentes autônomos exigem aprovação humana
deny[msg] {
    input.request_type == "AGENT_AUTONOMOUS"
    not input.has_human_approval
    msg := "Agente autônomo requer aprovação humana (Marco Legal IA, Art. 12)"
}
EOF

cat > src/policy-engine/policies/data.json <<'EOF'
{
  "approved_providers": {
    "nacionais": ["maritaca-mara", "sabia-3"],
    "homologados": ["maritaca-mara", "sabia-3", "enterprise-copilot-gov"]
  }
}
EOF

cat > src/policy-engine/tests/shadow_ai_test.rego <<'EOF'
package govaishield.ai_policy

test_allow_nacional {
    allow with input as {
        "ai_provider": "maritaca-mara",
        "data_classification": "DADO_PESSOAL",
        "user_authenticated": true,
    } with data.approved_providers.nacionais as ["maritaca-mara"]
}

test_deny_dado_classificado_fora_govnet {
    count(deny) > 0 with input as {
        "data_classification": "SECRETO",
        "destination_network": "INTERNET",
    }
}
EOF

# =============================================================================
# SOURCE — shared schemas / kafka topics
# =============================================================================
cat > src/shared/schemas/detection_event.json <<'EOF'
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "DetectionEvent",
  "type": "object",
  "required": ["event_id", "orgao_id", "detection_type", "severity", "detected_at"],
  "properties": {
    "event_id": { "type": "string", "format": "uuid" },
    "orgao_id": { "type": "string", "format": "uuid" },
    "provider_id": { "type": ["string", "null"], "format": "uuid" },
    "detection_type": { "enum": ["network", "dns", "process", "file", "ja4"] },
    "source_ip": { "type": "string" },
    "destination_ip": { "type": "string" },
    "severity": { "type": "integer", "minimum": 1, "maximum": 5 },
    "dlp_action": { "enum": ["ALLOW", "ANONYMIZE", "BLOCK", null] },
    "detected_at": { "type": "string", "format": "date-time" }
  }
}
EOF

cat > src/event-bus/kafka/topics.yaml <<'YAMLEOF'
topics:
  - { name: detection.events,  partitions: 12, replication: 3, retention_ms: 604800000 }
  - { name: policy.decisions,  partitions: 6,  replication: 3, retention_ms: 604800000 }
  - { name: dlp.results,       partitions: 6,  replication: 3, retention_ms: 604800000 }
  - { name: audit.log,         partitions: 6,  replication: 3, cleanup_policy: compact }
  - { name: alerts,            partitions: 3,  replication: 3, retention_ms: 2592000000 }
YAMLEOF

# =============================================================================
# MONITORING
# =============================================================================
cat > monitoring/prometheus/rules/govaishield.yml <<'YAMLEOF'
groups:
  - name: govaishield
    rules:
      - alert: ShadowAISpike
        expr: rate(govaishield_detection_events_total{severity="5"}[5m]) > 100
        for: 2m
        labels: { severity: critical }
        annotations:
          summary: "Pico de Shadow AI crítico"
      - alert: DLPBlockActive
        expr: increase(govaishield_dlp_blocked_total[1m]) > 0
        labels: { severity: high }
        annotations:
          summary: "Tentativa de exfiltração via IA bloqueada"
YAMLEOF

cat > monitoring/alertmanager/alertmanager.yml <<'YAMLEOF'
global: { resolve_timeout: 5m }
route:
  receiver: soc
  group_by: ['alertname', 'orgao']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
receivers:
  - name: soc
    webhook_configs: [{ url: 'http://soc-bridge.govaishield.svc:9000/alerts' }]
YAMLEOF

cat > monitoring/grafana/dashboards/overview.json <<'EOF'
{
  "title": "GovAI Shield — Overview",
  "schemaVersion": 39,
  "timezone": "America/Sao_Paulo",
  "panels": [
    {
      "type": "timeseries",
      "title": "Eventos de detecção por severidade",
      "gridPos": { "h": 8, "w": 24, "x": 0, "y": 0 },
      "datasource": { "type": "prometheus", "uid": "prometheus" },
      "targets": [
        { "expr": "sum by (severity) (rate(govaishield_detection_events_total[5m]))", "legendFormat": "sev {{severity}}" }
      ]
    }
  ],
  "time": { "from": "now-6h", "to": "now" }
}
EOF

# =============================================================================
# TESTS / SCRIPTS
# =============================================================================
cat > tests/load/k6/detection-events.js <<'EOF'
import http from 'k6/http';
import { check } from 'k6';
export const options = { stages: [{ duration: '30s', target: 200 }, { duration: '1m', target: 1000 }, { duration: '30s', target: 0 }] };
export default function () {
  const r = http.get('http://localhost:8080/api/v2/health');
  check(r, { 'health 200': (res) => res.status === 200 });
}
EOF

cat > scripts/generate-certs.sh <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
mkdir -p certs
openssl req -x509 -newkey rsa:4096 -sha256 -days 365 -nodes \
  -keyout certs/ca.key -out certs/ca.crt -subj "/CN=GovAI Shield Dev CA"
openssl req -newkey rsa:2048 -nodes -keyout certs/server.key -out certs/server.csr -subj "/CN=api-gateway"
openssl x509 -req -in certs/server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/server.crt -days 365
echo "✅ certs/ gerado (SÓ para dev!)"
EOF
chmod +x scripts/generate-certs.sh 2>/dev/null || true

cat > scripts/setup-dev.sh <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
echo "Subindo infra local..."
docker compose -f deploy/docker-compose.infra.yml up -d
echo "Aguardando PostgreSQL..."
until docker compose -f deploy/docker-compose.infra.yml exec -T postgres pg_isready -U govaishield >/dev/null 2>&1; do sleep 1; done
echo "✅ Infra pronta. Rode o gateway: cd src/api-gateway && go run ./cmd/main.go"
EOF
chmod +x scripts/setup-dev.sh 2>/dev/null || true

# =============================================================================
# DOCS (os que faltavam: 00,01,06,07,08,09,10,11,12,13,14)
# =============================================================================
cat > docs/00-INDEX.md <<'MDEOF'
# Índice da Documentação

| # | Documento | Para quem |
|---|-----------|-----------|
| 01 | Arquitetura | Arquitetos, SRE |
| 02 | APIs e Rotas | Devs backend/integração |
| 03 | Portas e Rede | Rede, SecOps |
| 04 | Lógica Negocial | PO, auditoria, jurídico |
| 05 | Lógica Técnica | Devs |
| 06 | Schema de BD | DBA |
| 07 | Pontos de Função | Gestão, contratação (SISP) |
| 08 | Deploy OpenShift | SRE, DevOps |
| 09 | DevSecOps | SecOps, DevOps |
| 10 | SRE Runbooks | SRE, SOC |
| 11 | Threat Model | SecOps |
| 12 | Observabilidade | SRE |
| 13 | Disaster Recovery | SRE, gestão |
| 14 | Glossário | Todos |
MDEOF

cat > docs/01-ARCHITECTURE.md <<'MDEOF'
# 01 — Arquitetura

## Pilares
1. **DETECT** — agente eBPF (kernel) + JA4 + DNS + ML
2. **GOVERN** — AI Gateway + DLP + OPA (policy-as-code)
3. **AUDIT** — trilha WORM + hash chain + âncora DOU
4. **COMPLY** — LGPD, Marco Legal IA (Lei 14.879/2024), LAI
5. **DISCLOSE** — portal de transparência ao cidadão

## Camadas (OpenShift)
- **Frontend**: Dashboard (React), Transparency Portal (Next.js)
- **API**: api-gateway (Go, net/http) — auth, rate-limit, routing
- **Serviços**: detection-service, dlp-engine (Python), policy-engine (OPA), audit-service
- **Eventos**: Kafka (KRaft/Strimzi) + Flink (CEP)
- **Dados**: PostgreSQL 16 (Crunchy, HA), ClickHouse (analytics), MinIO (WORM), Redis (cache/rate)
- **Node**: detection-agent (DaemonSet eBPF)

## ADRs (resumo)
- **ADR-001** Event-driven com Kafka (replay, desacoplamento, picos de 45k ev/s).
- **ADR-002** eBPF kernel-level (impossível bypass sem root; overhead <2%).
- **ADR-003** PostgreSQL 16 + particionamento mensal por `detected_at`.
- **ADR-004** ClickHouse para analytics (850M ev/dia; 100x vs PG em GROUP BY).
- **ADR-005** OPA/Rego GitOps (hot-reload, testável, padrão CNCF).
- **ADR-006** MinIO Object Lock (WORM, 5 anos) para auditoria imutável.
- **ADR-007** OpenShift 4.14+ (SCC, Operators, Service Mesh, ICP-Brasil/Gov.br).
- **ADR-008** api-gateway **zero dependências externas** (stdlib Go 1.22) → supply-chain mínima.

## Padrões
CQRS, Saga (detect→DLP→policy→audit), Circuit Breaker, Bulkhead, Sidecar (OPA/Envoy), DaemonSet (agent), Event Sourcing (audit), Repository (data access), Chain of Responsibility (DLP).

## Multi-tenancy por namespace
`govaishield-system`, `-data`, `-monitoring`, `-kafka`, e `-<orgao>` (config/policies/quotas por órgão).
MDEOF

cat > docs/06-DATABASE-SCHEMA.md <<'MDEOF'
# 06 — Schema de Banco de Dados

## PostgreSQL 16
- **Schemas**: `core`, `detection`, `policy`, `audit`, `dlp`, `admin`.
- **Tabelas principais**: `admin.orgaos`, `admin.usuarios` (CPF em hash SHA-256, nunca plaintext), `core.ai_providers`, `core.detection_signatures`, `detection.events` (**particionada** por mês), `policy.policies`, `policy.decisions`, `audit.trail`, `dlp.rules`, `admin.config`.
- **Particionamento**: `detection.events` por RANGE(`detected_at`); partição futura criada por CronJob (`create_monthly_partition`).
- **Índices**: GIN em `dlp_entities`; parciais em `severity>=4` e `status!='RESOLVED'`.
- **Imutabilidade de CPF**: armazenado apenas como `cpf_hash`; reversão impossível por construção (LGPD: minimização).
- **Tuning** (`postgresql.conf`): `shared_buffers=64GB`, `effective_cache_size=192GB`, `wal_level=logical`, `synchronous_commit=on`, HA 1 primary + 2 síncronas (Crunchy).

## ClickHouse
- `detection_events` (MergeTree, particionado por mês, TTL 90d hot → cold).
- Materialized Views (`SummingMergeTree`) para dashboards por órgão/hora.

## Redis
- `ratelimit:{ip}:{min}`, `quota:{user}:{date}:tokens`, `cache:provider:{slug}`, `cache:policy:bundle:{orgao}`.

## MinIO (WORM)
- Bucket `govaishield-audit` com Object Lock (GOVERNANCE, 1825 dias). Conteúdo da trilha = JSON assinado (Ed25519) com hash chain SHA-256.

## Estratégia de backup
- PG: pgBackRest (full semanal + incr diário + WAL contínuo) → S3/MinIO.
- RPO ≤ 5 min, RTO ≤ 30 min (ver doc 13).
MDEOF

cat > docs/07-FUNCTION-POINTS.md <<'MDEOF'
# 07 — Contagem de Pontos de Função (APF / IFPUG)

> Metodologia: **IFPUG 4.3.1**, aderente ao **Roteiro de Métricas de Software do SISP** (governo federal BR), usado para dimensionamento/contratação (APS) e medição de produtividade. Contagem do tipo **indicativa/estimativa** do escopo v2.0.

## Pesos (tabela IFPUG)
| Função | Baixa | Média | Alta |
|--------|:---:|:---:|:---:|
| ALI (ILF) | 7 | 10 | 15 |
| AIE (EIF) | 5 | 7 | 10 |
| EE (EI) | 3 | 4 | 6 |
| SE (EO) | 4 | 5 | 7 |
| CE (EQ) | 3 | 4 | 6 |

## Arquivos Lógicos Internos (ALI / ILF)
| ALI | Complex. | PF |
|-----|:---:|:---:|
| orgaos | Média | 10 |
| usuarios | Alta | 15 |
| ai_providers | Média | 10 |
| detection_signatures | Média | 10 |
| detection_events (partic.) | Alta | 15 |
| policies | Média | 10 |
| policy_versions | Baixa | 7 |
| decisions | Média | 10 |
| audit_trail | Alta | 15 |
| dlp_rules | Média | 10 |
| config | Baixa | 7 |
| quotas | Baixa | 7 |
| incidents | Média | 10 |
| **Subtotal ALI** | | **136** |

## Arquivos de Interface Externa (AIE / EIF)
| AIE | Complex. | PF |
|-----|:---:|:---:|
| catálogo threat-intel externo | Média | 7 |
| IdP Gov.br | Baixa | 5 |
| âncora DOU | Baixa | 5 |
| catálogo modelos nacionais | Média | 7 |
| **Subtotal AIE** | | **24** |

## Entradas Externas (EE / EI)
| EE | Complex. | PF |
|----|:---:|:---:|
| ingest_event | Média | 4 |
| ingest_bulk | Alta | 6 |
| create_provider | Média | 4 |
| approve_provider | Média | 4 |
| create_policy | Alta | 6 |
| update_policy | Alta | 6 |
| inspect_dlp | Alta | 6 |
| evaluate_policy | Média | 4 |
| create_user | Média | 4 |
| assign_roles | Média | 4 |
| create_dlp_rule | Média | 4 |
| acknowledge_event | Baixa | 3 |
| verify_audit | Média | 4 |
| export_audit | Alta | 6 |
| create_orgao | Média | 4 |
| **Subtotal EE** | | **69** |

## Saídas Externas (SE / EO)
| SE | Complex. | PF |
|----|:---:|:---:|
| report_monthly | Alta | 7 |
| export_tcu | Alta | 7 |
| alert_emit | Média | 5 |
| realtime_ws | Alta | 7 |
| dashboard_aggregations | Alta | 7 |
| transparency_report | Média | 5 |
| ripd_generation | Alta | 7 |
| **Subtotal SE** | | **45** |

## Consultas Externas (CE / EQ)
| CE | Complex. | PF |
|----|:---:|:---:|
| list_events | Média | 4 |
| get_event | Baixa | 3 |
| stats | Média | 4 |
| list_providers | Baixa | 3 |
| get_provider | Baixa | 3 |
| list_policies | Baixa | 3 |
| transparency_orgaos | Baixa | 3 |
| timeline_user | Média | 4 |
| audit_trail_query | Média | 4 |
| **Subtotal CE** | | **31** |

## Pontos de Função Não-Ajustados (PFNA)
`136 + 24 + 69 + 45 + 31 =` **305 PFNA**

## Fator de Ajuste (VAF) — 14 Características Gerais de Sistema
| # | Característica | Grau (0-5) |
|---|----------------|:---:|
| 1 | Comunicação de dados | 5 |
| 2 | Processamento distribuído | 4 |
| 3 | Performance | 5 |
| 4 | Utilização do equipamento | 4 |
| 5 | Volume de transações | 5 |
| 6 | Entrada de dados on-line | 4 |
| 7 | Eficiência do usuário final | 3 |
| 8 | Atualização on-line | 5 |
| 9 | Processamento complexo | 5 |
| 10 | Reusabilidade | 4 |
| 11 | Facilidade de instalação | 3 |
| 12 | Facilidade operacional | 3 |
| 13 | Múltiplos locais | 4 |
| 14 | Facilidade de mudanças | 5 |
| **TDI** | | **54** |

`VAF = 0,65 + (0,01 × 54) = 1,19`

## Pontos de Função Ajustados (PFA)
`PFA = 305 × 1,19 =` **≈ 363 PF**

## Uso para contratação (referência SISP)
- Produtividade de referência (desenvolvimento): **~6 a 11 h/PF** (varia por linguagem/pontos de função de ajuste do órgão).
- Esforço estimado (faixa): **363 × [6..11] ≈ 2.178 a 3.993 horas-homem**.
- *Valores em R$ dependem do preço-hora do contrato/APS vigente; esta contagem fornece a **grandeza** objetiva e auditável.*

> ⚠️ Contagem **estimativa**. A contagem **detalhada** (com DET/RET por função e evidências) deve ser produzida no detalhamento do projeto, conforme Roteiro SISP, e revisada por contador certificado (CFPS) quando usada em contrato.
MDEOF

cat > docs/08-OPENSHIFT-DEPLOYMENT.md <<'MDEOF'
# 08 — Deploy no OpenShift

## Pré-requisitos
- OCP 4.14+, `oc` autenticado com permissão de criar projeto.
- Operators: **CrunchyData** (PG), **Strimzi** (Kafka), **MinIO**, **Grafana/Prometheus** (ou monitoring stack do cluster).
- Cluster-admin para aplicar o **SCC** `govaishield-ebpf` (doc/manifest 01).

## Ordem de aplicação (importa)
