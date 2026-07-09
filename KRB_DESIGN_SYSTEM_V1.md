# KRB Design System v1

Source documents:
- `docs/KRB_EXPERIENCE_ARCHITECTURE_V1.md`
- `docs/KRB_EXPERIENCE_STATE_MATRIX_V1.md`

Purpose: create a calm, premium design foundation for the KRB platform before full screen redesign.

This is a foundation layer. It does not change workflows, remove screens, or redesign every view.

## 1. Visual Principles

### Calm Intelligence

The interface should feel composed and precise. The platform is doing complex reasoning, but the surface should not feel noisy.

Use:
- Neutral surfaces.
- Clear hierarchy.
- Reserved accent color.
- Strong spacing rhythm.

Avoid:
- Decorative gradients.
- Random colors.
- Busy cards.
- Dashboard clutter.

### Evidence-Backed Trust

The platform is only credible when insight is traceable. Evidence states, confidence indicators, stakeholder chips, and source links should feel native, not bolted on.

### Decision-First Layout

Owner and executive surfaces should answer:
- What is happening?
- Why is it happening?
- How serious is it?
- What should we do first?
- What happens if we do nothing?

### Operational Clarity

Admin and Operations Center surfaces should show:
- Current state.
- Stuck state.
- Risk state.
- Next safe action.

### Minimal Friction

The UI should reduce cognitive load. Participants answer questions. Admins take actions. Owners make decisions.

### Premium But Not Decorative

Premium means restraint, spacing, typography, and reliable interaction. It does not mean visual noise.

### Dense When Needed, Simple By Default

Tables, logs, and workflow health can be dense. Owner and respondent screens should be simple by default.

## 2. Design Tokens

Implemented in `styles.css`.

Core tokens:
- `--color-bg`
- `--color-surface`
- `--color-surface-raised`
- `--color-surface-subtle`
- `--color-surface-muted`
- `--color-text`
- `--color-text-soft`
- `--color-text-muted`
- `--color-border`
- `--color-border-strong`
- `--color-accent`
- `--color-success`
- `--color-warning`
- `--color-danger`
- `--color-info`

Spacing:
- `--space-1` through `--space-8`

Radius:
- `--radius-xs`
- `--radius-sm`
- `--radius-md`
- `--radius-lg`
- `--radius-xl`

Shadows:
- `--shadow-card`
- `--shadow-raised`
- `--shadow-focus`

Layout:
- `--layout-page-max`
- `--layout-readable`

Layers:
- `--z-sidebar`
- `--z-topbar`
- `--z-drawer`
- `--z-modal`
- `--z-toast`

## 3. Typography

Use the system font stack already in the project.

Scale:
- Page title: `.topbar h1`, `.page-title`
- Section title: `.panel-header h2`, `.section-title`
- Card title: `.card-title`, card `strong`
- Metric number: `.metric-number`, metric card `strong`
- Body: default `body`
- Caption: `.caption`, `.table-caption`
- Table text: `table`, `td`
- Badge text: `.status-pill`, `.badge`, `.state-badge`

Numbers:
- Use tabular numeric styling for metrics.
- Keep metric cards high-contrast and low-decoration.

## 4. Layout System

Reusable classes:
- `.app-shell`
- `.workspace-layout`
- `.page-header`
- `.page-subheader`
- `.command-grid`
- `.card-grid`
- `.two-column-layout`
- `.detail-drawer`
- `.sticky-action-bar`
- `.table-toolbar`
- `.section-stack`

Existing screens now inherit the foundation through existing classes:
- `.topbar`
- `.panel`
- `.owner-dashboard`
- `.assessment-engine-dashboard`
- `.krb-ops-panel`
- `.executive-report-page`
- `.respondent-shell`

## 5. Core Components

Styled in v1:
- Cards
- Metric cards
- Insight cards
- Risk cards
- Opportunity cards
- Status badges
- Progress bars
- Workflow pipeline / stepper
- Tabs
- Filters
- Tables
- Drawers
- Empty states
- Loading skeletons
- Warning states
- Error states
- Permission denied states
- Evidence chips
- Stakeholder chips
- Confidence indicators
- ROI/value indicators

State components remain driven by:
- `renderScreenState(...)`
- `renderLoadingSkeleton(...)`

## 6. Navigation System

Navigation is visually grouped by journey stage.

Setup:
- Projects
- Company DNA
- Assessment Setup

Collect:
- Surveys
- Stakeholders
- Meetings

Intelligence:
- Findings
- Recommendations
- Roadmap
- Question Banks

Executive:
- Owner Dashboard
- Executive Report

Control:
- KRB Operations Center
- Users
- Methodology

No route or workflow changed in v1.

## 7. Motion / Interaction

Allowed:
- Card hover lift.
- Drawer slide.
- Skeleton shimmer.
- Button hover/loading feedback.
- Success confirmation states.

Avoid:
- Heavy page transitions.
- Decorative motion.
- Animations that slow admin work.

## 8. Accessibility

Baseline requirements:
- Focus states are visible.
- Text contrast uses neutral high-contrast tokens.
- Status badges include text, not color alone.
- Tables remain readable.
- Respondent mobile flow remains single-column and usable.
- Magic-link users remain isolated from admin navigation.

## 9. Applied In v1

Applied first to:
1. App shell/navigation
2. Projects
3. Participants
4. Respondent Assessment
5. Owner Dashboard
6. Executive Report
7. KRB Operations Center

Secondary screens inherit tokens and basic components but are not fully redesigned yet.

## 10. Future Redesign Rules

When redesigning screens:
- Use the state matrix before layout decisions.
- Do not show zero-value dashboards when data is missing.
- Keep owner surfaces decision-first.
- Keep admin surfaces operational.
- Keep respondent screens isolated.
- Use approved data by default in executive surfaces.
- Never expose raw stack traces.

