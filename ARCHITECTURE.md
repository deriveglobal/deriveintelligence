# Derive / KRB Platform Architecture

## Key Architectural Decisions

**1. Framework-level vs company-level**

Questions and domains are
FRAMEWORK-LEVEL — reusable across
all companies in an industry.

Company context (intake data,
perception gaps, KPI selections)
enters at FINDINGS time, not at
QUESTION GENERATION time.

This enables:
- Scale: one framework serves
  all tire companies
- Learning: findings improve with
  each assessment
- Benchmarking: cross-company
  comparison becomes possible

**2. Domains vs KPIs**

Domains = what we measure
(organizational dimensions)

KPIs = measurable signals within
domains (optional linkage)

KPI linkage on questions is OPTIONAL.
Only tag when the question genuinely
probes perception of a specific
measurable metric. Most questions
probe perception, not metrics.

**3. Sampling over exhaustive testing**

15 questions per participant (target),
not all questions in the bank.

Pool size (25-40) serves multiple
companies and activities.
Participant set (15) serves engagement
and data quality.

Adding more questions to a bank
only helps if they add UNIQUE SIGNAL
— different domain, different
misalignment pattern.

**4. Perception gaps as primary signal**

The gap between owner self-assessment
(intake) and participant reality
(responses) is the most powerful
misalignment signal.

This feeds AI findings as high-priority
context — a 2.6 gap in data_quality
should almost always generate a finding.

**5. Learning system**

The platform gets smarter with each
assessment. Consultant feedback
(approve/reject/edit) feeds back
into the AI findings generation
context for the same industry.

Over time this creates an industry-
specific intelligence layer that
no competitor can replicate without
running the same volume of assessments.

**6. The photo taker principle**

Derive diagnoses. It does not track.
Ongoing KPI monitoring, dashboards,
and trend tracking are extensional
modules — not core product.

The assessment is a snapshot in time.
Value comes from the quality of the
diagnosis, not the frequency of
measurement.

---

## Known Gaps & Next Sprints

**Sprint 1 (current — commercial push):**
- [ ] Complete question bank generation
- [ ] PDF report polish
- [ ] Email system (HTML templates)
- [ ] Run KRB end-to-end
- [ ] Homepage update

**Sprint 2 (post-commercial):**
- [ ] Three-way perception comparison UI
  (intake vs owner vs participants)
- [ ] Domain heatmap in reports
- [ ] Bank quality audit tool
  (redundant question detection)
- [ ] Role-specific expected domains
  (not universal 9 for every role)
- [ ] Shell refactoring (shared components)

**Sprint 3:**
- [ ] Bilingual EN/TR
  (question_translations table)
- [ ] Industry benchmarks UI
  (hallucination index display)
- [ ] Second framework (new industry)
- [ ] Owner structured assessment
  (replaces intake maturity scores)

**Future (extensional modules):**
- [ ] KPI tracking dashboard
- [ ] Trend comparison (assessment over time)
- [ ] API for ERP integration
- [ ] White-label for consultants
- [ ] Mobile participant app

---

## Database Tables Reference

Core:
- `assessments` — assessment instances
- `assessment_sessions` — per-participant
- `responses` — individual answers
- `questions` — question pool
- `framework_question_banks` — role banks
- `frameworks` — assessment frameworks

Intelligence:
- `domain_taxonomy` — 22 domains
- `framework_kpis` — 31 KPIs
- `framework_activities` — 18 activities
- `intake_domain_mapping` — intake → domain
- `domain_perception_gaps` — gap scores
- `industry_benchmarks` — rolling averages

Findings:
- `findings` — named problems
- `evidence` — supporting responses
- `recommendations` — actions
- `roadmap_items` — sequenced plan
- `ai_finding_examples` — learning data
- `finding_consultant_feedback`
- `ai_analysis_context` — industry learning

Config:
- `framework_scoring_config` — weights
- `company_kpi_selections` — tracked KPIs
- `project_context_intakes` — intake data
- `company_profiles` — normalized profile

---

## Server Architecture

- **Runtime:** Node.js (ES modules)
- **Database:** PostgreSQL via pg pool
- **AI:** Anthropic SDK (claude-sonnet-4-6)
- **PDF:** pdfkit
- **Email:** Microsoft Graph API
- **Container:** Docker on Hetzner VPS
- **Domain:** krb.deriveglobal.com
- **Port mapping:** 8080 → 3000

**Key files:**
- `server.mjs` — all API routes,
  AI engine, DB queries
- `app.js` — client-side application
- `shells/platform.js` — platform owner UI
- `shells/consultant.js` — consultant UI
- `participant.js` — participant view
- `components/` — shared UI components
- `styles.css` — global styles

---

*This document should be updated
whenever a significant architectural
decision is made or a new layer
is added to the intelligence chain.*
