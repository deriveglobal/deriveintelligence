-- Digital Transformation Assessment Platform
-- PostgreSQL schema v0.1
--
-- Design principle:
-- This is not a KRB-only survey database. It is a multi-tenant assessment
-- engine where methodology templates can be reused across organizations,
-- industries, languages, and projects.

create extension if not exists pgcrypto;
create extension if not exists citext;

-- ---------------------------------------------------------------------------
-- 1. SaaS tenant core
-- ---------------------------------------------------------------------------

create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  legal_name text,
  industry text,
  country_code text,
  default_language text not null default 'en',
  status text not null default 'active' check (status in ('active', 'paused', 'archived')),
  classification text not null default 'production' check (classification in ('production', 'demo', 'qa', 'internal')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table users (
  id uuid primary key default gen_random_uuid(),
  email citext not null unique,
  full_name text,
  auth_provider text not null default 'local',
  password_hash text,
  password_reset_required boolean not null default false,
  credentials_sent_at timestamptz,
  status text not null default 'active' check (status in ('active', 'invited', 'disabled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table user_sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

create table password_reset_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references users(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table organization_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('platform_admin', 'creator', 'consultant', 'auditor', 'owner', 'manager', 'participant', 'viewer')),
  status text not null default 'active' check (status in ('active', 'invited', 'disabled')),
  invited_by uuid references users(id),
  created_at timestamptz not null default now(),
  unique (organization_id, user_id)
);

create table audit_events (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid references organizations(id) on delete cascade,
  actor_user_id uuid references users(id),
  event_type text not null,
  entity_type text,
  entity_id uuid,
  metadata jsonb not null default '{}',
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 2. Methodology library
-- ---------------------------------------------------------------------------

create table methodology_templates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  description text,
  owner_organization_id uuid references organizations(id) on delete set null,
  is_global boolean not null default false,
  status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table methodology_versions (
  id uuid primary key default gen_random_uuid(),
  methodology_template_id uuid not null references methodology_templates(id) on delete cascade,
  version_label text not null,
  notes text,
  status text not null default 'draft' check (status in ('draft', 'published', 'archived')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  unique (methodology_template_id, version_label)
);

create table stakeholder_types (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  layer text,
  sort_order integer not null default 0,
  unique (methodology_version_id, code)
);

create table business_domains (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  sort_order integer not null default 0,
  unique (methodology_version_id, code)
);

create table assessment_categories (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  sort_order integer not null default 0,
  unique (methodology_version_id, code)
);

create table problem_types (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  category_id uuid references assessment_categories(id) on delete set null,
  keywords jsonb not null default '[]',
  description text,
  unique (methodology_version_id, code)
);

create table root_cause_types (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  unique (methodology_version_id, code)
);

create table impact_dimensions (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  unique (methodology_version_id, code)
);

create table maturity_dimensions (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  description text,
  sort_order integer not null default 0,
  unique (methodology_version_id, code)
);

create table opportunity_classes (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  min_timeline_months integer,
  max_timeline_months integer,
  description text,
  unique (methodology_version_id, code)
);

create table roadmap_phases (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  code text not null,
  name text not null,
  phase_number integer not null,
  description text,
  unique (methodology_version_id, code)
);

create table survey_templates (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  stakeholder_type_id uuid references stakeholder_types(id) on delete set null,
  code text not null,
  name text not null,
  description text,
  default_language text not null default 'en',
  status text not null default 'draft' check (status in ('draft', 'active', 'archived')),
  sort_order integer not null default 0,
  unique (methodology_version_id, code)
);

create table question_templates (
  id uuid primary key default gen_random_uuid(),
  methodology_version_id uuid not null references methodology_versions(id) on delete cascade,
  survey_template_id uuid not null references survey_templates(id) on delete cascade,
  stakeholder_type_id uuid references stakeholder_types(id) on delete set null,
  code text not null,
  question_type text not null check (question_type in ('single_choice', 'multiple_choice', 'likert_1_5', 'numeric', 'open_text', 'yes_no')),
  required boolean not null default true,
  scoring_eligible boolean not null default false,
  weight numeric(8,2) not null default 1,
  ai_intent text not null,
  kpi_extractable boolean not null default false,
  maturity_dimension_id uuid references maturity_dimensions(id) on delete set null,
  response_guidance text,
  sort_order integer not null default 0,
  status text not null default 'active' check (status in ('active', 'disabled', 'archived')),
  unique (survey_template_id, code)
);

create table question_translations (
  id uuid primary key default gen_random_uuid(),
  question_template_id uuid not null references question_templates(id) on delete cascade,
  language_code text not null,
  question_text text not null,
  helper_text text,
  placeholder text,
  unique (question_template_id, language_code)
);

create table question_options (
  id uuid primary key default gen_random_uuid(),
  question_template_id uuid not null references question_templates(id) on delete cascade,
  option_code text not null,
  score numeric(8,2),
  sort_order integer not null default 0,
  unique (question_template_id, option_code)
);

create table question_option_translations (
  id uuid primary key default gen_random_uuid(),
  question_option_id uuid not null references question_options(id) on delete cascade,
  language_code text not null,
  label text not null,
  unique (question_option_id, language_code)
);

create table question_domain_map (
  question_template_id uuid not null references question_templates(id) on delete cascade,
  domain_id uuid not null references business_domains(id) on delete cascade,
  primary key (question_template_id, domain_id)
);

create table question_category_map (
  question_template_id uuid not null references question_templates(id) on delete cascade,
  category_id uuid not null references assessment_categories(id) on delete cascade,
  primary key (question_template_id, category_id)
);

create table question_expected_problem_types (
  question_template_id uuid not null references question_templates(id) on delete cascade,
  problem_type_id uuid not null references problem_types(id) on delete cascade,
  primary key (question_template_id, problem_type_id)
);

create table question_expected_impacts (
  question_template_id uuid not null references question_templates(id) on delete cascade,
  impact_dimension_id uuid not null references impact_dimensions(id) on delete cascade,
  primary key (question_template_id, impact_dimension_id)
);

create table question_expected_root_causes (
  question_template_id uuid not null references question_templates(id) on delete cascade,
  root_cause_type_id uuid not null references root_cause_types(id) on delete cascade,
  primary key (question_template_id, root_cause_type_id)
);

-- ---------------------------------------------------------------------------
-- 3. Assessment execution
-- ---------------------------------------------------------------------------

create table assessment_projects (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  methodology_version_id uuid not null references methodology_versions(id),
  name text not null,
  client_display_name text not null,
  industry_context text,
  default_language text not null default 'en',
  status text not null default 'draft' check (status in ('draft', 'active', 'analysis', 'completed', 'archived')),
  classification text not null default 'production' check (classification in ('production', 'demo', 'qa', 'internal')),
  starts_at date,
  ends_at date,
  created_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table project_memberships (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  user_id uuid not null references users(id) on delete cascade,
  role text not null check (role in ('creator', 'consultant', 'auditor', 'owner', 'manager', 'participant', 'viewer')),
  status text not null default 'active' check (status in ('active', 'invited', 'disabled')),
  invited_by uuid references users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (assessment_project_id, user_id)
);

create table departments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid references assessment_projects(id) on delete cascade,
  name text not null,
  location text,
  parent_department_id uuid references departments(id),
  created_at timestamptz not null default now()
);

create table process_inventory (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  department_id uuid references departments(id) on delete set null,
  name text not null,
  description text,
  owner_user_id uuid references users(id),
  criticality text check (criticality in ('low', 'medium', 'high', 'critical')),
  created_at timestamptz not null default now()
);

create table project_stakeholders (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  stakeholder_type_id uuid references stakeholder_types(id),
  department_id uuid references departments(id) on delete set null,
  name text,
  email text,
  role_title text,
  language_code text not null default 'en',
  external boolean not null default false,
  created_at timestamptz not null default now()
);

create table project_participants (
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

create table project_context_intakes (
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

create table survey_assignments (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  survey_template_id uuid not null references survey_templates(id),
  project_stakeholder_id uuid references project_stakeholders(id) on delete set null,
  assigned_to_email text,
  assigned_to_name text,
  language_code text not null default 'en',
  token text not null unique,
  status text not null default 'created' check (status in ('created', 'sent', 'opened', 'completed', 'expired', 'cancelled')),
  sent_at timestamptz,
  opened_at timestamptz,
  completed_at timestamptz,
  expires_at timestamptz,
  metadata jsonb not null default '{}',
  created_by uuid references users(id),
  created_at timestamptz not null default now()
);

create table survey_response_sessions (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  survey_assignment_id uuid references survey_assignments(id) on delete set null,
  survey_template_id uuid not null references survey_templates(id),
  project_stakeholder_id uuid references project_stakeholders(id) on delete set null,
  department_id uuid references departments(id) on delete set null,
  process_id uuid references process_inventory(id) on delete set null,
  respondent_name text,
  respondent_email text,
  language_code text not null default 'en',
  status text not null default 'submitted' check (status in ('draft', 'submitted', 'reviewed', 'excluded')),
  submitted_at timestamptz not null default now(),
  metadata jsonb not null default '{}'
);

create table response_answers (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  response_session_id uuid not null references survey_response_sessions(id) on delete cascade,
  question_template_id uuid not null references question_templates(id),
  answer_text text,
  numeric_value numeric(18,4),
  selected_option_codes text[],
  normalized_answer jsonb not null default '{}',
  confidence_score numeric(5,4),
  created_at timestamptz not null default now(),
  unique (response_session_id, question_template_id)
);

-- ---------------------------------------------------------------------------
-- 4. AI-derived evidence and outputs
-- ---------------------------------------------------------------------------

create table response_answer_analysis (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  response_answer_id uuid not null references response_answers(id) on delete cascade,
  stakeholder_type_id uuid references stakeholder_types(id),
  category_id uuid references assessment_categories(id),
  frequency text check (frequency in ('rare', 'monthly', 'weekly', 'daily', 'continuous')),
  severity integer check (severity between 1 and 5),
  automation_potential integer check (automation_potential between 1 and 5),
  analysis_summary text,
  ai_model text,
  ai_confidence numeric(5,4),
  raw_ai_json jsonb not null default '{}',
  reviewed_by uuid references users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create table response_analysis_domains (
  response_answer_analysis_id uuid not null references response_answer_analysis(id) on delete cascade,
  domain_id uuid not null references business_domains(id) on delete cascade,
  primary key (response_answer_analysis_id, domain_id)
);

create table response_analysis_problem_types (
  response_answer_analysis_id uuid not null references response_answer_analysis(id) on delete cascade,
  problem_type_id uuid not null references problem_types(id) on delete cascade,
  primary key (response_answer_analysis_id, problem_type_id)
);

create table response_analysis_root_causes (
  response_answer_analysis_id uuid not null references response_answer_analysis(id) on delete cascade,
  root_cause_type_id uuid not null references root_cause_types(id) on delete cascade,
  primary key (response_answer_analysis_id, root_cause_type_id)
);

create table response_analysis_impacts (
  response_answer_analysis_id uuid not null references response_answer_analysis(id) on delete cascade,
  impact_dimension_id uuid not null references impact_dimensions(id) on delete cascade,
  primary key (response_answer_analysis_id, impact_dimension_id)
);

create table pain_points (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  title text not null,
  description text,
  primary_category_id uuid references assessment_categories(id),
  primary_problem_type_id uuid references problem_types(id),
  frequency text check (frequency in ('rare', 'monthly', 'weekly', 'daily', 'continuous')),
  severity integer check (severity between 1 and 5),
  evidence_count integer not null default 0,
  status text not null default 'candidate' check (status in ('candidate', 'validated', 'dismissed')),
  created_at timestamptz not null default now()
);

create table pain_point_evidence (
  pain_point_id uuid not null references pain_points(id) on delete cascade,
  response_answer_analysis_id uuid not null references response_answer_analysis(id) on delete cascade,
  primary key (pain_point_id, response_answer_analysis_id)
);

create table kpis (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  source_response_answer_id uuid references response_answers(id) on delete set null,
  name text not null,
  value numeric(18,4),
  unit text,
  raw_value text,
  dimension text,
  confidence_score numeric(5,4),
  created_at timestamptz not null default now()
);

create table kpi_definitions (
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

create table project_kpi_measurements (
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

create table project_kpi_gaps (
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

create table opportunities (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  pain_point_id uuid references pain_points(id) on delete set null,
  opportunity_class_id uuid references opportunity_classes(id),
  title text not null,
  description text,
  expected_benefit text,
  impact_score integer check (impact_score between 1 and 5),
  effort_score integer check (effort_score between 1 and 5),
  automation_potential integer check (automation_potential between 1 and 5),
  status text not null default 'candidate' check (status in ('candidate', 'approved', 'rejected')),
  created_at timestamptz not null default now()
);

create table recommendations (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  opportunity_id uuid references opportunities(id) on delete cascade,
  title text not null,
  recommended_action text not null,
  expected_benefit text,
  estimated_effort text,
  estimated_timeline text,
  priority_score numeric(8,2),
  created_at timestamptz not null default now()
);

create table roadmap_items (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  recommendation_id uuid references recommendations(id) on delete set null,
  roadmap_phase_id uuid references roadmap_phases(id),
  title text not null,
  description text,
  start_month integer,
  end_month integer,
  owner_role text,
  status text not null default 'planned' check (status in ('planned', 'active', 'completed', 'deferred')),
  created_at timestamptz not null default now()
);

create table maturity_scores (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  maturity_dimension_id uuid not null references maturity_dimensions(id),
  score numeric(4,2) not null check (score >= 1 and score <= 5),
  evidence_summary text,
  confidence_score numeric(5,4),
  created_at timestamptz not null default now(),
  unique (assessment_project_id, maturity_dimension_id)
);

create table generated_reports (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  assessment_project_id uuid not null references assessment_projects(id) on delete cascade,
  report_type text not null check (report_type in ('executive_summary', 'findings', 'roadmap', 'full_assessment')),
  title text not null,
  content_json jsonb not null,
  generated_by uuid references users(id),
  generated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- 5. Indexes for tenant safety and analysis performance
-- ---------------------------------------------------------------------------

create index idx_memberships_org_user on organization_memberships (organization_id, user_id);
create index idx_project_memberships_project_user on project_memberships (assessment_project_id, user_id);
create index idx_project_memberships_user on project_memberships (user_id);
create index idx_projects_org_status on assessment_projects (organization_id, status);
create index idx_assignments_project_status on survey_assignments (assessment_project_id, status);
create index idx_assignments_token on survey_assignments (token);
create index idx_sessions_project_submitted on survey_response_sessions (assessment_project_id, submitted_at desc);
create index idx_answers_project_question on response_answers (assessment_project_id, question_template_id);
create index idx_answer_analysis_project_severity on response_answer_analysis (assessment_project_id, severity desc);
create index idx_pain_points_project_severity on pain_points (assessment_project_id, severity desc);
create index idx_kpi_definitions_objective on kpi_definitions (business_objective, business_domain);
create index idx_kpi_definitions_industry_activity on kpi_definitions (industry, business_activity);
create index idx_project_kpi_measurements_project_status on project_kpi_measurements (assessment_project_id, measurement_status);
create index idx_project_kpi_gaps_project_status on project_kpi_gaps (assessment_project_id, measurement_status);
create index idx_opportunities_project_priority on opportunities (assessment_project_id, impact_score desc, effort_score asc);
create index idx_roadmap_project_phase on roadmap_items (assessment_project_id, roadmap_phase_id);

-- ---------------------------------------------------------------------------
-- 6. RLS note
-- ---------------------------------------------------------------------------
-- Production should enable row level security on tenant-owned tables and set
-- application.current_organization_id at request start. The backend must still
-- enforce authorization before every query. RLS is the safety net, not the only
-- gate.
