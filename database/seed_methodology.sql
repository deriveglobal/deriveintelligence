-- Starter reusable methodology seed.
-- This creates the global "Digital Transformation Assessment" methodology shell.
-- Question templates should be inserted after this, per stakeholder/survey pack.

with template as (
  insert into methodology_templates (name, description, is_global, status)
  values (
    'Digital Transformation Assessment',
    'Reusable methodology for assessing strategy, operations, data, technology, people, customer experience, financial impact, and innovation opportunities.',
    true,
    'active'
  )
  returning id
),
version as (
  insert into methodology_versions (methodology_template_id, version_label, notes, status, published_at)
  select id, 'v1', 'Initial reusable methodology for multi-industry transformation discovery.', 'published', now()
  from template
  returning id
)
insert into stakeholder_types (methodology_version_id, code, name, layer, sort_order)
select id, code, name, layer, sort_order
from version
cross join (
  values
    ('OWNER', 'Owner', 'Executive Layer', 10),
    ('EXECUTIVE', 'Executive', 'Executive Layer', 20),
    ('OPERATIONS_MANAGER', 'Operations Manager', 'Management Layer', 30),
    ('BRANCH_MANAGER', 'Branch Manager', 'Management Layer', 40),
    ('DISPATCHER', 'Dispatcher', 'Operational Layer', 50),
    ('TECHNICIAN', 'Technician', 'Operational Layer', 60),
    ('WAREHOUSE', 'Warehouse', 'Operational Layer', 70),
    ('FINANCE', 'Finance', 'Management Layer', 80),
    ('SALES', 'Sales', 'Management Layer', 90),
    ('CUSTOMER', 'Customer', 'External Layer', 100),
    ('SUPPLIER', 'Supplier / Partner', 'External Layer', 110),
    ('IT', 'IT', 'Management Layer', 120)
) as seed(code, name, layer, sort_order);

