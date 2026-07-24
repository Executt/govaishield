# 04 — Lógica Negocial

Derivada de: **LGPD** (13.709/2018), **Marco Legal da IA** (14.879/2024), **LAI** (12.527/2011), classificação de sigilo (Lei 12.527 art. 23-31), **PCI-DSS** (quando aplicável), normas **TCU/CGU**.

## 1. Entidades
Órgão 1—* Servidor 1—* EventoDeDetecção *—1 ProvedorDeIA 1—* AssinaturaDeDetecção; Política *—* Provedor; Política 1—* Decisão; EventoDeDetecção 1—1 RegistroDeAuditoria; Órgão 1—* RelatórioDeTransparência.

## 2. Regras de negócio
- **RN-001 Risco do provedor**: 1 nacional homologado=permitir · 2 SaaS com DPA/UE=permitir+log · 3 externa sem DPA=alertar · 4 jurisdição desconhecida=bloquear por padrão · 5 lista negra ANPD/GSI=bloquear+incidente.
- **RN-002 Dado no prompt** (score): CPF/CNPJ ≥0.85=BLOQUEAR, 0.50–0.84=ANONIMIZAR; **Dado de saúde** ≥0.50=BLOQUEAR; **Dado classificado (sigilo)** qualquer score=BLOQUEAR (+incidente se ≥0.85); telefone/e-mail=alertar/anonimizar; nome (NER)=anonimizar.
- **RN-003 Quotas**: servidor 50k tokens/100 req·dia (risk≤2); gestor/CISO 200k/500 (≤3); TI/dev 500k/1000 (todos homologados); admin ilimitado; órgão 10M/50k.
- **RN-004 Agentes autônomos**: PROIBIDO sem (1) aprovação 4-eyes, (2) sandbox K8s, (3) ≤10 tool calls, (4) log total, (5) kill-switch 5min.
- **RN-005 Modelos locais**: permitidos SE homologado + patch ≤30d + hardware do órgão + sem internet + logs de inferência enviados.
- **RN-006 Auditoria**: imutável, hash chain SHA-256, retenção 5 anos, âncora semanal no DOU; acesso TCU/CGU/ANPD/MPF; cidadão só agregado/anonimizado.
- **RN-007 Transparência**: publicação trimestral por órgão (IAs usadas, finalidade, volume agregado, incidentes); **nunca** conteúdo de prompts.
- **RN-008 Incidente**: sev5=15min (CISO+GSI+ANPD) · 4=1h · 3=4h · 2=24h · 1=dashboard.

## 3. Fluxos
- **Principal**: Servidor usa IA → Detecção(eBPF) classifica provedor/risco → DLP busca CPF/CNPJ/score → Política(OPA) decide ALLOW/BLOCK/ANONYMIZE → Auditoria registra imutável+hash.
- **Homologação**: solicitação → análise técnica (risk+pentest+DPA+jurisdição) → jurídica (LGPD+Marco IA+LAI) → CISO 4-eyes → catálogo público.
- **Incidente**: detecção(sev≥4) → alerta SOC → triagem → contenção (block user/IP via OPA hot-reload) → erradicação → recuperação → post-mortem+update de política.

## 4. Casos de uso
UC-01 usa IA homologada na quota · UC-02 tenta IA não homologada (block) · UC-03 envia CPF (DLP block) · UC-04 CISO vê dashboard · UC-05 admin homologa provedor · UC-06 admin cria política Rego · UC-07 auditor TCU exporta trilha · UC-08 cidadão consulta transparência · UC-09 SOC responde incidente · UC-10 relatório mensal automático · UC-11 admin configura quotas · UC-12 dev registra modelo local.
