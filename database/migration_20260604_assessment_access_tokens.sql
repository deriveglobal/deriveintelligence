create table if not exists assessment_access_tokens (
  token_id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references assessment_participants(participant_id) on delete cascade,
  session_id uuid not null references assessment_sessions(id) on delete cascade,
  token text not null unique,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null,
  first_opened_at timestamptz,
  last_opened_at timestamptz,
  completed_at timestamptz,
  is_active boolean not null default true
);

create index if not exists idx_assessment_access_tokens_participant on assessment_access_tokens (participant_id, is_active);
create index if not exists idx_assessment_access_tokens_session on assessment_access_tokens (session_id, is_active);
