create table if not exists project_context_intakes (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  token text not null unique,
  recipient_name text,
  recipient_email citext,
  language_code text not null default 'tr',
  status text not null default 'draft' check (status in ('draft', 'sent', 'opened', 'submitted', 'archived')),
  context_data jsonb not null default '{}',
  sent_at timestamptz,
  opened_at timestamptz,
  submitted_at timestamptz,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_project_context_intakes_project
  on project_context_intakes (assessment_project_id, status, updated_at desc);

create index if not exists idx_project_context_intakes_token
  on project_context_intakes (token);
