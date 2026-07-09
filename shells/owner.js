import { getSlice, mergeState } from '../store.js';
import {
  renderExecutivePreviewComponent,
  renderExecutiveReportComponent
} from '../components/executive.js';
import {
  renderFindingsWorkbenchComponent
} from '../components/findings.js';
import {
  renderRecommendationsComponent
} from '../components/recommendations.js?v=20260609c';
import {
  renderRoadmapComponent
} from '../components/roadmap.js';
import {
  renderProgressMemorySectionComponent
} from '../components/progress.js';
import {
  renderAlignmentHeatmapComponent
} from '../components/alignment.js';
import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml
} from '../shared.js';

let ownerContainer = null;
let ownerViewContainer = null;

let ownerState = {
  activeView: 'overview',
  selectedFindingId: null,
  overviewRefreshScheduled: false,
  overviewRefreshAttempts: 0,
  progressLoading: false,
  progressLoadedProjectId: null,
  filterState: {
    stakeholderGroup: null,
    stakeholderRole: null,
    heatmapDomain: null,
    heatmapGroup: null,
    heatmapMinPriority: null,
    onlyMisalignment: false,
    onlyHighConfidence: false,
    selectedHeatmapCellKey: null
  },
  reportToggles: {
    showEvidence: false,
    showAppendix: false
  }
};

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

const OWNER_NAV_ITEMS = [
  ['overview', 'Overview'],
  ['findings', 'Findings'],
  ['recommendations', 'Recommendations'],
  ['roadmap', 'Roadmap'],
  ['progress', 'Progress']
];

function ownerEmptyState(message) {
  return renderScreenState('owner-dashboard', 'empty', {
    title: message,
    message: 'Your consultant will publish owner-ready intelligence after review.',
    actionLabel: '',
    actionView: '',
    compact: true
  });
}

function approvedOwnerFindings(findings = []) {
  return (findings || []).filter((finding) => String(finding.status || '').toLowerCase() === 'approved');
}

function ownerReadyRecommendations(recommendations = []) {
  const allowed = new Set(['approved', 'accepted', 'in_progress', 'completed']);
  return (recommendations || []).filter((recommendation) => allowed.has(String(recommendation.status || '').toLowerCase()));
}

function approvedRecommendations(recommendations = []) {
  return (recommendations || []).filter((recommendation) => String(recommendation.status || '').toLowerCase() === 'approved');
}

function activeOrganization(platform = {}, assessment = getSlice('assessment') || {}) {
  const projects = Array.isArray(platform.projects) ? platform.projects : [];
  const project = projects.find((item) => String(item.id) === String(platform.activeProjectId)) || projects[0] || null;
  if (project) return project;
  const profile = assessment.companyProfile || assessment.company_profile || {};
  if (profile && Object.keys(profile).length) {
    return {
      ...profile,
      name: profile.companyName || profile.company_name || profile.name,
      clientDisplayName: profile.companyName || profile.company_name || profile.name,
      updated_at: profile.updatedAt || profile.updated_at
    };
  }
  return null;
}

function activeAssessmentContext(assessment = {}, organization = {}) {
  const record = assessment.assessment || {};
  return {
    id: assessment.activeAssessmentId || record.id || organization?.activeAssessmentId || organization?.active_assessment_id || null,
    name: record.title || record.name || organization?.activeAssessmentName || organization?.active_assessment_name || organization?.assessment_name || organization?.current_assessment_name || 'Business Assessment',
    title: record.title || record.name || organization?.activeAssessmentName || organization?.active_assessment_name || organization?.assessment_name || organization?.current_assessment_name || 'Business Assessment',
    status: record.status || organization?.assessment_status || organization?.status || 'active',
    updated_at: record.updated_at || record.created_at || organization?.updated_at || organization?.last_updated || null
  };
}

function ownerActiveProjectId() {
  const platform = getSlice('platform') || {};
  const assessment = getSlice('assessment') || {};
  return platform.activeProjectId
    || activeOrganization(platform, assessment)?.id
    || assessment.assessment?.company_id
    || assessment.companyProfile?.assessment_project_id
    || assessment.company_profile?.assessment_project_id
    || null;
}

