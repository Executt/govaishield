# 12 — Observabilidade

- **Métricas**: Prometheus + ServiceMonitor; ClickHouse p/ alta cardinalidade.
- **Logs**: Loki; JSON estruturado; `trace_id` correlaciona gateway→DLP→OPA→audit.
- **Traces**: Tempo (OTel) — span por etapa do pipeline de decisão.
- **Dashboards**: Operacional (SOC) · Gerencial (CISO) · Executivo · Transparência (público) · Forense (TCU/CGU).
- **Alertas**: Alertmanager → SOC (webhook/Telegram/PagerDuty); severidades por RN-008.
- **Regras-chave**: `ShadowAISpike`, `DLPBlockActive`, `UnauthorizedModelExecution`, `QuotaExhaustion`.
- **Golden signals** por serviço: latência, tráfego, erros, saturação (RED/USE).
