-- ops_schema.sql — diagnose-only ops layer storage.
-- ops_health   : every check result of every run (history).
-- ops_incident : deduped OPEN issues (one open row per check_key) for email + dashboard.
-- ops_ayar     : thresholds + alert recipient (editable).

CREATE TABLE IF NOT EXISTS ops_health (
  id         bigserial PRIMARY KEY,
  run_id     uuid        NOT NULL,
  check_key  text        NOT NULL,
  category   text        NOT NULL,          -- pipeline | system | data_quality | app
  title      text        NOT NULL,
  status     text        NOT NULL CHECK (status IN ('ok','warn','crit')),
  value      text,
  detail     text,
  metric     numeric,
  checked_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS ix_ops_health_key_time ON ops_health (check_key, checked_at DESC);
CREATE INDEX IF NOT EXISTS ix_ops_health_run      ON ops_health (run_id);

CREATE TABLE IF NOT EXISTS ops_incident (
  id          bigserial PRIMARY KEY,
  check_key   text        NOT NULL,
  category    text        NOT NULL,
  title       text        NOT NULL,
  severity    text        NOT NULL CHECK (severity IN ('warn','crit')),
  detail      text,
  status      text        NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved')),
  first_seen  timestamptz NOT NULL DEFAULT now(),
  last_seen   timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz,
  occurrences int         NOT NULL DEFAULT 1,
  email_sent  boolean     NOT NULL DEFAULT false,
  seen        boolean     NOT NULL DEFAULT false
);
-- one OPEN incident per check_key (enables ON CONFLICT dedup)
CREATE UNIQUE INDEX IF NOT EXISTS ux_ops_incident_open ON ops_incident (check_key) WHERE status = 'open';
CREATE INDEX IF NOT EXISTS ix_ops_incident_status ON ops_incident (status, severity);

CREATE TABLE IF NOT EXISTS ops_ayar (key text PRIMARY KEY, value text);
INSERT INTO ops_ayar (key, value) VALUES
  ('alert_email',       'fatih@deriveglobal.com'),
  ('ingest_warn_days',  '2'),
  ('ingest_crit_days',  '5'),
  ('scrape_warn_hours', '36'),
  ('scrape_crit_hours', '72'),
  ('disk_warn_pct',     '80'),
  ('disk_crit_pct',     '90')
ON CONFLICT (key) DO NOTHING;
