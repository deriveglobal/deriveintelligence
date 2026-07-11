-- Daily greeting cache: one row per (user, agent, day). On open, if today's row
-- exists, the server streams it back with ZERO LLM cost; only a new day regenerates.
CREATE TABLE IF NOT EXISTS agent_greeting_cache (
  tenant_id  uuid,
  user_id    uuid NOT NULL,
  agent      text NOT NULL,           -- 'ceo' | 'rep' | ...
  greet_date date NOT NULL,
  content    text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, agent, greet_date)
);
