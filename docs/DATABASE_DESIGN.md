# Digital Transformation Assessment Platform Database Design

## Product Principle

This platform must be reusable for any company. KRB is the first assessment project, not the product boundary.

The product is a structured discovery engine:

```text
Organization
  -> Assessment Project
    -> Methodology Template
      -> Survey Templates
        -> Question Metadata
          -> Responses
            -> AI Findings
              -> Pain Points
              -> KPIs
              -> Opportunities
              -> Recommendations
              -> Roadmap Items
```

## Research-Informed Design Decisions

1. Use PostgreSQL as the product database.
   PostgreSQL is a strong fit because the app needs relational integrity, JSONB for AI outputs, indexes for analytics, and future Row Level Security.

2. Use a shared-schema multi-tenant model first.
   Every tenant-owned table carries `organization_id`; most assessment records also carry `assessment_project_id`. This keeps the first SaaS version operationally simple while preserving a path to stronger tenant isolation later.

3. Treat methodology as versioned product data.
   Domains, categories, problem types, root causes, impact dimensions, maturity dimensions, survey templates, and questions are stored under `methodology_templates` and `methodology_versions`. This lets us improve the methodology without breaking historical projects.

4. Separate human question text from AI-readable metadata.
   A good answer is only analyzable if the question already carries intent, expected signals, category mappings, and scoring rules.

## Core Tables

### SaaS Core

- `organizations`
- `users`
- `organization_memberships`
- `audit_events`

These make the platform reusable across many client companies.

### Methodology Library

- `methodology_templates`
- `methodology_versions`
- `stakeholder_types`
- `business_domains`
- `assessment_categories`
- `problem_types`
- `root_cause_types`
- `impact_dimensions`
- `maturity_dimensions`
- `opportunity_classes`
- `roadmap_phases`

These tables are the reusable consulting intelligence.

### Question System

- `survey_templates`
- `question_templates`
- `question_translations`
- `question_options`
- `question_option_translations`
- `question_domain_map`
- `question_category_map`
- `question_expected_problem_types`
- `question_expected_impacts`
- `question_expected_root_causes`

This is the most important part for AI readability.

Each question must define:

- stakeholder type
- domains
- categories
- question type
- required status
- scoring eligibility
- weight
- AI intent
- expected problem types
- expected impact dimensions
- expected root causes
- KPI extractability
- maturity dimension
- English and Turkish text

### Assessment Execution

- `assessment_projects`
- `departments`
- `process_inventory`
- `project_stakeholders`
- `survey_assignments`
- `survey_response_sessions`
- `response_answers`

These records are client/project-specific.

### AI Outputs

- `response_answer_analysis`
- `response_analysis_domains`
- `response_analysis_problem_types`
- `response_analysis_root_causes`
- `response_analysis_impacts`
- `pain_points`
- `pain_point_evidence`
- `kpis`
- `opportunities`
- `recommendations`
- `roadmap_items`
- `maturity_scores`
- `generated_reports`

These are the outputs the platform sells.

## AI-Readable Question Design

Bad question:

```text
What problems do you have?
```

Better:

```text
Which process creates the most delay?
How often does it happen?
Who is affected?
What system or communication channel is involved?
What is the business impact?
```

Best database representation:

```text
Question:
Which process creates the most delay?

AI Intent:
Detect bottlenecks, delay frequency, affected process, and time/customer impact.

Expected Problem Types:
Bottleneck, Delay, Approval Delay, Process Complexity

Expected Impact Dimensions:
Time, Customer, Quality

Expected Root Causes:
Process, Governance, People

KPI Extractable:
Yes

Scoring Eligible:
Yes
```

## Why Responses Need Context

Weak response:

```text
Reports take too long.
```

AI-readable response:

```text
Organization: KRB
Project: Digital Transformation Assessment
Stakeholder: Operations Manager
Department: Operations
Process: Weekly KPI Reporting
Question Intent: Detect manual reporting workload
Answer: Reports take too long.
Frequency: Weekly
Impact: Time + Management Visibility
```

This enables AI to produce:

```text
Problem Type: Reporting Gap
Root Cause: Data + Technology
Severity: 4
Automation Potential: 5
Opportunity: Quick Win
Recommendation: Create automated KPI dashboard
Roadmap Phase: Phase 1 - Quick Wins
```

## Build Sequence

1. Install PostgreSQL.
2. Apply `database/schema.sql`.
3. Apply `database/seed_methodology.sql`.
4. Move hardcoded app constants into methodology tables.
5. Replace localStorage users, surveys, responses, and analysis with API-backed database records.
6. Add server-side auth and role enforcement.
7. Add AI analysis endpoint that writes to `response_answer_analysis`.
8. Generate reports from database-backed findings, not browser state.

## Next Engineering Step

The next code milestone should be:

```text
POST /api/survey-assignments
GET /api/survey-assignments/:token
POST /api/responses
POST /api/projects/:id/analyze
```

That moves the platform from browser state into a reusable, sellable SaaS foundation.
