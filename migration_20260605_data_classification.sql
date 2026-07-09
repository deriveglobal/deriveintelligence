-- Data Classification & Production Metrics v1
-- Adds SaaS operating classifications so production metrics do not mix real
-- customer work with demo, QA, or internal records.

alter table organizations
  add column if not exists classification text not null default 'production'
  check (classification in ('production', 'demo', 'qa', 'internal'));

alter table assessment_projects
  add column if not exists classification text not null default 'production'
  check (classification in ('production', 'demo', 'qa', 'internal'));

update organizations
set classification = case
  when lower(coalesce(name, '') || ' ' || coalesce(legal_name, '') || ' ' || coalesce(industry, '')) ~ '(demo|sample)' then 'demo'
  when lower(coalesce(name, '') || ' ' || coalesce(legal_name, '') || ' ' || coalesce(industry, '')) ~ '(qa|test|chaos|validation)' then 'qa'
  when lower(coalesce(name, '') || ' ' || coalesce(legal_name, '') || ' ' || coalesce(industry, '')) ~ '(internal)' then 'internal'
  else 'production'
end
where classification = 'production';

update assessment_projects ap
set classification = case
  when lower(coalesce(ap.name, '') || ' ' || coalesce(ap.client_display_name, '') || ' ' || coalesce(ap.industry_context, '') || ' ' || coalesce(o.name, '')) ~ '(demo|sample)' then 'demo'
  when lower(coalesce(ap.name, '') || ' ' || coalesce(ap.client_display_name, '') || ' ' || coalesce(ap.industry_context, '') || ' ' || coalesce(o.name, '')) ~ '(qa|test|chaos|validation)' then 'qa'
  when lower(coalesce(ap.name, '') || ' ' || coalesce(ap.client_display_name, '') || ' ' || coalesce(ap.industry_context, '') || ' ' || coalesce(o.name, '')) ~ '(internal)' then 'internal'
  else coalesce(o.classification, 'production')
end
from organizations o
where o.id = ap.organization_id
  and ap.classification = 'production';

create index if not exists idx_organizations_classification on organizations(classification);
create index if not exists idx_assessment_projects_classification on assessment_projects(classification);