async function loadOwnerProgressHistory() {
  const projectId = ownerActiveProjectId();
  if (!projectId || ownerState.progressLoading) return;
  ownerState.progressLoading = true;
  if (ownerState.activeView === 'progress') renderOwnerProgress();
  try {
    const response = await fetch(`/api/progress-history?projectId=${encodeURIComponent(projectId)}`, {
      headers: authHeaders()
    });
    const data = await response.json();
    if (data.progressMemory) {
      mergeState('assessment', {
        progressMemory: data.progressMemory
      });
      ownerState.progressLoadedProjectId = projectId;
    }
  } catch (error) {
    console.error('Owner progress load error:', error);
  }
  ownerState.progressLoading = false;
  if (ownerState.activeView === 'progress') renderOwnerProgress();
  if (ownerState.activeView === 'overview') renderOwnerOverview();
}

function firstUsefulLabel(candidates = [], fallback = '') {
  return candidates.find((candidate) => {
    const value = String(candidate || '').trim();
    if (!value) return false;
    return !['organization', 'business assessment', 'assessment'].includes(value.toLowerCase());
  }) || fallback;
}

function ownerOrganizationName(organization = {}) {
  return firstUsefulLabel([
    organization?.client_display_name,
    organization?.clientDisplayName,
    organization?.name,
    organization?.organization_name,
    organization?.company_name,
    organization?.tenant_name,
    organization?.workspace_name,
    organization?.display_name,
    organization?.organizationName
  ], 'Organization');
}

function ownerAssessmentName(assessmentContext = {}, organization = {}) {
  return firstUsefulLabel([
    assessmentContext?.name,
    assessmentContext?.title,
    organization?.activeAssessmentName,
    organization?.active_assessment_name,
    organization?.assessment_name,
    organization?.current_assessment_name
  ], 'Business Assessment');
}

function organizationProfile(organization = {}, assessment = {}) {
  return organization?.profile || organization?.companyProfile || organization?.organizationProfile || assessment?.blueprint?.company_profile || {};
}

function assessmentDateLabel(assessment = {}, organization = {}) {
  const value = assessment?.updated_at || assessment?.last_updated || organization?.updated_at || organization?.last_updated || null;
  return value ? new Date(value).toLocaleDateString() : 'Not updated yet';
}

function ownerSeverityValue(finding = {}) {
  return Number(finding.severity ?? finding.priority_score ?? finding.priorityScore ?? 0);
}

function isCriticalOwnerFinding(finding = {}) {
  return ownerSeverityValue(finding) >= 4;
}

function ownerFindingSeverityLevel(finding = {}) {
  const value = ownerSeverityValue(finding);
  if (isCriticalOwnerFinding(finding)) return 'high';
  if (value >= 3) return 'medium';
  return 'low';
}

function ownerOperationalHealth(assessment = {}, executive = {}) {
  return assessment.operational_health
    ?? assessment.operationalHealth
    ?? assessment.health_score
    ?? assessment.healthScore
    ?? assessment.executivePreview?.operational_health
    ?? assessment.executivePreview?.operationalHealth
    ?? executive.report?.operational_health
    ?? executive.report?.operationalHealth
    ?? null;
}

function ownerScoreClass(value) {
  const score = Number(value || 0);
  if (score >= 80) return 'success';
  if (score >= 60) return 'accent';
  if (score > 0) return 'danger';
  return '';
}

function renderOwnerScoreValue(value) {
  if (value === null || value === undefined || value === '') return '--';
  return `<span class="metric-val">${escapeHtml(String(value))}</span><span class="metric-suffix">/100</span>`;
}

function ownerAssessmentMonth(value) {
  if (!value) return 'Not dated';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not dated';
  return date.toLocaleDateString([], { month: 'short', year: 'numeric' });
}

function ownerRecommendationPriority(recommendation = {}) {
  return Number(recommendation.priority_score ?? recommendation.priorityScore ?? recommendation.estimated_business_value ?? recommendation.expected_value ?? 0);
}

function ownerRecommendationPhase(recommendation = {}) {
  return recommendation.roadmap_phase || recommendation.roadmap_relevance || 'Priority action';
}

