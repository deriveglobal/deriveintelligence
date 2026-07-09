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

insert into stakeholder_groups (id, name, description, sort_order, active) values
  ('executive', 'Executive', 'Owners and senior decision-makers responsible for strategy, investment, and overall company direction.', 1, true),
  ('management', 'Management', 'Managers responsible for translating strategy into operational execution.', 2, true),
  ('operations', 'Operations', 'Teams directly involved in service delivery, field work, dispatch, inventory, and day-to-day execution.', 3, true),
  ('support_functions', 'Support Functions', 'Finance, HR, IT, accounting, compliance, and administrative support teams.', 4, true),
  ('commercial', 'Commercial', 'Sales, account management, marketing, and customer acquisition teams.', 5, true),
  ('customer', 'Customer', 'External customers who receive products or services from the company.', 6, true),
  ('partner', 'Partner', 'External service partners, suppliers, dealers, vendors, or network participants.', 7, true)
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  sort_order = excluded.sort_order,
  active = excluded.active;

insert into stakeholder_roles (id, stakeholder_group_id, name, description, sort_order, active) values
  ('owner', 'executive', 'Owner', 'Business owner or shareholder involved in strategic direction and major decisions.', 1, true),
  ('ceo', 'executive', 'CEO / Managing Director', 'Senior executive responsible for overall business leadership.', 2, true),
  ('operations_manager', 'management', 'Operations Manager', 'Manager responsible for operational coordination, process performance, and execution oversight.', 10, true),
  ('branch_manager', 'management', 'Branch Manager', 'Manager responsible for local branch operations, staff, customers, and performance.', 11, true),
  ('dispatcher', 'operations', 'Dispatcher / Customer Service Coordinator', 'Role responsible for request intake, dispatch coordination, customer updates, and service scheduling.', 20, true),
  ('technician', 'operations', 'Technician / Field Service Technician', 'Field employee responsible for executing service work, inspections, repairs, and documentation.', 21, true),
  ('warehouse_manager', 'operations', 'Warehouse Manager', 'Role responsible for warehouse operations, receiving, storage, picking, and local inventory control.', 22, true),
  ('inventory_coordinator', 'operations', 'Inventory Coordinator', 'Role responsible for inventory tracking, replenishment, transfers, and stock accuracy.', 23, true),
  ('finance_manager', 'support_functions', 'Finance Manager', 'Role responsible for financial reporting, billing, cost control, profitability, and cash flow visibility.', 30, true),
  ('accountant', 'support_functions', 'Accountant', 'Role responsible for accounting records, invoices, reconciliations, and financial transactions.', 31, true),
  ('it_manager', 'support_functions', 'IT Manager / Systems Administrator', 'Role responsible for software systems, integrations, access, infrastructure, and technical support.', 32, true),
  ('sales_manager', 'commercial', 'Sales Manager', 'Role responsible for sales strategy, customer acquisition, account management, and commercial performance.', 40, true),
  ('sales_representative', 'commercial', 'Sales Representative / Account Manager', 'Role responsible for customer communication, selling, follow-up, and account relationship management.', 41, true),
  ('fleet_customer', 'customer', 'Fleet Customer', 'External fleet customer using company services or products.', 50, true),
  ('dealer_customer', 'customer', 'Dealer Customer', 'External dealer or reseller customer.', 51, true),
  ('retail_customer', 'customer', 'Retail Customer', 'Individual or small business customer.', 52, true),
  ('service_partner', 'partner', 'Service Partner', 'External partner involved in service delivery or field support.', 60, true),
  ('dealer_partner', 'partner', 'Dealer Partner', 'Dealer or network partner supporting sales or service operations.', 61, true),
  ('supplier', 'partner', 'Supplier', 'External supplier providing products, parts, materials, or services.', 62, true)
on conflict (id) do update set
  stakeholder_group_id = excluded.stakeholder_group_id,
  name = excluded.name,
  description = excluded.description,
  sort_order = excluded.sort_order,
  active = excluded.active;

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

update questions
set stakeholder_role_id = case
    when lower(coalesce(stakeholder_role, '')) like '%operations manager%' then 'operations_manager'
    when lower(coalesce(stakeholder_role, '')) like '%branch manager%' then 'branch_manager'
    when lower(coalesce(stakeholder_role, '')) like '%dispatcher%' or lower(coalesce(stakeholder_role, '')) like '%customer service coordinator%' then 'dispatcher'
    when lower(coalesce(stakeholder_role, '')) like '%technician%' or lower(coalesce(stakeholder_role, '')) like '%field service technician%' then 'technician'
    when lower(coalesce(stakeholder_role, '')) like '%owner%' then 'owner'
    when lower(coalesce(stakeholder_role, '')) like '%finance manager%' then 'finance_manager'
    when lower(coalesce(stakeholder_role, '')) like '%sales manager%' then 'sales_manager'
    when lower(coalesce(stakeholder_role, '')) like '%fleet customer%' then 'fleet_customer'
    else stakeholder_role_id
  end
where stakeholder_role_id is null;

update questions q
set stakeholder_group_id = r.stakeholder_group_id
from stakeholder_roles r
where q.stakeholder_role_id = r.id and q.stakeholder_group_id is null;

update assessment_sessions
set stakeholder_role_id = case
    when lower(coalesce(stakeholder_role, '')) like '%operations manager%' then 'operations_manager'
    when lower(coalesce(stakeholder_role, '')) like '%branch manager%' then 'branch_manager'
    when lower(coalesce(stakeholder_role, '')) like '%dispatcher%' or lower(coalesce(stakeholder_role, '')) like '%customer service coordinator%' then 'dispatcher'
    when lower(coalesce(stakeholder_role, '')) like '%technician%' or lower(coalesce(stakeholder_role, '')) like '%field service technician%' then 'technician'
    when lower(coalesce(stakeholder_role, '')) like '%owner%' then 'owner'
    when lower(coalesce(stakeholder_role, '')) like '%finance manager%' then 'finance_manager'
    when lower(coalesce(stakeholder_role, '')) like '%sales manager%' then 'sales_manager'
    when lower(coalesce(stakeholder_role, '')) like '%fleet customer%' then 'fleet_customer'
    else stakeholder_role_id
  end
where stakeholder_role_id is null;

update assessment_sessions s
set stakeholder_group_id = r.stakeholder_group_id
from stakeholder_roles r
where s.stakeholder_role_id = r.id and s.stakeholder_group_id is null;

update responses r
set stakeholder_group_id = s.stakeholder_group_id,
    stakeholder_role_id = s.stakeholder_role_id
from assessment_sessions s
where r.assessment_session_id = s.id
  and (r.stakeholder_group_id is null or r.stakeholder_role_id is null);
