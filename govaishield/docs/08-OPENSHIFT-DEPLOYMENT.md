# 08 — Deploy no OpenShift

## Pré-requisitos
- OCP 4.14+, `oc` autenticado com permissão de criar projeto.
- Operators: **CrunchyData** (PG), **Strimzi** (Kafka), **MinIO**, **Grafana/Prometheus** (ou monitoring stack do cluster).
- Cluster-admin para aplicar o **SCC** `govaishield-ebpf` (doc/manifest 01).

## Ordem de aplicação (importa)
