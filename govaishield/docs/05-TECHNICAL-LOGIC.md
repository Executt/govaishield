# 05 — Lógica Técnica

## 1. Detection Agent (eBPF)
Kernel-space: tracepoints `sys_enter_connect` / `sys_enter_execve` + kprobe `tcp_sendmsg` (JA4) → BPF maps (`ai_providers_map` LRU_HASH ip/port→id; `process_map` pid→info; `events_ringbuf`; `dns_queries_map`). User-space (Go): RingBuf reader → Enricher (JA4 + correlação DNS 30s) → Batcher (100 ev ou 5s) → Kafka producer.

Algoritmo: p/ cada connect de saída extrai src/dst ip+port+pid+uid → lookup em `ai_providers_map` (senão JA4 via uprobe OpenSSL) → lookup processo (nome, cmdline, cgroup/container) → correlaciona DNS recente → score = f(risk, volume, encrypted, is_agent) → emite no ringbuf.

## 2. JA4 (TLS sem MITM)
`JA4 = {proto}{tlsver}{SNI}{cipher_hash}_{ext_hash}_{alpn_hash}`. Ex.: openai-python `t13d1517h2_8daaf6152771_e5627efa2ab1`. Base 200+ fingerprints. Identifica SDK mesmo com TLS 1.3/QUIC, **sem** decifrar.

## 3. DLP (Chain of Responsibility)
(1) Regex rápido (CPF/CNPJ) → score<0.3 ALLOW fast-path · (2) NER spaCy `pt_core_news_lg` → <0.5 ALLOW · (3) Presidio + regras BR → <0.85 ANONYMIZE · (4) ≥0.85 BLOCK+alert+audit. CPF/CNPJ usam **validação módulo 11** (não só regex) → corta falsos-positivos.

## 4. Policy Engine (OPA)
Request → ext_authz → OPA carrega bundle (Git sync 30s) → avalia input contra políticas → ALLOW(200)/DENY(403)/ANONYMIZE(200+sanitized). Input inclui `user_id, orgao, role, ai_provider, provider_risk_level, data_classification, dlp_entities_found, dlp_max_score, request_type, daily_tokens_used, quota_max_tokens, is_agent_autonomous, destination_network`.

## 5. Kafka + Flink
Topics: `detection.events`(12p) · `policy.decisions`(6p) · `dlp.results`(6p) · `audit.log`(6p, compact, ∞) · `alerts`(3p). Retenção 7d (30d alerts). Flink CEP: *Shadow AI Spike* (sev≥4, >100 em 5min p/ mesmo órgão → CRITICAL+auto-block temp) · *Data Exfiltration* (DLP BLOCK em CPF/CNPJ/CLASSIFICADO → incidente+SOC) · *Quota Exhaustion* (>10 DENY quota em 1h p/ mesmo user → HIGH).

## 6. Hash chain (auditoria)
`record = {sequence, timestamp, event_type, event_data, prev_hash}`; `hash = SHA256(canonical(record))`; `signature = Ed25519(hash, orgao_key)`; escrita WORM MinIO (`govaishield-audit`, GOVERNANCE 1825d). Verificação: recompute hash + checa `prev_hash` encadeado + valida assinatura; qualquer falha = TAMPERED/CHAIN_BROKEN. Âncora DOU = hash do último bloco da semana.

## 7. Resiliência
Circuit Breaker (sony/gobreaker: thr=5, to=30s) · Retry exp backoff+jitter (max3) · Bulkhead (pool 100/serviço) · Timeouts (API 10s, DLP 5s, OPA 2s) · Fallback (cache última decisão OPA 60s) · DLQ (`dlq.detection.events` após 3 retries).

## 8. Cache (Redis)
`provider:{slug}` 5m · `policy:bundle:{orgao}` 30s · `quota:{user}:{date}` 24h · `ratelimit:{ip}` 1m · `session:{jwt_id}` TTL · `dlp:rules:active` 5m · `ja4:{fp}` 1h.
