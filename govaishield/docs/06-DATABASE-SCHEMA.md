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
