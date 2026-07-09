import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

function formatEstimatedValue(value = 0) {
  const amount = Number(value || 0);
  if (!amount) return 'Value TBD';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    maximumFractionDigits: 0
  }).format(amount) + '/year';
}

function formatOpsDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function platformSeverityClass(severity = '') {
  if (severity === 'critical') return 'danger';
  if (severity === 'high') return 'danger';
  if (severity === 'medium') return 'warning';
  return 'success';
}

function platformStageClass(stage = '') {
  const normalized = String(stage || '').toLowerCase().replace(/\s+/g, '-');
  if (normalized === 'executive-ready' || normalized === 'completed') return 'approved';
  if (normalized === 'review' || normalized === 'recommendations') return 'in-progress';
  if (normalized === 'collecting') return 'warning';
  return 'draft';
}

function platformTaskButton(item = {}, className = 'ghost-button', callbacks = {}) {
  const projectId = item.project_id || '';
  const actionView = item.action_view || 'dashboard';
  if (actionView === 'executive-report' && callbacks.onOpenReport) {
    return `<button class="${className}" data-component-platform-open-report="${escapeHtml(projectId)}" type="button">${escapeHtml(item.action_label || 'Open')}</button>`;
  }
  if (callbacks.onOpenOrganization) {
    return `<button class="${className}" data-component-platform-open-organization="${escapeHtml(projectId)}" data-platform-view="${escapeHtml(actionView)}" type="button">${escapeHtml(item.action_label || 'Open')}</button>`;
  }
  return '';
}

function renderPlatformMetric(label, value, note = '') {
  const hasValue = value !== null && value !== undefined && value !== '';
  return `
    <article>
      <span>${escapeHtml(label)}</span>
      <strong>${hasValue ? escapeHtml(String(value)) : 'No data yet'}</strong>
      ${note ? `<small>${escapeHtml(note)}</small>` : ''}
    </article>
  `;
}

