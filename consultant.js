import { getSlice, mergeState } from '../store.js';
import {
  renderFindingsWorkbenchComponent,
  renderEvidenceExplorerComponent,
  renderFindingClustersComponent
} from '../components/findings.js';
import { renderRecommendationsComponent } from '../components/recommendations.js';
import { renderRoadmapComponent } from '../components/roadmap.js';
import { renderProgressMemorySectionComponent } from '../components/progress.js';
import { renderAlignmentHeatmapComponent } from '../components/alignment.js';
import { renderExecutiveReportComponent } from '../components/executive.js';
import {
  renderHealthPill,
  renderProgressIntelligence
} from '../components/progress-intelligence.js?v=20260607-dark-table';
import {
  renderParticipantsSectionComponent,
  renderParticipantUploadPanelComponent,
  renderInvitationPanelComponent,
  renderReminderPanelComponent
} from '../components/participants.js';
import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml
} from '../shared.js';

let consultantContainer = null;
let consultantViewContainer = null;
let consultantCallbacks = {};

let consultantState = {
  activeEngagementId: null,
  activeStage: null,
  activeView: 'engagements',
  selectedFindingId: null,
  selectedRecommendationId: null,
  filterState: {
    heatmapDomain: null,
    heatmapGroup: null,
    heatmapMinPriority: null,
    onlyMisalignment: false,
    onlyHighConfidence: false,
    selectedHeatmapCellKey: null,
    stakeholderGroup: null,
    stakeholderRole: null,
    group: null,
    role: null,
    status: null
  },
  reportToggles: {
    showEvidence: true,
    showAppendix: true
  },
  contradictionResolutions: {},
  activeResolutionFindingId: null,
  stageLockMessage: null,
  invitationScope: 'not_invited',
  reminderScope: 'incomplete',
  invitationSendState: {
    status: 'idle',
    message: '',
    count: null
  },
  progressIntelligenceByProject: {}
};

let invitationSendMessageTimer = null;

const STAGES = [
  { id: 'setup', label: 'Setup' },
  { id: 'collection', label: 'Collection' },
  { id: 'review', label: 'Review' },
  { id: 'recommendations', label: 'Recommendations' },
  { id: 'deliver', label: 'Deliver' }
];

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function authHeaders() {
  const token = (typeof window !== 'undefined' && (
    window.__platformSessionToken
    || window.localStorage?.getItem('platformSessionToken')
  )) || '';
  return {
    Authorization: `Bearer ${token}`,
    'x-session-token': token
  };
}

function snapshotsFromProgressMemory(progressMemory = {}) {
  return [
    progressMemory.previous_snapshot,
    progressMemory.latest_snapshot
  ].filter(Boolean);
}

async function fetchProgressIntelligence(projectId) {
  if (!projectId) return null;
  if (consultantState.progressIntelligenceByProject[projectId]) {
    return consultantState.progressIntelligenceByProject[projectId];
  }
  const response = await fetch(`/api/progress-intelligence?projectId=${encodeURIComponent(projectId)}`, {
    headers: authHeaders()
  });
  const data = await response.json();
  if (response.ok) {
    consultantState.progressIntelligenceByProject[projectId] = data;
    return data;
  }
  throw new Error(data.error || 'Progress intelligence could not load.');
}

function closeProgressPanel() {
  document.querySelector('.progress-panel-backdrop')?.remove();
  document.querySelector('.progress-panel')?.remove();
}

function renderProgressPanel(data = {}) {
  closeProgressPanel();
  const backdrop = document.createElement('div');
  backdrop.className = 'progress-panel-backdrop';
  const panel = document.createElement('aside');
  panel.className = 'progress-panel progress-intelligence-panel';
  panel.style.background = '#111110';
  panel.style.color = '#F0EDE6';
  panel.innerHTML = `
    <header>
      <div>
        <h2>Progress intelligence</h2>
        <span>${escapeHtml(data.organization?.name || 'Organization')}</span>
      </div>
      <button class="text-button" data-progress-panel-close type="button">×</button>
    </header>
    <div class="progress-panel-body" style="background:#111110;color:#F0EDE6;">
      ${renderProgressIntelligence(data)}
    </div>
  `;
  document.body.appendChild(backdrop);
  document.body.appendChild(panel);
  backdrop.addEventListener('click', closeProgressPanel);
  panel.querySelector('[data-progress-panel-close]')?.addEventListener('click', closeProgressPanel);
}

async function openProgressPanel(projectId) {
  try {
    const data = await fetchProgressIntelligence(projectId);
    renderProgressPanel(data);
  } catch (error) {
    console.error('Progress intelligence error:', error);
  }
}

function clearClientSession() {
  if (typeof window === 'undefined') return;
  window.localStorage?.removeItem('krbCurrentUserEmail');
  window.localStorage?.removeItem('krbSession');
  window.localStorage?.removeItem('currentPlatformUser');
  window.localStorage?.removeItem('platformSessionToken');
  window.__platformSessionToken = '';
}

function handleLogout() {
  const headers = authHeaders();
  clearClientSession();
  fetch('/api/auth/logout', {
    method: 'POST',
    headers
  })
    .then(() => {
      window.location.href = '/';
    })
    .catch(() => {
      window.location.href = '/';
    });
}

function normalizeStatus(value = '') {
  return String(value || '').toLowerCase().replace(/\s+/g, '_');
}