insert into business_domains (methodology_version_id, code, name, sort_order)
select v.id, seed.code, seed.name, seed.sort_order
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('STRATEGY', 'Strategy', 10),
    ('LEADERSHIP', 'Leadership', 20),
    ('OPERATIONS', 'Operations', 30),
    ('SERVICE_DELIVERY', 'Service Delivery', 40),
    ('INVENTORY', 'Inventory', 50),
    ('PROCUREMENT', 'Procurement', 60),
    ('LOGISTICS', 'Logistics', 70),
    ('SALES', 'Sales', 80),
    ('CUSTOMER_SERVICE', 'Customer Service', 90),
    ('FINANCE', 'Finance', 100),
    ('REPORTING', 'Reporting', 110),
    ('DATA', 'Data', 120),
    ('TECHNOLOGY', 'Technology', 130),
    ('HR', 'HR', 140),
    ('COMPLIANCE', 'Compliance', 150),
    ('INNOVATION', 'Innovation', 160)
) as seed(code, name, sort_order)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into assessment_categories (methodology_version_id, code, name, sort_order)
select v.id, seed.code, seed.name, seed.sort_order
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('PROCESS', 'Process', 10),
    ('DATA', 'Data', 20),
    ('TECHNOLOGY', 'Technology', 30),
    ('PEOPLE', 'People', 40),
    ('CUSTOMER_EXPERIENCE', 'Customer Experience', 50),
    ('GOVERNANCE', 'Governance', 60),
    ('FINANCIAL', 'Financial', 70),
    ('RISK', 'Risk', 80)
) as seed(code, name, sort_order)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into problem_types (methodology_version_id, code, name, category_id, keywords, description)
select v.id, seed.code, seed.name, c.id, seed.keywords::jsonb, seed.description
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('BOTTLENECK', 'Bottleneck', 'PROCESS', '["bottleneck","blocked","waiting","tıkan","bekliyor"]', 'Work stops or queues because a step cannot proceed.'),
    ('DELAY', 'Delay', 'PROCESS', '["delay","late","slow","gecik","yavaş"]', 'A process takes longer than expected or agreed.'),
    ('REWORK', 'Rework', 'PROCESS', '["rework","again","repeat","tekrar","yeniden"]', 'Work must be repeated due to missing data, mistakes, or poor handoff.'),
    ('MANUAL_PROCESS', 'Manual Process', 'PROCESS', '["manual","manuel","paper","form","excel"]', 'Work depends on manual effort instead of controlled digital workflow.'),
    ('DUPLICATE_ACTIVITY', 'Duplicate Activity', 'PROCESS', '["duplicate","double","copy","same data","tekrar giriş","kopya"]', 'The same work or data entry occurs more than once.'),
    ('APPROVAL_DELAY', 'Approval Delay', 'PROCESS', '["approval","approve","onay"]', 'Work waits for unclear, slow, or offline approval.'),
    ('LACK_OF_STANDARDIZATION', 'Lack of Standardization', 'PROCESS', '["standard","different","varies","standardizasyon","farklı"]', 'Different teams perform the same work differently.'),
    ('MISSING_OWNERSHIP', 'Missing Ownership', 'GOVERNANCE', '["owner","responsible","ownership","sahip","sorumlu"]', 'No clear accountable owner exists for a process, data object, or decision.'),
    ('MISSING_DATA', 'Missing Data', 'DATA', '["missing data","missing information","eksik bilgi","eksik veri"]', 'Required information is absent at the point of work or decision.'),
    ('INACCURATE_DATA', 'Inaccurate Data', 'DATA', '["wrong","incorrect","inaccurate","hatalı","yanlış"]', 'Data cannot be trusted because it is incorrect or outdated.'),
    ('DUPLICATE_DATA', 'Duplicate Data', 'DATA', '["duplicate data","duplicate record","mükerrer","çift kayıt"]', 'Multiple records represent the same real object or transaction.'),
    ('DATA_SILOS', 'Data Silos', 'DATA', '["silo","separate","not shared","ayrı","paylaşılmıyor"]', 'Information is trapped in separate teams, tools, or files.'),
    ('REPORTING_GAPS', 'Reporting Gaps', 'DATA', '["report","dashboard","kpi","rapor"]', 'The organization cannot reliably produce needed operational or management reporting.'),
    ('NO_SINGLE_SOURCE_OF_TRUTH', 'No Single Source of Truth', 'DATA', '["single source","truth","which number","tek kaynak"]', 'Teams disagree on which system or number is authoritative.'),
    ('LEGACY_SYSTEM', 'Legacy System', 'TECHNOLOGY', '["legacy","old system","eski sistem"]', 'A system limits workflow, reporting, integration, or usability.'),
    ('MISSING_INTEGRATION', 'Missing Integration', 'TECHNOLOGY', '["integration","integrated","connect","entegrasyon","bağlı değil"]', 'Systems do not exchange required data automatically.'),
    ('POOR_USABILITY', 'Poor Usability', 'TECHNOLOGY', '["hard to use","difficult system","kullanımı zor"]', 'Users avoid or misuse a tool because it is difficult to use.'),
    ('SYSTEM_DOWNTIME', 'System Downtime', 'TECHNOLOGY', '["downtime","unavailable","çalışmıyor","erişilemiyor"]', 'Systems are unavailable when work needs to be performed.'),
    ('LACK_OF_AUTOMATION', 'Lack of Automation', 'TECHNOLOGY', '["automation","automate","otomasyon","otomatik"]', 'Repeatable work is not automated.'),
    ('SPREADSHEET_DEPENDENCY', 'Spreadsheet Dependency', 'TECHNOLOGY', '["spreadsheet","excel"]', 'Key processes or reports depend on spreadsheets.'),
    ('WHATSAPP_DEPENDENCY', 'WhatsApp Dependency', 'TECHNOLOGY', '["whatsapp"]', 'Operational coordination depends on WhatsApp or similar unmanaged channels.'),
    ('TRAINING_GAP', 'Training Gap', 'PEOPLE', '["training","train","eğitim"]', 'Users lack training required to perform work consistently.'),
    ('KNOWLEDGE_DEPENDENCY', 'Knowledge Dependency', 'PEOPLE', '["one person","specific employee","knowledge","kişiye bağlı"]', 'Work depends on specific people rather than documented process/system.'),
    ('SKILL_GAP', 'Skill Gap', 'PEOPLE', '["skill","capability","yetkinlik","beceri"]', 'The organization lacks required skills for the target operating model.'),
    ('COMMUNICATION_PROBLEM', 'Communication Problem', 'PEOPLE', '["communication","communicate","iletişim"]', 'People or teams do not receive the right information at the right time.'),
    ('RESOURCE_CONSTRAINT', 'Resource Constraint', 'PEOPLE', '["resource","capacity","too few","kaynak","kapasite"]', 'Work is constrained by staffing, capacity, or availability.'),
    ('CHANGE_RESISTANCE', 'Change Resistance', 'PEOPLE', '["resistance","adoption","direnç","benimseme"]', 'Users resist or struggle to adopt new ways of working.'),
    ('VISIBILITY_PROBLEM', 'Visibility Problem', 'CUSTOMER_EXPERIENCE', '["visibility","tracking","view","görünürlük","takip"]', 'Customers or internal teams cannot see status, history, or ownership.'),
    ('SLOW_RESPONSE', 'Slow Response', 'CUSTOMER_EXPERIENCE', '["response","waiting customer","yanıt","müşteri bekliyor"]', 'Customers wait too long for service, confirmation, or updates.'),
    ('SERVICE_QUALITY_ISSUE', 'Service Quality Issue', 'CUSTOMER_EXPERIENCE', '["quality","repeat visit","complaint","kalite","tekrar ziyaret"]', 'Service outcomes are inconsistent or below expectation.'),
    ('COMPLAINT_TREND', 'Complaint Trend', 'CUSTOMER_EXPERIENCE', '["complaint","şikayet"]', 'Repeated customer complaints reveal a pattern.'),
    ('CUSTOMER_FRUSTRATION', 'Customer Frustration', 'CUSTOMER_EXPERIENCE', '["frustration","annoyed","memnuniyetsizlik","rahatsız"]', 'The customer experience creates avoidable friction.'),
    ('REVENUE_LEAKAGE', 'Revenue Leakage', 'FINANCIAL', '["revenue","lost sale","leakage","gelir"]', 'Money is lost due to process, billing, pricing, or missed opportunity.'),
    ('COST_OVERRUN', 'Cost Overrun', 'FINANCIAL', '["cost overrun","extra cost","fazla maliyet"]', 'Costs exceed expectation due to inefficiency or poor control.'),
    ('BILLING_DELAY', 'Billing Delay', 'FINANCIAL', '["billing","invoice","fatura"]', 'Invoice or billing flow is delayed.'),
    ('INVENTORY_WASTE', 'Inventory Waste', 'FINANCIAL', '["inventory","stock","stok","envanter"]', 'Inventory problems create waste, shortage, or excess cost.'),
    ('MARGIN_EROSION', 'Margin Erosion', 'FINANCIAL', '["margin","profitability","marj","kârlılık"]', 'Profit margin is reduced by operational or commercial leakage.')
) as seed(code, name, category_code, keywords, description)
join assessment_categories c on c.methodology_version_id = v.id and c.code = seed.category_code
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into root_cause_types (methodology_version_id, code, name)
select v.id, seed.code, seed.name
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('PEOPLE', 'People'),
    ('PROCESS', 'Process'),
    ('TECHNOLOGY', 'Technology'),
    ('DATA', 'Data'),
    ('ORGANIZATION', 'Organization'),
    ('GOVERNANCE', 'Governance')
) as seed(code, name)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into impact_dimensions (methodology_version_id, code, name)
select v.id, seed.code, seed.name
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('TIME', 'Time'),
    ('COST', 'Cost'),
    ('QUALITY', 'Quality'),
    ('CUSTOMER', 'Customer'),
    ('REVENUE', 'Revenue'),
    ('RISK', 'Risk'),
    ('COMPLIANCE', 'Compliance'),
    ('EMPLOYEE_EXPERIENCE', 'Employee Experience')
) as seed(code, name)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into maturity_dimensions (methodology_version_id, code, name, sort_order)
select v.id, seed.code, seed.name, seed.sort_order
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('LEADERSHIP', 'Leadership', 10),
    ('STRATEGY', 'Strategy', 20),
    ('OPERATIONS', 'Operations', 30),
    ('CUSTOMER_EXPERIENCE', 'Customer Experience', 40),
    ('DATA', 'Data', 50),
    ('TECHNOLOGY', 'Technology', 60),
    ('AUTOMATION', 'Automation', 70),
    ('ANALYTICS', 'Analytics', 80),
    ('INNOVATION', 'Innovation', 90)
) as seed(code, name, sort_order)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into opportunity_classes (methodology_version_id, code, name, min_timeline_months, max_timeline_months, description)
select v.id, seed.code, seed.name, seed.min_months, seed.max_months, seed.description
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('QUICK_WIN', 'Quick Win', 0, 3, 'Low complexity initiative deliverable in less than three months.'),
    ('MEDIUM_INITIATIVE', 'Medium Initiative', 3, 12, 'Cross-functional improvement delivered in three to twelve months.'),
    ('STRATEGIC_INITIATIVE', 'Strategic Initiative', 12, null, 'Larger capability requiring staged delivery and organizational alignment.'),
    ('TRANSFORMATIONAL_INITIATIVE', 'Transformational Initiative', 12, null, 'Enterprise-wide platform, operating model, or data capability.')
) as seed(code, name, min_months, max_months, description)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';

insert into roadmap_phases (methodology_version_id, code, name, phase_number, description)
select v.id, seed.code, seed.name, seed.phase_number, seed.description
from methodology_versions v
join methodology_templates t on t.id = v.methodology_template_id
cross join (
  values
    ('PHASE_1_QUICK_WINS', 'Phase 1 - Quick Wins', 1, 'Immediate improvements, forms, dashboards, and reporting fixes.'),
    ('PHASE_2_FOUNDATION', 'Phase 2 - Foundation', 2, 'Data model, integrations, governance, and core workflow standardization.'),
    ('PHASE_3_OPTIMIZATION', 'Phase 3 - Optimization', 3, 'Automation, analytics, operational intelligence, and process performance.'),
    ('PHASE_4_TRANSFORMATION', 'Phase 4 - Transformation', 4, 'Enterprise platforms, predictive systems, and new digital capabilities.')
) as seed(code, name, phase_number, description)
where t.name = 'Digital Transformation Assessment' and v.version_label = 'v1';
