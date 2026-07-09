# KRB Experience Architecture v1

Purpose: define the product experience before redesigning UI.

Core rule: every screen must support a user journey. A screen should not exist only because a feature exists.

## User Types

- Public Visitor: learns the platform story, explores the intelligence engine, and enters login/signup.
- Creator / Platform Admin: configures, launches, monitors, audits, and troubleshoots KRB assessments.
- Consultant / Analyst: reviews findings, evidence, KPI gaps, recommendations, roadmap, ROI, and report outputs.
- Business Owner / Executive Viewer: consumes approved decision intelligence, dashboard, evidence drill-down, progress, and report.
- Assessment Participant / Respondent: completes one assigned role-based assessment through a secure link.
- QA / Auditor: verifies access control, workflow health, logs, QA runs, cleanup, and data quality.

## Core Journeys

1. Public visitor understands the platform.
2. Admin creates a real KRB assessment.
3. Participant completes an assessment.
4. Admin monitors response collection.
5. Analyst runs intelligence review.
6. Owner reviews decision intelligence.
7. Admin runs operations control.
8. Company tracks progress over time.

## Navigation Model

Public:
- Home
- Explore Intelligence Engine
- Login
- Signup / Request Access

Workspace:
- Projects
- Assessment Setup
- Participants
- Analysis
- Owner Dashboard
- Executive Report
- Progress
- KRB Operations Center
- Users
- Methodology

Respondent:
- No workspace navigation.
- Assessment only.

## Information Hierarchy

1. Company Context: Company DNA, blueprint, stakeholder role coverage.
2. Collection State: participants, sessions, links, invitations, reminders, completion.
3. Evidence: questions, responses, evidence records, trigger rules, stakeholder roles/groups.
4. Intelligence: findings, KPI gaps, agreement, contradictions, confidence, priority.
5. Action: recommendations, roadmap, owners, timeline, dependencies.
6. Value And Outcomes: ROI estimates, actual value, outcome tracking, recommendation accuracy.
7. Control And Trust: Operations Center, issues, errors, audit logs, QA runs, system health.

## Command Center Design

KRB Operations Center is mission control, not an owner insight dashboard.

It should answer:
- Is the app healthy?
- Are assessments moving?
- Who is stuck?
- Which communications failed?
- Which links are broken or expired?
- Are completed sessions producing intelligence?
- Are reports complete?
- What errors happened?
- Who changed what?
- What needs action now?

Modes:
- Monitor: quick health check.
- Investigate: inspect stuck or failing workflow.
- Act: take safe operational actions.
- Prove: verify QA, audit, cleanup, and health before pilot.

## Screen Principle

Owner screens show decisions, not survey administration.
Admin screens show control, traceability, and risk.
Respondent screens stay isolated.
Evidence is the trust layer.
Approved data is the executive default.

