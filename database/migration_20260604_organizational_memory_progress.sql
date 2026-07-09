create table if not exists company_progress_snapshots (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  assessment_id uuid not null references assessments(id) on delete cascade,
  snapshot_date timestamptz not null default now(),
  business_health_score integer not null default 0,
  digital_maturity_score integer not null default 0,
  assessment_completeness_score integer not null default 0,
  assessment_confidence_score integer not null default 0,
  total_findings integer not null default 0,
  critical_findings_count integer not null default 0,
  high_priority_findings_count integer not null default 0,
  approved_recommendations_count integer not null default 0,
  completed_recommendations_count integer not null default 0,
  total_estimated_value numeric(14,2) not null default 0,
  total_actual_value numeric(14,2) not null default 0,
  average_recommendation_accuracy numeric(5,2),
  created_at timestamptz not null default now()
);

create table if not exists finding_history (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  finding_id uuid references findings(id) on delete set null,
  assessment_id uuid not null references assessments(id) on delete cascade,
  normalized_finding_key text not null,
  title text,
  business_domain text,
  problem_types jsonb not null default '[]',
  severity integer,
  frequency integer,
  confidence integer,
  priority_score numeric(8,2),
  stakeholder_agreement_score numeric(5,2),
  evidence_count integer,
  status text,
  snapshot_date timestamptz not null default now()
);

create table if not exists kpi_history (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  assessment_id uuid not null references assessments(id) on delete cascade,
  kpi_id text not null,
  kpi_name text,
  business_domain text,
  measurement_status text,
  current_value numeric(14,2),
  desired_value numeric(14,2),
  gap_value numeric(14,2),
  unit text,
  snapshot_date timestamptz not null default now()
);

create table if not exists recommendation_history (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  recommendation_id uuid references recommendations(id) on delete set null,
  assessment_id uuid not null references assessments(id) on delete cascade,
  normalized_recommendation_key text not null,
  title text,
  roadmap_phase text,
  lifecycle_status text,
  estimated_value numeric(14,2),
  actual_value numeric(14,2),
  recommendation_accuracy_score numeric(5,2),
  recommended_owner text,
  priority_score numeric(8,2),
  snapshot_date timestamptz not null default now()
);

create table if not exists progress_insights (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  assessment_id uuid not null references assessments(id) on delete cascade,
  insight_type text not null,
  title text not null,
  description text,
  business_domain text,
  related_finding_key text,
  related_kpi_id text,
  related_recommendation_key text,
  previous_value numeric(14,2),
  current_value numeric(14,2),
  change_value numeric(14,2),
  change_direction text,
  severity text not null default 'medium',
  confidence integer not null default 3,
  created_at timestamptz not null default now()
);

create index if not exists idx_progress_snapshots_company_date on company_progress_snapshots (company_id, snapshot_date desc);
create index if not exists idx_finding_history_company_key on finding_history (company_id, normalized_finding_key, snapshot_date desc);
create index if not exists idx_kpi_history_company_kpi on kpi_history (company_id, kpi_id, snapshot_date desc);
create index if not exists idx_recommendation_history_company_key on recommendation_history (company_id, normalized_recommendation_key, snapshot_date desc);
create index if not exists idx_progress_insights_company_assessment on progress_insights (company_id, assessment_id, created_at desc);
