# 07 — Contagem de Pontos de Função (APF / IFPUG)

> Metodologia: **IFPUG 4.3.1**, aderente ao **Roteiro de Métricas de Software do SISP** (governo federal BR), usado para dimensionamento/contratação (APS) e medição de produtividade. Contagem do tipo **indicativa/estimativa** do escopo v2.0.

## Pesos (tabela IFPUG)
| Função | Baixa | Média | Alta |
|--------|:---:|:---:|:---:|
| ALI (ILF) | 7 | 10 | 15 |
| AIE (EIF) | 5 | 7 | 10 |
| EE (EI) | 3 | 4 | 6 |
| SE (EO) | 4 | 5 | 7 |
| CE (EQ) | 3 | 4 | 6 |

## Arquivos Lógicos Internos (ALI / ILF)
| ALI | Complex. | PF |
|-----|:---:|:---:|
| orgaos | Média | 10 |
| usuarios | Alta | 15 |
| ai_providers | Média | 10 |
| detection_signatures | Média | 10 |
| detection_events (partic.) | Alta | 15 |
| policies | Média | 10 |
| policy_versions | Baixa | 7 |
| decisions | Média | 10 |
| audit_trail | Alta | 15 |
| dlp_rules | Média | 10 |
| config | Baixa | 7 |
| quotas | Baixa | 7 |
| incidents | Média | 10 |
| **Subtotal ALI** | | **136** |

## Arquivos de Interface Externa (AIE / EIF)
| AIE | Complex. | PF |
|-----|:---:|:---:|
| catálogo threat-intel externo | Média | 7 |
| IdP Gov.br | Baixa | 5 |
| âncora DOU | Baixa | 5 |
| catálogo modelos nacionais | Média | 7 |
| **Subtotal AIE** | | **24** |

## Entradas Externas (EE / EI)
| EE | Complex. | PF |
|----|:---:|:---:|
| ingest_event | Média | 4 |
| ingest_bulk | Alta | 6 |
| create_provider | Média | 4 |
| approve_provider | Média | 4 |
| create_policy | Alta | 6 |
| update_policy | Alta | 6 |
| inspect_dlp | Alta | 6 |
| evaluate_policy | Média | 4 |
| create_user | Média | 4 |
| assign_roles | Média | 4 |
| create_dlp_rule | Média | 4 |
| acknowledge_event | Baixa | 3 |
| verify_audit | Média | 4 |
| export_audit | Alta | 6 |
| create_orgao | Média | 4 |
| **Subtotal EE** | | **69** |

## Saídas Externas (SE / EO)
| SE | Complex. | PF |
|----|:---:|:---:|
| report_monthly | Alta | 7 |
| export_tcu | Alta | 7 |
| alert_emit | Média | 5 |
| realtime_ws | Alta | 7 |
| dashboard_aggregations | Alta | 7 |
| transparency_report | Média | 5 |
| ripd_generation | Alta | 7 |
| **Subtotal SE** | | **45** |

## Consultas Externas (CE / EQ)
| CE | Complex. | PF |
|----|:---:|:---:|
| list_events | Média | 4 |
| get_event | Baixa | 3 |
| stats | Média | 4 |
| list_providers | Baixa | 3 |
| get_provider | Baixa | 3 |
| list_policies | Baixa | 3 |
| transparency_orgaos | Baixa | 3 |
| timeline_user | Média | 4 |
| audit_trail_query | Média | 4 |
| **Subtotal CE** | | **31** |

## Pontos de Função Não-Ajustados (PFNA)
`136 + 24 + 69 + 45 + 31 =` **305 PFNA**

## Fator de Ajuste (VAF) — 14 Características Gerais de Sistema
| # | Característica | Grau (0-5) |
|---|----------------|:---:|
| 1 | Comunicação de dados | 5 |
| 2 | Processamento distribuído | 4 |
| 3 | Performance | 5 |
| 4 | Utilização do equipamento | 4 |
| 5 | Volume de transações | 5 |
| 6 | Entrada de dados on-line | 4 |
| 7 | Eficiência do usuário final | 3 |
| 8 | Atualização on-line | 5 |
| 9 | Processamento complexo | 5 |
| 10 | Reusabilidade | 4 |
| 11 | Facilidade de instalação | 3 |
| 12 | Facilidade operacional | 3 |
| 13 | Múltiplos locais | 4 |
| 14 | Facilidade de mudanças | 5 |
| **TDI** | | **54** |

`VAF = 0,65 + (0,01 × 54) = 1,19`

## Pontos de Função Ajustados (PFA)
`PFA = 305 × 1,19 =` **≈ 363 PF**

## Uso para contratação (referência SISP)
- Produtividade de referência (desenvolvimento): **~6 a 11 h/PF** (varia por linguagem/pontos de função de ajuste do órgão).
- Esforço estimado (faixa): **363 × [6..11] ≈ 2.178 a 3.993 horas-homem**.
- *Valores em R$ dependem do preço-hora do contrato/APS vigente; esta contagem fornece a **grandeza** objetiva e auditável.*

> ⚠️ Contagem **estimativa**. A contagem **detalhada** (com DET/RET por função e evidências) deve ser produzida no detalhamento do projeto, conforme Roteiro SISP, e revisada por contador certificado (CFPS) quando usada em contrato.
