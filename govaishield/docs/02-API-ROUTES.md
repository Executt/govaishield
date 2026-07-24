# 02 — APIs e Rotas

## 1. Convenções
| Item | Padrão |
|------|--------|
| Base URL | `https://api.govaishield.gov.br/api/v2` |
| Auth | Bearer JWT (Gov.br OAuth2) + mTLS (ICP-Brasil) service-to-service |
| Content-Type | `application/json; charset=utf-8` |
| Versionamento | URI path (`/v2/`) |
| Paginação | `?page=1&per_page=50` (máx 200) |
| Ordenação | `?sort=detected_at&order=desc` |
| Rate Limit | 1000 req/min (auth) · 100 req/min (público) |
| Idempotência | Header `Idempotency-Key` em POST/PUT |
| Erros | RFC 7807 (Problem Details) |

## 2. Códigos de resposta
200 OK · 201 Created · 204 No Content · 400 Bad Request · 401 Unauthorized · 403 Forbidden · 404 Not Found · 409 Conflict · 422 Unprocessable (regra de negócio) · 429 Too Many Requests · 500 Internal · 503 Unavailable.

## 3. Health & System
| Método | Rota | Auth | Descrição |
|---|---|---|---|
| GET | `/health` | não | liveness |
| GET | `/health/ready` | não | readiness (checa `READY_CHECKS`) |
| GET | `/health/startup` | não | startup |
| GET | `/metrics` | mTLS | Prometheus |
| GET | `/version` | não | versão/build |

## 4. Detection Events
| Método | Rota | RBAC | Descrição |
|---|---|---|---|
| GET | `/detection/events` | read:events | listar (paginado/filtrado) |
| GET | `/detection/events/{id}` | read:events | detalhe |
| POST | `/detection/events` | write:events | ingestão (agente→API) |
| POST | `/detection/events/bulk` | write:events | lote (≤1000) |
| GET | `/detection/events/{id}/raw` | admin:events | payload bruto (forense) |
| DELETE | `/detection/events/{id}` | admin:events | soft-delete (LGPD) |
| GET | `/detection/stats` | read:stats | agregações |
| GET | `/detection/stats/realtime` | read:stats | WebSocket |
| GET | `/detection/timeline` | read:events | timeline do usuário |

Exemplo `GET /detection/events?orgao=RFB&severity_gte=4&since=2026-07-01T00:00:00Z` → `data[]` com `event_id, orgao, provider{slug,risk_level}, detection_type, source_ip, destination_ip, ja4_fingerprint, dlp_action, dlp_entities[], severity, detected_at` + `meta{page,per_page,total}` + `links{self,next,last}`.

## 5. AI Providers
GET `/providers` · GET `/providers/{id}` · POST `/providers` (admin) · PUT `/providers/{id}` (admin) · PATCH `/providers/{id}/approve` (admin) · GET `/providers/{id}/signatures` · POST `/providers/{id}/signatures` (admin) · GET `/providers/approved` · GET `/providers/high-risk`.

## 6. Policies (OPA/Rego)
GET `/policies` · GET `/policies/{id}` · POST `/policies` (admin) · PUT `/policies/{id}` (admin) · DELETE `/policies/{id}` (admin) · POST `/policies/{id}/test` (admin) · GET `/policies/{id}/versions` · POST `/policies/evaluate` (mTLS, service:policy) · GET `/policies/bundles`.

## 7. DLP Engine
POST `/dlp/inspect` (mTLS) · POST `/dlp/inspect/bulk` (mTLS) · GET `/dlp/rules` · POST `/dlp/rules` (admin) · PUT `/dlp/rules/{id}` (admin) · GET `/dlp/entities` · POST `/dlp/anonymize` (mTLS) · GET `/dlp/stats`.

Exemplo `POST /dlp/inspect`:
```json
{"text":"...","context":{"orgao":"RFB","ai_provider":"openai-chatgpt","data_classification":"DADO_PESSOAL"}}
```
→ `{"action":"BLOCK","entities_found":[{"type":"BR_CPF","score":0.97,"masked":"***.***.***-**"}],"policy_applied":"POL-RFB-001"}`.

## 8. Audit Trail
GET `/audit/trail` · GET `/audit/trail/{seq}` · POST `/audit/verify` (admin) · GET `/audit/trail/{seq}/proof` · GET `/audit/export` (admin, TCU/CGU) · GET `/audit/anchor/latest`.

## 9. Transparency (PÚBLICO, sem auth)
GET `/transparency/orgaos` · GET `/transparency/orgaos/{id}/ai-usage` · GET `/transparency/stats/national` · GET `/transparency/reports/{year}/{month}` · GET `/transparency/policies/public`.

## 10. Admin
GET/POST `/admin/users` · PUT `/admin/users/{id}/roles` · GET/POST `/admin/orgaos` · GET/PUT `/admin/config` · POST `/admin/maintenance`.

## 11. Erro (RFC 7807)
```json
{"type":"https://govaishield.gov.br/errors/dlp-block","title":"DLP Block","status":422,
 "detail":"Prompt contém CPF. Envio bloqueado.","instance":"/api/v2/dlp/inspect",
 "timestamp":"2026-07-24T14:32:01Z","trace_id":"abc123"}
```

## 12. WebSocket (tempo real)
`wss://api.govaishield.gov.br/api/v2/detection/stats/realtime` (Bearer JWT) → `{"type":"detection_event","data":{...}}`.