function ownerRecommendationOwner(recommendation = {}) {
  return recommendation.recommended_owner || recommendation.accountable_owner || recommendation.owner_role || recommendation.responsible_role || 'Owner TBD';
}

function ownerOverviewStatus(assessment = {}, executive = {}, findings = [], recommendations = []) {
  const status = String(assessment?.assessment?.status || assessment?.status || '').toLowerCase();
  const delivered = status === 'delivered'
    || Boolean(executive.report)
    || (findings.length > 0 && recommendations.length > 0);
  return delivered
    ? { delivered: true, label: 'Intelligence delivered', className: 'approved' }
    : { delivered: false, label: 'Assessment in progress', className: 'warning' };
}

function setOwnerView(viewId) {
  ownerState.activeView = viewId;
  renderOwnerView(viewId);
}

function wireOwnerShell(container) {
  container.addEventListener('click', (event) => {
    if (event.target.closest('[data-owner-logout]')) {
      handleLogout();
      return;
    }

    const navButton = event.target.closest('[data-owner-view]');
    if (navButton) {
      setOwnerView(navButton.dataset.ownerView);
      return;
    }

    const findingButton = event.target.closest('[data-component-select-finding]');
    if (findingButton) {
      ownerState.selectedFindingId = findingButton.dataset.componentSelectFinding;
      renderOwnerView(ownerState.activeView);
      return;
    }

    const heatmapCell = event.target.closest('[data-component-heatmap-cell]');
    if (heatmapCell) {
      ownerState.filterState.selectedHeatmapCellKey = heatmapCell.dataset.componentHeatmapCell;
      renderOwnerView(ownerState.activeView);
      return;
    }

    const reportButton = event.target.closest('[data-component-view-report], [data-component-report-action="generate"]');
    if (reportButton) {
      setOwnerView('report');
      return;
    }

    const ownerNavigate = event.target.closest('[data-component-navigate]');
    if (ownerNavigate) {
      setOwnerView(ownerNavigate.dataset.componentNavigate);
      return;
    }

    const reportNav = event.target.closest('[data-component-report-nav]');
    if (reportNav) {
      const target = container.querySelector(`#report-${reportNav.dataset.componentReportNav}`);
      target?.scrollIntoView?.({ behavior: 'smooth', block: 'start' });
    }
  });

  container.addEventListener('change', (event) => {
    const filter = event.target.closest('[data-component-heatmap-filter]');
    if (filter) {
      const filterName = filter.dataset.componentHeatmapFilter;
      if (filterName === 'domain') ownerState.filterState.heatmapDomain = filter.value || null;
      if (filterName === 'group') ownerState.filterState.heatmapGroup = filter.value || null;
      if (filterName === 'min-priority') ownerState.filterState.heatmapMinPriority = filter.value || null;
      if (filterName === 'misalignment') ownerState.filterState.onlyMisalignment = Boolean(filter.checked);
      if (filterName === 'high-confidence') ownerState.filterState.onlyHighConfidence = Boolean(filter.checked);
      renderOwnerView(ownerState.activeView);
      return;
    }

    const reportToggle = event.target.closest('[data-component-report-toggle]');
    if (reportToggle) {
      if (reportToggle.dataset.componentReportToggle === 'evidence') ownerState.reportToggles.showEvidence = Boolean(reportToggle.checked);
      if (reportToggle.dataset.componentReportToggle === 'appendix') ownerState.reportToggles.showAppendix = Boolean(reportToggle.checked);
      renderOwnerView('report');
    }
  });
}

function updateOwnerContextStrip() {
  if (!ownerContainer) return;
  const platform = getSlice('platform') || {};
  const assessment = getSlice('assessment') || {};
  const organization = activeOrganization(platform, assessment);
  const assessmentContext = activeAssessmentContext(assessment, organization);
  const organizationNode = ownerContainer.querySelector('[data-owner-context="organization"]');
  const assessmentNode = ownerContainer.querySelector('[data-owner-context="assessment"]');
  const dateNode = ownerContainer.querySelector('[data-owner-context="date"]');
  if (organizationNode) organizationNode.textContent = ownerOrganizationName(organization);
  if (assessmentNode) assessmentNode.textContent = ownerAssessmentName(assessmentContext, organization);
  if (dateNode) dateNode.textContent = assessmentDateLabel(assessmentContext, organization);
}

