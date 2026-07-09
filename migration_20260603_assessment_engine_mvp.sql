-- Assessment Engine MVP
-- Purpose: prove Response -> Finding -> Evidence -> Recommendation -> Roadmap
-- using the Operations Manager v1 question bank.

create extension if not exists pgcrypto;

create table if not exists assessments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references assessment_projects(id) on delete cascade,
  title text not null,
  status text not null default 'draft' check (status in ('draft', 'active', 'analysis', 'completed', 'archived')),
  created_at timestamptz not null default now()
);

create table if not exists assessment_sessions (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  stakeholder_role text not null,
  respondent_name text,
  respondent_email text,
  status text not null default 'started' check (status in ('started', 'completed', 'analyzed')),
  started_at timestamptz not null default now(),
  completed_at timestamptz
);

create table if not exists questions (
  id uuid primary key default gen_random_uuid(),
  question_id text not null unique,
  stakeholder_group text not null,
  stakeholder_role text not null,
  section text not null,
  question_text text not null,
  response_type text not null,
  options jsonb not null default '[]',
  required boolean not null default true,
  score_mapping jsonb not null default '{}',
  business_domain text not null,
  assessment_category text not null,
  problem_types_detectable jsonb not null default '[]',
  impact_dimensions jsonb not null default '[]',
  maturity_dimensions jsonb not null default '[]',
  kpi_outputs jsonb not null default '[]',
  ai_analysis_purpose text,
  follow_up_enabled boolean not null default false,
  follow_up_questions jsonb not null default '[]',
  recommendation_triggers jsonb not null default '[]',
  roadmap_relevance text not null default 'foundation',
  finding_strength text not null default 'medium' check (finding_strength in ('low', 'medium', 'high')),
  metadata jsonb not null default '{}'
);

create table if not exists responses (
  id uuid primary key default gen_random_uuid(),
  assessment_session_id uuid not null references assessment_sessions(id) on delete cascade,
  question_id uuid not null references questions(id) on delete cascade,
  answer_value jsonb,
  answer_text text,
  score_value numeric(8,2),
  created_at timestamptz not null default now(),
  unique (assessment_session_id, question_id)
);

create table if not exists findings (
  id uuid primary key default gen_random_uuid(),
  assessment_id uuid not null references assessments(id) on delete cascade,
  title text not null,
  description text,
  business_domain text,
  assessment_category text,
  problem_types jsonb not null default '[]',
  source_question_ids jsonb not null default '[]',
  source_response_ids jsonb not null default '[]',
  severity integer not null default 3 check (severity between 1 and 5),
  frequency integer not null default 3 check (frequency between 1 and 5),
  confidence integer not null default 3 check (confidence between 1 and 5),
  evidence_count integer not null default 0,
  time_impact integer not null default 3 check (time_impact between 1 and 5),
  cost_impact integer not null default 2 check (cost_impact between 1 and 5),
  customer_impact integer not null default 2 check (customer_impact between 1 and 5),
  revenue_impact integer not null default 2 check (revenue_impact between 1 and 5),
  risk_impact integer not null default 2 check (risk_impact between 1 and 5),
  employee_impact integer not null default 2 check (employee_impact between 1 and 5),
  automation_potential integer not null default 3 check (automation_potential between 1 and 5),
  priority_score numeric(8,2) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists evidence (
  id uuid primary key default gen_random_uuid(),
  finding_id uuid not null references findings(id) on delete cascade,
  evidence_type text not null,
  source_question_id uuid references questions(id) on delete set null,
  source_response_id uuid references responses(id) on delete set null,
  description text,
  created_at timestamptz not null default now()
);

alter table findings add column if not exists status text not null default 'Draft'
  check (status in ('Draft', 'Approved', 'Rejected', 'Archived'));
alter table findings add column if not exists analyst_notes text;
alter table findings add column if not exists parent_finding_id uuid references findings(id) on delete set null;
alter table findings add column if not exists cluster_key text;
alter table findings add column if not exists trigger_rule text;
alter table findings add column if not exists stakeholder_agreement_score integer not null default 1
  check (stakeholder_agreement_score between 1 and 5);
alter table findings add column if not exists stakeholder_groups jsonb not null default '[]';
alter table findings add column if not exists supporting_response_count integer not null default 0;
alter table findings add column if not exists contradiction_detected boolean not null default false;
alter table findings add column if not exists contradiction_details jsonb not null default '{}';
alter table evidence add column if not exists trigger_rule text;

alter table recommendations add column if not exists assessment_id uuid references assessments(id) on delete cascade;
alter table recommendations add column if not exists finding_id uuid references findings(id) on delete cascade;
alter table recommendations add column if not exists description text;
alter table recommendations add column if not exists recommendation_category text;
alter table recommendations add column if not exists recommendation_type text;
alter table recommendations add column if not exists effort_score integer check (effort_score between 1 and 5);
alter table recommendations add column if not exists business_value_score integer check (business_value_score between 1 and 5);
alter table recommendations add column if not exists implementation_risk_score integer check (implementation_risk_score between 1 and 5);
alter table recommendations add column if not exists roadmap_phase text;
alter table recommendations add column if not exists status text not null default 'Draft'
  check (status in ('Draft', 'Approved', 'Rejected'));
alter table recommendations add column if not exists analyst_notes text;

alter table roadmap_items add column if not exists assessment_id uuid references assessments(id) on delete cascade;
alter table roadmap_items add column if not exists phase text;
alter table roadmap_items add column if not exists theme text;
alter table roadmap_items add column if not exists expected_outcomes jsonb not null default '[]';
alter table roadmap_items add column if not exists dependencies jsonb not null default '[]';
alter table roadmap_items add column if not exists estimated_effort text;
alter table roadmap_items add column if not exists business_value text;
alter table roadmap_items add column if not exists priority_score numeric(8,2);
alter table roadmap_items add column if not exists estimated_timeline text;

create index if not exists idx_assessments_company_status on assessments (company_id, status);
create index if not exists idx_assessment_sessions_assessment_status on assessment_sessions (assessment_id, status);
create index if not exists idx_engine_responses_session_question on responses (assessment_session_id, question_id);
create index if not exists idx_findings_assessment_priority on findings (assessment_id, priority_score desc);
create index if not exists idx_engine_recommendations_assessment_priority on recommendations (assessment_id, priority_score desc);
create index if not exists idx_engine_roadmap_assessment_phase on roadmap_items (assessment_id, phase);
