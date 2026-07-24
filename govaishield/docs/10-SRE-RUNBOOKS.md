# 10 — SRE Runbooks

## RB-01 api-gateway CrashLoop
1. `oc logs deploy/api-gateway -p`. 2. `/health/ready` → qual dep `down`? 3. `postgres down`: StatefulSet/PVC/NetworkPolicy. 4. OOMKilled: HPA/limits + Grafana.

## RB-02 Pico de Shadow AI (ShadowAISpike)
1. Dashboard SOC: top órgão/provedor/user. 2. Confirmar em ClickHouse + trilha. 3. Conter: block user/IP via política de emergência (OPA hot-reload). 4. Incidente (RN-008) + escalonamento.

## RB-03 DLP falso-positivo em massa
1. Validar amostra; ajustar `score_threshold` em `dlp.rules`. 2. Regra em modo `ALERT` (shadow) antes de `BLOCK`. 3. Versionar (GitOps) + registrar na trilha.

## RB-04 Hash chain de auditoria rompida
1. `POST /audit/verify` com range → `sequence` rompida. 2. **Não** reescrever (WORM). Isolar + incidente crítico + forense + CGU/TCU. 3. Âncora DOU prova estado válido até o último bloco ancorado.

## RB-05 Readiness 503 após zero-trust
Causa: egress de DNS bloqueado. Conferir netpol `allow-api-gateway` → regra p/ `openshift-dns` (UDP/TCP 5353 ou 53 conforme OCP). Reaplicar; re-testar `/health/ready`.

## RB-06 ImagePullBackOff
Imagem não chegou/tag errada. `describe pod | grep -i -A3 pull`; `get imagestreamtag`. Repetir build+push via `port-forward` no registry interno.

## SLOs
Disponibilidade API **99,95%** · latência p99 overhead gateway **<15ms** · RPO 0 / RTO <30s.