export function initOwnerSurface(container) {
  ownerContainer = container;
  renderOwnerShell(container);
  wireOwnerShell(container);
  renderOwnerView('overview');
}

export function renderOwnerShell(container) {
  ownerContainer = container;
  const platform = getSlice('platform') || {};
  const assessment = getSlice('assessment') || {};
  const organization = activeOrganization(platform, assessment);
  const assessmentContext = activeAssessmentContext(assessment, organization);
  container.innerHTML = `
    <section class="owner-surface-shell">
      <header class="owner-context-strip">
        <div>
          <span class="eyebrow">Organization</span>
          <strong data-owner-context="organization">${escapeHtml(ownerOrganizationName(organization))}</strong>
        </div>
        <div>
          <span class="eyebrow">Assessment</span>
          <strong data-owner-context="assessment">${escapeHtml(ownerAssessmentName(assessmentContext, organization))}</strong>
        </div>
        <div>
          <span class="eyebrow">Assessment Date</span>
          <strong data-owner-context="date">${escapeHtml(assessmentDateLabel(assessmentContext, organization))}</strong>
        </div>
        <button class="text-button" data-owner-logout type="button" style="margin-left: auto; color: var(--color-text-muted);">
          <i class="ti ti-logout" aria-hidden="true"></i>
          <span>Sign out</span>
        </button>
      </header>
      <nav class="owner-surface-nav" aria-label="Owner navigation">
        ${OWNER_NAV_ITEMS.map(([id, label]) => `<button class="${ownerState.activeView === id ? 'active' : ''}" data-owner-view="${id}" type="button">${escapeHtml(label)}</button>`).join('')}
      </nav>
      <main class="owner-surface-view" id="owner-surface-view"></main>
    </section>
  `;
  ownerViewContainer = container.querySelector('#owner-surface-view');
}

export function renderOwnerView(viewId) {
  ownerState.activeView = viewId;
  window.__ownerState = { activeView: viewId };
  updateOwnerContextStrip();
  if (!ownerViewContainer && ownerContainer) {
    ownerViewContainer = ownerContainer.querySelector('#owner-surface-view');
  }
  if (!ownerViewContainer) return;
  ownerContainer?.querySelectorAll('[data-owner-view]').forEach((button) => {
    button.classList.toggle('active', button.dataset.ownerView === viewId);
  });
  switch (viewId) {
    case 'overview':
      renderOwnerOverview();
      break;
    case 'findings':
      renderOwnerFindings();
      break;
    case 'recommendations':
      renderOwnerRecommendations();
      break;
    case 'roadmap':
      renderOwnerRoadmap();
      break;
    case 'progress':
      renderOwnerProgress();
      break;
    case 'report':
      renderOwnerReport();
      break;
    default:
      renderOwnerOverview();
  }
}

