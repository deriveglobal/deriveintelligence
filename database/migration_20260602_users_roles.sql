alter table users add column if not exists password_hash text;
alter table users add column if not exists password_reset_required boolean not null default false;

create table if not exists project_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('creator', 'owner', 'manager', 'participant', 'viewer')),
  status text not null default 'active' check (status in ('active', 'invited', 'disabled')),
  invited_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_project_id, user_id)
);

create index if not exists idx_project_memberships_project_user on project_memberships (assessment_project_id, user_id);
create index if not exists idx_project_memberships_user on project_memberships (user_id);
