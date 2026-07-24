# 🛡️ GovAI Shield

## Plataforma Pública de Governança e Combate ao Shadow AI

[![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)](LICENSE)
[![OpenShift](https://img.shields.io/badge/OpenShift-4.14+-red.svg)](https://www.openshift.com/)
[![Go](https://img.shields.io/badge/Go-1.22+-00ADD8.svg)](https://go.dev/)
[![Python](https://img.shields.io/badge/Python-3.12+-3776AB.svg)](https://python.org/)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-16+-336791.svg)](https://postgresql.org/)

---

## 📋 Sumário

- [Visão Geral](#visão-geral)
- [Problema](#problema)
- [Solução](#solução)
- [Arquitetura](#arquitetura)
- [Componentes](#componentes)
- [Stack Tecnológica](#stack-tecnológica)
- [Quick Start](#quick-start)
- [Deploy no OpenShift](#deploy-no-openshift)
- [Documentação](#documentação)
- [Contribuição](#contribuição)
- [Licença](#licença)

---

## Visão Geral

O **GovAI Shield** é uma plataforma de software público, aberta e soberana para
**detecção, monitoramento, governança e auditoria** do uso de ferramentas de
Inteligência Artificial em organizações públicas brasileiras.

Nasce como resposta ao avanço do **Shadow AI** — o uso não autorizado de IAs
(ChatGPT, Claude, Copilot, Cursor, agentes autônomos, etc.) por servidores
públicos, expondo dados de 215 milhões de cidadãos a riscos de vazamento,
violação da LGPD e descumprimento do Marco Legal da IA (Lei 14.879/2024).

## Problema

| Risco | Impacto |
|-------|---------|
| Exfiltração de dados via prompts | Vazamento de CPF, CNPJ, dados de saúde |
| Agentes autônomos sem supervisão | Ações irreversíveis em sistemas gov |
| Modelos locais sem patch | Vulnerabilidades exploráveis |
| Sem trilha de auditoria | Impossibilidade de accountability |
| Violação LGPD | Multas de até R$ 50M |
| TLS 1.3/QUIC | DLP tradicional ineficaz |

## Solução