function renderOwnerOverview() {
  const assessment = getSlice('assessment') || {};
  const executive = getSlice('executive') || {};
  const platform = getSlice('platform') || {};
  const organization = activeOrganization(platform, assessment);
  const projectId = ownerActiveProjectId();
  const assessmentContext = activeAssessmentContext(assessment, organization);
  const findings = approvedOwnerFindings(assessment.findings);
  const recommendations = ownerReadyRecommendations(assessment.recommendations);
  const approvedRecs = approvedRecommendations(assessment.recommendations);
  const kpiGaps = assessment.kpiGaps || assessment.kpi_gaps || assessment.executivePreview?.missingKpis || [];
  const progressMemory = assessment.progressMemory || {};
  const snapshot = progressMemory.latest_snapshot || {};
  const businessHealth = snapshot.business_health_score ?? null;
  const digitalMaturity = snapshot.digital_maturity_score ?? null;
  const assessmentDate = snapshot.snapshot_date || assessmentContext.updated_at;
  const status = ownerOverviewStatus(assessment, executive, findings, recommendations);
  const criticalCount = findings.filter(isCriticalOwnerFinding).length;
  const topFindings = [...findings]
    .sort((a, b) => ownerSeverityValue(b) - ownerSeverityValue(a))
    .slice(0, 3);
  const nextMove = [...approvedRecs]
    .sort((a, b) => ownerRecommendationPriority(b) - ownerRecommendationPriority(a))[0];
  if (findings.length || recommendations.length) {
    ownerState.overviewRefreshAttempts = 0;
  }
  if (projectId && ownerState.progressLoadedProjectId !== projectId && !ownerState.progressLoading) {
    loadOwnerProgressHistory();
  }
  if (
    !ownerState.overviewRefreshScheduled
    && !findings.length
    && !recommendations.length
    && ownerState.overviewRefreshAttempts < 12
  ) {
    ownerState.overviewRefreshScheduled = true;
    ownerState.overviewRefreshAttempts += 1;
    window.setTimeout(() => {
      ownerState.overviewRefreshScheduled = false;
      if (ownerState.activeView === 'overview') renderOwnerView('overview');
    }, 500);
  }
  ownerViewContainer.innerHTML = `
    <section class="owner-executive-brief">
      <section class="owner-brief-context">
        <div>
          <strong>${escapeHtml(ownerOrganizationName(organization))}</strong>
          <span>${escapeHtml(ownerAssessmentName(assessmentContext, organization))} · ${escapeHtml(assessmentDateLabel(assessmentContext, organization))}</span>
        </div>
        <span class="status-pill ${status.className}">${escapeHtml(status.label)}</span>
      </section>

      <section class="owner-brief-hero">
        <span class="eyebrow">Your organizational intelligence</span>
        <h1>${findings.length
          ? `Your organization has ${criticalCount} operational gap${criticalCount === 1 ? '' : 's'} that are costing you every week.`
          : 'Your assessment is being prepared.'}</h1>
        <p>${status.delivered
          ? `${findings.length} findings. ${approvedRecs.length} recommendations. A clear path from quick wins to transformation. Your consultant has reviewed every signal and prepared a prioritized action plan.`
          : 'Your consultant is reviewing the assessment data. You will be notified when your intelligence is ready.'}</p>
        ${status.delivered ? `<button class="primary-button" data-owner-view="findings" type="button">View full intelligence report →</button>` : ''}
        ${projectId ? `
          <div class="owner-report-downloads" style="display: flex; gap: 8px; margin-top: 12px; flex-wrap: wrap;">
            <button type="button" onclick="window.open('/api/reports/executive-summary?projectId=${encodeURIComponent(projectId)}', '_blank')" style="background: transparent; border: 0.5px solid rgba(200,169,110,0.3); color: rgba(200,169,110,0.8); font-size: 12px; padding: 7px 14px; border-radius: 6px; cursor: pointer;">↓ Executive Summary PDF</button>
            <button type="button" onclick="window.open('/api/reports/full-report?projectId=${encodeURIComponent(projectId)}', '_blank')" style="background: transparent; border: 0.5px solid rgba(200,169,110,0.3); color: rgba(200,169,110,0.8); font-size: 12px; padding: 7px 14px; border-radius: 6px; cursor: pointer;">↓ Full Intelligence Report</button>
          </div>
        ` : ''}
      </section>

      <section class="owner-signal-metrics" aria-label="Signal metrics">
        <article class="${ownerScoreClass(businessHealth)}"><strong>${renderOwnerScoreValue(businessHealth)}</strong><span>Business health</span></article>
        <article class="${ownerScoreClass(digitalMaturity)}"><strong>${renderOwnerScoreValue(digitalMaturity)}</strong><span>Digital maturity</span></article>
        <article class="danger"><strong>${criticalCount}</strong><span>Critical risks</span></article>
        <article class="success"><strong>${approvedRecs.length}</strong><span>Recommendations ready</span></article>
        <article class="accent"><strong>${Array.isArray(kpiGaps) ? kpiGaps.length : 0}</strong><span>KPI gaps found</span></article>
        <article><strong>${escapeHtml(ownerAssessmentMonth(assessmentDate))}</strong><span>Assessment date</span></article>
      </section>

      <section class="owner-top-findings">
        <span class="owner-brief-section-label">What we found — top priority issues</span>
        ${topFindings.length ? topFindings.map((finding, index) => {
          const severity = ownerFindingSeverityLevel(finding);
          const tag = severity === 'high' ? 'Critical risk' : severity === 'medium' ? 'Opportunity' : 'Systemic gap';
          return `
            <article class="owner-brief-finding ${severity}">
              <span>${String(index + 1).padStart(2, '0')}</span>
              <div>
                <h3>${escapeHtml(finding.title || 'Untitled finding')}</h3>
                <p>${escapeHtml(finding.description || finding.summary || finding.body || 'No description provided yet.')}</p>
                <small class="status-pill ${severity === 'high' ? 'danger' : severity === 'medium' ? 'approved' : 'production'}">${escapeHtml(tag)}</small>
              </div>
            </article>
          `;
        }).join('') : `
          <article class="owner-brief-muted-card">Findings will appear here after your consultant completes the review.</article>
        `}
      </section>

      ${nextMove ? `
        <section class="owner-next-move">
          <div>
            <span class="eyebrow">Recommended first move</span>
            <h3>${escapeHtml(nextMove.title || 'Recommended action')}</h3>
            <p>${escapeHtml(ownerRecommendationPhase(nextMove))} · ${escapeHtml(ownerRecommendationOwner(nextMove))} · Review in Recommendations tab</p>
          </div>
          <button class="secondary-button" data-owner-view="recommendations" type="button">Review recommendations →</button>
        </section>
      ` : ''}
    </section>
  `;
}

