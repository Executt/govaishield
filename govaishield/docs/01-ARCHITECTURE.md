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
