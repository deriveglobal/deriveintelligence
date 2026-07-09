create table if not exists project_participants (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  stakeholder_code text not null,
  full_name text not null,
  email citext,
  company text,
  department text,
  title text,
  language_code text not null default 'tr',
  notes text,
  status text not null default 'active' check (status in ('active', 'disabled')),
  source text not null default 'manual',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_project_id, email)
);

create index if not exists idx_project_participants_project on project_participants (assessment_project_id, stakeholder_code, status);