function renderOwnerFindings() {
  const assessment = getSlice('assessment') || {};
  const findings = approvedOwnerFindings(assessment.findings);
  const recommendations = approvedRecommendations(assessment.recommendations);
  const recommendationsByFindingId = recommendations.reduce((acc, recommendation) => {
    if (recommendation.finding_id) acc[String(recommendation.finding_id)] = recommendation;
    return acc;
  }, {});
  ownerViewContainer.innerHTML = renderFindingsWorkbenchComponent(
    findings,
    recommendationsByFindingId,
    ownerState.selectedFindingId,
    ownerEmptyState('No findings are available yet. Findings will appear here once your assessment has been reviewed.'),
    {
      onSelectFinding: (id) => {
        ownerState.selectedFindingId = id;
        renderOwnerView('findings');
      }
    }
  );
}

function renderOwnerRecommendations() {
  const assessment = getSlice('assessment') || {};
  const recommendations = ownerReadyRecommendations(assessment.recommendations);
  ownerViewContainer.innerHTML = renderRecommendationsComponent(
    recommendations,
    true,
    ownerEmptyState('No recommendations are available yet. They will appear here once your consultant has completed their review.'),
    {
      onViewReport: () => renderOwnerView('report')
    }
  );
}

function renderOwnerRoadmap() {
  const assessment = getSlice('assessment') || {};
  ownerViewContainer.innerHTML = renderRoadmapComponent(
    assessment.roadmapItems || [],
    ownerEmptyState('Your roadmap is being prepared.'),
    {}
  );
}

