alter table recommendations drop constraint if exists recommendations_status_check;

alter table recommendations add constraint recommendations_status_check
  check (status in ('Draft', 'Proposed', 'Approved', 'Accepted', 'Rejected', 'In Progress', 'Completed'));

alter table recommendations add column if not exists expected_value numeric(12,2) not null default 0;
alter table recommendations add column if not exists actual_value numeric(12,2);
alter table recommendations add column if not exists expected_time_savings numeric(12,2) not null default 0;
alter table recommendations add column if not exists actual_time_savings numeric(12,2);
alter table recommendations add column if not exists expected_cost_savings numeric(12,2) not null default 0;
alter table recommendations add column if not exists actual_cost_savings numeric(12,2);
alter table recommendations add column if not exists expected_outcome text;
alter table recommendations add column if not exists actual_outcome text;
alter table recommendations add column if not exists recommendation_accuracy_score numeric(5,2);
alter table recommendations add column if not exists outcome_notes text;
alter table recommendations add column if not exists outcome_updated_at timestamptz;

create index if not exists idx_engine_recommendations_status on recommendations (assessment_id, status);