function labelFromId(value = '') {
  return String(value || '')
    .replace(/[_-]/g, ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function firstUsefulLabel(values = [], fallback = '') {
  return values.find((value) => String(value || '').trim()) || fallback;
}

function firstValue(...values) {
  return values.find((value) => value !== undefined && value !== null && String(value).trim() !== '');
}

function formatLabelValue(value, fallback = 'Not set') {
  if (value === undefined || value === null || String(value).trim() === '') return fallback;
  return String(value)
    .replace(/[_-]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function normalizeProfileList(value) {
  if (Array.isArray(value)) return value.filter(Boolean);
  if (typeof value === 'string') {
    return value.split(/\n|,/).map((item) => item.trim()).filter(Boolean);
  }
  return [];
}

function formatPriorityLabel(str) {
  if (!str) return '';
  return String(str)
    .replace(/_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function formatDate(dateStr) {
  if (!dateStr) return '';
  const date = new Date(dateStr);
  if (Number.isNaN(date.getTime())) return String(dateStr);
  return date.toLocaleDateString('en-GB', {
    day: 'numeric',
    month: 'long',
    year: 'numeric'
  });
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
  const values = safeArray(roles);
  if (!values.length) return `<p style="font-size:13px;color:rgba(232,228,220,0.35);margin:0;">No roles derived yet.</p>`;
  return values.map((role, index) => `
    <div style="padding:7px 0;${index === values.length - 1 ? '' : 'border-bottom:0.5px solid rgba(200,169,110,0.08);'}">
      <div style="font-size:13px;color:#E8E4DC;">${escapeHtml(role.name || role.label || role.role_name || role.id || 'Role')}</div>
      <div style="font-size:11px;color:rgba(200,169,110,0.5);margin-top:2px;">${escapeHtml(role.stakeholder_group_name || role.group_name || role.stakeholderGroupName || 'Group not set')}</div>
    </div>
  `).join('');
}

function kpiRows(kpis = []) {
  const values = safeArray(kpis);
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

function activeOrganization(platform = {}) {
  const projects = safeArray(platform.projects);
  if (consultantState.activeEngagementId) {
    const project = projects.find((project) =>
      String(project.id || project.organization_id || project.assessment_project_id || project.name) === String(consultantState.activeEngagementId)
    );
    if (project) return project;
    const consultant = getSlice('consultant') || {};
    const command = consultant.commandCenterState || {};
    const engagements = safeArray(command.organizations)
      .concat(safeArray(command.assigned_organizations))
      .concat(safeArray(command.engagements));
    return engagements.find((engagement) =>
      String(engagement.id || engagement.project_id || engagement.organization_id || engagement.assessment_project_id || engagement.name) === String(consultantState.activeEngagementId)
    ) || null;
  }
  if (projects[0]) return projects[0];
  const consultant = getSlice('consultant') || {};
  const command = consultant.commandCenterState || {};
  return safeArray(command.organizations)[0]
    || safeArray(command.assigned_organizations)[0]
    || safeArray(command.engagements)[0]
    || null;
}

function organizationName(organization = {}) {
  return firstUsefulLabel([
    organization?.client_display_name,
    organization?.clientDisplayName,
    organization?.displayName,
    organization?.display_name,
    organization?.organization_name,
    organization?.organization_name,
    organization?.name
  ], 'Organization');
}

function frameworkName(organization = {}, assessment = {}) {
  return firstUsefulLabel([
    organization?.framework_name,
    organization?.frameworkName,
    organization?.methodology_name,
    assessment?.blueprint?.framework_name,
    assessment?.blueprint?.framework?.name,
    assessment?.blueprint?.frameworkName
  ], 'Fleet & Service Operations Framework v1');
}

function assessmentName(organization = {}, assessment = {}) {
  return firstUsefulLabel([
    organization?.activeAssessmentName,
    organization?.active_assessment_name,
    organization?.assessment_name,
    organization?.assessmentName,
    organization?.name,
    assessment?.assessment?.title,
    assessment?.blueprint?.assessment_name
  ], 'Business Assessment');
}

function assessmentDate(organization = {}, assessment = {}) {
  const value = organization?.updated_at || organization?.last_updated || assessment?.assessment?.updated_at || assessment?.blueprint?.updated_at;
  return value ? new Date(value).toLocaleDateString() : 'Not updated yet';
}

function assessmentContext() {
  const platform = getSlice('platform') || {};
  const assessment = getSlice('assessment') || {};
  const organization = activeOrganization(platform) || {};
  return { platform, assessment, organization };
}

function projectIdForEngagement(engagement = {}) {
  return engagement.id
    || engagement.project_id
    || engagement.assessment_project_id
    || engagement.company_id
    || engagement.organization_id
    || null;
}

function organizationProfileData(organization = {}, assessment = {}) {
  const profile = assessment.companyProfile
    || assessment.company_profile
    || organization.companyProfile
    || organization.company_profile
    || organization.profile
    || {};
  const intake = assessment.projectContextIntake
    || assessment.project_context_intake
    || organization.projectContextIntake
    || organization.project_context_intake
    || {};
  const context = profile.contextData
    || profile.context_data
    || intake.contextData
    || intake.context_data
    || organization.contextData
    || organization.context_data
    || {};
  return { profile, intake, context };
}

function mergeKpiSelectionsIntoProfile(profile, kpiData = {}) {
  if (!profile) return profile;
  const selected = new Map((kpiData.selected || []).map((row) => [String(row.kpi_key), row]));
  const recommended = (kpiData.recommended || profile.recommendedKpis || profile.recommended_kpis || []).map((kpi) => {
    const key = kpi.key || kpi.kpi_key || kpi.id;
    const selection = selected.get(String(key));
    return selection
      ? {
          ...kpi,
          is_currently_tracked: Boolean(selection.is_currently_tracked),
          tracking_method: selection.tracking_method,
          notes: selection.notes
        }
      : kpi;
  });
  return {
    ...profile,
    recommendedKpis: recommended,
    recommended_kpis: recommended
  };
}

async function fetchProjectKpis(projectId) {
  if (!projectId) return {};
  const response = await fetch(`/api/projects/${encodeURIComponent(projectId)}/kpis`, { headers: authHeaders() });
  return response.ok ? response.json().catch(() => ({})) : {};
}

async function saveProjectKpiTracking(projectId, kpiKey, isTracked) {
  if (!projectId || !kpiKey) return;
  const response = await fetch(`/api/projects/${encodeURIComponent(projectId)}/kpis`, {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      kpi_key: kpiKey,
      is_currently_tracked: Boolean(isTracked)
    })
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok || data.error) throw new Error(data.error || 'Failed to save KPI tracking.');
}

function updateLocalKpiTracking(kpiKey, isTracked) {
  const assessment = getSlice('assessment') || {};
  const profile = assessment.companyProfile || {};
  const recommended = safeArray(profile.recommendedKpis || profile.recommended_kpis).map((kpi) =>
    String(kpi.key || kpi.kpi_key || kpi.id) === String(kpiKey)
      ? { ...kpi, is_currently_tracked: Boolean(isTracked), tracked: Boolean(isTracked) }
      : kpi
  );
  mergeState('assessment', {
    companyProfile: {
      ...profile,
      recommendedKpis: recommended,
      recommended_kpis: recommended
    }
  });
}

async function bootstrapEngagementContext(engagement = {}) {
  const projectId = projectIdForEngagement(engagement);
  if (!projectId) return;
  try {
    const [contextResponse, kpiData] = await Promise.all([
      fetch(`/api/project-context?projectId=${encodeURIComponent(projectId)}`, { headers: authHeaders() }),
      fetchProjectKpis(projectId)
    ]);
    const data = await contextResponse.json().catch(() => ({}));
    if (!contextResponse.ok || data.error) return;
    mergeState('assessment', {
      companyProfile: mergeKpiSelectionsIntoProfile(data.companyProfile || null, kpiData),
      projectContextIntake: data.intake || null
    });
    mergeState('consultant', {
      activeProjectContext: data
    });
    renderConsultantView(consultantState.activeView || consultantState.activeStage || 'setup');
  } catch (error) {
    console.error('Consultant project context bootstrap error:', error);
  }
}

async function bootstrapEngagementAssessment(engagement = {}) {
  const projectId = projectIdForEngagement(engagement);
  if (!projectId) return;
  try {
    const [response, kpiData] = await Promise.all([
      fetch(`/api/assessment-engine?projectId=${encodeURIComponent(projectId)}`, { headers: authHeaders() }),
      fetchProjectKpis(projectId)
    ]);
    const data = await response.json().catch(() => ({}));
    if (!response.ok || data.error) return;
    mergeState('assessment', {
      assessment: data.assessment || null,
      activeAssessmentId: data.assessment?.id || null,
      blueprint: data.blueprint || data.assessmentBlueprint || null,
      participants: data.assessmentParticipants || [],
      sessions: data.sessions || [],
      findings: data.findings || [],
      evidence: data.evidence || [],
      clusters: data.clusters || [],
      recommendations: data.recommendations || [],
      roadmapItems: data.roadmapItems || [],
      coverage: data.participantCoverage || null,
      progressMemory: data.progressMemory || null,
      companyProfile: mergeKpiSelectionsIntoProfile(data.companyProfile || null, kpiData),
      kpiGaps: data.kpiGaps || []
    });
    renderConsultantView(consultantState.activeView || consultantState.activeStage || 'setup');
  } catch (error) {
    console.error('Consultant assessment bootstrap error:', error);
  }
}

function emptyState(title, message = 'When the assessment is ready, this area will show the work required for consultant review.') {
  return renderScreenState('consultant', 'empty', {
    title,
    message,
    actionLabel: '',
    actionView: '',
    compact: true
  });
}

function approvedFindings(findings = []) {
  return safeArray(findings).filter((finding) => normalizeStatus(finding.status) === 'approved');
}

function approvedRecommendations(recommendations = []) {
  return safeArray(recommendations).filter((recommendation) => normalizeStatus(recommendation.status) === 'approved');
}

function visibleContradictions(finding = {}) {
  const explicit = safeArray(finding.contradictions);
  const details = finding.contradiction_details || {};
  const detailItems = safeArray(details.conflicting_responses).map((item) => ({
    description: item.description || item.response || `${item.stakeholder_group_name || item.stakeholder_group_id || 'Stakeholder'} reported a conflicting account.`
  }));
  if (explicit.length) return explicit;
  if (finding.contradiction_detected || detailItems.length) {
    return detailItems.length ? detailItems : [{ description: 'Contradiction detected in stakeholder evidence.' }];
  }
  return [];
}

function hasUnresolvedContradiction(finding = {}) {
  return visibleContradictions(finding).length > 0 && !consultantState.contradictionResolutions[finding.id]?.resolution;
}

function recommendationsByFindingId(recommendations = []) {
  return safeArray(recommendations).reduce((acc, recommendation) => {
    if (recommendation.finding_id) acc[String(recommendation.finding_id)] = recommendation;
    return acc;
  }, {});
}

function roleMergeKey(role = {}) {
  return String(
    role.id
    || role.role_id
    || role.stakeholder_role_id
    || role.key
    || role.role_key
    || role.name
    || role.role_name
    || role.label
    || role
  ).toLowerCase().replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '');
}

function mergeRoleListsPreferLater(...lists) {
  const map = new Map();
  lists.flatMap((list) => safeArray(list)).forEach((role) => {
    const key = roleMergeKey(role);
    if (!key) return;
    const normalized = typeof role === 'string' ? { id: role, name: role } : role;
    map.set(key, { ...(map.get(key) || {}), ...normalized });
  });
  return [...map.values()];
}

function requiredRoles(blueprint = {}, coverage = {}) {
  return mergeRoleListsPreferLater(
    blueprint.required_roles,
    blueprint.requiredRoles,
    blueprint.required_stakeholder_roles,
    coverage.required_roles
  );
}

function roleId(role = {}) {
  return role.id || role.role_id || role.stakeholder_role_id || role.name || role.role_name || role;
}

function roleLabel(role = {}) {
  return role.name || role.role_name || role.label || labelFromId(roleId(role));
}

function roleOptionsFromCoverage(coverage = {}) {
  return requiredRoles({}, coverage)
    .concat(safeArray(coverage.recommended_roles), safeArray(coverage.optional_roles))
    .map((role) => ({ id: roleId(role), name: roleLabel(role) }))
    .filter((role) => role.id);
}

function computeSetupGate() {
  const assessment = getSlice('assessment') || {};
  return {
    passed: Boolean(assessment.blueprint),
    blockers: assessment.blueprint ? [] : ['Assessment blueprint has not been generated yet.']
  };
}

function computeCollectionGate() {
  const assessment = getSlice('assessment') || {};
  const required = requiredRoles(assessment.blueprint || {}, assessment.coverage || {});
  if (!required.length) {
    const completed = safeArray(assessment.participants).filter((participant) => normalizeStatus(participant.status) === 'completed').length;
    return {
      passed: completed > 0,
      blockers: completed > 0 ? [] : ['At least one participant response is required before review confidence is meaningful.']
    };
  }
  const participants = safeArray(assessment.participants);
  const missing = required.filter((role) => {
    const id = String(roleId(role));
    const assigned = Number(role.assigned_count || role.assigned || 0);
    const completed = Number(role.completed_count || role.completed || 0);
    if (assigned > 0 || completed > 0 || ['covered', 'completed'].includes(normalizeStatus(role.status))) return false;
    return !participants.some((participant) =>
      String(participant.stakeholder_role_id || participant.role_id || participant.role) === id
      && normalizeStatus(participant.status) !== 'deactivated'
    );
  });
  return {
    passed: missing.length === 0,
    blockers: missing.length ? [`${missing.length} required role${missing.length === 1 ? '' : 's'} still need participant coverage.`] : []
  };
}

function computeReviewGate() {
  const assessment = getSlice('assessment') || {};
  const findings = safeArray(assessment.findings);
  const unresolvedStatus = findings.filter((finding) => !['approved', 'rejected'].includes(normalizeStatus(finding.status))).length;
  const unresolvedContradictions = findings.filter(hasUnresolvedContradiction).length;
  const blockers = [];
  if (!findings.length) blockers.push('No findings have been generated yet.');
  if (unresolvedStatus) blockers.push(`${unresolvedStatus} finding${unresolvedStatus === 1 ? ' has' : 's have'} not been approved or rejected.`);
  if (unresolvedContradictions) blockers.push(`${unresolvedContradictions} contradiction${unresolvedContradictions === 1 ? '' : 's'} require resolution.`);
  return { passed: findings.length > 0 && !unresolvedStatus && !unresolvedContradictions, blockers };
}

function computeRecommendationsGate() {
  const assessment = getSlice('assessment') || {};
  const recommendations = safeArray(assessment.recommendations);
  const unapproved = recommendations.filter((recommendation) => normalizeStatus(recommendation.status) !== 'approved').length;
  const blockers = [];
  if (!recommendations.length) blockers.push('No recommendations have been generated yet.');
  if (unapproved) blockers.push(`${unapproved} recommendation${unapproved === 1 ? ' has' : 's have'} not been approved.`);
  return { passed: recommendations.length > 0 && !unapproved, blockers };
}

function gateStatus() {
  const setup = computeSetupGate();
  const collection = computeCollectionGate();
  const review = computeReviewGate();
  const recommendations = computeRecommendationsGate();
  return {
    setupPassed: setup.passed,
    collectionPassed: collection.passed,
    reviewPassed: review.passed,
    recommendationsPassed: recommendations.passed,
    setupBlockers: setup.blockers,
    collectionBlockers: collection.blockers,
    reviewBlockers: review.blockers,
    recommendationsBlockers: recommendations.blockers
  };
}

function stageAccessible(stageId, gates = gateStatus()) {
  if (['setup', 'collection', 'review'].includes(stageId)) return true;
  if (stageId === 'recommendations') return gates.reviewPassed;
  if (stageId === 'deliver') return gates.recommendationsPassed;
  return false;
}

function stageStatus(stageId, gates = gateStatus()) {
  if (stageId === consultantState.activeStage) return 'current';
  if (stageId === 'setup' && gates.setupPassed) return 'complete';
  if (stageId === 'collection' && gates.collectionPassed) return 'complete';
  if (stageId === 'review' && gates.reviewPassed) return 'complete';
  if (stageId === 'recommendations' && gates.recommendationsPassed) return 'complete';
  if (!stageAccessible(stageId, gates)) return 'locked';
  return 'available';
}

function stageIcon(status) {
  if (status === 'complete') return '✓';
  if (status === 'current') return '●';
  if (status === 'locked') return '🔒';
  return '○';
}

function stageBlockers(stageId, gates = gateStatus()) {
  if (stageId === 'recommendations') return gates.reviewBlockers;
  if (stageId === 'deliver') return gates.recommendationsBlockers;
  return [];
}

function inferStage(engagement = {}, gates = gateStatus()) {
  const raw = normalizeStatus(engagement.stage || engagement.current_stage || engagement.lifecycle_stage);
  if (raw.includes('deliver') || raw.includes('executive')) return 'deliver';
  if (raw.includes('recommend')) return 'recommendations';
  if (raw.includes('review')) return 'review';
  if (raw.includes('collect')) return 'collection';
  if (raw.includes('setup')) return 'setup';
  if (!gates.setupPassed) return 'setup';
  if (!gates.collectionPassed) return 'collection';
  if (!gates.reviewPassed) return 'review';
  if (!gates.recommendationsPassed) return 'recommendations';
  return 'deliver';
}

function stageLabel(stageId = '') {
  return STAGES.find((stage) => stage.id === stageId)?.label || labelFromId(stageId || 'setup');
}

function statusPill(status = '') {
  const normalized = normalizeStatus(status);
  const label = normalized === 'complete' ? 'Complete'
    : normalized === 'blocked' ? 'Blocked'
    : normalized === 'in_progress' ? 'In progress'
    : normalized === 'not_started' ? 'Not started'
    : labelFromId(status || 'Not started');
  const className = normalized === 'complete' ? 'approved'
    : normalized === 'blocked' ? 'rejected'
    : normalized === 'in_progress' ? 'started'
    : 'not-started';
  return `<span class="status-pill ${className}">${escapeHtml(label)}</span>`;
}

function engagementStatus(stageId, gates = gateStatus()) {
  if (stageId === 'setup') return gates.setupPassed ? 'complete' : 'in_progress';
  if (stageId === 'collection') return gates.collectionPassed ? 'complete' : 'in_progress';
  if (stageId === 'review') return gates.reviewPassed ? 'complete' : 'blocked';
  if (stageId === 'recommendations') return gates.recommendationsPassed ? 'complete' : 'blocked';
  if (stageId === 'deliver') return gates.recommendationsPassed ? 'in_progress' : 'blocked';
  return 'not_started';
}

function nextActionForEngagement(engagement = {}, gates = gateStatus()) {
  const assessment = getSlice('assessment') || {};
  if (!gates.setupPassed) return 'Generate or review the assessment blueprint.';
  if (!gates.collectionPassed) {
    const participants = safeArray(assessment.participants);
    const completed = participants.filter((participant) => normalizeStatus(participant.status) === 'completed').length;
    return `${completed} of ${participants.length || 0} participants have responded.`;
  }
  if (!gates.reviewPassed) return gates.reviewBlockers[0] || 'Review findings before recommendations.';
  if (!gates.recommendationsPassed) return gates.recommendationsBlockers[0] || 'Approve recommendations before delivery.';
  return engagement.next_action || 'Ready to generate executive report.';
}

function engagementsFromStore() {
  const platform = getSlice('platform') || {};
  const consultant = getSlice('consultant') || {};
  const command = consultant.commandCenterState || {};
  const candidates = safeArray(command.organizations)
    .concat(safeArray(command.assigned_organizations))
    .concat(safeArray(command.engagements));
  const source = candidates.length ? candidates : safeArray(platform.projects);
  return source.map((item, index) => ({
    ...item,
    id: item.id || item.project_id || item.organization_id || item.assessment_project_id || item.name || `engagement-${index}`
  }));
}

function setActiveStage(stageId) {
  const gates = gateStatus();
  if (!stageAccessible(stageId, gates)) {
    consultantState.stageLockMessage = {
      stageId,
      blockers: stageBlockers(stageId, gates)
    };
    renderConsultantView(consultantState.activeStage || 'review');
    return;
  }
  consultantState.stageLockMessage = null;
  consultantState.activeStage = stageId;
  consultantState.activeView = stageId;
  renderConsultantView(stageId);
}

function openEngagement(engagementId) {
  consultantState.activeEngagementId = engagementId;
  const engagement = engagementsFromStore().find((item) => String(item.id) === String(engagementId)) || {};
  consultantState.activeStage = inferStage(engagement);
  consultantState.activeView = consultantState.activeStage;
  renderConsultantShell(consultantContainer);
  renderConsultantView(consultantState.activeStage);
  bootstrapEngagementContext(engagement);
  bootstrapEngagementAssessment(engagement);
}

function callbacks() {
  return consultantCallbacks || {};
}

function updateViewContainer(html) {
  if (!consultantViewContainer && consultantContainer) {
    consultantViewContainer = consultantContainer.querySelector('#consultant-surface-view');
  }
  if (consultantViewContainer) consultantViewContainer.innerHTML = html;
}

function invitationSentCount(result, fallback = null) {
  if (!result || typeof result !== 'object') return fallback;
  const candidates = [
    result.sent,
    result.sent_count,
    result.invitationSummary?.sent,
    result.summary?.sent,
    result.email_status === 'sent' ? 1 : null,
    result.status === 'sent' ? 1 : null
  ];
  const count = candidates.find((value) => Number.isFinite(Number(value)));
  return count === undefined || count === null ? fallback : Number(count);
}

function clearInvitationSendMessageAfterDelay() {
  if (invitationSendMessageTimer) clearTimeout(invitationSendMessageTimer);
  invitationSendMessageTimer = setTimeout(() => {
    consultantState.invitationSendState = {
      status: 'idle',
      message: '',
      count: null
    };
    if (consultantState.activeView === 'collection') renderConsultantView('collection');
  }, 5000);
}

function renderInvitationSendStatus() {
  const state = consultantState.invitationSendState || {};
  if (!state.status || state.status === 'idle') return '';
  const isSending = state.status === 'sending';
  const isSuccess = state.status === 'success';
  const color = isSending ? 'var(--color-accent)'
    : isSuccess ? 'var(--color-success)'
      : 'var(--color-danger)';
  const background = isSuccess ? 'rgba(107,184,138,0.08)'
    : isSending ? 'rgba(200,169,110,0.08)'
      : 'rgba(224,123,90,0.08)';
  const border = isSuccess ? 'rgba(107,184,138,0.3)'
    : isSending ? 'rgba(200,169,110,0.3)'
      : 'rgba(224,123,90,0.3)';
  const countLine = isSuccess && Number.isFinite(Number(state.count))
    ? `<span style="display:block;color:var(--color-text-muted);font-size:12px;margin-top:4px;">${Number(state.count)} invitation${Number(state.count) === 1 ? '' : 's'} sent</span>`
    : '';
  return `
    <article class="consultant-invitation-send-status" style="margin-top:-10px;margin-bottom:16px;background:${background};border:0.5px solid ${border};border-radius:var(--radius-md);padding:12px 14px;color:${color};font-size:13px;">
      <strong>${escapeHtml(state.message || (isSending ? 'Sending invitations...' : isSuccess ? 'Invitations sent successfully.' : 'Failed to send invitations. Please try again.'))}</strong>
      ${countLine}
    </article>
  `;
}

function applyInvitationSendingState(html) {
  if (consultantState.invitationSendState?.status !== 'sending') return html;
  return html.replace(
    'data-component-send-bulk-invitations type="button">Send Invitations</button>',
    'data-component-send-bulk-invitations type="button" disabled>Sending...</button>'
  );
}

async function handleConsultantSendInvitation(idOrScope, button = null) {
  const sendInvite = callbacks().onSendInvite;
  if (!sendInvite || consultantState.invitationSendState?.status === 'sending') return;

  if (button) {
    button.disabled = true;
    button.dataset.originalText = button.textContent || 'Send Invitations';
    button.textContent = 'Sending...';
  }

  consultantState.invitationSendState = {
    status: 'sending',
    message: 'Sending invitations...',
    count: null
  };
  renderConsultantView('collection');

  try {
    const result = await sendInvite(idOrScope);
    const fallback = idOrScope && idOrScope !== consultantState.invitationScope ? 1 : null;
    const count = invitationSentCount(result, fallback);
    consultantState.invitationSendState = {
      status: 'success',
      message: 'Invitations sent successfully.',
      count
    };
    renderConsultantView('collection');
    clearInvitationSendMessageAfterDelay();
  } catch (error) {
    consultantState.invitationSendState = {
      status: 'error',
      message: 'Failed to send invitations. Please try again.',
      count: null
    };
    renderConsultantView('collection');
    clearInvitationSendMessageAfterDelay();
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = button.dataset.originalText || 'Send Invitations';
    }
  }
}

function wireConsultantShell(container) {
  if (container.dataset.consultantShellWired === 'true') return;
  container.dataset.consultantShellWired = 'true';

  container.addEventListener('click', (event) => {
    const closeProgress = event.target.closest('[data-progress-panel-close]');
    if (closeProgress) {
      closeProgressPanel();
      return;
    }
    const progressOpen = event.target.closest('[data-consultant-progress-open]');
    if (progressOpen) {
      openProgressPanel(progressOpen.dataset.consultantProgressOpen);
      return;
    }
    const engagementButton = event.target.closest('[data-consultant-engagement]');
    if (engagementButton) {
      openEngagement(engagementButton.dataset.consultantEngagement);
      return;
    }

    if (event.target.closest('[data-consultant-logout]')) {
      handleLogout();
      return;
    }

    const stageButton = event.target.closest('[data-consultant-stage]');
    if (stageButton) {
      setActiveStage(stageButton.dataset.consultantStage);
      return;
    }

    const backButton = event.target.closest('[data-consultant-back]');
    if (backButton) {
      consultantState.activeEngagementId = null;
      consultantState.activeStage = null;
      consultantState.activeView = 'engagements';
      renderConsultantShell(container);
      renderConsultantView('engagements');
      return;
    }

    const resolveButton = event.target.closest('[data-consultant-resolve]');
    if (resolveButton) {
      consultantState.activeResolutionFindingId = resolveButton.dataset.consultantResolve;
      renderConsultantView('review');
      return;
    }

    const confirmResolution = event.target.closest('[data-consultant-confirm-resolution]');
    if (confirmResolution) {
      const findingId = confirmResolution.dataset.consultantConfirmResolution;
      const input = container.querySelector(`[data-consultant-resolution-input="${CSS.escape(findingId)}"]`);
      const resolution = String(input?.value || '').trim();
      if (resolution.length < 20) {
        const error = container.querySelector(`[data-consultant-resolution-error="${CSS.escape(findingId)}"]`);
        if (error) error.textContent = 'Resolution must be at least 20 characters.';
        return;
      }
      consultantState.contradictionResolutions[findingId] = { resolution, resolvedAt: Date.now() };
      consultantState.activeResolutionFindingId = null;
      renderConsultantView('review');
      return;
    }

    const findingAction = event.target.closest('[data-component-finding-action]');
    if (findingAction) {
      const findingId = findingAction.dataset.findingId;
      const action = findingAction.dataset.componentFindingAction;
      if (action === 'approve') patchConsultantFindingStatus(findingId, 'Approved');
      if (action === 'reject') patchConsultantFindingStatus(findingId, 'Rejected');
      if (action === 'draft') patchConsultantFindingStatus(findingId, 'Draft');
      if (action === 'edit') callbacks().onEditFinding?.(findingId);
      if (action === 'notes') callbacks().onFindingNotes?.(findingId);
      return;
    }

    const selectFinding = event.target.closest('[data-component-select-finding]');
    if (selectFinding) {
      event.preventDefault();
      const list = container.querySelector('.consultant-review-finding-list');
      const scrollTop = list?.scrollTop || 0;
      consultantState.selectedFindingId = selectFinding.dataset.componentSelectFinding;
      renderConsultantView(consultantState.activeView);
      requestAnimationFrame(() => {
        const updatedList = container.querySelector('.consultant-review-finding-list');
        if (updatedList) updatedList.scrollTop = scrollTop;
      });
      return;
    }

    const mergeSelected = event.target.closest('[data-component-merge-selected-findings]');
    if (mergeSelected) {
      const ids = [...container.querySelectorAll('[data-component-merge-finding]:checked')].map((input) => input.dataset.componentMergeFinding);
      callbacks().onMergeFindings?.(ids);
      return;
    }

    const mergeCluster = event.target.closest('[data-component-merge-cluster]');
    if (mergeCluster) {
      const clusters = safeArray((getSlice('assessment') || {}).clusters);
      callbacks().onMergeCluster?.(clusters[Number(mergeCluster.dataset.componentMergeCluster)]);
      return;
    }

    const recAction = event.target.closest('[data-component-rec-action]');
    if (recAction) {
      const recId = recAction.dataset.recId;
      const action = recAction.dataset.componentRecAction;
      if (action === 'approve') patchConsultantRecommendationStatus(recId, 'Approved');
      if (action === 'reject') patchConsultantRecommendationStatus(recId, 'Rejected');
      if (action === 'draft') patchConsultantRecommendationStatus(recId, 'Draft');
      if (action === 'accept') patchConsultantRecommendationStatus(recId, 'Accepted');
      if (action === 'progress') patchConsultantRecommendationStatus(recId, 'In Progress');
      if (action === 'complete') patchConsultantRecommendationStatus(recId, 'Completed');
      if (action === 'outcome') callbacks().onTrackOutcome?.(recId);
      if (action === 'notes') callbacks().onRecommendationNotes?.(recId);
      return;
    }

    const selectRecommendation = event.target.closest('[data-consultant-select-recommendation]');
    if (selectRecommendation) {
      consultantState.selectedRecommendationId = selectRecommendation.dataset.consultantSelectRecommendation;
      renderConsultantView('recommendations');
      return;
    }

    const participantAction = event.target.closest('[data-component-edit-participant], [data-component-deactivate-participant], [data-component-create-session], [data-component-view-session], [data-component-generate-link], [data-component-copy-link], [data-component-open-link], [data-component-preview-invite], [data-component-send-invite], [data-component-preview-reminder], [data-component-send-reminder]');
    if (participantAction) {
      const d = participantAction.dataset;
      if (d.componentEditParticipant) callbacks().onEditParticipant?.(d.componentEditParticipant);
      if (d.componentDeactivateParticipant) callbacks().onDeactivateParticipant?.(d.componentDeactivateParticipant);
      if (d.componentCreateSession) callbacks().onCreateSession?.(d.componentCreateSession);
      if (d.componentViewSession) callbacks().onViewSession?.(d.componentViewSession);
      if (d.componentGenerateLink) callbacks().onGenerateLink?.(d.componentGenerateLink);
      if (d.componentCopyLink) callbacks().onCopyLink?.(participantAction.dataset.link || '');
      if (d.componentOpenLink) callbacks().onViewSession?.(d.componentOpenLink);
      if (d.componentPreviewInvite) callbacks().onPreviewInvite?.(d.componentPreviewInvite);
      if (d.componentSendInvite) handleConsultantSendInvitation(d.componentSendInvite, participantAction);
      if (d.componentPreviewReminder) callbacks().onPreviewReminder?.(d.componentPreviewReminder);
      if (d.componentSendReminder) callbacks().onSendReminder?.(d.componentSendReminder);
      return;
    }

    if (event.target.closest('[data-component-download-template]')) callbacks().onDownloadTemplate?.();
    if (event.target.closest('[data-component-preview-upload]')) callbacks().onPreviewUpload?.();
    if (event.target.closest('[data-component-confirm-import]')) callbacks().onConfirmImport?.();
    if (event.target.closest('[data-component-download-errors]')) callbacks().onDownloadErrors?.();
    if (event.target.closest('[data-component-create-uploaded-sessions]')) callbacks().onCreateSessionsForImported?.();
    const bulkInvitationsButton = event.target.closest('[data-component-send-bulk-invitations]');
    if (bulkInvitationsButton) handleConsultantSendInvitation(consultantState.invitationScope, bulkInvitationsButton);
    if (event.target.closest('[data-component-send-bulk-reminders]')) callbacks().onSendReminder?.(consultantState.reminderScope);
    if (event.target.closest('[data-progress-action="generate"]')) callbacks().onGenerateSnapshot?.();
    if (event.target.closest('[data-progress-action="regenerate"]')) callbacks().onRegenerateSnapshot?.();
    if (event.target.closest('[data-consultant-generate-report]')) callbacks().onGenerateReport?.();
    if (event.target.closest('[data-consultant-mark-delivered]')) callbacks().onMarkDelivered?.();

    const reportAction = event.target.closest('[data-component-report-action]');
    if (reportAction) {
      const action = reportAction.dataset.componentReportAction;
      if (action === 'generate') callbacks().onGenerateReport?.();
      if (action === 'print') callbacks().onPrint?.() || window.print?.();
      if (action === 'export') callbacks().onExportReport?.();
    }

    const reportNav = event.target.closest('[data-component-report-nav]');
    if (reportNav) {
      container.querySelector(`#report-${reportNav.dataset.componentReportNav}`)?.scrollIntoView?.({ behavior: 'smooth', block: 'start' });
    }

    const heatmapCell = event.target.closest('[data-component-heatmap-cell]');
    if (heatmapCell) {
      consultantState.filterState.selectedHeatmapCellKey = heatmapCell.dataset.componentHeatmapCell;
      renderConsultantView(consultantState.activeView);
    }
  });

  container.addEventListener('submit', (event) => {
    const form = event.target.closest('[data-component-participant-form]');
    if (!form) return;
    event.preventDefault();
    callbacks().onAddParticipant?.(Object.fromEntries(new FormData(form).entries()));
  });

  container.addEventListener('change', (event) => {
    const kpiTracking = event.target.closest('[data-component-kpi-tracking]');
    if (kpiTracking) {
      const { assessment, organization } = assessmentContext();
      const projectId = projectIdForEngagement(organization)
        || assessment.assessment?.company_id
        || consultantState.activeEngagementId;
      const key = kpiTracking.dataset.componentKpiTracking;
      const checked = kpiTracking.checked;
      saveProjectKpiTracking(projectId, key, checked).then(() => {
        updateLocalKpiTracking(key, checked);
        renderConsultantView(consultantState.activeView || consultantState.activeStage || 'setup');
      }).catch((error) => {
        kpiTracking.checked = !kpiTracking.checked;
        console.error('KPI tracking save failed:', error);
      });
      return;
    }

    const participantFilter = event.target.closest('[data-component-participant-filter]');
    if (participantFilter) {
      const key = participantFilter.dataset.componentParticipantFilter;
      consultantState.filterState[key] = participantFilter.value || null;
      renderConsultantView('collection');
      return;
    }

    const uploadFile = event.target.closest('[data-component-upload-file]');
    if (uploadFile) {
      callbacks().onFileSelected?.(uploadFile.files?.[0] || null);
      return;
    }

    const invitationScope = event.target.closest('[data-component-invitation-scope]');
    if (invitationScope) {
      consultantState.invitationScope = invitationScope.value;
      callbacks().onScopeChange?.('invitation', invitationScope.value);
      return;
    }

    const reminderScope = event.target.closest('[data-component-reminder-scope]');
    if (reminderScope) {
      consultantState.reminderScope = reminderScope.value;
      callbacks().onScopeChange?.('reminder', reminderScope.value);
      return;
    }

    const heatmapFilter = event.target.closest('[data-component-heatmap-filter]');
    if (heatmapFilter) {
      const key = heatmapFilter.dataset.componentHeatmapFilter;
      if (key === 'domain') consultantState.filterState.heatmapDomain = heatmapFilter.value || null;
      if (key === 'group') consultantState.filterState.heatmapGroup = heatmapFilter.value || null;
      if (key === 'min-priority') consultantState.filterState.heatmapMinPriority = heatmapFilter.value || null;
      if (key === 'misalignment') consultantState.filterState.onlyMisalignment = Boolean(heatmapFilter.checked);
      if (key === 'high-confidence') consultantState.filterState.onlyHighConfidence = Boolean(heatmapFilter.checked);
      renderConsultantView(consultantState.activeView);
      return;
    }

    const reportToggle = event.target.closest('[data-component-report-toggle]');
    if (reportToggle) {
      const key = reportToggle.dataset.componentReportToggle === 'evidence' ? 'showEvidence' : 'showAppendix';
      consultantState.reportToggles[key] = Boolean(reportToggle.checked);
      callbacks().onToggleReportSection?.(key, Boolean(reportToggle.checked));
      renderConsultantView('deliver');
    }
  });
}

export function initConsultantSurface(container, callbacks = {}) {
  consultantContainer = container;
  consultantCallbacks = callbacks || {};
  renderConsultantShell(container);
  wireConsultantShell(container);
  const consultant = getSlice('consultant') || {};
  if (!consultant.commandCenterState) {
    updateViewContainer(renderLoadingSkeleton('Loading engagements', 3));
    fetch('/api/consultant-command-center', { headers: authHeaders() })
      .then((response) => response.json())
      .then((data) => {
        if (data && !data.error) {
          mergeState('consultant', {
            commandCenterState: data,
            commandCenterError: null
          });
        } else {
          mergeState('consultant', {
            commandCenterError: data?.error || 'Failed to load engagements.'
          });
        }
        renderConsultantView('engagements');
      })
      .catch((error) => {
        mergeState('consultant', {
          commandCenterError: error.message || 'Failed to load engagements.'
        });
        renderConsultantView('engagements');
      });
    return;
  }
  renderConsultantView('engagements');
}

export function renderConsultantShell(container) {
  consultantContainer = container;
  const context = assessmentContext() || {};
  const assessment = context.assessment || {};
  const organization = context.organization || {};
  const activeProjectId = projectIdForEngagement(organization) || consultantState.activeEngagementId || '';
  const progressData = activeProjectId
    ? consultantState.progressIntelligenceByProject[activeProjectId] || null
    : null;
  const healthSnapshots = progressData?.snapshots?.length
    ? progressData.snapshots
    : snapshotsFromProgressMemory(assessment?.progressMemory || {});
  if (!consultantState.activeEngagementId) {
    container.innerHTML = `
      <section class="consultant-surface-shell consultant-surface-shell--list">
        <div style="display: flex; justify-content: flex-end; padding: 24px 36px 0;">
          <button class="text-button" data-consultant-logout type="button" style="color: var(--color-text-muted);">
            <i class="ti ti-logout" aria-hidden="true"></i>
            <span>Sign out</span>
          </button>
        </div>
        <main class="consultant-surface-view" id="consultant-surface-view"></main>
      </section>
    `;
  } else {
    container.innerHTML = `
      <section class="consultant-surface-shell consultant-surface-shell--workspace">
        <aside class="consultant-sidebar">
          <div class="consultant-wordmark">
            Derive <span class="consultant-wordmark-sub">intelligence</span>
          </div>
          <button class="text-button consultant-back-button" data-consultant-back type="button">Back to engagements</button>
          <div class="consultant-sidebar-context">
            <div>
              <span class="eyebrow">Organization</span>
              <strong>${escapeHtml(organizationName(organization))}</strong>
              ${healthSnapshots.length ? `<button class="health-pill-button" data-consultant-progress-open="${escapeHtml(activeProjectId)}" type="button">${renderHealthPill(healthSnapshots)}</button>` : ''}
            </div>
            <div><span class="eyebrow">Assessment</span><strong>${escapeHtml(assessmentName(organization, assessment))}</strong></div>
            <div><span class="eyebrow">Framework</span><strong>${escapeHtml(frameworkName(organization, assessment))}</strong></div>
            <div><span class="eyebrow">Assessment Date</span><strong>${escapeHtml(assessmentDate(organization, assessment))}</strong></div>
          </div>
          ${renderStageNav(consultantState.activeStage || 'setup')}
          <div class="consultant-logout-block" style="margin-top: auto; border-top: 0.5px solid var(--color-border); padding: 12px 10px;">
            <button class="nav-item consultant-logout-button" data-consultant-logout type="button" style="color: var(--color-text-muted);">
              <i class="ti ti-logout" aria-hidden="true"></i>
              <span>Sign out</span>
            </button>
          </div>
        </aside>
        <main class="consultant-main">
          <div class="consultant-surface-view" id="consultant-surface-view"></div>
        </main>
      </section>
    `;
  }
  consultantViewContainer = container.querySelector('#consultant-surface-view');
}

export function renderConsultantView(viewId) {
  consultantState.activeView = viewId;
  window.__consultantState = {
    activeView: consultantState.activeView,
    activeStage: consultantState.activeStage,
    activeEngagementId: consultantState.activeEngagementId
  };
  if (!consultantViewContainer && consultantContainer) {
    consultantViewContainer = consultantContainer.querySelector('#consultant-surface-view');
  }
  if (!consultantViewContainer) return;

  if (viewId === 'engagements') {
    renderConsultantEngagementList();
    return;
  }

  if (consultantState.activeStage !== viewId && STAGES.some((stage) => stage.id === viewId)) {
    consultantState.activeStage = viewId;
  }

  consultantContainer.querySelector('.consultant-stage-nav')?.replaceWith(
    document.createRange().createContextualFragment(renderStageNav(consultantState.activeStage || viewId)).firstElementChild
  );

  switch (viewId) {
    case 'setup':
      renderConsultantSetup();
      break;
    case 'collection':
      renderConsultantCollection();
      break;
    case 'review':
      renderConsultantReview();
      break;
    case 'recommendations':
      renderConsultantRecommendations();
      break;
    case 'deliver':
      renderConsultantDeliver();
      break;
    default:
      renderConsultantEngagementList();
  }
}

function renderStageNav(currentStage) {
  const gates = gateStatus();
  return `
    <nav class="consultant-stage-nav" aria-label="Consultant workflow stages">
      ${STAGES.map((stage) => {
        const status = stageStatus(stage.id, gates);
        const accessible = stageAccessible(stage.id, gates);
        return `
          <button class="consultant-stage-button ${status}" data-consultant-stage="${escapeHtml(stage.id)}" type="button" ${accessible ? '' : 'aria-disabled="true"'}>
            <span>${stageIcon(status)}</span>
            <strong>${escapeHtml(stage.label)}</strong>
          </button>
        `;
      }).join('')}
    </nav>
  `;
}

function renderStageLockMessage() {
  const lock = consultantState.stageLockMessage;
  if (!lock) return '';
  return `
    <article class="warning-banner consultant-gate-banner">
      <strong>Complete the previous stage before proceeding to ${escapeHtml(stageLabel(lock.stageId))}.</strong>
      <ul>${safeArray(lock.blockers).map((blocker) => `<li>${escapeHtml(blocker)}</li>`).join('')}</ul>
    </article>
  `;
}

function renderConsultantEngagementList() {
  const engagements = engagementsFromStore();
  const gates = gateStatus();
  if (!engagements.length) {
    updateViewContainer(emptyState('No active engagements.', 'Contact your platform administrator to be assigned to an organization.'));
    return;
  }
  updateViewContainer(`
    <section class="consultant-engagement-list">
      <div class="owner-section-head">
        <div>
          <span class="eyebrow">Consultant Command Center</span>
          <h2>Assigned engagements</h2>
          <p>Open the engagement that needs review, recommendation approval, or delivery preparation.</p>
        </div>
      </div>
      <div class="card-grid consultant-engagement-grid">
        ${engagements.map((engagement) => {
          const stageId = inferStage(engagement, gates);
          const status = normalizeStatus(engagement.status || engagementStatus(stageId, gates));
          return `
            <article class="insight-card consultant-engagement-card">
              <div class="owner-section-head">
                <div>
                  <span class="eyebrow">${escapeHtml(frameworkName(engagement))}</span>
                  <h3>${escapeHtml(organizationName(engagement))}</h3>
                </div>
                ${statusPill(status)}
              </div>
              <p><strong>${escapeHtml(assessmentName(engagement))}</strong></p>
              <div class="recommendation-meta">
                <span>Stage: <strong>${escapeHtml(stageLabel(stageId))}</strong></span>
                <span>Status: <strong>${escapeHtml(labelFromId(status))}</strong></span>
              </div>
              <p>${escapeHtml(nextActionForEngagement(engagement, gates))}</p>
              <button class="primary-button" data-consultant-engagement="${escapeHtml(engagement.id)}" type="button">Open</button>
            </article>
          `;
        }).join('')}
      </div>
    </section>
  `);
}

function renderConsultantSetup() {
  const { assessment, organization } = assessmentContext();
  const { profile, intake, context } = organizationProfileData(organization, assessment);
  const projectId = firstValue(
    organization.id,
    organization.project_id,
    organization.assessment_project_id,
    assessment.assessment?.company_id,
    profile.assessmentProjectId,
    profile.assessment_project_id,
    consultantState.activeEngagementId
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
    organizationName(organization)
  );
  const industry = formatLabelValue(firstValue(
    profile.industry,
    context.industry,
    organization.industry_context,
    assessment.blueprint?.industry,
    assessment.blueprint?.company_profile?.industry
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
  updateViewContainer(`
    ${renderStageLockMessage()}
    <section class="consultant-stage consultant-setup-stage">
      <div class="owner-section-head">
        <div><span class="eyebrow">Setup</span><h2>Engagement foundation</h2><p>Review the complete company intake before collection scales.</p></div>
      </div>
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
  `);
}

function renderConsultantCollection() {
  const assessment = getSlice('assessment') || {};
  const filters = {
    group: consultantState.filterState.group,
    role: consultantState.filterState.role,
    status: consultantState.filterState.status
  };
  const liveSummary = {
    incomplete_participants: safeArray(assessment.participants).filter((participant) => !['completed', 'deactivated'].includes(normalizeStatus(participant.status))).length,
    overdue_participants: safeArray(assessment.participants).filter((participant) => participant.overdue).length,
    reminders_sent: safeArray(assessment.participants).reduce((sum, participant) => sum + Number(participant.reminder_count || 0), 0),
    not_started_after_invite: safeArray(assessment.participants).filter((participant) => normalizeStatus(participant.status) === 'invited').length,
    started_but_not_completed: safeArray(assessment.participants).filter((participant) => normalizeStatus(participant.status) === 'started').length
  };
  const invitationPanelHtml = applyInvitationSendingState(renderInvitationPanelComponent(
    assessment.invitationSummary,
    assessment.invitationPreview,
    { onBulkSend: callbacks().onSendInvite, onScopeChange: true }
  ));
  updateViewContainer(`
    ${renderStageLockMessage()}
    <section class="consultant-stage consultant-collection-stage">
      <div class="owner-section-head"><div><span class="eyebrow">Collection</span><h2>Participant completion and communication</h2><p>Keep the assessment moving by managing coverage, sessions, links, invitations, and reminders.</p></div></div>
      ${renderParticipantsSectionComponent(
        { id: assessment.activeAssessmentId || assessment.assessment?.id || 'assessment' },
        assessment.participants || [],
        assessment.coverage || {},
        filters,
        assessment.participantAccessLinks || {},
        roleOptionsFromCoverage(assessment.coverage || {}),
        emptyState('Add participants manually or upload a stakeholder list to launch the assessment.'),
        {
          onAddParticipant: callbacks().onAddParticipant,
          onEdit: callbacks().onEditParticipant,
          onDeactivate: callbacks().onDeactivateParticipant,
          onCreateSession: callbacks().onCreateSession,
          onViewSession: callbacks().onViewSession,
          onGenerateLink: callbacks().onGenerateLink,
          onCopyLink: callbacks().onCopyLink,
          onOpenLink: callbacks().onViewSession,
          onPreviewInvite: callbacks().onPreviewInvite,
          onSendInvite: callbacks().onSendInvite,
          onPreviewReminder: callbacks().onPreviewReminder,
          onSendReminder: callbacks().onSendReminder,
          onFilterChange: true
        }
      )}
      ${renderParticipantUploadPanelComponent(
        assessment.uploadPreview,
        assessment.importSummary,
        emptyState('Upload a stakeholder list when manual entry would slow the assessment down.'),
        {
          onDownloadTemplate: callbacks().onDownloadTemplate,
          onPreviewUpload: callbacks().onPreviewUpload,
          onConfirmImport: callbacks().onConfirmImport,
          onDownloadErrors: callbacks().onDownloadErrors,
          onCreateSessionsForImported: callbacks().onCreateSessionsForImported,
          onFileSelected: callbacks().onFileSelected
        }
      )}
      ${invitationPanelHtml}
      ${renderInvitationSendStatus()}
      ${renderReminderPanelComponent(assessment.participants || [], assessment.reminderSummary, assessment.reminderPreview, liveSummary, { onBulkSend: callbacks().onSendReminder, onScopeChange: true })}
    </section>
  `);
}

function renderContradictionBanner(findings = []) {
  const unresolved = findings.filter(hasUnresolvedContradiction);
  if (!unresolved.length) return '';
  return `
    <article class="warning-banner consultant-contradiction-banner">
      <strong>${unresolved.length} finding${unresolved.length === 1 ? '' : 's'} with unresolved contradictions</strong>
      <p>Resolution required before proceeding to recommendations.</p>
      ${unresolved.map((finding) => `
        <div class="consultant-contradiction-item">
          <h4>${escapeHtml(finding.title)}</h4>
          ${visibleContradictions(finding).map((contradiction) => `<p>${escapeHtml(contradiction.description || contradiction.summary || 'Contradiction detected.')}</p>`).join('')}
          <button class="ghost-button" data-consultant-resolve="${escapeHtml(finding.id)}" type="button">Resolve</button>
          ${consultantState.activeResolutionFindingId === finding.id ? `
            <div class="consultant-resolution-panel">
              <label>How was this resolved?
                <textarea data-consultant-resolution-input="${escapeHtml(finding.id)}" placeholder="Describe how you interpreted this contradiction and which account was used in the finding..." rows="3"></textarea>
              </label>
              <small data-consultant-resolution-error="${escapeHtml(finding.id)}"></small>
              <button class="primary-button" data-consultant-confirm-resolution="${escapeHtml(finding.id)}" type="button">Confirm Resolution</button>
            </div>
          ` : ''}
        </div>
      `).join('')}
    </article>
  `;
}

function renderGateStatus(title, gate, successMessage) {
  return gate.passed
    ? `<article class="success-banner consultant-gate-status"><strong>${escapeHtml(successMessage)}</strong></article>`
    : `<article class="warning-banner consultant-gate-status"><strong>${escapeHtml(title)}</strong><ul>${gate.blockers.map((blocker) => `<li>${escapeHtml(blocker)}</li>`).join('')}</ul></article>`;
}

function reviewStatus(value = '') {
  return String(value || 'Draft').toLowerCase();
}

function reviewStatusLabel(value = '') {
  const status = reviewStatus(value);
  if (status === 'approved') return 'Approved';
  if (status === 'rejected') return 'Rejected';
  return 'Pending';
}

function reviewStatusIcon(value = '') {
  const status = reviewStatus(value);
  if (status === 'approved') return '✓';
  if (status === 'rejected') return '✗';
  return '○';
}

function problemTypeList(finding = {}) {
  const value = finding.problem_types || finding.problemTypes || [];
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

function selectedEvidenceForFinding(finding = {}, evidence = []) {
  return safeArray(evidence).filter((item) => String(item.finding_id || item.findingId) === String(finding.id));
}

function renderConsultantFindingRows(findings = [], selectedFindingId = '') {
  return `
    <div class="consultant-review-finding-list" role="list">
      ${safeArray(findings).map((finding) => {
        const status = reviewStatus(finding.status);
        const selected = String(finding.id) === String(selectedFindingId);
        return `
          <article class="consultant-review-finding-row ${selected ? 'selected' : ''} ${status === 'approved' ? 'approved' : ''} ${status === 'rejected' ? 'rejected' : ''}" role="listitem">
            <input type="checkbox" aria-label="Select finding for merge" data-component-merge-finding="${escapeHtml(finding.id)}" ${selected ? 'disabled' : ''} />
            <button class="consultant-review-finding-select" data-component-select-finding="${escapeHtml(finding.id)}" type="button">
              <strong>${escapeHtml(finding.title || 'Untitled finding')}</strong>
              <span class="consultant-review-finding-meta">
                <span class="mini-chip">${escapeHtml(finding.business_domain || 'Domain')}</span>
                <span class="mini-chip">${escapeHtml(finding.assessment_category || 'Category')}</span>
              </span>
              <span class="consultant-review-finding-status ${status === 'approved' ? 'approved' : status === 'rejected' ? 'rejected' : 'pending'}">
                ${reviewStatusIcon(finding.status)} ${escapeHtml(reviewStatusLabel(finding.status))}
              </span>
            </button>
          </article>
        `;
      }).join('')}
    </div>
  `;
}

function renderConsultantFindingDetail(finding, evidence = []) {
  if (!finding) {
    return `
      <div class="consultant-review-empty-detail">
        <strong>Select a finding from the list</strong>
        <p>Select a finding from the list to review its evidence and make a decision.</p>
      </div>
    `;
  }
  const status = reviewStatus(finding.status);
  const isApproved = status === 'approved';
  const isRejected = status === 'rejected';
  const evidenceItems = selectedEvidenceForFinding(finding, evidence);
  const primaryEvidence = evidenceItems[0] || {};
  const problemTypes = problemTypeList(finding);
  return `
    <article class="consultant-review-detail">
      <header>
        <div>
          <h3>${escapeHtml(finding.title || 'Untitled finding')}</h3>
          <p>${escapeHtml(finding.business_domain || 'Domain')} · ${escapeHtml(finding.assessment_category || 'Category')} · Severity ${escapeHtml(finding.severity ?? '-')}</p>
        </div>
        <span class="status-pill ${isApproved ? 'approved' : isRejected ? 'rejected' : 'draft'}">${escapeHtml(reviewStatusLabel(finding.status))}</span>
      </header>
      <section class="consultant-review-detail-section">
        <h4>Supporting evidence</h4>
        <article class="consultant-review-evidence-card">
          <span>${escapeHtml(primaryEvidence.evidence_type || 'Evidence')}</span>
          <strong>${escapeHtml(primaryEvidence.source_question || finding.source_question || 'Source question unavailable')}</strong>
          <p>${escapeHtml(primaryEvidence.source_response || primaryEvidence.response_value || finding.description || 'No source response text available.')}</p>
          <small>Trigger rule: ${escapeHtml(primaryEvidence.trigger_rule || finding.trigger_rule || 'rule_based_analysis')}</small>
        </article>
        ${evidenceItems.length > 1 ? `<small class="muted-text">${evidenceItems.length - 1} additional evidence records attached.</small>` : ''}
      </section>
      <section class="consultant-review-detail-section">
        <h4>Problem types</h4>
        <div class="chip-list">
          ${problemTypes.map((type) => `<span class="mini-chip">${escapeHtml(labelFromId(type))}</span>`).join('') || '<span class="mini-chip">No problem types tagged</span>'}
        </div>
      </section>
      <div class="consultant-review-score-grid">
        <article><span>Confidence score</span><strong>${escapeHtml(finding.confidence ?? '-')}/5</strong></article>
        <article><span>Agreement score</span><strong>${escapeHtml(finding.overall_stakeholder_agreement_score || finding.stakeholder_agreement_score || 1)}/5</strong></article>
      </div>
      <label class="consultant-review-notes">
        Review notes
        <textarea rows="4" placeholder="Add review notes..." data-component-finding-notes-input="${escapeHtml(finding.id)}">${escapeHtml(finding.analyst_notes || finding.notes || '')}</textarea>
      </label>
      <div class="consultant-review-actions">
        ${isApproved ? `
          <div class="consultant-review-decision-state approved"><strong>Approved</strong><span>This finding is approved for recommendations.</span></div>
          <button class="text-button" data-component-finding-action="draft" data-finding-id="${escapeHtml(finding.id)}" type="button">Undo</button>
        ` : isRejected ? `
          <div class="consultant-review-decision-state rejected"><strong>Rejected</strong><span>This finding will not unlock recommendations.</span></div>
          <button class="text-button" data-component-finding-action="draft" data-finding-id="${escapeHtml(finding.id)}" type="button">Undo</button>
        ` : `
          <button class="consultant-review-approve" data-component-finding-action="approve" data-finding-id="${escapeHtml(finding.id)}" type="button">✓ Approve Finding</button>
          <button class="consultant-review-reject" data-component-finding-action="reject" data-finding-id="${escapeHtml(finding.id)}" type="button">✗ Reject Finding</button>
        `}
      </div>
    </article>
  `;
}

function renderConsultantReviewGate(findings = []) {
  const total = safeArray(findings).length;
  const reviewed = safeArray(findings).filter((finding) => ['approved', 'rejected'].includes(reviewStatus(finding.status))).length;
  if (total && reviewed === total) {
    return `<article class="consultant-review-gate passed"><strong>All findings reviewed.</strong><p>Recommendations are now unlocked.</p></article>`;
  }
  return `<article class="consultant-review-gate blocked"><strong>Review gate is blocked</strong><ul><li>${Math.max(total - reviewed, 0)} finding${total - reviewed === 1 ? '' : 's'} still need approval or rejection.</li></ul></article>`;
}

async function patchConsultantFindingStatus(findingId, status) {
  const assessment = getSlice('assessment') || {};
  const originalFindings = safeArray(assessment.findings);
  const optimisticFindings = originalFindings.map((finding) => String(finding.id) === String(findingId) ? { ...finding, status } : finding);
  mergeState('assessment', { findings: optimisticFindings });
  renderConsultantView('review');
  try {
    const response = await fetch(`/api/findings/${encodeURIComponent(findingId)}`, {
      method: 'PATCH',
      headers: {
        ...authHeaders(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ status })
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Finding update failed.');
    const updatedFindings = safeArray((getSlice('assessment') || {}).findings).map((finding) => String(finding.id) === String(findingId) ? { ...finding, ...(data.finding || {}), status: data.finding?.status || status } : finding);
    mergeState('assessment', { findings: updatedFindings });
    sendConsultantFindingFeedback(findingId, status);
  } catch (error) {
    console.error('Consultant finding status update failed:', error);
    mergeState('assessment', { findings: originalFindings });
  }
  renderConsultantView('review');
}

function sendConsultantFindingFeedback(findingId, status) {
  const normalized = normalizeStatus(status);
  if (!['approved', 'rejected'].includes(normalized)) return;
  fetch(`/api/findings/${encodeURIComponent(findingId)}/feedback`, {
    method: 'POST',
    headers: {
      ...authHeaders(),
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({ action: normalized })
  }).catch((error) => {
    console.warn('Finding feedback sync failed:', error);
  });
}

function renderConsultantReview() {
  const assessment = getSlice('assessment') || {};
  const findings = safeArray(assessment.findings);
  const selectedFindingId = consultantState.selectedFindingId || findings[0]?.id || null;
  consultantState.selectedFindingId = selectedFindingId;
  const selectedFinding = findings.find((finding) => String(finding.id) === String(selectedFindingId)) || findings[0] || null;
  const approved = approvedFindings(findings);
  const reviewed = findings.filter((finding) => ['approved', 'rejected'].includes(reviewStatus(finding.status))).length;
  const progress = findings.length ? Math.round((reviewed / findings.length) * 100) : 0;
  updateViewContainer(`
    ${renderStageLockMessage()}
    <section class="consultant-stage consultant-review-stage">
      <section class="consultant-review-header">
        <div class="owner-section-head">
          <div>
            <span class="eyebrow">Review</span>
            <h2>Findings quality gate</h2>
            <p>Review each finding, resolve contradictions, then approve or reject before recommendations unlock.</p>
          </div>
          <button class="primary-button" data-component-merge-selected-findings type="button">Merge Selected Into Active</button>
        </div>
        <div class="consultant-review-progress">
          <span>${reviewed} of ${findings.length} findings reviewed</span>
          <div class="progress-track"><div class="progress-fill" style="width: ${progress}%"></div></div>
        </div>
      </section>
      ${renderContradictionBanner(findings)}
      <section class="consultant-review-workbench">
        ${findings.length ? `
          <aside class="consultant-review-list-column">
            ${renderConsultantFindingRows(findings, selectedFindingId)}
          </aside>
          <div class="consultant-review-detail-column">
            ${renderConsultantFindingDetail(selectedFinding, assessment.evidence || [])}
          </div>
        ` : emptyState('No findings have been generated yet. Run analysis after enough responses are complete.')}
      </section>
      <details class="consultant-review-collapsible">
        <summary><span>Finding clusters (${safeArray(assessment.clusters).length})</span><i>⌄</i></summary>
        <div class="consultant-review-collapsible-body consultant-review-clusters">
          ${renderFindingClustersComponent(assessment.clusters || [], emptyState('No clusters detected yet.'), { onMergeCluster: callbacks().onMergeCluster })}
        </div>
      </details>
      <details class="consultant-review-collapsible">
        <summary><span>Organizational alignment heatmap<small>Expand to see where the organization agrees or disagrees</small></span><i>⌄</i></summary>
        <div class="consultant-review-collapsible-body consultant-review-heatmap-scroll">
          ${renderAlignmentHeatmapComponent(
            approved,
            consultantState.filterState,
            emptyState('Alignment will appear after findings are approved.'),
            {
              onDomainFilterChange: true,
              onGroupFilterChange: true,
              onMinPriorityChange: true,
              onMisalignmentToggle: true,
              onHighConfidenceToggle: true,
              onCellSelect: true,
              onSelectFinding: true
            }
          )}
        </div>
      </details>
      ${renderConsultantReviewGate(findings)}
    </section>
  `);
}

function recommendationStatus(value = '') {
  return String(value || 'Draft').toLowerCase().replace(/\s+/g, '_');
}

function recommendationStatusLabel(value = '') {
  const status = recommendationStatus(value);
  if (status === 'approved') return 'Approved';
  if (status === 'rejected') return 'Rejected';
  if (status === 'in_progress') return 'In progress';
  if (status === 'completed') return 'Completed';
  if (status === 'accepted') return 'Accepted';
  return 'Pending';
}

function recommendationStatusIcon(value = '') {
  const status = recommendationStatus(value);
  if (status === 'approved' || status === 'accepted' || status === 'in_progress' || status === 'completed') return '✓';
  if (status === 'rejected') return '✗';
  return '○';
}

function recommendationPriorityLabel(recommendation = {}) {
  return labelFromId(
    recommendation.roadmap_relevance
    || recommendation.roadmap_phase
    || 'quick_win'
  );
}

function recommendationOwner(recommendation = {}) {
  return recommendation.recommended_owner
    || recommendation.accountable_owner
    || recommendation.owner_role
    || recommendation.responsible_role
    || 'Owner TBD';
}

function recommendationTimeline(recommendation = {}) {
  return recommendation.estimated_timeline
    || recommendation.timeframe
    || recommendation.implementation_timeline
    || recommendation.roadmap_timeline
    || recommendation.roadmap_phase
    || 'Timeline TBD';
}

function renderConsultantRecommendationRows(recommendations = [], selectedRecommendationId = '') {
  return `
    <div class="consultant-rec-list" role="list">
      ${safeArray(recommendations).map((recommendation) => {
        const status = recommendationStatus(recommendation.status);
        const selected = String(recommendation.id) === String(selectedRecommendationId);
        return `
          <article class="consultant-rec-row ${selected ? 'selected' : ''} ${status === 'approved' ? 'approved' : ''} ${status === 'rejected' ? 'rejected' : ''}" role="listitem">
            <button class="consultant-rec-select" data-consultant-select-recommendation="${escapeHtml(recommendation.id)}" type="button">
              <span class="status-pill production">${escapeHtml(recommendationPriorityLabel(recommendation))}</span>
              <strong>${escapeHtml(recommendation.title || 'Untitled recommendation')}</strong>
              <span class="consultant-rec-owner">Owner: ${escapeHtml(recommendationOwner(recommendation))}</span>
              <span class="consultant-rec-status ${status === 'approved' ? 'approved' : status === 'rejected' ? 'rejected' : 'pending'}">
                ${recommendationStatusIcon(recommendation.status)} ${escapeHtml(recommendationStatusLabel(recommendation.status))}
              </span>
            </button>
          </article>
        `;
      }).join('')}
    </div>
  `;
}

function renderConsultantRecommendationDetail(recommendation) {
  if (!recommendation) {
    return `
      <div class="consultant-rec-empty-detail">
        <strong>Select a recommendation to review</strong>
        <p>Choose a recommendation from the list to inspect its outcome, owner, and approval state.</p>
      </div>
    `;
  }
  const status = recommendationStatus(recommendation.status);
  const isApproved = status === 'approved';
  const isRejected = status === 'rejected';
  const impact = recommendation.impact
    || recommendation.expected_benefit
    || recommendation.expected_value
    || recommendation.estimated_business_value
    || 'Impact to be quantified';
  const kpiConfidence = recommendation.kpi_confidence
    || recommendation.kpi_confidence_score
    || recommendation.recommendation_accuracy_score
    || recommendation.confidence
    || 'TBD';
  return `
    <article class="consultant-rec-detail">
      <header>
        <div>
          <h3>${escapeHtml(recommendation.title || 'Untitled recommendation')}</h3>
          <p>${escapeHtml(recommendationPriorityLabel(recommendation))} · ${escapeHtml(labelFromId(recommendation.roadmap_phase || 'Phase TBD'))} · Confidence ${escapeHtml(recommendation.confidence ?? recommendation.recommendation_confidence ?? '-')} · Specificity ${escapeHtml(recommendation.specificity ?? recommendation.specificity_score ?? '-')}</p>
        </div>
        <span class="status-pill ${isApproved ? 'approved' : isRejected ? 'rejected' : 'draft'}">${escapeHtml(recommendationStatusLabel(recommendation.status))}</span>
      </header>
      <p class="consultant-rec-description">${escapeHtml(recommendation.description || recommendation.recommendation || 'No description provided.')}</p>
      <section class="consultant-rec-detail-section">
        <h4>Expected outcome</h4>
        <p>${escapeHtml(recommendation.expected_outcome || recommendation.expectedOutcome || recommendation.expected_benefit || 'Expected outcome has not been captured yet.')}</p>
      </section>
      <div class="consultant-rec-score-grid">
        <article><span>Owner</span><strong>${escapeHtml(recommendationOwner(recommendation))}</strong></article>
        <article><span>Timeline</span><strong>${escapeHtml(recommendationTimeline(recommendation))}</strong></article>
      </div>
      <div class="chip-list">
        <span class="mini-chip">Impact: ${escapeHtml(String(impact))}</span>
        <span class="mini-chip">KPI confidence: ${escapeHtml(String(kpiConfidence))}</span>
      </div>
      <label class="consultant-rec-notes">
        Review notes
        <textarea rows="4" placeholder="Add review notes..." data-component-recommendation-notes-input="${escapeHtml(recommendation.id)}">${escapeHtml(recommendation.analyst_notes || recommendation.notes || '')}</textarea>
      </label>
      <div class="consultant-rec-actions">
        ${isApproved ? `
          <div class="consultant-review-decision-state approved"><strong>Approved</strong><span>This recommendation is approved for delivery.</span></div>
          <button class="text-button" data-component-rec-action="draft" data-rec-id="${escapeHtml(recommendation.id)}" type="button">Undo</button>
        ` : isRejected ? `
          <div class="consultant-review-decision-state rejected"><strong>Rejected</strong><span>This recommendation will not move into delivery.</span></div>
          <button class="text-button" data-component-rec-action="draft" data-rec-id="${escapeHtml(recommendation.id)}" type="button">Undo</button>
        ` : `
          <button class="consultant-rec-approve" data-component-rec-action="approve" data-rec-id="${escapeHtml(recommendation.id)}" type="button">✓ Approve</button>
          <button class="consultant-rec-reject" data-component-rec-action="reject" data-rec-id="${escapeHtml(recommendation.id)}" type="button">✗ Reject</button>
        `}
        <button class="text-button" data-component-rec-action="progress" data-rec-id="${escapeHtml(recommendation.id)}" type="button">Mark In Progress</button>
        <button class="text-button" data-component-rec-action="complete" data-rec-id="${escapeHtml(recommendation.id)}" type="button">Mark Complete</button>
      </div>
    </article>
  `;
}

function renderRoadmapPhases(recommendations = []) {
  const phases = [
    ['Quick Wins', ['quick_win', 'quick wins', 'quick win']],
    ['Foundation', ['foundation']],
    ['Optimization', ['optimization']],
    ['Transformation', ['transformation']]
  ];
  return phases.map(([label, keys]) => {
    const items = safeArray(recommendations).filter((recommendation) => {
      const value = recommendationStatus(recommendation.roadmap_phase || recommendation.roadmap_relevance || recommendation.priority_score);
      return keys.some((key) => value === recommendationStatus(key));
    });
    return `
      <article class="consultant-rec-roadmap-phase">
        <h4>${escapeHtml(label)}</h4>
        ${items.length ? `<ul>${items.map((item) => `<li>${escapeHtml(item.title || 'Untitled recommendation')}</li>`).join('')}</ul>` : '<p>No recommendations in this phase yet.</p>'}
      </article>
    `;
  }).join('');
}

function renderConsultantRecommendationsGate(recommendations = []) {
  const total = safeArray(recommendations).length;
  const approved = approvedRecommendations(recommendations).length;
  const progress = total ? Math.round((approved / total) * 100) : 0;
  return `
    <article class="consultant-rec-gate ${total && approved === total ? 'passed' : 'blocked'}">
      <div>
        <strong>${approved} of ${total} recommendations approved</strong>
        <p>${total && approved === total ? 'Deliver is now unlocked.' : 'Approve all recommendations before delivery unlocks.'}</p>
      </div>
      <div class="progress-track"><div class="progress-fill" style="width: ${progress}%"></div></div>
    </article>
  `;
}

async function patchConsultantRecommendationStatus(recommendationId, status) {
  const assessment = getSlice('assessment') || {};
  const originalRecommendations = safeArray(assessment.recommendations);
  const optimisticRecommendations = originalRecommendations.map((recommendation) => String(recommendation.id) === String(recommendationId) ? { ...recommendation, status } : recommendation);
  mergeState('assessment', { recommendations: optimisticRecommendations });
  renderConsultantView('recommendations');
  try {
    const response = await fetch(`/api/recommendations/${encodeURIComponent(recommendationId)}`, {
      method: 'PATCH',
      headers: {
        ...authHeaders(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ status })
    });
    const data = await response.json();
    if (!response.ok) throw new Error(data.error || 'Recommendation update failed.');
    const updatedRecommendations = safeArray((getSlice('assessment') || {}).recommendations).map((recommendation) => String(recommendation.id) === String(recommendationId) ? { ...recommendation, ...(data.recommendation || {}), status: data.recommendation?.status || status } : recommendation);
    mergeState('assessment', { recommendations: updatedRecommendations });
  } catch (error) {
    console.error('Consultant recommendation status update failed:', error);
    mergeState('assessment', { recommendations: originalRecommendations });
  }
  renderConsultantView('recommendations');
}

function renderConsultantRecommendations() {
  const assessment = getSlice('assessment') || {};
  const recommendations = safeArray(assessment.recommendations);
  const selectedRecommendationId = consultantState.selectedRecommendationId || recommendations[0]?.id || null;
  consultantState.selectedRecommendationId = selectedRecommendationId;
  const selectedRecommendation = recommendations.find((recommendation) => String(recommendation.id) === String(selectedRecommendationId)) || recommendations[0] || null;
  updateViewContainer(`
    ${renderStageLockMessage()}
    <section class="consultant-stage consultant-recommendations-stage">
      <div class="owner-section-head"><div><span class="eyebrow">Recommendations</span><h2>Action quality gate</h2><p>Approve the recommendations that should reach delivery, then confirm the roadmap and progress memory.</p></div></div>
      <section class="consultant-rec-workbench">
        ${recommendations.length ? `
          <aside class="consultant-rec-list-column">
            ${renderConsultantRecommendationRows(recommendations, selectedRecommendationId)}
          </aside>
          <div class="consultant-rec-detail-column">
            ${renderConsultantRecommendationDetail(selectedRecommendation)}
          </div>
        ` : emptyState('No recommendations have been generated yet.')}
      </section>
      <details class="consultant-rec-collapsible">
        <summary><span>Roadmap</span><i>⌄</i></summary>
        <div class="consultant-rec-collapsible-body consultant-rec-roadmap">
          ${renderRoadmapPhases(recommendations)}
          ${renderRoadmapComponent(assessment.roadmapItems || [], emptyState('Roadmap items will appear after recommendations are approved.'), { onItemClick: () => {} })}
        </div>
      </details>
      <details class="consultant-rec-collapsible">
        <summary><span>Organizational memory</span><i>⌄</i></summary>
        <div class="consultant-rec-collapsible-body">
          ${renderProgressMemorySectionComponent(
            assessment.progressMemory || {},
            emptyState('Generate a progress snapshot after recommendations are ready.'),
            true,
            {
              onGenerateSnapshot: callbacks().onGenerateSnapshot,
              onRegenerateSnapshot: callbacks().onRegenerateSnapshot
            }
          )}
        </div>
      </details>
      ${renderConsultantRecommendationsGate(recommendations)}
    </section>
  `);
}

function deliveryValue(recommendations = []) {
  return safeArray(recommendations).reduce((sum, rec) => sum + Number(rec.estimated_business_value || rec.expected_value || 0), 0);
}

function renderConsultantDeliver() {
  const assessment = getSlice('assessment') || {};
  const executive = getSlice('executive') || {};
  const findings = approvedFindings(assessment.findings);
  const recommendations = approvedRecommendations(assessment.recommendations);
  const phaseCount = new Set(safeArray(assessment.roadmapItems).map((item) => item.phase || item.roadmap_phase).filter(Boolean)).size;
  const reportGenerated = Boolean(executive.report);
  const value = deliveryValue(recommendations);
  const projectId = assessment.assessment?.company_id
    || assessment.companyProfile?.assessment_project_id
    || consultantState.activeEngagementId
    || '';
  const assessmentDelivered = String(assessment.assessment?.status || '').toLowerCase() === 'completed';
  const progressSaved = Boolean(assessment.progressMemory?.latest_snapshot);
  const executivePdfUrl = `/api/reports/executive-summary?projectId=${encodeURIComponent(projectId)}`;
  const fullPdfUrl = `/api/reports/full-report?projectId=${encodeURIComponent(projectId)}`;
  const readiness = `
    <div class="blueprint-score-grid">
      <article><span>Approved Findings</span><strong>${findings.length}</strong></article>
      <article><span>Approved Recommendations</span><strong>${recommendations.length}</strong></article>
      <article><span>Roadmap Phases</span><strong>${phaseCount}</strong></article>
      <article><span>Value at Stake</span><strong>${value ? `$${Math.round(value).toLocaleString()}` : 'TBD'}</strong></article>
      <article><span>Progress Memory</span><strong>${assessment.progressMemory?.latest_snapshot ? 'Present' : 'Not generated'}</strong></article>
      <article><span>Report Status</span><strong>${reportGenerated ? 'Generated' : 'Not generated'}</strong></article>
    </div>
  `;
  updateViewContainer(`
    ${renderStageLockMessage()}
    <section class="consultant-stage consultant-deliver-stage">
      <div class="consultant-deliver-panel">
        <div class="owner-section-head"><div><span class="eyebrow">Deliver</span><h2>Final owner deliverable</h2><p>This is the report your client will see. Review it before delivering.</p></div></div>
        ${readiness}
        <article class="engine-block">
          <h3>Save progress baseline</h3>
          <p>Creates a snapshot of this assessment's results for future comparison.</p>
          <button class="secondary-button" data-progress-action="generate" type="button" style="width: 100%; justify-content: center;">Save progress baseline</button>
          ${progressSaved ? `
            <div class="gate-passed" style="margin-top: 12px;">
              <div class="gate-title">Progress baseline saved.</div>
              <p>When the next assessment is complete, Derive will show what improved, what persisted, and what is new.</p>
            </div>
          ` : ''}
        </article>
        <div class="consultant-deliver-downloads" style="display: grid; gap: 8px; margin-bottom: 16px;">
          <button class="primary-button" type="button" onclick="window.open('${executivePdfUrl}', '_blank')">Download Executive Summary PDF</button>
          <button class="secondary-button" type="button" onclick="window.open('${fullPdfUrl}', '_blank')">Download Full Intelligence Report PDF</button>
        </div>
        ${reportGenerated ? `
          ${renderExecutiveReportComponent(
            executive.report,
            findings,
            recommendations,
            assessment.progressMemory || {},
            consultantState.reportToggles,
            emptyState('Generate the executive report after recommendations are approved.'),
            {
              onGenerate: callbacks().onGenerateReport,
              onToggleSection: true,
              onNavigateSection: true,
              onPrint: true,
              onExport: callbacks().onExportReport
            }
          )}
          ${assessmentDelivered ? `
            <div class="gate-passed">
              <div class="gate-title">Marked as delivered.</div>
              <p>The assessment is now recorded as delivered.</p>
            </div>
          ` : `<button class="primary-button" data-consultant-mark-delivered type="button">Mark as delivered</button>`}
        ` : `
          <article class="engine-block">
            <h3>Generate executive report</h3>
            <p>This will generate the report that your client will see. Review it before delivering.</p>
            <button class="primary-button" data-consultant-generate-report type="button">Generate executive report</button>
          </article>
        `}
      </div>
    </section>
  `);
}
