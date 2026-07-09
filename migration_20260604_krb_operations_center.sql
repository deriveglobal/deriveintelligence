create table if not exists system_error_logs (
  id uuid primary key default gen_random_uuid(),
  timestamp timestamptz not null default now(),
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  area text not null default 'system',
  action text,
  message text not null,
  stack_trace text,
  user_id uuid references users(id) on delete set null,
  assessment_id uuid references assessments(id) on delete set null,
  participant_id uuid references assessment_participants(participant_id) on delete set null,
  metadata_json jsonb not null default '{}'
);

create table if not exists krb_issues (
  issue_id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  severity text not null default 'medium' check (severity in ('low', 'medium', 'high', 'critical')),
  status text not null default 'open' check (status in ('open', 'investigating', 'waiting', 'resolved', 'closed')),
  category text not null default 'workflow' check (category in ('workflow', 'participant', 'email', 'reminder', 'magic_link', 'analysis', 'report', 'data_quality', 'qa', 'bug', 'user_request')),
  assessment_id uuid references assessments(id) on delete set null,
  participant_id uuid references assessment_participants(participant_id) on delete set null,
  related_area text,
  assigned_to text,
  source text not null default 'manual' check (source in ('manual', 'system_generated', 'qa')),
  source_error_log_id uuid references system_error_logs(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolution_notes text
);

create table if not exists krb_audit_logs (
  audit_id uuid primary key default gen_random_uuid(),
  timestamp timestamptz not null default now(),
  actor_user_id uuid references users(id) on delete set null,
  actor_email text,
  action text not null,
  entity_type text,
  entity_id text,
  assessment_id uuid references assessments(id) on delete set null,
  participant_id uuid references assessment_participants(participant_id) on delete set null,
  before_json jsonb,
  after_json jsonb,
  metadata_json jsonb not null default '{}',
  ip_address text,
  user_agent text
);

create table if not exists krb_qa_runs (
  qa_run_id uuid primary key default gen_random_uuid(),
  qa_type text not null,
  status text not null default 'running' check (status in ('running', 'passed', 'failed', 'warning')),
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  record_counts_json jsonb not null default '{}',
  checks_json jsonb not null default '[]',
  failed_checks_json jsonb not null default '[]',
  cleanup_status text,
  notes text
);

create index if not exists idx_system_error_logs_recent on system_error_logs (timestamp desc, severity);
create index if not exists idx_krb_issues_status on krb_issues (status, severity, updated_at desc);
create index if not exists idx_krb_audit_logs_recent on krb_audit_logs (timestamp desc, action);
create index if not exists idx_krb_qa_runs_recent on krb_qa_runs (started_at desc, status);
