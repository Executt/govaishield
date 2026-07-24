CREATE DATABASE IF NOT EXISTS govaishield_metrics;
CREATE TABLE IF NOT EXISTS govaishield_metrics.detection_events (
    event_id UUID, orgao_sigla LowCardinality(String),
    provider_slug LowCardinality(String), detection_type LowCardinality(String),
    severity UInt8, dlp_action LowCardinality(String),
    bytes_sent UInt64, bytes_received UInt64,
    detected_at DateTime64(3,'America/Sao_Paulo'),
    detected_date Date DEFAULT toDate(detected_at)
) ENGINE = MergeTree()
PARTITION BY toYYYYMM(detected_date)
ORDER BY (orgao_sigla, detected_at, severity)
TTL detected_date + INTERVAL 90 DAY DELETE;
