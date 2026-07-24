# 13 — Disaster Recovery

| Ativo | Estratégia | RPO | RTO |
|---|---|:--:|:--:|
| PostgreSQL | pgBackRest + réplica síncrona + DR assíncrona | ≤5min | ≤30min |
| Kafka | replicação 3x + MirrorMaker2 p/ DR | ≤1min | ≤15min |
| MinIO (WORM) | versioning + replicação cross-DC | 0 | ≤1h |
| ClickHouse | réplicas/shard + rebuild de MV | ≤1h | ≤2h |
| Manifests | GitOps (ArgoCD) — reconstrói cluster do zero | 0 | ≤1h |

## Failover
1. Declarar incidente + comitê de crise. 2. Promover réplica PG do DC secundário; repontar Service/DNS. 3. Validar hash chain no DR (`/audit/verify`). 4. Comunicar ANPD/TCU se houver impacto a dados pessoais.

## Testes
DR drill **trimestral** (failover real controlado) c/ relatório + lições aprendidas.
