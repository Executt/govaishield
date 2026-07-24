-- Partições iniciais; as futuras são criadas pelo CronJob (create_monthly_partition).
CREATE TABLE IF NOT EXISTS detection.events_2026_07 PARTITION OF detection.events FOR VALUES FROM ('2026-07-01') TO ('2026-08-01');
CREATE TABLE IF NOT EXISTS detection.events_2026_08 PARTITION OF detection.events FOR VALUES FROM ('2026-08-01') TO ('2026-09-01');
CREATE TABLE IF NOT EXISTS detection.events_2026_09 PARTITION OF detection.events FOR VALUES FROM ('2026-09-01') TO ('2026-10-01');
