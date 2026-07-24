INSERT INTO admin.orgaos (codigo_siafi, nome, sigla, esfera, poder) VALUES
 ('00001','Agência Nacional de Proteção de Dados','ANPD','FEDERAL','EXECUTIVO'),
 ('00010','Serviço Federal de Processamento de Dados','SERPRO','FEDERAL','EXECUTIVO'),
 ('00020','Receita Federal do Brasil','RFB','FEDERAL','EXECUTIVO')
ON CONFLICT DO NOTHING;

INSERT INTO core.ai_providers (slug, display_name, category, risk_level, approved, data_residency) VALUES
 ('openai-chatgpt','OpenAI ChatGPT','llm_web',4,FALSE,'US'),
 ('anthropic-claude','Anthropic Claude','llm_web',4,FALSE,'US'),
 ('maritaca-mara','Maritaca AI (MARA)','llm_api',1,TRUE,'BR'),
 ('cursor-ide','Cursor IDE','ide_assistant',5,FALSE,'US')
ON CONFLICT DO NOTHING;
