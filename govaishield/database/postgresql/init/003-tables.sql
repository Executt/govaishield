CREATE TABLE admin.orgaos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    codigo_siafi VARCHAR(10) UNIQUE NOT NULL,
    nome VARCHAR(255) NOT NULL,
    sigla VARCHAR(20) UNIQUE NOT NULL,
    esfera VARCHAR(20) NOT NULL CHECK (esfera IN ('FEDERAL','ESTADUAL','MUNICIPAL')),
    poder  VARCHAR(20) NOT NULL CHECK (poder IN ('EXECUTIVO','LEGISLATIVO','JUDICIARIO')),
    cnpj VARCHAR(18), ativo BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE admin.usuarios (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    orgao_id UUID NOT NULL REFERENCES admin.orgaos(id),
    cpf_hash VARCHAR(64) UNIQUE NOT NULL,
    nome_hash VARCHAR(64), email VARCHAR(255), cargo VARCHAR(100),
    roles TEXT[] DEFAULT '{}',
    quota_tokens BIGINT DEFAULT 50000, quota_requests INTEGER DEFAULT 100,
    ativo BOOLEAN DEFAULT TRUE, last_login_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE core.ai_providers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    slug VARCHAR(100) UNIQUE NOT NULL, display_name VARCHAR(255) NOT NULL,
    category VARCHAR(50) NOT NULL,
    risk_level SMALLINT NOT NULL CHECK (risk_level BETWEEN 1 AND 5),
    approved BOOLEAN DEFAULT FALSE, approved_by UUID REFERENCES admin.usuarios(id),
    approved_at TIMESTAMPTZ, data_residency VARCHAR(100),
    lgpd_adequacy BOOLEAN DEFAULT FALSE, has_dpa BOOLEAN DEFAULT FALSE,
    api_endpoint VARCHAR(500), website VARCHAR(500), description TEXT,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE core.detection_signatures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    provider_id UUID NOT NULL REFERENCES core.ai_providers(id) ON DELETE CASCADE,
    sig_type VARCHAR(30) NOT NULL CHECK (sig_type IN
      ('DOMAIN','IP_CIDR','JA4','PROCESS','FILE_PATH','PORT','HEADER','TRAFFIC_PATTERN')),
    value VARCHAR(500) NOT NULL, confidence DECIMAL(3,2) DEFAULT 0.90,
    active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE detection.events (
    id BIGSERIAL, event_id UUID NOT NULL DEFAULT uuid_generate_v4(),
    orgao_id UUID NOT NULL, usuario_id UUID, provider_id UUID,
    detection_type VARCHAR(30) NOT NULL,
    source_ip INET, destination_ip INET, destination_port SMALLINT,
    process_name VARCHAR(255), process_cmdline TEXT, container_id VARCHAR(64),
    bytes_sent BIGINT DEFAULT 0, bytes_received BIGINT DEFAULT 0,
    ja4_fingerprint VARCHAR(100), dns_query VARCHAR(500),
    dlp_action VARCHAR(20), dlp_entities JSONB, dlp_max_score DECIMAL(3,2),
    policy_id UUID, policy_decision VARCHAR(20),
    severity SMALLINT NOT NULL CHECK (severity BETWEEN 1 AND 5),
    status VARCHAR(20) DEFAULT 'NEW' CHECK (status IN
      ('NEW','ACKNOWLEDGED','INVESTIGATING','RESOLVED','FALSE_POSITIVE')),
    raw_metadata JSONB DEFAULT '{}', detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, detected_at)
) PARTITION BY RANGE (detected_at);

CREATE TABLE policy.policies (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    orgao_id UUID REFERENCES admin.orgaos(id),
    name VARCHAR(255) NOT NULL, slug VARCHAR(100) UNIQUE NOT NULL,
    description TEXT, rego_code TEXT NOT NULL, version INTEGER NOT NULL DEFAULT 1,
    active BOOLEAN DEFAULT TRUE, priority SMALLINT DEFAULT 100,
    created_by UUID REFERENCES admin.usuarios(id),
    created_at TIMESTAMPTZ DEFAULT NOW(), updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE policy.decisions (
    id BIGSERIAL PRIMARY KEY, event_id UUID NOT NULL,
    policy_id UUID REFERENCES policy.policies(id),
    decision VARCHAR(20) NOT NULL CHECK (decision IN ('ALLOW','DENY','ANONYMIZE','ALERT')),
    reason TEXT, input_snapshot JSONB NOT NULL, evaluated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE audit.trail (
    sequence BIGSERIAL PRIMARY KEY, event_type VARCHAR(50) NOT NULL,
    orgao_id UUID, actor_type VARCHAR(30) NOT NULL, actor_id VARCHAR(100),
    action VARCHAR(100) NOT NULL, resource_type VARCHAR(50), resource_id VARCHAR(100),
    hash VARCHAR(64) NOT NULL, prev_hash VARCHAR(64) NOT NULL,
    signature VARCHAR(128), minio_key VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE dlp.rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL, entity_type VARCHAR(50) NOT NULL,
    pattern_type VARCHAR(30) NOT NULL CHECK (pattern_type IN ('REGEX','NER','KEYWORD','ML')),
    pattern_value TEXT NOT NULL, score_threshold DECIMAL(3,2) DEFAULT 0.85,
    action VARCHAR(20) DEFAULT 'BLOCK', orgao_id UUID REFERENCES admin.orgaos(id),
    active BOOLEAN DEFAULT TRUE, created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE admin.config (
    key VARCHAR(100) PRIMARY KEY, value JSONB NOT NULL, description TEXT,
    updated_by UUID REFERENCES admin.usuarios(id), updated_at TIMESTAMPTZ DEFAULT NOW()
);
