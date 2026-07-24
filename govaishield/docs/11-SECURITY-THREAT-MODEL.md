# 11 — Threat Model (MITRE ATT&CK + STRIDE)

## Vetores Shadow AI
| Tática | Técnica | Vetor |
|---|---|---|
| Exfiltration | T1048/T1567 | prompt com dados / upload p/ API de IA |
| Collection | T1119 | Copilot/Cursor indexa codebase c/ segredos |
| C2 | T1071 | IA como canal disfarçado |
| Evasion | T1573 | TLS 1.3/QUIC sem inspeção |
| Supply chain | T1195 | extensão de IA maliciosa |

## STRIDE
Spoofing (credencial de outro setor) · Tampering (prompt injection) · Repudiation ("não fui eu") · Info disclosure (cidadão no prompt) · DoS (quota esgotada) · Elevation (IA c/ acesso além do escopo).

## Detecção em tráfego encriptado (sem MITM de tráfego pessoal)
1. JA4 passivo (identifica SDK). 2. Correlação DNS (inclusive DoH via agente local). 3. ML de padrão (req pequeno → SSE streaming grande; entropia). 4. mTLS **só** na rede interna (sidecar Envoy + CA ICP-Brasil).

## Controles da própria plataforma
Agente eBPF c/ IMA/EVM; catálogo assinado (cosign); DLP ensemble (regex+NER+ML); WORM + hash chain; dual-control 4-eyes p/ admins; bug bounty público; SCC mínimo (capabilities exatas, não privileged solto).
