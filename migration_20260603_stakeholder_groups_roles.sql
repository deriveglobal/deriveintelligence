create table if not exists stakeholder_groups (
  id text primary key,
  name text not null,
  description text,
  sort_order integer not null default 0,
  active boolean not null default true
);

create table if not exists stakeholder_roles (
  id text primary key,
  stakeholder_group_id text not null references stakeholder_groups(id),
  name text not null,
  description text,
  sort_order integer not null default 0,
  active boolean not null default true
);

alter table questions add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table questions add column if not exists stakeholder_role_id text references stakeholder_roles(id);
alter table assessment_sessions add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table assessment_sessions add column if not exists stakeholder_role_id text references stakeholder_roles(id);
alter table responses add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table responses add column if not exists stakeholder_role_id text references stakeholder_roles(id);
alter table evidence add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table evidence add column if not exists stakeholder_role_id text references stakeholder_roles(id);
alter table findings add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table findings add column if not exists stakeholder_role_id text references stakeholder_roles(id);
alter table findings add column if not exists supporting_stakeholder_roles jsonb not null default '[]';
alter table findings add column if not exists supporting_stakeholder_groups jsonb not null default '[]';
alter table findings add column if not exists stakeholder_role_agreement_score integer not null default 1 check (stakeholder_role_agreement_score between 1 and 5);
alter table findings add column if not exists stakeholder_group_agreement_score integer not null default 1 check (stakeholder_group_agreement_score between 1 and 5);
alter table findings add column if not exists overall_stakeholder_agreement_score numeric(3,1) not null default 1;
alter table recommendations add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table recommendations add column if not exists stakeholder_role_id text references stakeholder_roles(id);
alter table roadmap_items add column if not exists stakeholder_group_id text references stakeholder_groups(id);
alter table roadmap_items add column if not exists stakeholder_role_id text references stakeholder_roles(id);
