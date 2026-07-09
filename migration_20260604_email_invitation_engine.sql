alter table assessment_participants add column if not exists invite_count integer not null default 0;
alter table assessment_participants add column if not exists last_invite_sent_at timestamptz;
alter table assessment_participants add column if not exists email_status text not null default 'not_sent';
alter table assessment_participants add column if not exists email_error text;
alter table assessment_participants add column if not exists invitation_token_id uuid;

alter table assessment_access_tokens add column if not exists raw_token text;

create table if not exists assessment_invitation_logs (
  id uuid primary key default gen_random_uuid(),
  participant_id uuid not null references assessment_participants(participant_id) on delete cascade,
  assessment_id uuid not null references assessments(id) on delete cascade,
  email text,
  subject text,
  status text not null,
  error_message text,
  sent_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_assessment_invitation_logs_participant on assessment_invitation_logs (participant_id, created_at desc);
