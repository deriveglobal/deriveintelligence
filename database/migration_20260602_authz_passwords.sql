alter table organization_memberships drop constraint if exists organization_memberships_role_check;
alter table organization_memberships
  add constraint organization_memberships_role_check
  check (role in ('platform_admin', 'creator', 'consultant', 'auditor', 'owner', 'manager', 'participant', 'viewer'));

alter table project_memberships drop constraint if exists project_memberships_role_check;
alter table project_memberships
  add constraint project_memberships_role_check
  check (role in ('creator', 'consultant', 'auditor', 'owner', 'manager', 'participant', 'viewer'));

create table if not exists user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table if not exists password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_user_sessions_user_active on user_sessions (user_id, expires_at) where revoked_at is null;
create index if not exists idx_password_reset_tokens_user_active on password_reset_tokens (user_id, expires_at) where used_at is null;
