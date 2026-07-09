alter table users add column if not exists role text not null default 'participant';
alter table users add column if not exists name text;
alter table users add column if not exists last_login_at timestamptz;

create table if not exists company_user_assignments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  company_id uuid not null references assessment_projects(id) on delete cascade,
  role text not null,
  permissions_json jsonb not null default '{}',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, company_id, role)
);

create table if not exists consultant_company_assignments (
  id uuid primary key default gen_random_uuid(),
  consultant_user_id uuid not null references users(id) on delete cascade,
  company_id uuid not null references assessment_projects(id) on delete cascade,
  assigned_by_user_id uuid references users(id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  revoked_at timestamptz,
  unique (consultant_user_id, company_id)
);

create index if not exists idx_company_user_assignments_user on company_user_assignments (user_id, is_active);
create index if not exists idx_company_user_assignments_company on company_user_assignments (company_id, is_active);
create index if not exists idx_consultant_company_assignments_user on consultant_company_assignments (consultant_user_id, is_active);
create index if not exists idx_consultant_company_assignments_company on consultant_company_assignments (company_id, is_active);
