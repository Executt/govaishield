# 03 — Portas e Rede

## 1. Mapa de portas
| Serviço | Interna | Externa | Proto | Exposição |
|---|:--:|:--:|:--:|:--:|
| api-gateway | 8080 | 443 (Route) | HTTPS | pública (auth) |
| dlp-engine | 8081 | — | HTTP/mTLS | cluster-only |
| policy-engine (OPA) | 8082 | — | HTTP | cluster-only |
| detection-service | 8083 | — | gRPC | cluster-only |
| audit-service | 8084 | — | gRPC | cluster-only |
| dashboard | 3000 | 443 | HTTPS | pública (auth) |
| transparency-portal | 3001 | 443 | HTTPS | pública (aberta) |
| PostgreSQL | 5432 | — | TCP | cluster-only |
| ClickHouse | 8123/9000 | — | HTTP/TCP | cluster-only |
| Kafka | 9092 | — | TCP | cluster-only |
| Redis | 6379 | — | TCP | cluster-only |
| MinIO | 9000/9001 | — | HTTP | cluster-only |
| Prometheus / Grafana | 9090 / 3000 | 443 | HTTPS | interna |
| Loki / Tempo | 3100 / 3200 | — | HTTP | cluster-only |
| OTEL collector | 4317/4318 | — | gRPC/HTTP | cluster-only |
| detection-agent (eBPF) | n/a | n/a | kernel | node-level |

## 2. NetworkPolicies (zero-trust)
- **default-deny-all**: `podSelector: {}`, `policyTypes: [Ingress,Egress]`.
- **allow-api-gateway**: ingress do `network.openshift.io/policy-group: ingress` na 8080; egress para DNS do cluster (`openshift-dns`, UDP/TCP 5353), `govaishield-pg:5432`, `dlp-engine:8081`, `policy-engine:8082`.
- **allow-postgres**: ingress só de `api-gateway` e `audit-service` na 5432.
- **allow-dlp-engine**: ingress só de `api-gateway` na 8081.

> ⚠️ Sem a regra de **egress de DNS**, o readiness do gateway vira 503 porque o `Service` do Postgres não resolve. Erro mais comum ao ativar zero-trust (ver doc 10).

## 3. Service Mesh (mTLS)
`PeerAuthentication` namespace-wide `mtls.mode: STRICT` (OpenShift Service Mesh / Istio). mTLS **só** na malha interna; tráfego pessoal do servidor **nunca** é decifrado.

## 4. Routes
| Route | Host | TLS |
|---|---|---|
| api-gateway | api.govaishield.* | edge + Redirect + HSTS |
| transparency | transparencia.govaishield.* | edge + Redirect |
| grafana | grafana.govaishield.* | edge (interna) |

## 5. DNS interno
`api-gateway.govaishield.svc.cluster.local:8080`, `govaishield-pg.govaishield.svc.cluster.local:5432` (`-primary`/`-replicas` com Crunchy), `kafka-bootstrap...:9092`, `clickhouse...:8123`, `minio...:9000`, `redis...:6379`.
