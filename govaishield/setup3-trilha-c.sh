#!/usr/bin/env bash
# =============================================================================
# GovAI Shield — trilha C (fundação no OpenShift)
# Rode DENTRO da raiz (onde existe README.md):  bash setup3-trilha-c.sh
# =============================================================================
set -uo pipefail
[ -f README.md ] || { echo "❌ rode na raiz do projeto"; exit 1; }
mkdir -p src/api-gateway/internal/handlers src/api-gateway/internal/config deploy/openshift
echo "🛡️  Trilha C — gravando readiness configurável + manifests de fundação..."

# -----------------------------------------------------------------------------
# (1) config.go — ganha ReadyChecks (csv via env READY_CHECKS, default postgres)
# -----------------------------------------------------------------------------
cat > src/api-gateway/internal/config/config.go <<'GOEOF'
package config

import (
	"os"
	"strings"
)

type Config struct {
	AppEnv      string
	Port        string
	PGHost      string
	PGPort      string
	Kafka       []string
	Redis       string
	ReadyChecks []string // dependências que o /health/ready efetivamente checa
}

func get(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func csv(k, def string) []string {
	parts := strings.Split(get(k, def), ",")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

func Load() Config {
	return Config{
		AppEnv:      get("APP_ENV", "development"),
		Port:        get("APP_PORT", "8080"),
		PGHost:      get("POSTGRES_HOST", "localhost"),
		PGPort:      get("POSTGRES_PORT", "5432"),
		Kafka:       strings.Split(get("KAFKA_BROKERS", ""), ","),
		Redis:       get("REDIS_HOST", "") + ":" + get("REDIS_PORT", "6379"),
		ReadyChecks: csv("READY_CHECKS", "postgres"),
	}
}
GOEOF

# -----------------------------------------------------------------------------
# (2) health.go — readiness só checa o que está em ReadyChecks (sem deps externas)
# -----------------------------------------------------------------------------
cat > src/api-gateway/internal/handlers/health.go <<'GOEOF'
package handlers

import (
	"encoding/json"
	"net"
	"net/http"
	"strings"
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

// Ready checa APENAS as dependências listadas em READY_CHECKS (default: postgres).
// Deps não listadas não aparecem no resultado (não contam como "down").
// Assim o serviço fica Ready no cluster mesmo antes de Kafka/Redis existirem.
func Ready(cfg config.Config) http.HandlerFunc {
	addrs := map[string]string{
		"postgres": cfg.PGHost + ":" + cfg.PGPort,
		"kafka":    first(cfg.Kafka),
		"redis":    cfg.Redis,
	}
	return func(w http.ResponseWriter, r *http.Request) {
		result := map[string]string{}
		allOK := true
		for _, name := range cfg.ReadyChecks {
			addr := addrs[name]
			if addr == "" || addr == ":" || strings.HasPrefix(addr, ":") {
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
		writeJSON(w, status, map[string]any{"status": boolOK(allOK), "checks": cfg.ReadyChecks, "deps": result})
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

# -----------------------------------------------------------------------------
# (3) c-foundation.yaml — VITÓRIA 1 (autocontido, SEM cluster-admin, SEM netpol)
#     Namespace é criado via `oc new-project` (não aqui, pra evitar briga de ownership).
#     Postgres vanilla (sem schema ainda): na fundação validamos CONECTIVIDADE+PROBES.
# -----------------------------------------------------------------------------
cat > deploy/openshift/c-foundation.yaml <<'YAMLEOF'
# =============================================================================
# GovAI Shield — Fundação (trilha C / vitória 1)
# Aplica DEPOIS de: oc new-project govaishield
# Não exige cluster-admin. Não inclui o agente eBPF (trilha A).
# =============================================================================
---
apiVersion: v1
kind: Secret
metadata: { name: govaishield-db-credentials, namespace: govaishield }
type: Opaque
stringData:
  POSTGRES_USER: "govaishield"
  POSTGRES_PASSWORD: "DevChangeMe#2026"   # trocar por Vault/ESO em prod (doc 09)
---
apiVersion: v1
kind: Secret
metadata: { name: govaishield-jwt, namespace: govaishield }
type: Opaque
stringData:
  JWT_SECRET: "dev-only-256bit-secret-change-me-please-xxxx"
---
apiVersion: v1
kind: ConfigMap
metadata: { name: govaishield-config, namespace: govaishield }
data:
  APP_ENV: "dev"
  APP_LOG_FORMAT: "json"
  APP_PORT: "8080"
  POSTGRES_HOST: "govaishield-pg.govaishield.svc.cluster.local"
  POSTGRES_PORT: "5432"
  KAFKA_BROKERS: ""          # vazio => /ready não checa kafka nesta fase
  REDIS_HOST: ""             # vazio => /ready não checa redis nesta fase
  READY_CHECKS: "postgres"   # readiness checa SOMENTE postgres por enquanto
---
# --- PostgreSQL 16 vanilla (StatefulSet). Schema/migrações = próxima iteração. ---
apiVersion: v1
kind: Service
metadata: { name: govaishield-pg, namespace: govaishield }
spec:
  selector: { app: govaishield-pg }
  ports: [{ name: postgres, port: 5432, targetPort: 5432 }]
---
apiVersion: apps/v1
kind: StatefulSet
metadata: { name: govaishield-pg, namespace: govaishield }
spec:
  serviceName: govaishield-pg
  replicas: 1
  selector: { matchLabels: { app: govaishield-pg } }
  template:
    metadata: { labels: { app: govaishield-pg } }
    spec:
      securityContext: { runAsNonRoot: true, fsGroup: 70, seccompProfile: { type: RuntimeDefault } }
      containers:
        - name: postgres
          image: postgres:16-alpine
          ports: [{ containerPort: 5432, name: postgres }]
          env:
            - { name: POSTGRES_DB, value: govaishield }
            - { name: POSTGRES_USER, valueFrom: { secretKeyRef: { name: govaishield-db-credentials, key: POSTGRES_USER } } }
            - { name: POSTGRES_PASSWORD, valueFrom: { secretKeyRef: { name: govaishield-db-credentials, key: POSTGRES_PASSWORD } } }
            - { name: PGDATA, value: /var/lib/postgresql/data/pgdata }
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { cpu: "1",  memory: 1Gi }
          securityContext: { allowPrivilegeEscalation: false, capabilities: { drop: [ALL] } }
          livenessProbe:  { exec: { command: ["pg_isready","-U","govaishield"] }, initialDelaySeconds: 15, periodSeconds: 20 }
          readinessProbe: { exec: { command: ["pg_isready","-U","govaishield"] }, initialDelaySeconds: 5,  periodSeconds: 10 }
          volumeMounts: [{ name: pgdata, mountPath: /var/lib/postgresql/data }]
  volumeClaimTemplates:
    - metadata: { name: pgdata }
      spec:
        accessModes: [ReadWriteOnce]
        resources: { requests: { storage: 1Gi } }   # usa o StorageClass default do cluster
---
# --- API Gateway (Go, imagem do registry interno) ---
apiVersion: v1
kind: ServiceAccount
metadata: { name: govaishield-api, namespace: govaishield }
---
apiVersion: v1
kind: Service
metadata: { name: api-gateway, namespace: govaishield }
spec:
  selector: { app: api-gateway }
  ports: [{ name: http, port: 8080, targetPort: 8080 }]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: api-gateway, namespace: govaishield, labels: { app: api-gateway } }
spec:
  replicas: 2
  strategy: { type: RollingUpdate, rollingUpdate: { maxSurge: 1, maxUnavailable: 0 } }
  selector: { matchLabels: { app: api-gateway } }
  template:
    metadata: { labels: { app: api-gateway } }
    spec:
      serviceAccountName: govaishield-api
      securityContext: { runAsNonRoot: true, seccompProfile: { type: RuntimeDefault } }
      containers:
        - name: api-gateway
          image: image-registry.openshift-image-registry.svc:5000/govaishield/api-gateway:latest
          imagePullPolicy: Always
          ports: [{ containerPort: 8080, name: http }]
          envFrom:
            - configMapRef: { name: govaishield-config }
            - secretRef: { name: govaishield-jwt }
          resources:
            requests: { cpu: 100m, memory: 128Mi }
            limits:   { cpu: 500m, memory: 256Mi }
          securityContext: { allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: { drop: [ALL] } }
          startupProbe:   { httpGet: { path: /api/v2/health/startup, port: 8080 }, failureThreshold: 30, periodSeconds: 2 }
          livenessProbe:  { httpGet: { path: /api/v2/health,        port: 8080 }, initialDelaySeconds: 5, periodSeconds: 15 }
          readinessProbe: { httpGet: { path: /api/v2/health/ready,  port: 8080 }, initialDelaySeconds: 3, periodSeconds: 5 }
---
# --- Route (host gerado pelo cluster => universal; descubra com `oc get route`) ---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  name: api-gateway
  namespace: govaishield
  annotations:
    haproxy.router.openshift.io/hsts_header: "max-age=31536000;includeSubDomains;preload"
spec:
  to: { kind: Service, name: api-gateway }
  port: { targetPort: http }
  tls: { termination: edge, insecureEdgeTerminationPolicy: Redirect }
YAMLEOF

# -----------------------------------------------------------------------------
# (4) c-foundation-dlp.yaml — VITÓRIA 2 (segundo runtime: Python). Aplica DEPOIS
#     de buildar/pushar a imagem do dlp-engine. /health do dlp não checa deps.
# -----------------------------------------------------------------------------
cat > deploy/openshift/c-foundation-dlp.yaml <<'YAMLEOF'
apiVersion: v1
kind: Service
metadata: { name: dlp-engine, namespace: govaishield }
spec:
  selector: { app: dlp-engine }
  ports: [{ name: http, port: 8081, targetPort: 8081 }]
---
apiVersion: apps/v1
kind: Deployment
metadata: { name: dlp-engine, namespace: govaishield, labels: { app: dlp-engine } }
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
          imagePullPolicy: Always
          ports: [{ containerPort: 8081, name: http }]
          envFrom: [{ configMapRef: { name: govaishield-config } }]
          resources:
            requests: { cpu: 100m, memory: 256Mi }
            limits:   { cpu: "1",  memory: 768Mi }
          securityContext: { allowPrivilegeEscalation: false, readOnlyRootFilesystem: true, capabilities: { drop: [ALL] } }
          livenessProbe:  { httpGet: { path: /health, port: 8081 }, initialDelaySeconds: 10, periodSeconds: 15 }
          readinessProbe: { httpGet: { path: /health, port: 8081 }, initialDelaySeconds: 5,  periodSeconds: 10 }
YAMLEOF

# -----------------------------------------------------------------------------
# (5) c-foundation-zero-trust.yaml — HARDENING OPCIONAL (aplica POR ÚLTIMO,
#     DEPOIS que /health/ready estiver VERDE). Introduz default-deny + allows.
#     Se ficar vermelho após aplicar: suas allows precisam de ajuste (runbook abaixo).
# -----------------------------------------------------------------------------
cat > deploy/openshift/c-foundation-zero-trust.yaml <<'YAMLEOF'
# Aplica SOMENTE após vitória 1 verde. Fecha o namespace (zero-trust).
---
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
    # DNS do cluster (CoreDNS) — sem isso o Service do PG não resolve
    - to: [{ namespaceSelector: { matchLabels: { kubernetes.io/metadata.name: openshift-dns } } }]
      ports: [{ protocol: UDP, port: 5353 }, { protocol: TCP, port: 5353 }]
    # Postgres
    - to: [{ podSelector: { matchLabels: { app: govaishield-pg } } }]
      ports: [{ protocol: TCP, port: 5432 }]
    # DLP (quando o gateway passar a chamá-lo)
    - to: [{ podSelector: { matchLabels: { app: dlp-engine } } }]
      ports: [{ protocol: TCP, port: 8081 }]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-dlp-engine, namespace: govaishield }
spec:
  podSelector: { matchLabels: { app: dlp-engine } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { app: api-gateway } } }]
      ports: [{ protocol: TCP, port: 8081 }]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata: { name: allow-postgres, namespace: govaishield }
spec:
  podSelector: { matchLabels: { app: govaishield-pg } }
  policyTypes: [Ingress]
  ingress:
    - from: [{ podSelector: { matchLabels: { app: api-gateway } } }]
      ports: [{ protocol: TCP, port: 5432 }]
YAMLEOF

echo "✅ setup3 pronto. Arquivos: $(find . -type f -not -path './.git/*' | wc -l)"
echo "   Próximo: siga o fluxo de cluster abaixo (login → apply → build → push → verify)."
