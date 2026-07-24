CREATE OR REPLACE FUNCTION core.update_timestamp() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION detection.create_monthly_partition() RETURNS void AS $$
DECLARE
  next_month DATE := date_trunc('month', NOW()) + INTERVAL '1 month';
  pname TEXT; s TEXT; e TEXT;
BEGIN
  pname := 'detection.events_' || to_char(next_month,'YYYY_MM');
  s := to_char(next_month,'YYYY-MM-DD');
  e := to_char(next_month + INTERVAL '1 month','YYYY-MM-DD');
  EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF detection.events FOR VALUES FROM (%L) TO (%L)', pname, s, e);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION audit.compute_chain_hash(p_seq BIGINT, p_type VARCHAR, p_action VARCHAR, p_prev VARCHAR)
RETURNS VARCHAR AS $$
BEGIN
  RETURN encode(sha256(convert_to(p_seq::TEXT||'|'||p_type||'|'||p_action||'|'||p_prev||'|'||NOW()::TEXT,'UTF8')),'hex');
END;
$$ LANGUAGE plpgsql IMMUTABLE;
