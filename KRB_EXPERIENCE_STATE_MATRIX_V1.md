# KRB Experience State Matrix v1

Source of truth: `docs/KRB_EXPERIENCE_ARCHITECTURE_V1.md`.

Purpose: define required behavior for every major KRB screen before visual redesign. This matrix describes what the user should see in empty, loading, active, success, warning, error, and permission-denied states.

Global rules:
- Do not show broken-looking dashboards with zero values.
- Every empty or warning state should include a clear next action.
- Loading states use consistent skeletons or clear progress copy.
- Errors use friendly language and never expose raw stack traces.
- Permission denied states must be safe and must not leak data.
- Owner-facing screens use approved findings and approved recommendations by default.

## State Components Implemented

Reusable UI primitives now exist in `app.js` and `styles.css`:
- `renderScreenState(screenId, state, overrides)`
- `renderLoadingSkeleton(title, rows)`
- `screenStateCopy`
- `viewAllowedForRole(viewId, role)`
- safe generated `#permission-denied` screen
- shared `.screen-state-*` styles

## Screen Matrix

| Screen | Empty State | Loading State | Active State | Success State | Warning State | Error State | Permission Denied |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Public Homepage | Show product story and login/signup entry. | Minimal page load; avoid app shell flash. | Hero, Intelligence Engine explorer, login CTA. | Signup/login CTA focus or demo CTA accepted. | Browser/auth issue copy if login panel cannot initialize. | Friendly page load message; no stack trace. | Not applicable. |
| Login / Signup | Show sign-in and signup/access request options. | Button-level loading during auth. | Login, signup, reset password forms. | Authenticated user enters role-appropriate start page. | Invalid credentials or missing fields shown inline. | "Sign in failed. Check details and try again." | Not applicable. |
| Projects | "No projects yet. Create a company project..." | Skeleton or "Loading projects." | Project cards with open workspace actions. | New project appears and can be opened. | No active workspace selected for workspace views. | "Projects could not load." | Restricted to creator/consultant/auditor. |
| Company DNA | "Open a project first." | Form hydration loading. | Intake form and Company DNA summary. | Saved context updates recommended roles/KPIs. | Missing Company DNA blocks blueprint generation. | "Company context could not save/load." | Safe denied view if role cannot access. |
| Assessment Blueprint | "Blueprint is not generated yet." | "Generating blueprint..." | Required/recommended/optional roles, KPI sets, domains, coverage. | Blueprint generated/regenerated. | Coverage gaps and incomplete required roles. | "Blueprint action failed." | Safe denied view. |
| Participants | "Add participants manually or upload a stakeholder list..." | Participant table hydration. | Add/edit/deactivate, create sessions, links, invite/reminder actions. | Participant/session/link/invite/reminder action succeeds. | Required role coverage incomplete; overdue/incomplete participants. | Friendly participant action failure. | Safe denied view. |
| Participant Upload | "No upload preview yet." | "Reading upload..." | Preview rows with Ready/Warning/Invalid/Duplicate. | Import summary and create sessions action. | Warnings import only with confirmation. | Invalid file/upload failure message. | Safe denied view. |
| Respondent Assessment | "No questions are available for this role yet." | Secure link verification skeleton. | Role-specific questions, progress, save/submit. | Submitted state with completed badge. | Missing/invalid required answers highlighted. | Invalid/expired/regenerated link message. | Respondent cannot access admin screens. |
| Respondent Completion | Not applicable. | Not applicable. | Completed confirmation. | "Assessment Completed. Thank you." | Not applicable. | If completion cannot be confirmed, show contact-admin copy. | Isolated respondent route only. |
| Invalid / Expired Link | Not applicable. | Token validation. | Not applicable. | Not applicable. | Link expired or regenerated. | "Assessment link unavailable." | No data leakage. |
| Analysis Overview | "Assessment engine is waiting." | "Running analysis..." | Sessions, findings, evidence, recommendations, roadmap counts and panels. | Analysis outputs generated. | Completed sessions but missing findings/evidence/recommendations/roadmap. | "Analysis failed." | Safe denied view. |
| Findings Workbench | "No findings yet." | Refreshing engine. | Findings table, lifecycle controls, agreement, contradiction, evidence count. | Finding approved/rejected/edited/merged. | Findings without evidence or draft findings pending review. | Friendly finding action error. | Safe denied view. |
| Evidence Explorer | "Select a finding." | Finding/evidence refresh. | Source questions, responses, roles, groups, triggers. | Evidence inspected/selected. | Finding has no evidence records. | Evidence load failure copy. | Safe denied view. |
| KPI Gap Review | "No critical KPI gaps detected yet." | Analysis loading. | Missing KPI radar grouped by domain. | KPI gap approved or included in owner/report output. | Company DNA expects KPIs not measured. | KPI gap generation/load failure. | Safe denied view. |
| Recommendation Review | "No recommendations yet." | Recommendation generation/loading. | Recommendation cards with v2 intelligence, ROI, owner, timeline, lifecycle. | Approved/accepted/in progress/completed/outcome tracked. | Draft recommendations need approval; missing ROI fields. | Friendly recommendation action error. | Safe denied view. |
| Roadmap Review | "No roadmap items yet." | Roadmap generation/loading. | Quick Wins/Foundation/Optimization/Transformation. | Roadmap items generated and approved through recommendation lifecycle. | Recommendations exist but roadmap missing. | Roadmap load/generation failure. | Safe denied view. |
| Owner Dashboard | "Assessment is still in progress..." | Owner dashboard hydration. | Approved executive command center with evidence drill-down. | Owner can open report or evidence. | Coverage gaps, misalignment, missing KPIs, no approved recommendations. | Owner dashboard could not load. | Safe denied view. |
| Executive Report | "Executive report is not ready yet..." | "Generating executive report..." | Structured report page with print-friendly sections. | Report generated and viewable. | Approved findings/recommendations missing; report incomplete. | "Executive report unavailable." | Safe denied view. |
| Progress History | "No progress baseline yet." | Snapshot generation/loading. | Snapshot history and comparisons. | Snapshot generated/regenerated. | Baseline only; no previous comparison yet. | Progress snapshot failure. | Safe denied view. |
| KRB Operations Center | "No KRB operations records yet." | Mission control skeleton. | Overview, workflow, participants, comms, links, analysis, report, issues, logs, QA, health. | No open issues / healthy system states. | Overdue, failed, missing, validation warning, incomplete workflow. | Operations Center could not load. | Creator-only safe denied view. |
| Issues | "No open issues." | Issue list loading. | Manual/system issues with resolve actions. | Issue resolved/closed. | Generated issue suggestions need review. | Issue action failure. | Creator-only safe denied view. |
| Audit Logs | "No audit events recorded yet." | Log loading. | Filterable audit events. | Action appears in audit trail. | Missing expected audit event should be QA warning. | Audit log load failure. | Creator/auditor-safe denied view. |
| QA History | "No QA runs recorded yet." | QA history loading. | QA runs, failed checks, cleanup, counts. | QA run saved. | Warning/failed QA run visible. | QA save/load failure. | Creator/auditor-safe denied view. |
| System Health | "No recent backend errors." | Health endpoint loading. | App, DB, email, errors, warnings, failed emails/reminders. | Healthy checks display green. | Email disabled, workflow warnings, npm audit note. | Health endpoint failure. | Creator-only safe denied view. |

## Implemented Screen Behavior

Implemented now:
- Shared state component and skeleton styles.
- Safe permission-denied screen for role-restricted navigation.
- Projects empty state.
- Company DNA no-workspace state.
- Assessment Blueprint no-blueprint state.
- Participants no-assessment and no-participant states.
- Participant Upload no-preview state.
- Respondent loading, invalid-link, no-question, validation-warning states.
- Analysis Overview no-workspace/no-engine state.
- Findings Workbench empty state.
- Evidence Explorer empty and warning states.
- Recommendations empty state.
- Roadmap empty state.
- Owner Dashboard in-progress gate before approved data exists.
- Executive Report readiness warning and report-generation empty state.
- Operations Center loading, empty, no-issues, no-logs, no-links, no-analysis, no-report, no-QA, and no-errors states.

## Remaining Redesign Notes

For visual redesign, keep these behaviors and improve layout only:
- Do not remove state copy.
- Do not show zero-value dashboards before data is ready.
- Keep next-action buttons visible.
- Keep permission denial safe.
- Keep respondent validation strict and visible.

