import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

function formatOpsDate(value) {
  if (!value) return '-';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '-';
  return date.toLocaleString([], { month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' });
}

function formatStakeholderId(value = '') {
  return String(value || '')
    .replace(/_/g, ' ')
    .replace(/-/g, ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function participantStatusLabel(status = '') {
  return formatStakeholderId(status || 'unknown');
}

function stakeholderRoleLabel(id = '') {
  return formatStakeholderId(id || 'role');
}

function stakeholderGroupLabel(id = '') {
  return formatStakeholderId(id || 'group');
}

function opsStatusLabel(status = 'green') {
  if (status === 'red') return 'Critical';
  if (status === 'yellow') return 'Warning';
  if (status === 'completed') return 'Complete';
  if (status === 'missing') return 'Missing';
  if (status === 'error') return 'Error';
  return participantStatusLabel(status || 'healthy');
}

function renderOpsMetric(label, value, status = 'green') {
  return `
    <article class="ops-metric ops-${escapeHtml(status)}">
      <span>${escapeHtml(label)}</span>
      <strong>${escapeHtml(value)}</strong>
      <small>${escapeHtml(opsStatusLabel(status))}</small>
    </article>
  `;
}

function renderOpsEmpty(message) {
  return renderScreenState('operations-center', 'empty', {
    title: 'No records',
    message,
    compact: true
  });
}

function renderOpsPipeline(assessment = {}, callbacks = {}) {
  return `
    <article class="ops-assessment-card">
      <div class="owner-section-head">
        <div>
          <span class="eyebrow">${escapeHtml(assessment.client_display_name || assessment.project_name || 'Organization')}</span>
          <h4>${escapeHtml(assessment.title || 'Assessment')}</h4>
        </div>
        <div class="row-actions">
          ${callbacks.onOpenWorkspace ? `<button class="ghost-button" data-component-ops-open-workspace="${escapeHtml(assessment.project_id || assessment.assessment_id || '')}" type="button">Open Assessment</button>` : ''}
          ${callbacks.onOpenReport ? `<button class="ghost-button" data-component-ops-open-report="${escapeHtml(assessment.report_id || assessment.assessment_id || '')}" type="button">View Report</button>` : ''}
        </div>
      </div>
      <div class="ops-pipeline">
        ${(assessment.workflow || []).map((step) => `
          <div class="ops-step ops-step-${statusClass(step.status)}">
            <strong>${escapeHtml(step.label)}</strong>
            <span>${escapeHtml(opsStatusLabel(step.status))}</span>
            <small>${escapeHtml(step.details || '')}</small>
          </div>
        `).join('')}
      </div>
    </article>
  `;
}

function participantActionButton(label, action, participantId, callbacks) {
  return callbacks.onParticipantAction
    ? `<button class="ghost-button" data-component-ops-participant-action="${escapeHtml(action)}" data-participant-id="${escapeHtml(participantId)}" type="button">${escapeHtml(label)}</button>`
    : '';
}

function renderOpsParticipants(participants = [], callbacks = {}) {
  if (!participants.length) return renderScreenState('participants', 'empty', { compact: true });
  return `
    <div class="table-scroll">
      <table class="compact-table ops-table">
        <thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Group</th><th>Status</th><th>Session</th><th>Progress</th><th>Invited</th><th>Started</th><th>Completed</th><th>Last Reminder</th><th>Overdue</th><th>Actions</th></tr></thead>
        <tbody>
          ${participants.map((p) => `
            <tr>
              <td><strong>${escapeHtml(p.full_name || '-')}</strong></td>
              <td>${escapeHtml(p.email || '-')}</td>
              <td>${escapeHtml(p.stakeholder_role_name || stakeholderRoleLabel(p.stakeholder_role_id))}</td>
              <td>${escapeHtml(p.stakeholder_group_name || stakeholderGroupLabel(p.stakeholder_group_id))}</td>
              <td><span class="status-pill ${statusClass(p.status)}">${participantStatusLabel(p.status)}</span></td>
              <td>${escapeHtml(p.session_status || (p.session_id ? 'created' : 'No session'))}</td>
              <td>${Number(p.completion_percent || 0)}%</td>
              <td>${formatOpsDate(p.invite_sent_at)}</td>
              <td>${formatOpsDate(p.started_at)}</td>
              <td>${formatOpsDate(p.completed_at)}</td>
              <td>${formatOpsDate(p.last_reminder_sent_at)}<br><small>${Number(p.reminder_count || 0)} sent</small></td>
              <td>${p.overdue ? `<span class="status-pill rejected">Overdue</span>` : '-'}</td>
              <td><div class="row-actions">
                ${p.session_id ? '' : participantActionButton('Create Session', 'create_session', p.participant_id, callbacks)}
                ${participantActionButton('Regenerate Link', 'generate_link', p.participant_id, callbacks)}
                ${participantActionButton('Send Invite', 'send_invite', p.participant_id, callbacks)}
                ${participantActionButton('Reminder', 'send_reminder', p.participant_id, callbacks)}
              </div></td>
            </tr>
          `).join('')}
        </tbody>
      </table>
    </div>
  `;
}

function renderOpsCommunications(data = {}) {
  const logs = data.logs || [];
  return `
    <div class="blueprint-score-grid">
      ${renderOpsMetric('Sent', data.sent_count || 0, 'green')}
      ${renderOpsMetric('Failed', data.failed_count || 0, Number(data.failed_count || 0) ? 'red' : 'green')}
      ${renderOpsMetric('Disabled', data.disabled_count || 0, Number(data.disabled_count || 0) ? 'yellow' : 'green')}
      ${renderOpsMetric('Skipped', data.skipped_count || 0, Number(data.skipped_count || 0) ? 'yellow' : 'green')}
      ${renderOpsMetric('Email Provider', data.email_provider_status?.configured ? 'Configured' : 'Disabled', data.email_provider_status?.configured ? 'green' : 'yellow')}
    </div>
    ${logs.length ? `
      <div class="table-scroll">
        <table class="compact-table ops-table">
          <thead><tr><th>Type</th><th>Email</th><th>Subject</th><th>Status</th><th>Error</th><th>Sent</th><th>Created</th></tr></thead>
          <tbody>${logs.map((log) => `
            <tr>
              <td>${escapeHtml(log.log_type)}</td>
              <td>${escapeHtml(log.email || '-')}</td>
              <td>${escapeHtml(log.subject || '-')}</td>
              <td><span class="status-pill ${statusClass(log.status)}">${escapeHtml(log.status || '-')}</span></td>
              <td>${escapeHtml(log.error_message || '-')}</td>
              <td>${formatOpsDate(log.sent_at)}</td>
              <td>${formatOpsDate(log.created_at)}</td>
            </tr>
          `).join('')}</tbody>
        </table>
      </div>
    ` : renderScreenState('operations-center', 'empty', {
      title: 'No communication logs yet',
      message: 'Invitation and reminder logs will appear here after emails are sent.',
      actionLabel: 'Open Participants',
      actionView: 'dashboard',
      compact: true
    })}
  `;
}

function renderOpsMagicLinks(data = {}, callbacks = {}) {
  const tokens = data.tokens || [];
  return `
    <div class="blueprint-score-grid">
      ${renderOpsMetric('Active', data.active_tokens || 0, 'green')}
      ${renderOpsMetric('Expired', data.expired_tokens || 0, Number(data.expired_tokens || 0) ? 'red' : 'green')}
      ${renderOpsMetric('Inactive', data.inactive_tokens || 0, Number(data.inactive_tokens || 0) ? 'yellow' : 'green')}
      ${renderOpsMetric('Opened', data.opened_tokens || 0, 'green')}
      ${renderOpsMetric('Never Opened', data.never_opened_tokens || 0, Number(data.never_opened_tokens || 0) ? 'yellow' : 'green')}
      ${renderOpsMetric('Completed', data.completed_tokens || 0, 'green')}
    </div>
    ${tokens.length ? `
      <div class="table-scroll">
        <table class="compact-table ops-table">
          <thead><tr><th>Participant</th><th>Role</th><th>Status</th><th>Token Health</th><th>Expires</th><th>First Opened</th><th>Last Opened</th><th>Actions</th></tr></thead>
          <tbody>${tokens.map((token) => `
            <tr>
              <td><strong>${escapeHtml(token.full_name || '-')}</strong><br><small>${escapeHtml(token.email || '')}</small></td>
              <td>${escapeHtml(token.stakeholder_role_name || stakeholderRoleLabel(token.stakeholder_role_id))}</td>
              <td><span class="status-pill ${statusClass(token.participant_status)}">${participantStatusLabel(token.participant_status)}</span></td>
              <td><span class="status-pill ${statusClass(token.token_health)}">${participantStatusLabel(token.token_health)}</span></td>
              <td>${formatOpsDate(token.expires_at)}</td>
              <td>${formatOpsDate(token.first_opened_at)}</td>
              <td>${formatOpsDate(token.last_opened_at)}</td>
              <td>${callbacks.onLinkAction ? `<button class="ghost-button" data-component-ops-link-action="regenerate" data-token-id="${escapeHtml(token.token_id || token.participant_id || '')}" type="button">Regenerate Link</button>` : ''}</td>
            </tr>
          `).join('')}</tbody>
        </table>
      </div>
    ` : renderScreenState('operations-center', 'empty', {
      title: 'No magic links generated yet',
      message: 'Magic link health will appear after participant links are generated.',
      actionLabel: 'Open Participants',
      actionView: 'dashboard',
      compact: true
    })}
  `;
}

function renderOpsAnalysisHealth(rows = []) {
  if (!rows.length) return renderScreenState('analysis', 'empty', { title: 'No analysis health records yet', message: 'Analysis health appears after assessments exist.', compact: true });
  return `
    <div class="table-scroll">
      <table class="compact-table ops-table">
        <thead><tr><th>Assessment</th><th>Completed Sessions</th><th>Responses</th><th>Findings</th><th>Evidence</th><th>KPI Gaps</th><th>Contradictions</th><th>Recommendations</th><th>Roadmap</th><th>ROI</th><th>Status</th></tr></thead>
        <tbody>${rows.map((row) => {
          const critical = Number(row.completed_sessions || 0) && !Number(row.findings_count || 0);
          const warning = Number(row.findings_count || 0) && (!Number(row.evidence_count || 0) || !Number(row.recommendations_count || 0) || !Number(row.roadmap_items_count || 0));
          return `
            <tr>
              <td>${escapeHtml(row.assessment_id)}</td>
              <td>${Number(row.completed_sessions || 0)}</td>
              <td>${Number(row.responses_count || 0)}</td>
              <td>${Number(row.findings_count || 0)}</td>
              <td>${Number(row.evidence_count || 0)}</td>
              <td>${Number(row.kpi_gap_findings || 0)}</td>
              <td>${Number(row.contradictions_count || 0)}</td>
              <td>${Number(row.recommendations_count || 0)} <small>v2 ${Number(row.v2_recommendations_count || 0)}</small></td>
              <td>${Number(row.roadmap_items_count || 0)}</td>
              <td>${Number(row.roi_estimate_count || 0)}</td>
              <td><span class="status-pill ${critical ? 'rejected' : warning ? 'warning' : 'approved'}">${critical ? 'Critical' : warning ? 'Warning' : 'Healthy'}</span></td>
            </tr>
          `;
        }).join('')}</tbody>
      </table>
    </div>
  `;
}

function renderOpsReportHealth(rows = [], callbacks = {}) {
  const sections = ['Organization Profile', 'Assessment Coverage', 'Top Findings', 'Evidence Summary', 'Agreement', 'Misalignment', 'KPI Gaps', 'ROI', 'Recommendations', 'Roadmap', 'Next Best Actions', 'Progress Memory'];
  if (!rows.length) return renderScreenState('executive-report', 'empty', { title: 'No report health records yet', message: 'Report health appears after assessments exist.', compact: true });
  return `
    <div class="table-scroll">
      <table class="compact-table ops-table">
        <thead><tr><th>Assessment</th><th>Ready</th><th>Approved Findings</th><th>Approved Recommendations</th><th>ROI</th><th>Roadmap</th><th>Misalignment</th><th>Progress Snapshot</th><th>Required Sections</th><th>Actions</th></tr></thead>
        <tbody>${rows.map((row) => {
          const ready = Number(row.approved_findings || 0) && Number(row.approved_recommendations || 0) && Number(row.roadmap_items || 0);
          return `
            <tr>
              <td>${escapeHtml(row.assessment_id)}</td>
              <td><span class="status-pill ${ready ? 'approved' : 'warning'}">${ready ? 'Ready' : 'Needs Review'}</span></td>
              <td>${Number(row.approved_findings || 0)}</td>
              <td>${Number(row.approved_recommendations || 0)}</td>
              <td>${Number(row.recommendations_with_roi || 0)}</td>
              <td>${Number(row.roadmap_items || 0)}</td>
              <td>${Number(row.misalignments || 0)}</td>
              <td>${formatOpsDate(row.last_progress_snapshot_at)}</td>
              <td>${sections.map((item) => `<span class="mini-chip">${escapeHtml(item)}</span>`).join('')}</td>
              <td>${callbacks.onOpenReport ? `<button class="ghost-button" data-component-ops-open-report="${escapeHtml(row.report_id || row.assessment_id || '')}" type="button">Open Report</button>` : ''}</td>
            </tr>
          `;
        }).join('')}</tbody>
      </table>
    </div>
  `;
}

function renderOpsIssues(state = {}, callbacks = {}) {
  const stored = state.issues || [];
  const generated = state.generated_issues || [];
  const all = [
    ...generated.map((issue, index) => ({ ...issue, issue_id: `generated-${index}`, generated: true, status: 'open' })),
    ...stored
  ];
  return `
    ${callbacks.onCreateIssue ? `
      <form data-component-ops-issue-form class="participant-form ops-issue-form">
        <h4>Create Issue</h4>
        <div class="form-grid compact">
          <label>Title<input name="title" required placeholder="Issue title"></label>
          <label>Severity<select name="severity"><option>low</option><option selected>medium</option><option>high</option><option>critical</option></select></label>
          <label>Category<select name="category"><option>workflow</option><option>participant</option><option>email</option><option>reminder</option><option>magic_link</option><option>analysis</option><option>report</option><option>data_quality</option><option>qa</option><option>bug</option><option>user_request</option></select></label>
          <label>Assigned To<input name="assigned_to" placeholder="Owner"></label>
        </div>
        <label>Description<textarea name="description" rows="2"></textarea></label>
        <button class="primary-button" type="submit">Create Issue</button>
      </form>
    ` : ''}
    ${all.length ? `
      <div class="table-scroll">
        <table class="compact-table ops-table">
          <thead><tr><th>Issue</th><th>Severity</th><th>Status</th><th>Category</th><th>Source</th><th>Related</th><th>Updated</th><th>Actions</th></tr></thead>
          <tbody>${all.map((issue) => `
            <tr>
              <td><strong>${escapeHtml(issue.title)}</strong><br><small>${escapeHtml(issue.description || '')}</small></td>
              <td><span class="status-pill ${statusClass(issue.severity)}">${escapeHtml(issue.severity || 'medium')}</span></td>
              <td><span class="status-pill ${statusClass(issue.status)}">${escapeHtml(issue.status || 'open')}</span></td>
              <td>${escapeHtml(issue.category || '-')}</td>
              <td>${issue.generated ? 'system suggestion' : escapeHtml(issue.source || 'manual')}</td>
              <td>${escapeHtml(issue.related_area || issue.assessment_title || issue.participant_name || '-')}</td>
              <td>${formatOpsDate(issue.updated_at || issue.created_at)}</td>
              <td>${issue.generated
                ? (callbacks.onCreateIssue ? `<button class="ghost-button" data-component-ops-save-generated-issue="${escapeHtml(issue.issue_id.replace('generated-', ''))}" type="button">Save Issue</button>` : '')
                : (callbacks.onResolveIssue ? `<button class="ghost-button" data-component-ops-resolve-issue="${escapeHtml(issue.issue_id)}" type="button">Resolve</button>` : '')}</td>
            </tr>
          `).join('')}</tbody>
        </table>
      </div>
    ` : renderScreenState('operations-center', 'success', {
      title: 'No open issues',
      message: 'No stored or generated issues are open.',
      compact: true
    })}
  `;
}

function renderOpsAuditLogs(logs = []) {
  if (!logs.length) return renderScreenState('audit-logs', 'empty', { compact: true });
  return `
    <div class="table-scroll">
      <table class="compact-table ops-table">
        <thead><tr><th>Time</th><th>Actor</th><th>Action</th><th>Entity</th><th>Assessment</th><th>Participant</th></tr></thead>
        <tbody>${logs.map((log) => `
          <tr>
            <td>${formatOpsDate(log.timestamp)}</td>
            <td>${escapeHtml(log.actor_email || '-')}</td>
            <td>${escapeHtml(log.action || '-')}</td>
            <td>${escapeHtml(log.entity_type || '-')}<br><small>${escapeHtml(log.entity_id || '')}</small></td>
            <td>${escapeHtml(log.assessment_id || '-')}</td>
            <td>${escapeHtml(log.participant_id || '-')}</td>
          </tr>
        `).join('')}</tbody>
      </table>
    </div>
  `;
}

function renderOpsQaHistory(rows = [], callbacks = {}) {
  return `
    ${callbacks.onRecordQaRun ? `
      <form data-component-ops-qa-run-form class="participant-form ops-issue-form">
        <h4>Record QA Run</h4>
        <div class="form-grid compact">
          <label>QA Type<select name="qa_type"><option>operations_center_qa</option><option>full_system_qa</option><option>participant_upload_qa</option><option>invitation_qa</option><option>reminder_qa</option><option>report_qa</option><option>analysis_qa</option></select></label>
          <label>Status<select name="status"><option value="passed">passed</option><option value="warning">warning</option><option value="failed">failed</option></select></label>
        </div>
        <label>Notes<textarea name="notes" rows="2"></textarea></label>
        <button class="primary-button" type="submit">Save QA Run</button>
      </form>
    ` : ''}
    ${rows.length ? `
      <div class="table-scroll">
        <table class="compact-table ops-table">
          <thead><tr><th>Type</th><th>Status</th><th>Started</th><th>Completed</th><th>Cleanup</th><th>Notes</th></tr></thead>
          <tbody>${rows.map((run) => `
            <tr>
              <td>${escapeHtml(run.qa_type)}</td>
              <td><span class="status-pill ${statusClass(run.status)}">${escapeHtml(run.status)}</span></td>
              <td>${formatOpsDate(run.started_at)}</td>
              <td>${formatOpsDate(run.completed_at)}</td>
              <td>${escapeHtml(run.cleanup_status || '-')}</td>
              <td>${escapeHtml(run.notes || '-')}</td>
            </tr>
          `).join('')}</tbody>
        </table>
      </div>
    ` : renderScreenState('qa-history', 'empty', { compact: true })}
  `;
}

function renderOpsSystemHealth(state = {}) {
  const health = state.system_health || {};
  const errors = state.errors || [];
  return `
    <div class="blueprint-score-grid">
      ${renderOpsMetric('App', health.app_status || 'unknown', health.app_status === 'healthy' ? 'green' : 'red')}
      ${renderOpsMetric('Database', health.db_status || 'unknown', health.db_status === 'healthy' ? 'green' : 'red')}
      ${renderOpsMetric('Email', health.email_status || 'unknown', health.email_status === 'configured' ? 'green' : 'yellow')}
      ${renderOpsMetric('Recent Errors', health.recent_errors || 0, Number(health.recent_errors || 0) ? 'red' : 'green')}
      ${renderOpsMetric('Workflow Warnings', health.workflow_warnings || 0, Number(health.workflow_warnings || 0) ? 'yellow' : 'green')}
    </div>
    <article class="upload-result"><strong>Server time</strong><p>${escapeHtml(health.server_time || '-')}</p><p>${escapeHtml(health.npm_audit_note || '')}</p></article>
    ${errors.length ? `
      <div class="table-scroll">
        <table class="compact-table ops-table">
          <thead><tr><th>Time</th><th>Severity</th><th>Area</th><th>Action</th><th>Message</th></tr></thead>
          <tbody>${errors.map((error) => `
            <tr>
              <td>${formatOpsDate(error.timestamp)}</td>
              <td><span class="status-pill ${statusClass(error.severity)}">${escapeHtml(error.severity)}</span></td>
              <td>${escapeHtml(error.area || '-')}</td>
              <td>${escapeHtml(error.action || '-')}</td>
              <td>${escapeHtml(error.message || '-')}</td>
            </tr>
          `).join('')}</tbody>
        </table>
      </div>
    ` : renderScreenState('system-health', 'success', {
      title: 'No recent backend errors',
      message: 'No recent backend errors are recorded.',
      compact: true
    })}
  `;
}

export function renderOperationsCenterComponent(
  operationsState,
  activeSection = 'overview',
  loading = false,
  error = null,
  lastRefreshed = null,
  emptyStateHtml = '',
  callbacks = {}
) {
  const sections = [
    ['overview', 'Overview'],
    ['workflow', 'Assessment Workflow Health'],
    ['participants', 'Participants & Completion'],
    ['communications', 'Communications'],
    ['magic_links', 'Magic Links'],
    ['analysis', 'Analysis Health'],
    ['report', 'Executive Report Health'],
    ['issues', 'Issues'],
    ['audit', 'Audit Logs'],
    ['qa', 'QA History'],
    ['system', 'System Health']
  ];
  const state = operationsState;
  if (!state) {
    return `<section class="panel"><div class="panel-header"><h2>Operations Center</h2><span>${loading ? 'Refreshing live mission control...' : 'Mission control'}</span></div>${loading ? renderLoadingSkeleton('Loading Operations Center', 5) : (emptyStateHtml || renderScreenState('operations-center', error ? 'error' : 'empty', { message: error || 'Operations data will appear here after the platform has activity.' }))}</section>`;
  }
  const summary = state.summary || {};
  let body = '';
  if (activeSection === 'overview') {
    body = `
      <div class="ops-card-grid">
        ${renderOpsMetric('Active Assessments', summary.active_assessments || 0, 'green')}
        ${renderOpsMetric('Participants Total', summary.participants_total || 0, 'green')}
        ${renderOpsMetric('Invited', summary.participants_invited || 0, 'green')}
        ${renderOpsMetric('Started', summary.participants_started || 0, 'green')}
        ${renderOpsMetric('Completed', summary.participants_completed || 0, 'green')}
        ${renderOpsMetric('Overdue', summary.overdue_participants || 0, Number(summary.overdue_participants || 0) ? 'yellow' : 'green')}
        ${renderOpsMetric('Failed Invitations', summary.failed_invitations || 0, Number(summary.failed_invitations || 0) ? 'red' : 'green')}
        ${renderOpsMetric('Failed Reminders', summary.failed_reminders || 0, Number(summary.failed_reminders || 0) ? 'red' : 'green')}
        ${renderOpsMetric('Active Magic Links', summary.active_magic_links || 0, 'green')}
        ${renderOpsMetric('Expired Magic Links', summary.expired_magic_links || 0, Number(summary.expired_magic_links || 0) ? 'red' : 'green')}
        ${renderOpsMetric('Findings', summary.findings_generated || 0, 'green')}
        ${renderOpsMetric('Recommendations', summary.recommendations_generated || 0, 'green')}
        ${renderOpsMetric('Reports Ready', summary.reports_ready || 0, 'green')}
        ${renderOpsMetric('Open Issues', summary.open_issues || 0, Number(summary.open_issues || 0) ? 'yellow' : 'green')}
        ${renderOpsMetric('Critical Issues', summary.critical_issues || 0, Number(summary.critical_issues || 0) ? 'red' : 'green')}
        ${renderOpsMetric('Recent Errors', summary.recent_errors || 0, Number(summary.recent_errors || 0) ? 'red' : 'green')}
      </div>
      <div class="ops-two-column">
        <section>${(state.assessments || []).slice(0, 4).map((assessment) => renderOpsPipeline(assessment, callbacks)).join('') || renderOpsEmpty('No active assessments found.')}</section>
        <section>${renderOpsIssues(state, callbacks)}</section>
      </div>
    `;
  } else if (activeSection === 'workflow') body = (state.assessments || []).map((assessment) => renderOpsPipeline(assessment, callbacks)).join('') || renderOpsEmpty('No active assessments found.');
  else if (activeSection === 'participants') body = renderOpsParticipants(state.participants || [], callbacks);
  else if (activeSection === 'communications') body = renderOpsCommunications(state.communications || {});
  else if (activeSection === 'magic_links') body = renderOpsMagicLinks(state.magic_links || {}, callbacks);
  else if (activeSection === 'analysis') body = renderOpsAnalysisHealth(state.analysis_health || []);
  else if (activeSection === 'report') body = renderOpsReportHealth(state.report_health || [], callbacks);
  else if (activeSection === 'issues') body = renderOpsIssues(state, callbacks);
  else if (activeSection === 'audit') body = renderOpsAuditLogs(state.audit_logs || []);
  else if (activeSection === 'qa') body = renderOpsQaHistory(state.qa_history || [], callbacks);
  else if (activeSection === 'system') body = renderOpsSystemHealth(state);
  return `
    <section class="panel krb-ops-panel">
      <div class="panel-header">
        <div>
          <h2>Operations Center</h2>
          <span>${loading ? 'Refreshing live data...' : `Last refreshed: ${escapeHtml(lastRefreshed || formatOpsDate(state.generated_at))}`}</span>
          ${error ? `<p class="upload-note">${escapeHtml(error)}</p>` : ''}
        </div>
        <div class="panel-actions">
          ${callbacks.onRefresh ? `<button class="ghost-button ${loading ? 'is-loading' : ''}" data-component-ops-refresh type="button" ${loading ? 'disabled' : ''}>${loading ? 'Refreshing...' : 'Refresh'}</button>` : ''}
          ${callbacks.onOpenWorkspace ? `<button class="primary-button" data-component-ops-open-workspace="" type="button">Open Workspace</button>` : ''}
        </div>
      </div>
      <nav class="ops-section-tabs">
        ${sections.map(([id, label]) => `<button class="${activeSection === id ? 'active' : ''}" data-component-ops-section="${id}" type="button">${escapeHtml(label)}</button>`).join('')}
      </nav>
      <div class="ops-section-body">${body}</div>
    </section>
  `;
}
