alter table assessment_participants add column if not exists reminder_count integer not null default 0;
alter table assessment_participants add column if not exists last_reminder_sent_at timestamptz;
alter table assessment_participants add column if not exists reminder_status text not null default 'not_sent';
alter table assessment_participants add column if not exists reminder_error text;

create table if not exists assessment_reminder_logs (
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

create index if not exists idx_assessment_reminder_logs_participant on assessment_reminder_logs (participant_id, created_at desc);
