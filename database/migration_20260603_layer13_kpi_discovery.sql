create table if not exists kpi_definitions (
  id text primary key,
  name text not null,
  business_objective text not null,
  business_domain text not null,
  industry text not null check (industry in ('universal', 'tire_industry')),
  business_activity text,
  description text,
  formula text,
  unit text,
  importance_score integer not null default 1 check (importance_score between 1 and 5),
  measurement_difficulty integer not null default 1 check (measurement_difficulty between 1 and 5),
  required_data_points jsonb not null default '[]'::jsonb,
  possible_data_sources jsonb not null default '[]'::jsonb,
  estimation_questions jsonb not null default '[]'::jsonb,
  related_stakeholders jsonb not null default '[]'::jsonb,
  related_problem_types jsonb not null default '[]'::jsonb,
  question_triggers jsonb not null default '[]'::jsonb,
  recommendation_triggers jsonb not null default '[]'::jsonb,
  roadmap_relevance text not null default 'foundation' check (roadmap_relevance in ('quick_win', 'foundation', 'optimization', 'transformation')),
  benchmark_available boolean not null default false,
  status text not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists project_kpi_measurements (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  kpi_definition_id text not null references kpi_definitions(id) on delete cascade,
  measurement_status text not null default 'missing' check (measurement_status in ('measured', 'estimatable', 'missing', 'not_applicable')),
  tracked_where text,
  current_value text,
  estimated_value text,
  estimate_method text,
  missing_data_points jsonb not null default '[]'::jsonb,
  evidence jsonb not null default '[]'::jsonb,
  owner_user_id uuid references users(id) on delete set null,
  updated_by uuid references users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_project_id, kpi_definition_id)
);

create table if not exists project_kpi_gaps (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  kpi_definition_id text not null references kpi_definitions(id) on delete cascade,
  recommended boolean not null default true,
  measurement_status text not null check (measurement_status in ('measured', 'estimatable', 'missing', 'not_applicable')),
  why_it_matters text,
  required_data_points jsonb not null default '[]'::jsonb,
  recommended_data_capture_method text,
  related_recommendation text,
  roadmap_relevance text not null default 'foundation',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_project_id, kpi_definition_id)
);

create index if not exists idx_kpi_definitions_objective
  on kpi_definitions (business_objective, business_domain);

create index if not exists idx_kpi_definitions_industry_activity
  on kpi_definitions (industry, business_activity);

create index if not exists idx_project_kpi_measurements_project_status
  on project_kpi_measurements (assessment_project_id, measurement_status);

create index if not exists idx_project_kpi_gaps_project_status
  on project_kpi_gaps (assessment_project_id, measurement_status);
