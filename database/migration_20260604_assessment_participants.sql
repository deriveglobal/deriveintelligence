create table if not exists assessment_participants (
  participant_id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  assessment_id uuid not null references assessments(id) on delete cascade,
  stakeholder_group_id text not null references stakeholder_groups(id),
  stakeholder_role_id text not null references stakeholder_roles(id),
  first_name text,
  last_name text,
  full_name text not null,
  email text,
  department text,
  location text,
  notes text,
  status text not null default 'not_invited'
    check (status in ('not_invited', 'invited', 'started', 'completed', 'deactivated')),
  session_id uuid references assessment_sessions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  invite_sent_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  is_active boolean not null default true
);

alter table assessment_sessions
  add column if not exists participant_id uuid references assessment_participants(participant_id) on delete set null;

create index if not exists idx_assessment_participants_assessment_role
  on assessment_participants (assessment_id, stakeholder_role_id, status);

create unique index if not exists idx_assessment_participants_session_unique
  on assessment_participants (session_id)
  where session_id is not null;
