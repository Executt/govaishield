CREATE OR REPLACE VIEW detection.v_high_severity AS
SELECT event_id, orgao_id, provider_id, severity, dlp_action, status, detected_at
FROM detection.events WHERE severity >= 4;

CREATE OR REPLACE VIEW core.v_approved_providers AS
SELECT id, slug, display_name, category, risk_level, data_residency
FROM core.ai_providers WHERE approved = TRUE;