function renderOwnerProgress() {
  const assessment = getSlice('assessment') || {};
  const projectId = ownerActiveProjectId();
  const progressMemory = assessment.progressMemory || {};
  const latest = progressMemory.latest_snapshot;
  if (projectId && ownerState.progressLoadedProjectId !== projectId && !ownerState.progressLoading) {
    loadOwnerProgressHistory();
  }
  if (ownerState.progressLoading && !latest) {
    ownerViewContainer.innerHTML = renderLoadingSkeleton('Loading progress history...');
    return;
  }
  const baselineSummary = latest && !progressMemory.previous_snapshot
    ? `
      <article class="owner-progress-baseline card" style="margin-bottom: 16px;">
        <span class="eyebrow">Baseline saved</span>
        <h3>This is your baseline.</h3>
        <p>After your next assessment, Derive will show what improved, what persisted, and what is new.</p>
        <div class="metrics-grid" style="margin-top: 16px;">
          <article class="metric"><span class="metric-label">Assessment date</span><strong class="metric-value" style="font-size: 18px;">${escapeHtml(latest.snapshot_date ? new Date(latest.snapshot_date).toLocaleDateString() : 'Saved')}</strong></article>
          <article class="metric"><span class="metric-label">Business health</span><strong class="metric-value">${escapeHtml(String(latest.business_health_score ?? '--'))}</strong></article>
          <article class="metric"><span class="metric-label">Digital maturity</span><strong class="metric-value">${escapeHtml(String(latest.digital_maturity_score ?? '--'))}</strong></article>
          <article class="metric"><span class="metric-label">Findings</span><strong class="metric-value">${escapeHtml(String(latest.total_findings ?? 0))}</strong></article>
          <article class="metric"><span class="metric-label">Critical findings</span><strong class="metric-value danger">${escapeHtml(String(latest.critical_findings_count ?? 0))}</strong></article>
          <article class="metric"><span class="metric-label">Recommendations</span><strong class="metric-value success">${escapeHtml(String(latest.approved_recommendations_count ?? 0))}</strong></article>
        </div>
      </article>
    `
    : '';
  ownerViewContainer.innerHTML = baselineSummary + renderProgressMemorySectionComponent(
    progressMemory,
    ownerEmptyState('Your progress baseline has not been saved yet. Ask your consultant to save the progress baseline from the Deliver stage.'),
    false,
    {}
  );
}

function renderOwnerReport() {
  const assessment = getSlice('assessment') || {};
  const executive = getSlice('executive') || {};
  const findings = approvedOwnerFindings(assessment.findings);
  const recommendations = ownerReadyRecommendations(assessment.recommendations);
  ownerViewContainer.innerHTML = renderExecutiveReportComponent(
    executive.report,
    findings,
    recommendations,
    assessment.progressMemory || {},
    ownerState.reportToggles,
    ownerEmptyState('Your executive report is being prepared.'),
    {
      onToggleSection: (sectionKey, enabled) => {
        if (sectionKey === 'evidence') ownerState.reportToggles.showEvidence = Boolean(enabled);
        if (sectionKey === 'appendix') ownerState.reportToggles.showAppendix = Boolean(enabled);
        renderOwnerView('report');
      },
      onNavigateSection: () => {},
      onPrint: () => {},
      onExport: () => {}
    }
  );
}

/*
Owner shell smoke-test fixture:

import { mergeState } from '../store.js';
mergeState('session', { currentRole: 'company_owner' });
mergeState('platform', {
  activeProjectId: 'org-1',
  projects: [{ id: 'org-1', name: 'Sample Organization', updated_at: '2026-06-06' }]
});
mergeState('assessment', {
  activeAssessmentId: 'assessment-1',
  blueprint: { assessment_confidence_score: 86, assessment_completeness_score: 92 },
  findings: [
    { id: 'f1', status: 'approved', title: 'Dispatch visibility gap', business_domain: 'service_delivery', priority_score: 88, confidence: 4, evidence_count: 2 },
    { id: 'f2', status: 'approved', title: 'Inventory KPI missing', business_domain: 'inventory_management', priority_score: 75, confidence: 4, evidence_count: 1 },
    { id: 'f3', status: 'approved', title: 'Customer response not measured', business_domain: 'customer_experience', priority_score: 65, confidence: 3, evidence_count: 1 }
  ],
  recommendations: [
    { id: 'r1', finding_id: 'f1', status: 'approved', title: 'Create dispatch scorecard', estimated_business_value: 120000 },
    { id: 'r2', finding_id: 'f2', status: 'accepted', title: 'Measure inventory turns', estimated_business_value: 80000 },
    { id: 'r3', finding_id: 'f3', status: 'completed', title: 'Track customer response SLA', estimated_business_value: 60000 }
  ],
  roadmapItems: [
    { id: 'rm1', title: 'Launch dispatch scorecard', phase: 'Quick Wins' },
    { id: 'rm2', title: 'Inventory analytics baseline', phase: 'Foundation' }
  ],
  evidence: [],
  progressMemory: null
});
const mockContainer = document.createElement('div');
initOwnerSurface(mockContainer);
*/