export function renderPlatformCommandCenterComponent(
  metrics,
  classificationFilter = 'production',
  error = null,
  emptyStateHtml = '',
  callbacks = {}
) {
  if (error) {
    return renderScreenState('projects', 'error', {
      title: 'Platform Command Center could not load',
      message: error,
      actionLabel: callbacks.onRefresh ? 'Refresh' : '',
      actionView: 'platform-command'
    });
  }
  const state = metrics;
  if (!state) return renderLoadingSkeleton('Loading Platform Command Center', 6);

  const snapshots = state.classification_snapshots || {};
  const activeClassification = snapshots[classificationFilter] ? classificationFilter : 'production';
  const snapshot = snapshots[activeClassification] || state.platform_snapshot || {};
  const allOrganizations = state.organization_portfolio_all || state.organization_portfolio_summary || [];
  const organizations = activeClassification === 'all'
    ? allOrganizations
    : allOrganizations.filter((org) => (org.classification || 'production') === activeClassification);
  const allAttention = state.needs_attention_all || state.needs_attention || [];
  const attention = activeClassification === 'all'
    ? allAttention
    : allAttention.filter((item) => (item.classification || 'production') === activeClassification);
  const pipeline = organizations.reduce((totals, org) => {
    if (org.stage === 'Setup') totals.setup += 1;
    else if (org.stage === 'Collecting') totals.collecting += 1;
    else if (org.stage === 'Review') totals.review += 1;
    else if (org.stage === 'Executive Ready') totals.executive_ready += 1;
    if (org.stage === 'Executive Ready' && org.report_status === 'Ready') totals.recommendations += 1;
    if (org.assessment_status === 'completed') totals.completed += 1;
    if (Number(org.completion_percent || 0) < 100 && (Number(org.open_issues || 0) || attention.some((item) => item.project_id === org.project_id && ['critical', 'high'].includes(item.severity)))) totals.at_risk += 1;
    return totals;
  }, { setup: 0, collecting: 0, review: 0, recommendations: 0, executive_ready: 0, completed: 0, at_risk: 0 });
  const consultants = state.consultant_workload || [];
  const allReports = state.reports_ready_all || state.reports_ready || [];
  const reports = activeClassification === 'all'
    ? allReports
    : allReports.filter((report) => (report.classification || 'production') === activeClassification);
  const ops = state.operations_health || {};
  const allIssues = state.open_issues_all || state.open_issues || [];
  const issues = activeClassification === 'all'
    ? allIssues
    : allIssues.filter((issue) => (issue.classification || 'production') === activeClassification);
  const activity = state.recent_activity || [];
  const next = attention[0] || (reports[0] ? {
    type: 'report_ready',
    severity: 'low',
    organization_name: reports[0].organization_name,
    assessment_name: reports[0].assessment_name,
    project_id: reports[0].project_id,
    label: 'Executive report ready',
    explanation: 'Review the report before delivery.',
    action_label: 'Open Report',
    action_view: 'executive-report'
  } : state.next_best_action);

  if (!Number(snapshot.total_organizations || 0)) {
    return emptyStateHtml || renderScreenState('projects', 'empty', {
      title: 'No organizations yet',
      message: 'Create your first organization to start an assessment.',
      actionLabel: callbacks.onOpenOrganization ? 'Create Organization' : '',
      actionView: 'projects'
    });
  }

  return `
    <section class="platform-command">
      <section class="panel platform-hero">
        <div>
          <span class="eyebrow">Platform Command Center</span>
          <h2>SaaS mission control across every organization and assessment.</h2>
          <p>Platform-wide status, tenant risks, delivery workload, report readiness, operations health, and the next best action are consolidated here.</p>
          <div class="owner-command-meta">
            <span>Generated: ${escapeHtml(formatOpsDate(state.generated_at))}</span>
            <span>Role: Platform Owner</span>
            <span>Scope: ${activeClassification === 'all' ? 'All classifications' : `${activeClassification} organizations`}</span>
          </div>
        </div>
        <div class="platform-next-action">
          <span class="eyebrow">Next Best Action</span>
          ${next ? `
            <span class="status-pill ${platformSeverityClass(next.severity)}">${escapeHtml(next.severity || 'priority')}</span>
            <h3>${escapeHtml(next.label || 'Open action')}</h3>
            <p>${escapeHtml(next.organization_name || 'Platform')} · ${escapeHtml(next.explanation || '')}</p>
            ${platformTaskButton(next, 'primary-button', callbacks)}
          ` : `
            <h3>No urgent platform action</h3>
            <p>There are no blocked assessments, critical issues, failed communications, or report-review alerts right now.</p>
          `}
        </div>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div><h2>Platform Snapshot</h2><span>Cross-tenant operating signals</span></div>
          <div class="panel-actions">
            <div class="segmented-control platform-classification-toggle" aria-label="Filter platform metrics by classification">
              ${['production', 'demo', 'qa', 'internal', 'all'].map((classification) => `
                <button class="${activeClassification === classification ? 'active' : ''}" ${callbacks.onClassificationFilterChange ? `data-component-platform-classification-filter="${classification}"` : ''} type="button">${escapeHtml(classification === 'qa' ? 'QA' : classification.charAt(0).toUpperCase() + classification.slice(1))}</button>
              `).join('')}
            </div>
            ${callbacks.onRefresh ? `<button class="ghost-button" data-component-platform-refresh type="button">Refresh</button>` : ''}
          </div>
        </div>
        <div class="platform-metric-grid">
          ${renderPlatformMetric('Production Organizations', snapshot.production_organizations)}
          ${renderPlatformMetric('Demo Organizations', snapshot.demo_organizations)}
          ${renderPlatformMetric('QA Organizations', snapshot.qa_organizations)}
          ${renderPlatformMetric('Internal Organizations', snapshot.internal_organizations)}
          ${renderPlatformMetric('Active Workspaces', snapshot.active_workspaces)}
          ${renderPlatformMetric('Active Assessments', snapshot.active_assessments)}
          ${renderPlatformMetric('Collecting Responses', snapshot.collecting_responses)}
          ${renderPlatformMetric('Analysis Ready', snapshot.analysis_ready)}
          ${renderPlatformMetric('Reports Ready', snapshot.reports_ready)}
          ${renderPlatformMetric('Completed Assessments', snapshot.completed_assessments)}
          ${renderPlatformMetric('Overdue Participants', snapshot.overdue_participants)}
          ${renderPlatformMetric('Failed Invitations', snapshot.failed_invitations)}
          ${renderPlatformMetric('Failed Reminders', snapshot.failed_reminders)}
          ${renderPlatformMetric('Participants Without Usable Link', snapshot.participants_without_usable_link)}
          ${renderPlatformMetric('Open Issues', snapshot.open_issues)}
          ${renderPlatformMetric('Generated Warnings', snapshot.generated_warnings)}
          ${renderPlatformMetric('Critical Issues', snapshot.critical_issues)}
          ${renderPlatformMetric('Estimated Value Identified', formatEstimatedValue(snapshot.estimated_value_identified || 0))}
          ${renderPlatformMetric('Actual Value Realized', formatEstimatedValue(snapshot.actual_value_realized || 0))}
        </div>
      </section>

      <section class="platform-grid">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Needs Attention</h2><span>Prioritized cross-tenant action queue</span></div>
          </div>
          <div class="consultant-list">
            ${attention.length ? attention.slice(0, 10).map((item) => `
              <div class="consultant-list-item">
                <span class="status-pill ${platformSeverityClass(item.severity)}">${escapeHtml(item.severity || 'priority')}</span>
                <div><strong>${escapeHtml(item.label)}</strong><small>${escapeHtml(item.organization_name || 'Organization')} · ${escapeHtml(item.assessment_name || 'Assessment')} · ${escapeHtml(item.explanation || '')}</small></div>
                ${platformTaskButton(item, 'ghost-button', callbacks)}
              </div>
            `).join('') : `<p class="upload-note">No organizations currently need attention.</p>`}
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div><h2>Assessment Pipeline</h2><span>Delivery stages across the platform</span></div>
          </div>
          <div class="consultant-pipeline-grid">
            ${[
              ['Setup', pipeline.setup || 0],
              ['Collecting', pipeline.collecting || 0],
              ['Review', pipeline.review || 0],
              ['Recommendations', pipeline.recommendations || 0],
              ['Executive Ready', pipeline.executive_ready || 0],
              ['Completed', pipeline.completed || 0],
              ['At Risk', pipeline.at_risk || 0]
            ].map(([label, count]) => `<article><span>${label}</span><strong>${count}</strong></article>`).join('')}
          </div>
        </article>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div><h2>Organization Portfolio</h2><span>${activeClassification === 'all' ? 'All active workspaces' : `${activeClassification} active workspaces`} with stage, readiness, and ownership</span></div>
          ${callbacks.onOpenOrganization ? `<button class="ghost-button" data-component-platform-open-organizations type="button">Open Organizations</button>` : ''}
        </div>
        <div class="table-scroll">
          <table class="compact-table platform-table">
            <thead>
              <tr><th>Organization</th><th>Classification</th><th>Framework</th><th>Assessment</th><th>Stage</th><th>Completion</th><th>Confidence</th><th>Issues</th><th>Report</th><th>Last Activity</th><th>Consultant</th><th>Actions</th><th>Next Action</th></tr>
            </thead>
            <tbody>
              ${organizations.map((org) => `
                <tr>
                  <td>${callbacks.onOpenOrganization ? `<button class="link-button" data-component-platform-open-organization="${escapeHtml(org.project_id)}" data-platform-view="dashboard" type="button">${escapeHtml(org.organization_name)}</button>` : escapeHtml(org.organization_name)}</td>
                  <td><span class="status-pill ${statusClass(org.classification || 'production')}">${escapeHtml(org.classification || 'production')}</span></td>
                  <td>${escapeHtml(org.framework_name || 'Framework')}</td>
                  <td>${escapeHtml(org.assessment_name || 'Assessment')}</td>
                  <td><span class="status-pill ${platformStageClass(org.stage)}">${escapeHtml(org.stage || 'Setup')}</span></td>
                  <td>${Number(org.completion_percent || 0)}%</td>
                  <td>${Number(org.confidence_score || 0)}%</td>
                  <td>${Number(org.open_issues || 0)}</td>
                  <td>${escapeHtml(org.report_status || 'Not Ready')}</td>
                  <td>${escapeHtml(formatOpsDate(org.last_activity))}</td>
                  <td>${escapeHtml(org.assigned_consultant || 'Unassigned')}</td>
                  <td>
                    <div class="row-actions compact">
                      <button class="icon-button" data-platform-report-menu="${escapeHtml(org.project_id)}" type="button" aria-label="Reports">↓</button>
                      <button class="icon-button" data-platform-progress-open="${escapeHtml(org.project_id)}" type="button" aria-label="Progress intelligence">📈</button>
                    </div>
                  </td>
                  <td>${platformTaskButton({ ...org, project_id: org.project_id, action_label: org.next_action || 'Open', action_view: org.report_ready ? 'executive-report' : 'dashboard' }, 'ghost-button', callbacks)}</td>
                </tr>
              `).join('') || `<tr><td colspan="13">No active organizations found for this classification.</td></tr>`}
            </tbody>
          </table>
        </div>
      </section>

      <section class="platform-grid">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Consultant Workload</h2><span>Delivery team capacity and queues</span></div>
            ${callbacks.onOpenUsers ? `<button class="ghost-button" data-component-platform-open-users type="button">Open Users & Access</button>` : ''}
          </div>
          <div class="consultant-list">
            ${consultants.length ? consultants.map((consultant) => `
              <div class="consultant-list-item">
                <span class="status-dot ${consultant.open_issues ? 'warning' : 'success'}"></span>
                <div>
                  <strong>${escapeHtml(consultant.consultant_name || consultant.email)}</strong>
                  <small>${consultant.assigned_organizations} orgs · ${consultant.active_assessments} active · ${consultant.findings_pending_review} findings pending · ${consultant.reports_ready} reports ready · ${consultant.overdue_collection_items} overdue · ${consultant.open_issues} issues</small>
                </div>
              </div>
            `).join('') : `
              ${renderScreenState('users', 'empty', {
                compact: true,
                title: 'No consultants assigned yet',
                message: 'Create or assign consultants so platform delivery work has clear ownership.',
                actionLabel: callbacks.onOpenUsers ? 'Open Users & Access' : '',
                actionView: 'users'
              })}
            `}
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div><h2>Reports Ready</h2><span>Executive reports ready for review or delivery</span></div>
          </div>
          <div class="consultant-list">
            ${reports.length ? reports.map((report) => `
              <div class="consultant-list-item">
                <span class="status-pill approved">ready</span>
                <div><strong>${escapeHtml(report.organization_name)}</strong><small>${escapeHtml(report.assessment_name || 'Assessment')} · ${formatEstimatedValue(report.estimated_value || 0)} value · ${escapeHtml(formatOpsDate(report.last_updated))}</small></div>
                ${callbacks.onOpenReport ? `<button class="ghost-button" data-component-platform-open-report="${escapeHtml(report.project_id)}" type="button">Open Report</button>` : ''}
              </div>
            `).join('') : `<p class="upload-note">No reports are ready for review yet.</p>`}
          </div>
        </article>
      </section>

      <section class="platform-grid">
        <article class="panel">
          <div class="panel-header">
            <div><h2>Operations Health</h2><span>Email, magic links, analysis, report, and backend signals</span></div>
            ${callbacks.onOpenOperations ? `<button class="ghost-button" data-component-platform-open-operations type="button">Open Operations Center</button>` : ''}
          </div>
          <div class="manager-metric-grid">
            ${[
              ['Email Provider', ops.email_provider_status || 'unknown'],
              ['Failed Invitations', ops.failed_invitations || 0],
              ['Failed Reminders', ops.failed_reminders || 0],
              ['Participants Without Usable Link', ops.participants_without_usable_link || 0],
              ['Expired Tokens', ops.expired_tokens || 0],
              ['Sessions Without Tokens', ops.sessions_without_tokens || 0],
              ['Participants Without Sessions', ops.participants_without_sessions || 0],
              ['Completed Sessions Without Findings', ops.completed_sessions_without_findings || 0],
              ['Reports Missing Sections', ops.reports_missing_required_sections || 0],
              ['Generated Warnings', ops.generated_warnings || 0],
              ['Recent Backend Errors', ops.recent_backend_errors || 0]
            ].map(([label, value]) => `<article><span>${label}</span><strong>${escapeHtml(String(value))}</strong></article>`).join('')}
          </div>
        </article>

        <article class="panel">
          <div class="panel-header">
            <div><h2>Open Issues</h2><span>Critical and high issues first</span></div>
            ${callbacks.onOpenOperations ? `<button class="ghost-button" data-component-platform-open-operations type="button">Open Issues</button>` : ''}
          </div>
          <div class="consultant-list">
            ${issues.length ? issues.slice(0, 8).map((issue) => `
              <div class="consultant-list-item">
                <span class="status-pill ${platformSeverityClass(issue.severity)}">${escapeHtml(issue.severity || 'issue')}</span>
                <div><strong>${escapeHtml(issue.title || 'Issue')}</strong><small>${escapeHtml(issue.organization_name || '')} ${issue.assessment_name ? `· ${escapeHtml(issue.assessment_name)}` : ''} · ${escapeHtml(issue.status || 'open')}</small></div>
                ${callbacks.onOpenOperations ? `<button class="ghost-button" data-component-platform-open-operations type="button">Open Issue</button>` : ''}
              </div>
            `).join('') : `<p class="upload-note">No open issues. Platform health is clear.</p>`}
          </div>
        </article>
      </section>

      <section class="panel">
        <div class="panel-header">
          <div><h2>Recent Activity</h2><span>Latest platform events</span></div>
        </div>
        <div class="platform-activity-list">
          ${activity.length ? activity.slice(0, 12).map((item) => `
            <div>
              <span class="status-dot success"></span>
              <strong>${escapeHtml(String(item.action || 'activity').replace(/_/g, ' '))}</strong>
              <small>${escapeHtml(item.entity_type || 'platform')} · ${escapeHtml(formatOpsDate(item.happened_at))}${item.actor_email ? ` · ${escapeHtml(item.actor_email)}` : ''}</small>
            </div>
          `).join('') : `<p class="upload-note">No recent platform activity yet.</p>`}
        </div>
      </section>
    </section>
  `;
}
