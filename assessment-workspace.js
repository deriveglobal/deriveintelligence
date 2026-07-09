import {
  renderParticipantsSectionComponent,
  renderParticipantUploadPanelComponent,
  renderInvitationPanelComponent,
  renderReminderPanelComponent
} from './participants.js';
import {
  renderFindingsWorkbenchComponent,
  renderEvidenceExplorerComponent,
  renderFindingClustersComponent
} from './findings.js';
import {
  renderAlignmentHeatmapComponent
} from './alignment.js';
import {
  renderRecommendationsComponent
} from './recommendations.js';
import {
  renderRoadmapComponent
} from './roadmap.js';
import {
  renderProgressMemorySectionComponent
} from './progress.js';
import {
  renderExecutivePreviewComponent,
  renderExecutiveReportComponent
} from './executive.js';
import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

const WORKSPACE_STAGES = [
  ['setup', 'Setup'],
  ['collection', 'Collection'],
  ['review', 'Review'],
  ['recommendations', 'Recommendations'],
  ['executive', 'Executive'],
  ['operations', 'Operations']
];

function normalizeArray(value) {
  return Array.isArray(value) ? value : [];
}

function firstValue(...values) {
  return values.find((value) => value !== undefined && value !== null && value !== '');
}

function formatLabelValue(value, fallback = 'Not set') {
  if (value === undefined || value === null || value === '') return fallback;
  return String(value)
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function normalizeProfileList(value) {
  if (Array.isArray(value)) return value.filter(Boolean);
  if (typeof value === 'string') {
    return value
      .split(/\n|,/)
      .map((item) => item.trim())
      .filter(Boolean);
  }
  return [];
}

function organizationProfileData(organization = {}) {
  const profile = organization?.companyProfile || organization?.company_profile || {};
  const intake = organization?.projectContextIntake || organization?.project_context_intake || {};
  const context = organization?.contextData || organization?.context_data || intake.contextData || intake.context_data || {};
  return { profile, intake, context };
}

function statusIs(value, expected) {
  return String(value || '').toLowerCase() === expected;
}

function formatDate(value) {
  if (!value) return '';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return String(value);
  return date.toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
}

function formatPriorityLabel(str) {
  if (!str) return '';
  return String(str)
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function setupValue(value, fallback = '—') {
  return value === undefined || value === null || value === '' ? fallback : value;
}

function setupTagList(items = [], empty = 'None recorded.') {
  const values = normalizeProfileList(items);
  if (!values.length) return `<span style="font-size:12px;color:rgba(232,228,220,0.35);">${escapeHtml(empty)}</span>`;
  return values.map((item) => `<span style="padding:3px 10px;border-radius:20px;font-size:11px;border:0.5px solid rgba(200,169,110,0.2);background:rgba(200,169,110,0.06);color:rgba(200,169,110,0.7);">${escapeHtml(formatPriorityLabel(item))}</span>`).join('');
}

function setupField(label, value) {
  return `
    <div>
      <div style="font-size:11px;color:rgba(232,228,220,0.35);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:3px;">${escapeHtml(label)}</div>
      <div style="font-size:13px;color:#E8E4DC;">${escapeHtml(String(setupValue(value)))}</div>
    </div>
  `;
}

function setupSection(title, subtitle, body, actions = '') {
  return `
    <article style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-radius:12px;padding:1.25rem 1.5rem;margin-bottom:12px;">
      <div style="display:flex;justify-content:space-between;align-items:center;gap:1rem;margin-bottom:1rem;">
        <div>
          <h2 style="font-size:14px;font-weight:500;color:#E8E4DC;margin:0;">${escapeHtml(title)}</h2>
          <p style="font-size:11px;color:rgba(200,169,110,0.5);margin:2px 0 0;">${escapeHtml(subtitle || '')}</p>
        </div>
        ${actions}
      </div>
      ${body}
    </article>
  `;
}

function maturityRow(label, score) {
  const numeric = Number(score);
  const hasScore = Number.isFinite(numeric);
  const width = hasScore ? Math.max(0, Math.min(100, (numeric / 5) * 100)) : 0;
  return `
    <div style="display:grid;grid-template-columns:160px minmax(0,1fr) 36px;align-items:center;gap:12px;margin-bottom:12px;">
      <div style="font-size:13px;color:#E8E4DC;">${escapeHtml(label)}</div>
      <div style="height:4px;background:rgba(200,169,110,0.1);border-radius:2px;overflow:hidden;">
        <div style="background:#C8A96E;height:100%;border-radius:2px;width:${width}%;"></div>
      </div>
      <div style="font-size:13px;color:${hasScore ? '#C8A96E' : 'rgba(232,228,220,0.35)'};text-align:right;">${hasScore ? escapeHtml(String(score)) : '—'}</div>
    </div>
  `;
}

function roleRows(roles = []) {
  const values = normalizeArray(roles);
  if (!values.length) return `<p style="font-size:13px;color:rgba(232,228,220,0.35);margin:0;">No roles derived yet.</p>`;
  return values.map((role, index) => `
    <div style="padding:7px 0;${index === values.length - 1 ? '' : 'border-bottom:0.5px solid rgba(200,169,110,0.08);'}">
      <div style="font-size:13px;color:#E8E4DC;">${escapeHtml(role.name || role.label || role.role_name || role.id || 'Role')}</div>
      <div style="font-size:11px;color:rgba(200,169,110,0.5);margin-top:2px;">${escapeHtml(role.stakeholder_group_name || role.group_name || role.stakeholderGroupName || 'Group not set')}</div>
    </div>
  `).join('');
}

function kpiRows(kpis = []) {
  const values = normalizeArray(kpis);
  if (!values.length) return `<p style="font-size:13px;color:rgba(232,228,220,0.35);margin:0;">No KPIs recommended yet.</p>`;
  const trackedCount = values.filter((kpi) => kpi.is_currently_tracked || kpi.tracked).length;
  const ratio = values.length ? trackedCount / values.length : 0;
  const message = ratio < 0.5
    ? 'Your organization has significant measurement blind spots'
    : ratio < 0.8
      ? 'Good baseline measurement — some gaps remain'
      : 'Strong measurement foundation';
  return `
    <div style="display:grid;gap:12px;">
      <div style="display:flex;justify-content:space-between;align-items:center;gap:1rem;padding-bottom:10px;border-bottom:0.5px solid rgba(200,169,110,0.1);">
        <strong style="font-size:13px;color:#E8E4DC;">Tracking ${trackedCount} of ${values.length} recommended KPIs</strong>
        <span style="font-size:12px;color:${ratio < 0.5 ? '#D9974A' : 'rgba(140,210,140,0.9)'};">${escapeHtml(message)}</span>
      </div>
      ${values.map((kpi, index) => {
        const tracked = Boolean(kpi.is_currently_tracked || kpi.tracked);
        const key = kpi.key || kpi.kpi_key || kpi.id || '';
        return `
          <div style="display:grid;grid-template-columns:auto 1fr auto;gap:12px;align-items:start;padding:10px 0;${index === values.length - 1 ? '' : 'border-bottom:0.5px solid rgba(200,169,110,0.08);'}">
            <input type="checkbox" data-component-kpi-tracking="${escapeHtml(key)}" ${tracked ? 'checked' : ''} aria-label="Currently tracking ${escapeHtml(kpi.name || key)}" />
            <div>
              <div style="font-size:13px;font-weight:500;color:#E8E4DC;">${escapeHtml(kpi.name || key)}</div>
              ${kpi.name_tr ? `<div style="font-size:12px;color:rgba(200,169,110,0.5);margin-top:2px;">${escapeHtml(kpi.name_tr)}</div>` : ''}
              <div style="font-size:12px;color:rgba(232,228,220,0.4);margin-top:4px;line-height:1.5;">${escapeHtml(kpi.description || '')}</div>
              ${kpi.why_it_matters ? `<div style="font-size:12px;color:rgba(232,228,220,0.35);margin-top:4px;line-height:1.5;">${escapeHtml(kpi.why_it_matters)}</div>` : ''}
              ${kpi.unit ? `<span style="display:inline-block;margin-top:6px;padding:2px 8px;border-radius:12px;background:rgba(200,169,110,0.08);border:0.5px solid rgba(200,169,110,0.15);color:rgba(200,169,110,0.65);font-size:11px;">${escapeHtml(kpi.unit)}</span>` : ''}
            </div>
            <span style="font-size:11px;padding:3px 9px;border-radius:20px;background:${tracked ? 'rgba(100,180,100,0.1)' : 'rgba(200,169,110,0.1)'};border:0.5px solid ${tracked ? 'rgba(100,180,100,0.3)' : 'rgba(200,169,110,0.3)'};color:${tracked ? 'rgba(140,210,140,0.9)' : '#D9974A'};">${tracked ? 'Tracked' : 'Not measured — blind spot'}</span>
          </div>
        `;
      }).join('')}
    </div>
  `;
}

function formatRoleName(role) {
  return role?.name || role?.label || role?.stakeholder_role_name || role?.role_name || role?.id || role?.roleId || 'Role';
}

function blueprintRoles(blueprint = {}) {
  blueprint = blueprint || {};
  return [
    ...(blueprint.requiredRoles || blueprint.required_roles || []).map((role) => ({ ...normalizeRole(role), level: 'Required' })),
    ...(blueprint.recommendedRoles || blueprint.recommended_roles || []).map((role) => ({ ...normalizeRole(role), level: 'Recommended' })),
    ...(blueprint.optionalRoles || blueprint.optional_roles || []).map((role) => ({ ...normalizeRole(role), level: 'Optional' }))
  ];
}

function normalizeRole(role) {
  if (typeof role === 'string') return { id: role, name: role };
  return role || {};
}

function roleOptionsFromBlueprint(blueprint = {}) {
  return blueprintRoles(blueprint)
    .map((role) => `<option value="${escapeHtml(role.id || role.roleId || role.value || role.name || role.label)}">${escapeHtml(formatRoleName(role))}</option>`)
    .join('');
}

function recommendationLookup(recommendations = []) {
  return normalizeArray(recommendations).reduce((lookup, recommendation) => {
    const findingId = recommendation.finding_id || recommendation.findingId || recommendation.source_finding_id;
    if (findingId) lookup[String(findingId)] = recommendation;
    return lookup;
  }, {});
}

function normalizeFindingStatus(status = '') {
  return String(status || 'Draft').toLowerCase();
}

function findingStatusLabel(status = '') {
  const normalized = normalizeFindingStatus(status);
  if (normalized === 'approved') return 'Approved';
  if (normalized === 'rejected') return 'Rejected';
  if (normalized === 'archived') return 'Archived';
  return 'Pending';
}

function findingStatusSymbol(status = '') {
  const normalized = normalizeFindingStatus(status);
  if (normalized === 'approved') return '✓';
  if (normalized === 'rejected') return '✗';
  return '○';
}

function findingProblemTypes(finding = {}) {
  const value = finding.problem_types || finding.problemTypes || finding.problem_types_detectable || [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') {
    try {
      const parsed = JSON.parse(value);
      if (Array.isArray(parsed)) return parsed;
    } catch {}
    return value.split(',').map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

function renderReviewFindingList(findings = [], selectedFindingId, callbacks = {}) {
  return `
    <div class="review-finding-list" role="list">
      ${normalizeArray(findings).map((finding) => {
        const status = normalizeFindingStatus(finding.status);
        const isSelected = String(finding.id) === String(selectedFindingId);
        return `
          <article class="review-finding-row ${isSelected ? 'selected' : ''} ${status === 'approved' ? 'approved' : ''} ${status === 'rejected' ? 'rejected' : ''}" role="listitem">
            <input
              type="checkbox"
              aria-label="Select finding for merge"
              data-component-merge-finding="${escapeHtml(finding.id)}"
              ${isSelected ? 'disabled' : ''}
            />
            <button class="review-finding-select" data-component-select-finding="${escapeHtml(finding.id)}" type="button">
              <strong>${escapeHtml(finding.title || 'Untitled finding')}</strong>
              <span class="review-finding-meta">
                <span class="mini-chip">${escapeHtml(finding.business_domain || finding.domain || 'Domain')}</span>
                <span class="mini-chip">${escapeHtml(finding.assessment_category || finding.category || 'Category')}</span>
              </span>
              <span class="review-finding-status ${status === 'approved' ? 'approved' : status === 'rejected' ? 'rejected' : 'pending'}">
                ${findingStatusSymbol(finding.status)} ${escapeHtml(findingStatusLabel(finding.status))}
              </span>
            </button>
          </article>
        `;
      }).join('')}
    </div>
  `;
}

function renderReviewEvidenceSummary(finding = {}, evidence = []) {
  const selectedEvidence = normalizeArray(evidence).filter((item) => String(item.finding_id || item.findingId) === String(finding.id));
  const primaryEvidence = selectedEvidence[0] || {};
  return `
    <section class="review-detail-section">
      <h4>Supporting evidence</h4>
      <article class="review-evidence-card">
        <span>${escapeHtml(primaryEvidence.evidence_type || 'Evidence')}</span>
        <strong>${escapeHtml(primaryEvidence.source_question || finding.source_question || finding.question_text || 'Source question unavailable')}</strong>
        <p>${escapeHtml(primaryEvidence.source_response || primaryEvidence.response_value || finding.source_response || finding.description || 'No source response text available.')}</p>
        <small>Trigger rule: ${escapeHtml(primaryEvidence.trigger_rule || finding.trigger_rule || 'rule_based_analysis')}</small>
      </article>
      ${selectedEvidence.length > 1 ? `<small class="muted-text">${selectedEvidence.length - 1} additional evidence records attached.</small>` : ''}
    </section>
  `;
}

function renderReviewFindingDetail(finding, evidence = [], callbacks = {}) {
  if (!finding) {
    return `
      <div class="review-empty-detail">
        <strong>Select a finding from the list</strong>
        <p>Select a finding from the list to review its evidence and make a decision.</p>
      </div>
    `;
  }
  const status = normalizeFindingStatus(finding.status);
  const isApproved = status === 'approved';
  const isRejected = status === 'rejected';
  const problemTypes = findingProblemTypes(finding);
  return `
    <article class="review-finding-detail">
      <header>
        <div>
          <h3>${escapeHtml(finding.title || 'Untitled finding')}</h3>
          <p>${escapeHtml(finding.business_domain || finding.domain || 'Domain')} · ${escapeHtml(finding.assessment_category || finding.category || 'Category')} · Severity ${escapeHtml(finding.severity ?? '-')}</p>
        </div>
        <span class="status-pill ${isApproved ? 'approved' : isRejected ? 'rejected' : 'draft'}">${escapeHtml(findingStatusLabel(finding.status))}</span>
      </header>
      ${renderReviewEvidenceSummary(finding, evidence)}
      <section class="review-detail-section">
        <h4>Problem types</h4>
        <div class="chip-list">
          ${problemTypes.map((type) => `<span class="mini-chip">${escapeHtml(formatLabelValue(type))}</span>`).join('') || '<span class="mini-chip">No problem types tagged</span>'}
        </div>
      </section>
      <div class="review-score-grid">
        <article><span>Confidence score</span><strong>${escapeHtml(finding.confidence ?? '-')}/5</strong></article>
        <article><span>Agreement score</span><strong>${escapeHtml(finding.overall_stakeholder_agreement_score || finding.stakeholder_agreement_score || 1)}/5</strong></article>
      </div>
      <label class="review-notes-field">
        Review notes
        <textarea rows="4" placeholder="Add review notes..." data-component-finding-notes-input="${escapeHtml(finding.id)}">${escapeHtml(finding.analyst_notes || finding.notes || '')}</textarea>
      </label>
      <div class="review-decision-actions">
        ${isApproved ? `
          <div class="review-decision-state approved"><strong>Approved</strong><span>This finding is approved for recommendations.</span></div>
          <button class="text-button" data-component-finding-action="draft" data-finding-id="${escapeHtml(finding.id)}" type="button">Undo</button>
        ` : isRejected ? `
          <div class="review-decision-state rejected"><strong>Rejected</strong><span>This finding will not unlock recommendations.</span></div>
          <button class="text-button" data-component-finding-action="draft" data-finding-id="${escapeHtml(finding.id)}" type="button">Undo</button>
        ` : `
          ${callbacks.onApproveFinding ? `<button class="review-approve-button" data-component-finding-action="approve" data-finding-id="${escapeHtml(finding.id)}" type="button">✓ Approve Finding</button>` : ''}
          ${callbacks.onRejectFinding ? `<button class="review-reject-button" data-component-finding-action="reject" data-finding-id="${escapeHtml(finding.id)}" type="button">✗ Reject Finding</button>` : ''}
        `}
      </div>
    </article>
  `;
}

function renderReviewGate(findings = []) {
  const allFindings = normalizeArray(findings);
  const reviewed = allFindings.filter((finding) => ['approved', 'rejected'].includes(normalizeFindingStatus(finding.status)));
  if (allFindings.length && reviewed.length === allFindings.length) {
    return `
      <section class="review-gate review-gate-passed">
        <strong>All findings reviewed.</strong>
        <p>Recommendations are now unlocked.</p>
      </section>
    `;
  }
  const remaining = Math.max(allFindings.length - reviewed.length, 0);
  return `
    <section class="review-gate review-gate-blocked">
      <strong>Review gate is blocked</strong>
      <ul>
        <li>${remaining} finding${remaining === 1 ? '' : 's'} still need approval or rejection.</li>
      </ul>
    </section>
  `;
}

function assessmentWorkspaceContextLabel(organization = {}, blueprint = {}, assessment = {}) {
  const orgName = organization?.clientDisplayName
    || organization?.organizationName
    || organization?.name
    || 'Selected Organization';
  const frameworkName = blueprint?.frameworkName
    || blueprint?.framework_name
    || blueprint?.name
    || assessment?.frameworkName
    || assessment?.framework_name
    || assessment?.assessment?.frameworkName
    || assessment?.assessment?.framework_name
    || 'Fleet & Service Operations v1';
  return `${orgName} · ${frameworkName}`;
}

function stageTabs(activeStage = 'setup', callbacks = {}) {
  return `
    <div class="assessment-workspace-tabs" role="tablist" aria-label="Assessment workspace stages">
      ${WORKSPACE_STAGES.map(([id, label]) => `
        <button
          class="assessment-workspace-tab ${activeStage === id ? 'active' : ''}"
          type="button"
          role="tab"
          aria-selected="${activeStage === id ? 'true' : 'false'}"
          data-assessment-workspace-stage="${escapeHtml(id)}"
          ${callbacks.onStageChange ? '' : 'disabled'}
        >
          ${escapeHtml(label)}
        </button>
      `).join('')}
    </div>
  `;
}

function metricCard(label, value, status = '') {
  return `<article><span>${escapeHtml(label)}</span><strong class="${status ? `status-pill ${statusClass(status)}` : ''}">${escapeHtml(value)}</strong></article>`;
}

function renderWorkspaceSetupStage(
  organization,
  assessment,
  blueprint,
  callbacks = {}
) {
  const { profile, intake, context } = organizationProfileData(organization);
  const projectId = firstValue(
    organization?.id,
    organization?.project_id,
    organization?.assessment_project_id,
    assessment?.company_id,
    profile.assessmentProjectId,
    profile.assessment_project_id
  );
  const intakeStatus = firstValue(intake.status, intake.intake_status, 'pending');
  const submitted = String(intakeStatus || '').toLowerCase() === 'submitted';
  const submittedBy = firstValue(intake.recipientName, intake.recipient_name, 'Unknown recipient');
  const submittedAt = firstValue(intake.submittedAt, intake.submitted_at);
  const workforce = profile.workforceStructure || profile.workforce_structure || {};
  const systems = profile.currentSystems || profile.current_systems || {};
  const companyName = firstValue(
    profile.companyName,
    profile.company_name,
    context.companyName,
    context.company_name,
    organization?.clientDisplayName,
    organization?.client_display_name,
    organization?.organizationName,
    organization?.name,
    'Selected organization'
  );
  const industry = formatLabelValue(firstValue(
    profile.industry,
    context.industry,
    organization?.industry,
    organization?.industryContext,
    organization?.industry_context,
    assessment?.industry
  ));
  const employeeRange = firstValue(profile.employeeRange, profile.employee_range, context.employeeRange, context.employee_range);
  const locationCount = firstValue(profile.locationCount, profile.location_count, context.locationCount, context.location_count);
  const revenueRange = firstValue(profile.revenueRange, profile.revenue_range, context.revenueRange, context.revenue_range);
  const customerRange = firstValue(profile.customerRange, profile.customer_range, context.customerRange, context.customer_range);
  const operatingModel = normalizeProfileList(workforce.operatingModel || workforce.operating_model || context.operatingModel || context.operating_model).join(' · ');
  const communicationTools = systems.communicationTools || systems.communication_tools || context.communicationTools || context.communication_tools || [];
  const departments = workforce.departments || context.departments || [];
  const recommendedRoles = profile.recommendedStakeholderRoles || profile.recommended_stakeholder_roles || [];
  const recommendedKpis = profile.recommendedKpis || profile.recommended_kpis || [];
  const strategicPriorities = profile.strategicPriorities || profile.strategic_priorities || context.topPriorities || context.top_priorities || [];
  const mostUrgentPriority = firstValue(context.mostUrgentPriority, context.most_urgent_priority);
  const expectationRows = [
    ['What success looks like', context.assessmentSuccess || context.assessment_success],
    ['Most urgent priority', mostUrgentPriority],
    ['Most important revenue', context.mostImportantRevenue || context.most_important_revenue],
    ['Fastest growing revenue', context.fastestGrowingRevenue || context.fastest_growing_revenue]
  ].filter(([, value]) => value !== undefined && value !== null && value !== '');
  const actionButtonStyle = 'padding:5px 10px;font-size:12px;border:0.5px solid rgba(200,169,110,0.25);border-radius:6px;background:transparent;color:rgba(200,169,110,0.7);display:inline-flex;align-items:center;gap:5px;cursor:pointer;';
  const intakeActions = `
    <div style="display:flex;align-items:center;gap:8px;flex-wrap:wrap;justify-content:flex-end;">
      <span style="background:${submitted ? 'rgba(100,180,100,0.1)' : 'rgba(200,169,110,0.1)'};border:0.5px solid ${submitted ? 'rgba(100,180,100,0.3)' : 'rgba(200,169,110,0.3)'};color:${submitted ? 'rgba(140,210,140,0.9)' : 'rgba(200,169,110,0.9)'};padding:4px 10px;border-radius:20px;font-size:11px;">${submitted ? 'Submitted' : 'Pending'}</span>
      <button type="button" data-component-resend-intake="${escapeHtml(projectId || '')}" onclick="console.log('Resend intake needs implementation', this.dataset.componentResendIntake)" style="${actionButtonStyle}">Resend link</button>
      <button type="button" data-component-edit-intake="${escapeHtml(projectId || '')}" onclick="console.log('Edit intake needs implementation', this.dataset.componentEditIntake)" style="${actionButtonStyle}">Edit</button>
    </div>
  `;
  return `
    <section class="assessment-workspace-stage assessment-workspace-setup">
      ${setupSection(
        'Company intake',
        submitted ? `Submitted by ${submittedBy} · ${formatDate(submittedAt)}` : 'Not yet submitted',
        `
          <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px 24px;">
            ${setupField('Company name', companyName)}
            ${setupField('Industry', industry)}
            ${setupField('Employees', employeeRange)}
            ${setupField('Locations', locationCount)}
            ${setupField('Revenue', revenueRange)}
            ${setupField('Customers', customerRange)}
          </div>
          <div style="height:0.5px;background:rgba(200,169,110,0.1);margin:1rem 0;"></div>
          <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:16px 24px;">
            ${setupField('ERP system', systems.erpSystem || systems.erp_system || context.erpSystem || context.erp_system)}
            ${setupField('Managers', workforce.managerCount || workforce.manager_count || context.managerCount || context.manager_count)}
            ${setupField('Field employees', workforce.fieldEmployeeCount || workforce.field_employee_count || context.fieldEmployeeCount || context.field_employee_count)}
            ${setupField('Operating model', operatingModel)}
          </div>
          <div style="height:0.5px;background:rgba(200,169,110,0.1);margin:1rem 0;"></div>
          <div style="display:grid;gap:14px;">
            <div>
              <div style="font-size:11px;color:rgba(232,228,220,0.35);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px;">Communication tools</div>
              <div style="display:flex;flex-wrap:wrap;gap:8px;">${setupTagList(communicationTools)}</div>
            </div>
            <div>
              <div style="font-size:11px;color:rgba(232,228,220,0.35);text-transform:uppercase;letter-spacing:0.05em;margin-bottom:6px;">Departments</div>
              <div style="display:flex;flex-wrap:wrap;gap:8px;">${setupTagList(departments)}</div>
            </div>
          </div>
        `,
        intakeActions
      )}
      ${setupSection(
        'Maturity scores',
        'Self-assessed by company owner',
        `
          ${maturityRow('Data quality', context.maturity_dataQuality || context.maturity_data_quality)}
          ${maturityRow('Reporting', context.maturity_reporting)}
          ${maturityRow('Technology', context.maturity_technology)}
          ${maturityRow('Analytics', context.maturity_analytics)}
          ${maturityRow('Automation', context.maturity_automation)}
          ${maturityRow('Process std.', context.maturity_processStandardization || context.maturity_process_standardization)}
          ${maturityRow('Customer exp.', context.maturity_customerExperience || context.maturity_customer_experience)}
        `
      )}
      ${setupSection(
        'Assessment expectations',
        "Owner's stated goals",
        expectationRows.length
          ? `<div style="display:grid;gap:14px;">${expectationRows.map(([label, value]) => setupField(label, value)).join('')}</div>`
          : '<p style="font-size:13px;color:rgba(232,228,220,0.35);margin:0;">No expectations recorded.</p>'
      )}
      ${setupSection(
        'Recommended stakeholder roles',
        `Derived from intake · ${recommendedRoles.length} roles`,
        roleRows(recommendedRoles)
      )}
      ${setupSection(
        'Key performance indicators',
        'Metrics that reveal organizational blind spots',
        kpiRows(recommendedKpis)
      )}
      ${setupSection(
        'Strategic priorities',
        `Most urgent: ${mostUrgentPriority ? formatPriorityLabel(mostUrgentPriority) : '—'}`,
        `<div style="display:flex;flex-wrap:wrap;gap:8px;">${setupTagList(strategicPriorities, 'No priorities recorded.')}</div>`
      )}
    </section>
  `;
}

function renderWorkspaceCollectionStage(
  assessment,
  blueprint,
  participants,
  coverage,
  filterState,
  uploadPreview,
  importSummary,
  invitationSummary,
  invitationPreview,
  reminderSummary,
  reminderPreview,
  emptyStateHtml,
  callbacks = {}
) {
  const roleOptions = roleOptionsFromBlueprint(blueprint);
  return `
    <section class="assessment-workspace-stage assessment-workspace-collection">
      ${renderParticipantsSectionComponent(
        assessment,
        participants,
        coverage,
        filterState,
        {},
        roleOptions,
        emptyStateHtml,
        {
          onAddParticipant: callbacks.onAddParticipant,
          onEdit: callbacks.onEditParticipant,
          onDeactivate: callbacks.onDeactivateParticipant,
          onCreateSession: callbacks.onCreateSession,
          onGenerateLink: callbacks.onGenerateLink,
          onCopyLink: callbacks.onCopyLink,
          onPreviewInvite: callbacks.onPreviewInvite,
          onSendInvite: callbacks.onSendInvite,
          onPreviewReminder: callbacks.onPreviewReminder,
          onSendReminder: callbacks.onSendReminder,
          onFilterChange: callbacks.onFilterChange
        }
      )}
      ${renderParticipantUploadPanelComponent(
        uploadPreview,
        importSummary,
        emptyStateHtml,
        {
          onDownloadTemplate: callbacks.onDownloadTemplate,
          onPreviewUpload: callbacks.onPreviewUpload,
          onConfirmImport: callbacks.onConfirmImport,
          onDownloadErrors: callbacks.onDownloadErrors,
          onCreateSessionsForImported: callbacks.onCreateSessionsForImported,
          onFileSelected: callbacks.onFileSelected
        }
      )}
      ${renderInvitationPanelComponent(
        invitationSummary,
        invitationPreview,
        {
          onBulkSend: callbacks.onBulkSendInvites,
          onScopeChange: callbacks.onInviteScopeChange
        }
      )}
      ${renderReminderPanelComponent(
        participants,
        reminderSummary,
        reminderPreview,
        {},
        {
          onBulkSend: callbacks.onBulkSendReminders,
          onScopeChange: callbacks.onReminderScopeChange
        }
      )}
    </section>
  `;
}

function renderWorkspaceReviewStage(
  sessions,
  findings,
  evidence,
  clusters,
  filterState,
  selectedFindingId,
  kpiGaps,
  emptyStateHtml,
  callbacks = {}
) {
  const allFindings = normalizeArray(findings);
  const approvedFindings = allFindings.filter((finding) => statusIs(finding.status, 'approved'));
  const rejectedFindings = allFindings.filter((finding) => statusIs(finding.status, 'rejected'));
  const reviewedCount = approvedFindings.length + rejectedFindings.length;
  const selectedFinding = allFindings.find((finding) => String(finding.id) === String(selectedFindingId)) || allFindings[0] || null;
  const selectedId = selectedFinding?.id || selectedFindingId || '';
  const reviewProgress = allFindings.length ? Math.round((reviewedCount / allFindings.length) * 100) : 0;
  return `
    <section class="assessment-workspace-stage assessment-workspace-review">
      <section class="review-quality-header">
        <div class="panel-header">
          <div>
            <span class="eyebrow">Review</span>
            <h2>Findings quality gate</h2>
            <p>Review each finding, resolve contradictions, then approve or reject before recommendations unlock.</p>
          </div>
          <div class="row-actions">
            ${callbacks.onRunAnalysis ? `<button class="secondary-button" data-assessment-action="run-analysis" type="button">Run Analysis</button>` : ''}
            ${callbacks.onMergeFindings ? `<button class="primary-button" data-component-merge-selected-findings type="button">Merge Selected Into Active</button>` : ''}
          </div>
        </div>
        <div class="review-progress-row">
          <span>${reviewedCount} of ${allFindings.length} findings reviewed</span>
          <div class="progress-track" aria-label="Finding review progress">
            <div class="progress-fill" style="width: ${reviewProgress}%"></div>
          </div>
        </div>
      </section>
      <section class="review-workbench">
        ${allFindings.length ? `
          <aside class="review-list-column">
            ${renderReviewFindingList(allFindings, selectedId, callbacks)}
          </aside>
          <div class="review-detail-column">
            ${renderReviewFindingDetail(selectedFinding, evidence, callbacks)}
          </div>
        ` : (emptyStateHtml || renderScreenState('findings', 'empty', {
          title: 'No findings have been generated yet',
          message: 'Run analysis after enough responses are complete.',
          compact: true
        }))}
      </section>
      <details class="review-collapsible">
        <summary>
          <span>Finding clusters (${normalizeArray(clusters).length})</span>
          <i>⌄</i>
        </summary>
        <div class="review-collapsible-body review-cluster-grid">
          ${renderFindingClustersComponent(
            clusters,
            emptyStateHtml,
            { onMergeCluster: callbacks.onMergeCluster }
          )}
        </div>
      </details>
      <details class="review-collapsible">
        <summary>
          <span>
            Organizational alignment heatmap
            <small>Expand to see where the organization agrees or disagrees</small>
          </span>
          <i>⌄</i>
        </summary>
        <div class="review-collapsible-body review-heatmap-scroll">
          ${renderAlignmentHeatmapComponent(
            approvedFindings,
            filterState,
            emptyStateHtml,
            {
              onDomainFilterChange: (value) => callbacks.onFilterChange?.('heatmapDomain', value),
              onGroupFilterChange: (value) => callbacks.onFilterChange?.('heatmapGroup', value),
              onMinPriorityChange: (value) => callbacks.onFilterChange?.('heatmapMinPriority', value),
              onMisalignmentToggle: (value) => callbacks.onFilterChange?.('onlyMisalignment', value),
              onHighConfidenceToggle: (value) => callbacks.onFilterChange?.('onlyHighConfidence', value),
              onCellSelect: (key) => callbacks.onFilterChange?.('selectedHeatmapCellKey', key),
              onSelectFinding: callbacks.onSelectFinding
            }
          )}
        </div>
      </details>
      ${renderReviewGate(allFindings)}
    </section>
  `;
}

function renderWorkspaceRecommendationsStage(
  recommendations,
  roadmapItems,
  progressMemory,
  emptyStateHtml,
  callbacks = {}
) {
  return `
    <section class="assessment-workspace-stage assessment-workspace-recommendations">
      <section class="panel">
        <div class="panel-header"><h2>Recommendations</h2><span>${normalizeArray(recommendations).length} generated</span></div>
        ${renderRecommendationsComponent(
          recommendations,
          false,
          emptyStateHtml,
          {
            onApprove: callbacks.onApproveRecommendation,
            onReject: callbacks.onRejectRecommendation,
            onAccept: (id) => callbacks.onRecommendationStatus?.(id, 'accepted'),
            onInProgress: (id) => callbacks.onRecommendationStatus?.(id, 'in_progress'),
            onComplete: (id) => callbacks.onRecommendationStatus?.(id, 'completed'),
            onNotes: callbacks.onRecommendationNotes,
            onTrackOutcome: callbacks.onTrackOutcome
          }
        )}
      </section>
      <section class="panel">
        <div class="panel-header"><h2>Roadmap</h2><span>Sequenced implementation phases</span></div>
        ${renderRoadmapComponent(roadmapItems, emptyStateHtml, {})}
      </section>
      <section class="panel">
        ${renderProgressMemorySectionComponent(
          progressMemory || {},
          emptyStateHtml,
          true,
          {
            onGenerateSnapshot: callbacks.onGenerateSnapshot,
            onRegenerateSnapshot: callbacks.onRegenerateSnapshot
          }
        )}
      </section>
    </section>
  `;
}

function renderWorkspaceExecutiveStage(
  organization,
  assessment,
  findings,
  recommendations,
  roadmapItems,
  evidence,
  progressMemory,
  selectedFindingId,
  filterState,
  executiveReport,
  reportToggles,
  emptyStateHtml,
  callbacks = {}
) {
  const approvedFindings = normalizeArray(findings).filter((finding) => statusIs(finding.status, 'approved'));
  const approvedRecs = normalizeArray(recommendations).filter((recommendation) => ['approved', 'accepted', 'in_progress', 'completed'].includes(String(recommendation.status || '').toLowerCase()));
  return `
    <section class="assessment-workspace-stage assessment-workspace-executive">
      <section class="panel">
        <div class="panel-header"><h2>Executive Preview</h2><span>Owner-facing intelligence preview</span></div>
        ${renderExecutivePreviewComponent(
          organization,
          assessment,
          null,
          null,
          approvedFindings,
          approvedRecs,
          roadmapItems,
          evidence,
          progressMemory || {},
          selectedFindingId,
          filterState,
          emptyStateHtml,
          {
            onSelectFinding: callbacks.onSelectFinding,
            onViewReport: callbacks.onViewReport,
            onFilterChange: callbacks.onFilterChange,
            onHeatmapCellSelect: (key) => callbacks.onFilterChange?.('selectedHeatmapCellKey', key),
            onNavigate: callbacks.onStageChange
          }
        )}
      </section>
      <section class="panel">
        <div class="panel-header"><h2>Executive Report</h2><span>Generated report</span></div>
        ${renderExecutiveReportComponent(
          executiveReport,
          approvedFindings,
          approvedRecs,
          progressMemory || {},
          reportToggles,
          emptyStateHtml,
          {
            onGenerate: callbacks.onGenerateReport,
            onToggleSection: callbacks.onToggleSection,
            onNavigateSection: () => {},
            onPrint: () => {
              if (typeof window !== 'undefined') window.print();
            },
            onExport: callbacks.onExportReport
          }
        )}
      </section>
    </section>
  `;
}

function renderWorkspaceOperationsStage(
  assessment,
  participants,
  sessions,
  findings,
  recommendations,
  blueprint,
  operationsData,
  emptyStateHtml,
  callbacks = {}
) {
  const missingSessions = normalizeArray(participants).filter((participant) => !participant.session_id);
  const failedCommunications = normalizeArray(participants).filter((participant) => participant.email_status === 'failed' || participant.reminder_status === 'failed');
  const requiredRoles = blueprintRoles(blueprint).filter((role) => role.level === 'Required');
  const coveredRequiredRoles = new Set(normalizeArray(participants).map((participant) => participant.stakeholder_role_id).filter(Boolean));
  return `
    <section class="assessment-workspace-stage assessment-workspace-operations">
      <div class="blueprint-score-grid">
        ${metricCard('Participants', normalizeArray(participants).length)}
        ${metricCard('Sessions', normalizeArray(sessions).length)}
        ${metricCard('Findings', normalizeArray(findings).length)}
        ${metricCard('Recommendations', normalizeArray(recommendations).length)}
        ${metricCard('Coverage', `${coveredRequiredRoles.size}/${requiredRoles.length || 0}`)}
        ${metricCard('Operations Events', normalizeArray(operationsData?.events || operationsData?.audit_logs || []).length)}
      </div>
      <section class="panel">
        <div class="panel-header">
          <div><h2>Operational Controls</h2><span>Assessment workflow controls</span></div>
          <div class="row-actions">
            ${callbacks.onCreateAssessment ? `<button class="ghost-button" data-assessment-action="create-assessment" type="button">Create Assessment</button>` : ''}
            ${callbacks.onRunAnalysis ? `<button class="ghost-button" data-assessment-action="run-analysis" type="button">Run Analysis</button>` : ''}
            ${callbacks.onOpenOperationsCenter ? `<button class="primary-button" data-assessment-action="open-operations-center" type="button">Open Operations Center</button>` : ''}
          </div>
        </div>
        <div class="dashboard-grid">
          <article>
            <h3>Readiness Checks</h3>
            <ul class="check-list">
              <li><span class="status-pill ${statusClass(requiredRoles.length && coveredRequiredRoles.size >= requiredRoles.length ? 'approved' : 'warning')}">Coverage</span> ${coveredRequiredRoles.size}/${requiredRoles.length || 0} required roles covered</li>
              <li><span class="status-pill ${statusClass(normalizeArray(findings).length ? 'approved' : 'warning')}">Findings</span> ${normalizeArray(findings).length} findings available</li>
              <li><span class="status-pill ${statusClass(normalizeArray(recommendations).length ? 'approved' : 'warning')}">Recommendations</span> ${normalizeArray(recommendations).length} recommendations available</li>
            </ul>
          </article>
          <article>
            <h3>Workflow Health</h3>
            <ul class="check-list">
              <li>${missingSessions.length} participants missing sessions</li>
              <li>${failedCommunications.length} failed communications</li>
              <li>Assessment: ${escapeHtml(assessment?.name || assessment?.title || assessment?.assessment?.name || 'Current assessment')}</li>
            </ul>
          </article>
        </div>
      </section>
      <section class="panel">
        <div class="panel-header"><h3>Missing Sessions</h3><span>${missingSessions.length} records</span></div>
        <div class="table-scroll">
          <table class="compact-table">
            <thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Status</th></tr></thead>
            <tbody>
              ${missingSessions.map((participant) => `
                <tr>
                  <td>${escapeHtml(participant.full_name || participant.name || '-')}</td>
                  <td>${escapeHtml(participant.email || '-')}</td>
                  <td>${escapeHtml(participant.stakeholder_role_name || participant.stakeholder_role_id || '-')}</td>
                  <td><span class="status-pill ${statusClass(participant.status)}">${escapeHtml(participant.status || '-')}</span></td>
                </tr>
              `).join('') || `<tr><td colspan="4">${emptyStateHtml || 'All participants with records have sessions.'}</td></tr>`}
            </tbody>
          </table>
        </div>
      </section>
      <section class="panel">
        <div class="panel-header"><h3>Failed Communications</h3><span>${failedCommunications.length} records</span></div>
        <div class="insight-list">
          ${failedCommunications.map((participant) => `
            <article class="insight-card">
              <strong>${escapeHtml(participant.full_name || participant.name || participant.email || 'Participant')}</strong>
              <p>Email: ${escapeHtml(participant.email_status || 'n/a')} · Reminder: ${escapeHtml(participant.reminder_status || 'n/a')}</p>
              <small>${escapeHtml(participant.email_error || participant.reminder_error || '')}</small>
            </article>
          `).join('') || '<p class="muted-text">No failed communications are currently flagged.</p>'}
        </div>
      </section>
    </section>
  `;
}

export function renderAssessmentWorkspaceComponent(
  activeStage,
  organization,
  assessment,
  blueprint,
  participants,
  sessions,
  findings,
  evidence,
  recommendations,
  roadmapItems,
  kpiGaps,
  clusters,
  coverage,
  progressMemory,
  uploadPreview,
  importSummary,
  invitationSummary,
  invitationPreview,
  reminderSummary,
  reminderPreview,
  filterState,
  selectedFindingId,
  reportToggles,
  executiveReport,
  operationsData,
  emptyStateHtml,
  callbacks = {}
) {
  const nextStage = WORKSPACE_STAGES.some(([id]) => id === activeStage) ? activeStage : 'setup';
  const stageContent = {
    setup: () => renderWorkspaceSetupStage(organization, assessment, blueprint, callbacks),
    collection: () => renderWorkspaceCollectionStage(
      assessment,
      blueprint,
      participants,
      coverage,
      filterState,
      uploadPreview,
      importSummary,
      invitationSummary,
      invitationPreview,
      reminderSummary,
      reminderPreview,
      emptyStateHtml,
      callbacks
    ),
    review: () => renderWorkspaceReviewStage(
      sessions,
      findings,
      evidence,
      clusters,
      filterState,
      selectedFindingId,
      kpiGaps,
      emptyStateHtml,
      callbacks
    ),
    recommendations: () => renderWorkspaceRecommendationsStage(recommendations, roadmapItems, progressMemory, emptyStateHtml, callbacks),
    executive: () => renderWorkspaceExecutiveStage(
      organization,
      assessment,
      findings,
      recommendations,
      roadmapItems,
      evidence,
      progressMemory,
      selectedFindingId,
      filterState,
      executiveReport,
      reportToggles,
      emptyStateHtml,
      callbacks
    ),
    operations: () => renderWorkspaceOperationsStage(
      assessment,
      participants,
      sessions,
      findings,
      recommendations,
      blueprint,
      operationsData,
      emptyStateHtml,
      callbacks
    )
  };
  if (!assessment && !blueprint) {
    return emptyStateHtml || renderScreenState('assessment-workspace', 'empty', {
      title: 'No assessment workspace loaded',
      message: 'Select an organization workspace to load assessment data.'
    });
  }
  return `
    <section class="assessment-workspace-component">
      <div class="panel-header">
        <div>
          <span class="eyebrow">Assessment Workspace</span>
          <h2>${escapeHtml(organization?.clientDisplayName || organization?.organizationName || organization?.name || 'Selected Organization')}</h2>
          <p class="assessment-workspace-context">${escapeHtml(assessmentWorkspaceContextLabel(organization, blueprint, assessment))}</p>
        </div>
        <span class="status-pill ${statusClass(assessment?.status || assessment?.assessment?.status || 'active')}">${escapeHtml(assessment?.status || assessment?.assessment?.status || 'Active')}</span>
      </div>
      ${stageTabs(nextStage, callbacks)}
      ${stageContent[nextStage] ? stageContent[nextStage]() : renderLoadingSkeleton('Loading assessment workspace', 3)}
    </section>
  `;
}
