import { getSlice, setState, mergeState } from '../store.js';
import { renderPlatformCommandCenterComponent } from '../components/platform-command.js';
import { renderOperationsCenterComponent } from '../components/operations.js';
import {
  renderFrameworkLibrary,
  renderFrameworkEditor,
  renderQuestionBankManager,
  renderFrameworkPreview
} from '../components/framework-builder.js';
import { renderUserRolesComponent, renderProjectAccessOptionsComponent } from '../components/users.js';
import { renderOrganizationsComponent } from '../components/organizations.js';
import {
  renderAssessmentWorkspaceComponent
} from '../components/assessment-workspace.js';
import {
  renderHealthPill,
  renderProgressIntelligence
} from '../components/progress-intelligence.js?v=20260607-dark-table';
import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

let platformContainer = null;
let platformViewContainer = null;
let platformCallbacks = {};
let platformAssessmentBootstrapPending = false;
let platformAssessmentBootstrapProjectId = null;
let platformAssessmentDataLoading = false;
let platformAssessmentDataProjectId = null;
let platformOperationsBootstrapPending = false;

let platformState = {
  activeView: 'command-center',
  classificationFilter: null,
  activeQuestionBankRole: null,
  operationsSection: 'overview',
  activeStage: 'setup',
  selectedAssessmentOrgId: null,
  assessmentReturnView: 'assessment',
  selectedFindingId: null,
  selectedFindingIds: [],
  selectedRecommendationIds: [],
  filterState: {
    heatmapDomain: null,
    heatmapGroup: null,
    heatmapMinPriority: null,
    onlyMisalignment: false,
    onlyHighConfidence: false,
    selectedHeatmapCellKey: null,
    stakeholderGroup: null,
    stakeholderRole: null
  },
  reportToggles: {
    showEvidence: true,
    showAppendix: true
  },
  frameworkBuilderView: 'library',
  selectedFrameworkId: null,
  selectedBankId: null,
  frameworkEditorTab: 'identity',
  frameworkEditorSection: null,
  questionBankPanelMode: 'editor',
  frameworks: [],
  selectedFramework: null,
  selectedBank: null,
  bankQuestions: [],
  frameworksLoading: false,
  frameworksError: null,
  scoringConfig: null,
  generatingQuestions: false,
  generatedDraft: null,
  auditingBanks: false,
  auditResults: null,
  completingBanks: false,
  completionResults: null,
  completionTotalGenerated: 0,
  domains: [],
  domainCategories: [],
  kpiCatalog: [],
  frameworkActivities: [],
  importingFleet: false,
  progressIntelligenceByProject: {},
  settings: null,
  glossary: [],
  glossaryEditEntry: null,
  glossarySaving: false,
  settingsError: null,
  settingsLoading: false,
  demoOrgs: [],
  demoLoading: false,
  demoError: null,
  demoGenerating: false,
  demoGenerateProgress: '',
  demoMode: 'list',
  lastGeneratedDemo: null,
  demoCredentials: null,
  selectedDemoConfig: {
    companyName: '',
    companySize: '51-100',
    depth: 'quick'
  }
};

const PLATFORM_NAV = [
  { id: 'command-center', label: 'Command Center', icon: 'ti-layout-dashboard' },
  { id: 'organizations', label: 'Organizations', icon: 'ti-building' },
  { id: 'operations', label: 'Operations', icon: 'ti-activity' },
  { id: 'intelligence', label: 'Intelligence', icon: 'ti-brain' },
  { id: 'demo', label: 'Demo', icon: 'ti-flask' },
  { id: 'frameworks', label: 'Frameworks', icon: 'ti-stack-2' },
  { id: 'users', label: 'Users', icon: 'ti-users' },
  { id: 'assessment', label: 'Assessment', icon: 'ti-clipboard-check' },
  { id: 'settings', label: 'Settings', icon: 'ti-settings' }
];

function callbacks() {
  return platformCallbacks || {};
}

function platformEnvironment() {
  if (typeof document === 'undefined') return '';
  const configured = document.body?.dataset?.environment || document.documentElement?.dataset?.environment || '';
  if (configured) return configured;
  const hostname = document.location?.hostname || '';
  if (hostname === 'localhost' || hostname === '127.0.0.1') return 'Development';
  return '';
}

function updateViewContainer(html = '') {
  if (!platformViewContainer && platformContainer) {
    platformViewContainer = platformContainer.querySelector?.('#platform-surface-view') || null;
  }
  if (platformViewContainer) platformViewContainer.innerHTML = html;
}

function authHeaders() {
  const token = (typeof window !== 'undefined' && window.__platformSessionToken) || '';
  return {
    Authorization: `Bearer ${token}`,
    'x-session-token': token
  };
}

function formatSettingsDate(value) {
  if (!value) return '—';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return '—';
  return date.toLocaleDateString([], { month: 'short', day: 'numeric', year: 'numeric' });
}

function platformStatusPill(label, tone = 'draft') {
  return `<span class="status-pill ${escapeHtml(tone)}">${escapeHtml(label)}</span>`;
}

function snapshotsFromProgressMemory(progressMemory = null) {
  if (!progressMemory) {
    return [];
  }
  return [
    progressMemory.previous_snapshot,
    progressMemory.latest_snapshot
  ].filter(Boolean);
}

async function fetchProgressIntelligence(projectId) {
  if (!projectId) return null;
  if (platformState.progressIntelligenceByProject[projectId]) {
    return platformState.progressIntelligenceByProject[projectId];
  }
  const response = await fetch(`/api/progress-intelligence?projectId=${encodeURIComponent(projectId)}`, {
    headers: authHeaders()
  });
  const data = await response.json();
  if (response.ok) {
    platformState.progressIntelligenceByProject[projectId] = data;
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
  backdrop.dataset.progressPanelClose = 'true';
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
    showToast(error.message || 'Progress intelligence could not load.', 'error');
  }
}

function closeReportMenu() {
  document.querySelector('.platform-report-menu')?.remove();
}

function openReportMenu(projectId, anchor) {
  closeReportMenu();
  if (!projectId) return;
  const rect = anchor?.getBoundingClientRect?.() || { right: window.innerWidth - 24, bottom: 80 };
  const menu = document.createElement('div');
  menu.className = 'platform-report-menu';
  menu.style.top = `${rect.bottom + 8}px`;
  menu.style.left = `${Math.max(16, rect.right - 220)}px`;
  menu.innerHTML = `
    <button data-platform-report-download="executive-summary" data-project-id="${escapeHtml(projectId)}" type="button">Executive Summary PDF</button>
    <button data-platform-report-download="full-report" data-project-id="${escapeHtml(projectId)}" type="button">Full Intelligence Report</button>
  `;
  document.body.appendChild(menu);
  menu.querySelectorAll('[data-platform-report-download]').forEach((button) => {
    button.addEventListener('click', () => {
      downloadReport(button.dataset.projectId, button.dataset.platformReportDownload);
      closeReportMenu();
    });
  });
}

function downloadReport(projectId, type) {
  if (!projectId) return;
  const endpoint = type === 'full-report' ? 'full-report' : 'executive-summary';
  window.open(`/api/reports/${endpoint}?projectId=${encodeURIComponent(projectId)}`, '_blank');
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

async function bootstrapPlatformData() {
  const platform = getSlice('platform') || {};
  const updates = {};

  if (!platform.metrics) {
    try {
      const res = await fetch('/api/platform-command-center', { headers: authHeaders() });
      const data = await res.json();
      if (res.ok && data && !data.error) {
        updates.metrics = data;
        updates.commandCenterError = null;
      } else {
        updates.commandCenterError = data?.error || 'Failed to load platform command center.';
      }
    } catch (err) {
      console.error('Platform command center bootstrap error:', err);
      updates.commandCenterError = err.message || 'Failed to load platform command center.';
    }
  }

  if (!Array.isArray(platform.projects) || platform.projects.length === 0) {
    try {
      const res = await fetch('/api/projects', { headers: authHeaders() });
      const data = await res.json();
      if (res.ok && Array.isArray(data.projects)) {
        updates.projects = data.projects;
        updates.activeProjectId = platform.activeProjectId || data.projects[0]?.id || null;
      }
    } catch (err) {
      console.error('Platform projects bootstrap error:', err);
    }
  }

  if (Object.keys(updates).length) {
    mergeState('platform', updates);
  }
}

async function loadPlatformSettings() {
  platformState.activeView = 'settings';
  platformState.settingsLoading = true;
  platformState.settingsError = null;
  renderPlatformSettings();
  markActiveNav();
  try {
    const [settingsRes, glossaryRes] = await Promise.all([
      fetch('/api/platform/settings', { headers: authHeaders() }),
      fetch('/api/glossary', { headers: authHeaders() })
    ]);
    const data = await settingsRes.json().catch(() => ({}));
    const glossaryData = await glossaryRes.json().catch(() => ({}));
    if (!settingsRes.ok || data.error) {
      throw new Error(data.error || 'Failed to load settings.');
    }
    if (!glossaryRes.ok || glossaryData.error) {
      throw new Error(glossaryData.error || 'Failed to load glossary.');
    }
    platformState.settings = data;
    platformState.glossary = glossaryData.glossary || [];
    platformState.settingsError = null;
  } catch (err) {
    platformState.settingsError = err.message || 'Failed to load settings.';
  } finally {
    platformState.settingsLoading = false;
    renderPlatformSettings();
    markActiveNav();
  }
}

async function saveGlossaryEntry(formData) {
  const entryId = formData.id || formData.key;
  if (!entryId) return;
  platformState.glossarySaving = true;
  renderPlatformSettings();
  try {
    const payload = {
      term: formData.term,
      term_tr: formData.term_tr || null,
      definition: formData.definition,
      calculation: formData.calculation || null,
      interpretation: formData.interpretation || null,
      example: formData.example || null,
      category: formData.category,
      context: String(formData.context || "")
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean),
      sort_order: Number(formData.sort_order || 0),
      is_active: formData.is_active === "on"
    };
    const res = await fetch(`/api/glossary/${encodeURIComponent(entryId)}`, {
      method: "PATCH",
      headers: { ...authHeaders(), "Content-Type": "application/json" },
      body: JSON.stringify(payload)
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || data.error) throw new Error(data.error || "Failed to save glossary entry.");
    platformState.glossary = platformState.glossary.map((entry) =>
      String(entry.id) === String(data.entry.id) ? data.entry : entry
    );
    platformState.glossaryEditEntry = null;
    showToast("Glossary entry updated.");
  } catch (err) {
    platformState.settingsError = err.message || "Failed to save glossary entry.";
  } finally {
    platformState.glossarySaving = false;
    renderPlatformSettings();
  }
}

async function loadDemoOrgs({ silent = false } = {}) {
  if (!silent) {
    platformState.demoLoading = true;
    platformState.demoError = null;
    renderPlatformView('demo');
  }
  try {
    const res = await fetch('/api/demo/organizations', { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok || data.error) throw new Error(data.error || 'Failed to load demo organizations.');
    platformState.demoOrgs = data.demoOrgs || [];
    platformState.demoError = null;
  } catch (err) {
    platformState.demoError = err.message || 'Failed to load demo organizations.';
  }
  platformState.demoLoading = false;
  if (!silent) renderPlatformView('demo');
}

async function generateDemo(config) {
  platformState.selectedDemoConfig = { ...platformState.selectedDemoConfig, ...config };
  platformState.demoGenerating = true;
  platformState.demoError = null;
  platformState.demoGenerateProgress = 'Creating organization profile...';
  renderPlatformView('demo');
  const messages = [
    'Creating organization profile...',
    'Setting up participants...',
    'Generating findings...',
    'Building recommendations...',
    'Saving progress snapshot...'
  ];
  let msgIndex = 0;
  const msgInterval = setInterval(() => {
    msgIndex = (msgIndex + 1) % messages.length;
    platformState.demoGenerateProgress = messages[msgIndex];
    if (platformState.activeView === 'demo') renderPlatformView('demo');
  }, 1200);
  try {
    const res = await fetch('/api/demo/generate', {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify(config)
    });
    const data = await res.json();
    clearInterval(msgInterval);
    if (!res.ok || data.error || !data.success) throw new Error(data.error || 'Generation failed.');
    platformState.lastGeneratedDemo = { ...data.organization, created: data.created };
    platformState.demoCredentials = data.credentials || null;
    platformState.demoMode = 'success';
    platformState.demoGenerating = false;
    platformState.demoGenerateProgress = '';
    await loadDemoOrgs({ silent: true });
    showToast(`${data.organization?.name || 'Demo organization'} is ready.`);
  } catch (err) {
    clearInterval(msgInterval);
    platformState.demoError = err.message || 'Generation failed. Try again.';
    platformState.demoGenerating = false;
    platformState.demoGenerateProgress = '';
  }
  renderPlatformView('demo');
}

async function deleteDemo(projectId, companyName) {
  if (!confirm(`Delete ${companyName}? This cannot be undone.`)) return;
  try {
    const res = await fetch(`/api/demo/organizations/${encodeURIComponent(projectId)}`, {
      method: 'DELETE',
      headers: authHeaders()
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || data.error) throw new Error(data.error || 'Delete failed.');
    await loadDemoOrgs({ silent: true });
    showToast(`${companyName} deleted.`);
    renderPlatformView('demo');
  } catch (err) {
    showToast(err.message || 'Delete failed.', 'error');
  }
}

function demoCompanySlug(name) {
  return String(name || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 48) || 'demo';
}

function updateDangerZoneControls() {
  const org = platformContainer?.querySelector?.('#danger-org-select')?.value || '';
  const confirm = platformContainer?.querySelector?.('#danger-confirm-input')?.value || '';
  const button = platformContainer?.querySelector?.('[data-danger-open]');
  if (button) button.disabled = !(org && confirm === 'DELETE');
}

function selectedDangerOption() {
  return document
    .querySelector('input[name="danger-option"]:checked')
    ?.value || 'responses';
}

function dangerOptionLabel(option = selectedDangerOption()) {
  return option === 'everything'
    ? 'everything including participants'
    : 'assessment responses';
}

function openDangerConfirmation() {
  const panel = platformContainer?.querySelector?.('#danger-confirmation-card');
  if (!panel) return;
  const select = platformContainer?.querySelector?.('#danger-org-select');
  const selectedName = select?.selectedOptions?.[0]?.textContent || 'selected organization';
  const option = selectedDangerOption();
  panel.classList.remove('hidden');
  panel.innerHTML = `
    <p>You are about to permanently delete <strong>${escapeHtml(dangerOptionLabel(option))}</strong> for <strong>${escapeHtml(selectedName)}</strong>.</p>
    <p style="margin-top:8px;color:var(--color-danger);">This cannot be undone.</p>
    <div style="display:flex;gap:8px;margin-top:14px;">
      <button class="secondary-button" data-danger-cancel type="button">Cancel</button>
      <button class="primary-button" data-danger-confirm type="button" style="background:var(--color-danger);color:white;">Confirm — delete permanently</button>
    </div>
  `;
  const button = platformContainer?.querySelector?.('[data-danger-open]');
  if (button) button.classList.add('hidden');
}

function closeDangerConfirmation() {
  const panel = platformContainer?.querySelector?.('#danger-confirmation-card');
  if (panel) {
    panel.classList.add('hidden');
    panel.innerHTML = '';
  }
  platformContainer?.querySelector?.('[data-danger-open]')?.classList.remove('hidden');
}

async function executeDangerZoneAction(selectedOption = null, confirmButton = null) {
  const resultPanel = platformContainer?.querySelector?.('#danger-result');
  const projectId = platformContainer?.querySelector?.('#danger-org-select')?.value || '';
  const option = selectedOption || selectedDangerOption();
  const endpoint = option === 'everything'
    ? '/api/platform/danger-zone/everything'
    : '/api/platform/danger-zone/responses';
  const payload = { projectId, confirm: 'DELETE' };
  if (confirmButton) {
    confirmButton.disabled = true;
    confirmButton.textContent = 'Deleting...';
  }
  if (resultPanel) {
    resultPanel.className = 'panel';
    resultPanel.style.marginTop = '12px';
    resultPanel.textContent = 'Deleting...';
  }
  try {
    const res = await fetch(endpoint, {
      method: 'DELETE',
      headers: {
        ...authHeaders(),
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || data.error) throw new Error(data.error || 'Deletion failed.');
    if (resultPanel) {
      const deleted = data.deleted || {};
      resultPanel.style.background = 'var(--color-success-muted)';
      resultPanel.style.borderColor = 'rgba(107,184,138,0.3)';
      resultPanel.innerHTML = `
        <strong style="color:var(--color-success);">Data cleared successfully.</strong>
        <p style="margin-top:8px;">Deleted: ${Number(deleted.findings || 0)} findings, ${Number(deleted.recommendations || 0)} recommendations, ${Number(deleted.responses || 0)} responses, ${Number(deleted.sessions || 0)} sessions.</p>
        ${Array.isArray(data.preserved) ? `<p style="margin-top:8px;color:var(--color-success);">Preserved: ${data.preserved.map(escapeHtml).join(', ')}</p>` : ''}
        <button class="text-button" data-danger-reset type="button" style="margin-top:10px;">Reset form</button>
      `;
    }
    platformContainer?.querySelector?.('#danger-form')?.classList.add('hidden');
    closeDangerConfirmation();
  } catch (err) {
    if (confirmButton) {
      confirmButton.disabled = false;
      confirmButton.textContent = 'Confirm — delete permanently';
    }
    if (resultPanel) {
      resultPanel.style.borderColor = 'rgba(224,123,90,0.25)';
      resultPanel.innerHTML = `<strong style="color:var(--color-danger);">Error</strong><p style="margin-top:8px;">${escapeHtml(err.message || 'Deletion failed.')}</p>`;
    }
  }
}

function getActivePlatformProject(platform = getSlice('platform') || {}) {
  return (platform.projects || []).find((project) => String(project.id) === String(platform.activeProjectId))
    || (platform.projects || [])[0]
    || null;
}

async function bootstrapAssessmentWorkspaceData() {
  if (platformAssessmentBootstrapPending) return;
  const platform = getSlice('platform') || {};
  const project = getActivePlatformProject(platform);
  if (!project?.id) return;
  if (String(platformAssessmentBootstrapProjectId || '') === String(project.id)) return;

  const assessment = getSlice('assessment') || {};
  if (assessment.companyProfile || assessment.projectContextIntake) return;

  platformAssessmentBootstrapPending = true;
  platformAssessmentBootstrapProjectId = project.id;
  try {
    const res = await fetch(`/api/project-context?projectId=${encodeURIComponent(project.id)}`, { headers: authHeaders() });
    const data = await res.json();
    if (res.ok && data && !data.error) {
      mergeState('assessment', {
        companyProfile: data.companyProfile || null,
        projectContextIntake: data.intake || null
      });
    }
  } catch (err) {
    console.error('Assessment workspace context bootstrap error:', err);
  } finally {
    platformAssessmentBootstrapPending = false;
  }
}

async function loadOrgAssessmentData(orgId) {
  if (!orgId || platformAssessmentDataLoading) return;
  if (String(platformAssessmentDataProjectId || '') === String(orgId)) return;

  platformAssessmentDataLoading = true;
  platformAssessmentDataProjectId = orgId;
  mergeState('assessment', {
    loading: true,
    error: null,
    selectedProjectId: orgId
  });

  try {
    const [contextPayload, enginePayload, kpiPayload] = await Promise.all([
      fetch(`/api/project-context?projectId=${encodeURIComponent(orgId)}`, { headers: authHeaders() })
        .then(async (res) => ({ ok: res.ok, payload: await res.json().catch(() => ({})) })),
      fetch(`/api/assessment-engine?projectId=${encodeURIComponent(orgId)}`, { headers: authHeaders() })
        .then(async (res) => ({ ok: res.ok, payload: await res.json().catch(() => ({})) })),
      fetch(`/api/projects/${encodeURIComponent(orgId)}/kpis`, { headers: authHeaders() })
        .then(async (res) => ({ ok: res.ok, payload: await res.json().catch(() => ({})) }))
    ]);
    const context = contextPayload.ok ? contextPayload.payload : {};
    const engine = enginePayload.ok ? enginePayload.payload : {};
    const kpiData = kpiPayload.ok ? kpiPayload.payload : {};
    const companyProfile = mergeKpiSelectionsIntoProfile(context.companyProfile || engine.companyProfile || null, kpiData);

    mergeState('assessment', {
      loading: false,
      error: context.error || engine.error || null,
      selectedProjectId: orgId,
      assessment: engine.assessment || null,
      activeAssessmentId: engine.assessment?.id || engine.activeAssessmentId || null,
      blueprint: engine.blueprint || engine.assessmentBlueprint || null,
      participants: engine.assessmentParticipants || engine.participants || [],
      sessions: engine.sessions || [],
      findings: engine.findings || [],
      evidence: engine.evidence || [],
      clusters: engine.clusters || [],
      recommendations: engine.recommendations || [],
      roadmapItems: engine.roadmapItems || [],
      kpiGaps: engine.kpiGaps || engine.kpi_gaps || [],
      coverage: engine.participantCoverage || engine.coverage || null,
      progressMemory: engine.progressMemory || null,
      companyProfile,
      projectContextIntake: context.intake || null
    });
    mergeState('platform', { activeProjectId: orgId });
  } catch (err) {
    console.error('Assessment workspace data load error:', err);
    mergeState('assessment', {
      loading: false,
      error: err.message || 'Failed to load assessment workspace.',
      selectedProjectId: orgId
    });
  } finally {
    platformAssessmentDataLoading = false;
  }
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

async function saveProjectKpiTracking(projectId, kpiKey, isTracked) {
  if (!projectId || !kpiKey) return;
  const res = await fetch(`/api/projects/${encodeURIComponent(projectId)}/kpis`, {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({
      kpi_key: kpiKey,
      is_currently_tracked: Boolean(isTracked)
    })
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || data.error) throw new Error(data.error || 'Failed to save KPI tracking.');
}

function updateLocalKpiTracking(kpiKey, isTracked) {
  const assessment = getSlice('assessment') || {};
  const profile = assessment.companyProfile || {};
  const updateList = (list = []) => list.map((kpi) =>
    String(kpi.key || kpi.kpi_key || kpi.id) === String(kpiKey)
      ? { ...kpi, is_currently_tracked: Boolean(isTracked), tracked: Boolean(isTracked) }
      : kpi
  );
  const recommended = updateList(profile.recommendedKpis || profile.recommended_kpis || []);
  mergeState('assessment', {
    companyProfile: {
      ...profile,
      recommendedKpis: recommended,
      recommended_kpis: recommended
    }
  });
}

async function bootstrapOperationsData(sectionId = platformState.operationsSection || 'overview') {
  if (platformOperationsBootstrapPending) return;
  platformOperationsBootstrapPending = true;
  mergeState('operations', {
    loading: true,
    error: null,
    section: sectionId
  });

  try {
    const sectionPathMap = {
      magic_links: 'magic-links',
      analysis: 'analysis-health',
      report: 'report-health',
      audit: 'audit-logs',
      qa: 'qa-history',
      system: 'system-health'
    };
    const apiSection = sectionPathMap[sectionId] || sectionId;
    const path = sectionId && sectionId !== 'overview'
      ? `/api/operations-center/${encodeURIComponent(apiSection)}`
      : '/api/operations-center';
    const res = await fetch(path, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok || data?.error) {
      mergeState('operations', {
        loading: false,
        error: data?.error || 'Failed to load Operations Center data.',
        section: sectionId
      });
      return;
    }

    const existing = getSlice('operations')?.krbOperationsState || {};
    const nextState = sectionId && sectionId !== 'overview'
      ? { ...existing, [sectionId.replace(/-/g, '_')]: data }
      : data;
    mergeState('operations', {
      krbOperationsState: nextState,
      loading: false,
      error: null,
      section: sectionId,
      lastRefreshed: new Date().toISOString()
    });
  } catch (err) {
    console.error('Platform operations bootstrap error:', err);
    mergeState('operations', {
      loading: false,
      error: err.message || 'Failed to load Operations Center data.',
      section: sectionId
    });
  } finally {
    platformOperationsBootstrapPending = false;
  }
}

function showToast(message, type = 'success') {
  if (typeof document === 'undefined') return;
  const toast = document.createElement('div');
  toast.style.cssText = [
    'position: fixed',
    'bottom: 24px',
    'right: 24px',
    'padding: 12px 20px',
    'background: var(--color-surface-raised, #161614)',
    'border: 1px solid var(--color-border, rgba(255,255,255,0.07))',
    'border-radius: var(--border-radius-md, 8px)',
    'font-size: 13px',
    'color: var(--color-text, #F0EDE6)',
    'box-shadow: 0 4px 24px rgba(0,0,0,0.08)',
    'z-index: 9999',
    'max-width: 320px'
  ].join(';');
  toast.dataset.toastType = type;
  toast.textContent = message;
  document.body.appendChild(toast);
  setTimeout(() => toast.remove(), 4000);
}

function renderContextStrip() {
  const environment = platformEnvironment();
  return `
    <div class="platform-context-strip">
      <article><span>Workspace</span><strong>Platform</strong></article>
      ${environment ? `<article><span>Environment</span><strong>${escapeHtml(environment)}</strong></article>` : ''}
    </div>
  `;
}

function renderNav() {
  return `
    <nav class="platform-surface-nav" aria-label="Platform navigation">
      ${PLATFORM_NAV.map((item) => `
        <button class="nav-item platform-nav-item ${platformState.activeView === item.id ? 'active' : ''}" data-platform-view="${item.id}" type="button">
          <i class="ti ${escapeHtml(item.icon || 'ti-circle')}" aria-hidden="true"></i>
          ${escapeHtml(item.label)}
        </button>
      `).join('')}
    </nav>
  `;
}

function renderLogoutBlock() {
  return `
    <div class="platform-logout-block" style="margin-top: auto; border-top: 0.5px solid var(--color-border); padding: 12px 10px;">
      <button class="nav-item platform-logout-button" data-platform-logout type="button" style="color: var(--color-text-muted);">
        <i class="ti ti-logout" aria-hidden="true"></i>
        <span>Sign out</span>
      </button>
    </div>
  `;
}

function markActiveNav() {
  platformContainer?.querySelectorAll?.('[data-platform-view]').forEach((button) => {
    button.classList.toggle('active', button.dataset.platformView === platformState.activeView);
  });
}

function activeProjectId() {
  return getSlice('platform')?.activeProjectId || null;
}

function getFrameworkRoles() {
  const framework = getSlice('framework') || {};
  return framework.roles || [];
}

function getActiveQuestionBankRole(roles = []) {
  return roles.find((role) => role.key === platformState.activeQuestionBankRole)
    || roles.find((role) => role.questions?.length)
    || roles[0]
    || null;
}

function renderPlatformCommandCenter() {
  const platform = getSlice('platform') || {};
  updateViewContainer(renderPlatformCommandCenterComponent(
    platform.metrics,
    platform.classificationFilter || platformState.classificationFilter || 'production',
    platform.commandCenterError,
    '',
    {
      onRefresh: callbacks().onRefresh,
      onClassificationFilterChange: (filter) => {
        platformState.classificationFilter = filter;
        setState('platform', 'classificationFilter', filter);
        callbacks().onSetClassificationFilter?.(filter);
        renderPlatformView('command-center');
      },
      onOpenOrganization: (projectId) => callbacks().onOpenOrganization?.(projectId),
      onOpenReport: (projectId) => callbacks().onOpenReport?.(projectId),
      onOpenOperations: () => renderPlatformView('operations'),
      onOpenUsers: () => renderPlatformView('users')
    }
  ));
}

function renderPlatformOrganizations() {
  const platform = getSlice('platform') || {};
  updateViewContainer(`
    <section class="panel">
      <div class="panel-header">
        <h2>Organization Workspaces</h2>
        <span>Platform workspace</span>
      </div>
      <div class="project-grid">
        ${renderOrganizationsComponent(
          platform.projects || [],
          platform.activeProjectId || activeProjectId(),
          '',
          {
            onOpenOrganization: callbacks().onOpenOrganization,
            onCreateOrganization: callbacks().onCreateOrganization
          }
        )}
      </div>
    </section>
  `);
}

function openPlatformAssessmentWorkspace(projectId, returnView = 'assessment') {
  if (!projectId) return;
  platformState.selectedAssessmentOrgId = projectId;
  platformState.assessmentReturnView = returnView;
  platformState.activeStage = 'setup';
  platformAssessmentDataProjectId = null;
  mergeState('platform', { activeProjectId: projectId });
  renderPlatformView('assessment');
}

function renderPlatformOperations() {
  const operations = getSlice('operations') || {};
  const activeSection = platformState.operationsSection || operations.section || 'overview';
  const hasOperationsData = operations.krbOperationsState && Object.keys(operations.krbOperationsState).length > 0;
  if (!hasOperationsData && !operations.loading && !platformOperationsBootstrapPending) {
    bootstrapOperationsData(activeSection).then(() => {
      if (platformState.activeView === 'operations') renderPlatformView('operations');
    });
  }
  updateViewContainer(renderOperationsCenterComponent(
    operations.krbOperationsState,
    activeSection,
    operations.loading || platformOperationsBootstrapPending,
    operations.error,
    operations.lastRefreshed,
    '',
    {
      onRefresh: callbacks().onRefreshOperations,
      onSectionChange: (sectionId) => {
        platformState.operationsSection = sectionId;
        bootstrapOperationsData(sectionId).then(() => {
          renderPlatformView('operations');
        });
        renderPlatformView('operations');
      },
      onOpenWorkspace: callbacks().onOpenAssessmentWorkspace,
      onOpenReport: callbacks().onOpenReport,
      onCreateIssue: callbacks().onCreateIssue,
      onResolveIssue: callbacks().onResolveIssue,
      onRecordQaRun: callbacks().onRecordQaRun,
      onParticipantAction: callbacks().onParticipantAction,
      onLinkAction: callbacks().onLinkAction
    }
  ));
}

function renderPlatformFrameworks() {
  const view = platformState.frameworkBuilderView || 'library';
  if (view === 'library') {
    updateViewContainer(renderFrameworkLibrary(
      platformState.frameworks,
      platformState.frameworksLoading || platformState.importingFleet,
      platformState.frameworksError,
      {
        onCreateFramework: showCreateFrameworkModal,
        onOpenFramework: (id) => {
          platformState.selectedFrameworkId = id;
          platformState.frameworkBuilderView = 'editor';
          platformState.frameworkEditorTab = 'identity';
          loadFrameworkDetail(id);
        },
        onImportFleet: importFleetFramework
      }
    ));
    return;
  }

  if (view === 'editor') {
    updateViewContainer(renderFrameworkEditor(
      platformState.selectedFramework,
      platformState.frameworkEditorTab,
      platformState.frameworksLoading,
      platformState.frameworksError,
      {
        onBack: () => {
          platformState.frameworkBuilderView = 'library';
          loadFrameworks();
        },
        onSaveIdentity: saveFrameworkIdentity,
        onAddBank: addFrameworkBank,
        onUpdateBank: updateFrameworkBank,
        onDeleteBank: deleteFrameworkBank,
        onAddKpi: addFrameworkKpi,
        onUpdateKpi: updateFrameworkKpi,
        onDeleteKpi: deleteFrameworkKpi,
        onTabChange: (tab) => {
          platformState.frameworkEditorTab = tab;
          renderPlatformView('frameworks');
        },
        onOpenQuestionBank: (bankId) => {
          platformState.selectedBankId = bankId;
          platformState.frameworkBuilderView = 'bank';
          platformState.questionBankPanelMode = 'editor';
          loadBankQuestions(bankId);
        },
        domains: platformState.domains || [],
        scoringConfig: platformState.scoringConfig || {}
      }
    ));
    return;
  }

  if (view === 'bank') {
    updateViewContainer(renderQuestionBankManager(
      platformState.selectedFramework,
      platformState.selectedBank,
      platformState.bankQuestions,
      platformState.domains || [],
      platformState.frameworkEditorSection,
      platformState.generatingQuestions,
      platformState.generatedDraft,
      platformState.questionBankPanelMode,
      platformState.frameworksLoading,
      platformState.frameworksError,
      {
        onBack: () => {
          platformState.frameworkBuilderView = 'editor';
          platformState.frameworkEditorTab = 'roles';
          loadFrameworkDetail(platformState.selectedFrameworkId);
        },
        onAddQuestion: addBankQuestion,
        onUpdateQuestion: updateBankQuestion,
        onDeleteQuestion: deleteBankQuestion,
        onReorderQuestions: reorderBankQuestions,
        onActivateBank: activateBank,
        onSectionChange: (section) => {
          platformState.frameworkEditorSection = section;
          renderPlatformView('frameworks');
        },
        onGenerateQuestions: generateQuestionsWithAI,
        onApproveDraftQuestion: approveDraftQuestion,
        onRejectDraftQuestion: rejectDraftQuestion,
        onApproveAllDraft: approveAllDraftQuestions,
        onClearDraft: clearGeneratedDraft
      }
    ));
    return;
  }

  updateViewContainer(renderFrameworkPreview(
    platformState.selectedFramework,
    platformState.selectedFramework?.banks || [],
    platformState.selectedFramework?.kpis || [],
    platformState.selectedFramework?.readiness || {},
    platformState.frameworksLoading,
    {
      onBack: () => {
        platformState.frameworkBuilderView = 'editor';
        renderPlatformView('frameworks');
      },
      onActivate: () => activateFramework(platformState.selectedFrameworkId),
      onOpenBank: (bankId) => {
        platformState.selectedBankId = bankId;
        platformState.frameworkBuilderView = 'bank';
        loadBankQuestions(bankId);
      },
      auditState: {
        auditing: platformState.auditingBanks,
        completing: platformState.completingBanks,
        results: platformState.auditResults || [],
        completionResults: platformState.completionResults || [],
        totalGenerated: platformState.completionTotalGenerated || 0
      }
    }
  ));
}

async function loadFrameworks() {
  platformState.frameworksLoading = true;
  if (platformState.activeView === 'frameworks') renderPlatformView('frameworks');
  try {
    const res = await fetch('/api/frameworks', { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load frameworks.');
    platformState.frameworks = data.frameworks || [];
    platformState.frameworksError = null;
  } catch (err) {
    platformState.frameworksError = 'Failed to load frameworks.';
  }
  platformState.frameworksLoading = false;
  if (platformState.activeView === 'frameworks') renderPlatformView('frameworks');
}

async function loadFrameworkDetail(id) {
  if (!id) return;
  platformState.frameworksLoading = true;
  renderPlatformView('frameworks');
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(id)}`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load framework.');
    platformState.selectedFramework = {
      ...data.framework,
      banks: data.banks || [],
      kpis: data.kpis || [],
      readiness: data.readiness || {},
      kpiCatalog: platformState.kpiCatalog || [],
      activities: platformState.frameworkActivities || []
    };
    await loadScoringConfig(id, { render: false });
    await loadDomainTaxonomy({ render: false });
    await loadKpiCatalog({ render: false });
    await loadFrameworkActivities(id, { render: false });
    platformState.selectedFramework = {
      ...platformState.selectedFramework,
      kpiCatalog: platformState.kpiCatalog || [],
      activities: platformState.frameworkActivities || []
    };
    platformState.frameworksError = null;
  } catch (err) {
    platformState.frameworksError = 'Failed to load framework.';
  }
  platformState.frameworksLoading = false;
  renderPlatformView('frameworks');
}

async function loadKpiCatalog({ render = true } = {}) {
  try {
    const res = await fetch('/api/kpis?industry=tire_fleet_service', { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load KPIs.');
    platformState.kpiCatalog = data.kpis || [];
    if (platformState.selectedFramework) {
      platformState.selectedFramework = {
        ...platformState.selectedFramework,
        kpiCatalog: platformState.kpiCatalog
      };
    }
  } catch (err) {
    platformState.frameworksError = err.message || 'Failed to load KPIs.';
  }
  if (render && platformState.activeView === 'frameworks') renderPlatformView('frameworks');
}

async function loadFrameworkActivities(frameworkId, { render = true } = {}) {
  if (!frameworkId) return;
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(frameworkId)}/activities`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load activities.');
    platformState.frameworkActivities = data.activities || [];
    if (platformState.selectedFramework) {
      platformState.selectedFramework = {
        ...platformState.selectedFramework,
        activities: platformState.frameworkActivities
      };
    }
  } catch (err) {
    platformState.frameworksError = err.message || 'Failed to load activities.';
  }
  if (render && platformState.activeView === 'frameworks') renderPlatformView('frameworks');
}

async function loadScoringConfig(frameworkId, { render = true } = {}) {
  try {
    const qs = frameworkId ? `?frameworkId=${encodeURIComponent(frameworkId)}` : '';
    const res = await fetch(`/api/scoring-config${qs}`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load scoring config.');
    platformState.scoringConfig = data.config || null;
  } catch (err) {
    platformState.frameworksError = err.message || 'Failed to load scoring config.';
  }
  if (render && platformState.activeView === 'frameworks') renderPlatformView('frameworks');
}

async function loadDomainTaxonomy({ render = true } = {}) {
  try {
    const res = await fetch('/api/domains?scope=all&industry=tire_fleet_service&include_inactive=true', { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load domains.');
    platformState.domains = data.domains || [];
    platformState.domainCategories = data.categories || [];
  } catch (err) {
    platformState.frameworksError = 'Failed to load domains.';
  }
  if (render && platformState.activeView === 'frameworks') renderPlatformView('frameworks');
}

async function loadBankQuestions(bankId) {
  if (!platformState.selectedFrameworkId || !bankId) return;
  platformState.frameworksLoading = true;
  renderPlatformView('frameworks');
  try {
    const fwId = platformState.selectedFrameworkId;
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/questions`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load questions.');
    platformState.bankQuestions = data.questions || [];
    platformState.selectedBank = platformState.selectedFramework?.banks?.find((bank) => String(bank.id) === String(bankId)) || null;
    await loadBankCoverage(bankId, { render: false });
    platformState.frameworksError = null;
  } catch (err) {
    platformState.frameworksError = 'Failed to load questions.';
  }
  platformState.frameworksLoading = false;
  renderPlatformView('frameworks');
}

async function loadBankCoverage(bankId, { render = true } = {}) {
  const fwId = platformState.selectedFrameworkId;
  if (!fwId || !bankId) return null;
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/coverage`, { headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Failed to load bank coverage.');
    if (platformState.selectedBank && String(platformState.selectedBank.id) === String(bankId)) {
      platformState.selectedBank = {
        ...platformState.selectedBank,
        coverage: data.coverage || platformState.selectedBank.coverage
      };
    }
    if (platformState.selectedFramework?.banks) {
      platformState.selectedFramework = {
        ...platformState.selectedFramework,
        banks: platformState.selectedFramework.banks.map((bank) =>
          String(bank.id) === String(bankId)
            ? { ...bank, coverage: data.coverage || bank.coverage }
            : bank
        )
      };
    }
    platformState.frameworksError = null;
    if (render && platformState.activeView === 'frameworks') renderPlatformView('frameworks');
    return data.coverage || null;
  } catch (err) {
    platformState.frameworksError = err.message || 'Failed to load bank coverage.';
    if (render && platformState.activeView === 'frameworks') renderPlatformView('frameworks');
    return null;
  }
}

async function importFleetFramework() {
  platformState.importingFleet = true;
  renderPlatformView('frameworks');
  try {
    const res = await fetch('/api/frameworks/import-fleet', { method: 'POST', headers: authHeaders() });
    const data = await res.json();
    if (!res.ok) throw new Error(data.error || 'Fleet import failed.');
    await loadFrameworks();
    showToast(`Fleet framework imported. ${data.imported_banks || 0} role banks, ${data.imported_questions || 0} questions.`);
    if (data.incomplete_banks?.length > 0) {
      showToast(`${data.incomplete_banks.length} roles have no questions yet. Use AI generation to build them.`, 'warning');
    }
  } catch (err) {
    platformState.frameworksError = 'Fleet import failed.';
  }
  platformState.importingFleet = false;
  renderPlatformView('frameworks');
}

async function saveFrameworkIdentity(data) {
  const id = platformState.selectedFrameworkId;
  const res = await fetch(`/api/frameworks/${encodeURIComponent(id)}`, {
    method: 'PUT',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  const result = await res.json();
  if (res.ok) platformState.selectedFramework = { ...platformState.selectedFramework, ...result.framework };
  else platformState.frameworksError = result.error || 'Failed to save framework.';
  renderPlatformView('frameworks');
}

async function saveScoringSettings(data) {
  const frameworkId = platformState.selectedFrameworkId;
  const current = platformState.scoringConfig || {};
  const weights = {
    breadth: Number(data.breadth || 0),
    quantity: Number(data.quantity || 0),
    depth: Number(data.depth || 0),
    response_mix: Number(data.response_mix || 0),
    activity_fit: Number(data.activity_fit || 0)
  };
  const weightTotal = Object.values(weights).reduce((sum, value) => sum + Number(value || 0), 0);
  if (weightTotal !== 100) {
    platformState.frameworksError = 'Scoring weights must total 100%.';
    renderPlatformView('frameworks');
    return;
  }
  const updates = [
    ['weights', weights],
    ['breadth_config', {
      ...(current.breadthConfig || {}),
      min_questions_per_domain: Number(data.min_questions_per_domain || 3),
      expected_domains: current.breadthConfig?.expected_domains || [
        'technology_adoption',
        'data_quality',
        'information_flow',
        'operational_execution',
        'communication_channels',
        'financial_visibility',
        'customer_perception',
        'people_capability',
        'process_standardization'
      ]
    }],
    ['quantity_config', {
      ...(current.quantityConfig || {}),
      target_per_domain: Number(data.target_per_domain || 5)
    }],
    ['depth_config', {
      ...(current.depthConfig || {}),
      deep_domain_threshold: Number(data.deep_domain_threshold || 5)
    }],
    ['quality_targets', {
      ...(current.qualityTargets || {}),
      kpi_linkage_pct: Number(data.kpi_linkage_pct || 80),
      finding_potential_pct: Number(data.finding_potential_pct || 80)
    }],
    ['grade_thresholds', {
      ...(current.gradeThresholds || {}),
      A: Number(data.grade_a || 90),
      B: Number(data.grade_b || 75),
      C: Number(data.grade_c || 60),
      D: Number(data.grade_d || 45),
      F: 0
    }]
  ];

  platformState.frameworksLoading = true;
  renderPlatformView('frameworks');
  try {
    for (const [configKey, configValue] of updates) {
      const res = await fetch('/api/scoring-config', {
        method: 'PATCH',
        headers: { ...authHeaders(), 'Content-Type': 'application/json' },
        body: JSON.stringify({
          framework_id: frameworkId,
          config_key: configKey,
          config_value: configValue
        })
      });
      const result = await res.json();
      if (!res.ok) throw new Error(result.error || 'Failed to save scoring config.');
    }
    await loadScoringConfig(frameworkId, { render: false });
    await loadFrameworkDetail(frameworkId);
    platformState.frameworksError = null;
    showToast('Scoring settings saved.');
  } catch (err) {
    platformState.frameworksError = err.message || 'Failed to save scoring settings.';
  }
  platformState.frameworksLoading = false;
  renderPlatformView('frameworks');
}

async function resetScoringSettings() {
  const frameworkId = platformState.selectedFrameworkId;
  if (!frameworkId) return;
  const res = await fetch('/api/scoring-config/reset', {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ framework_id: frameworkId })
  });
  const data = await res.json();
  if (!res.ok) {
    platformState.frameworksError = data.error || 'Failed to reset scoring settings.';
    renderPlatformView('frameworks');
    return;
  }
  platformState.scoringConfig = data.config || null;
  await loadFrameworkDetail(frameworkId);
  showToast('Scoring settings reset to defaults.');
}

async function addFrameworkBank(data) {
  const id = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(id)}/banks`, {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  await loadFrameworkDetail(id);
}

async function updateFrameworkBank(bankId, data) {
  const id = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(id)}/banks/${encodeURIComponent(bankId)}`, {
    method: 'PUT',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  await loadFrameworkDetail(id);
}

async function deleteFrameworkBank(bankId) {
  const id = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(id)}/banks/${encodeURIComponent(bankId)}`, {
    method: 'DELETE',
    headers: authHeaders()
  });
  await loadFrameworkDetail(id);
}

async function addFrameworkKpi(domainName, data) {
  const id = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(id)}/kpis`, {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ ...data, domain_name: domainName || data.domain_name })
  });
  await loadFrameworkDetail(id);
}

async function updateFrameworkKpi(kpiId, data) {
  const id = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(id)}/kpis/${encodeURIComponent(kpiId)}`, {
    method: 'PUT',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  await loadFrameworkDetail(id);
}

async function deleteFrameworkKpi(kpiId) {
  const id = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(id)}/kpis/${encodeURIComponent(kpiId)}`, {
    method: 'DELETE',
    headers: authHeaders()
  });
  await loadFrameworkDetail(id);
}

const DOMAIN_CATEGORIES = [
  'Strategic',
  'Operational',
  'Information & Technology',
  'People & Culture',
  'Customer & Market',
  'Financial',
  'Risk & Compliance',
  'External Relationships'
];

const KPI_UNITS = ['percentage', 'minutes', 'hours', 'days', 'count', 'ratio', 'currency', 'score'];
const KPI_TARGET_DIRECTIONS = ['higher_is_better', 'lower_is_better', 'target_range'];

function domainKeyFromName(name = '') {
  return String(name || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .replace(/^[^a-z]+/, '');
}

function showDomainModal({ mode = 'add', scope = 'industry', industry = 'tire_fleet_service', domain = null } = {}) {
  const existing = document.getElementById('domain-modal');
  if (existing) existing.remove();
  const isEdit = mode === 'edit' && domain;
  const modal = document.createElement('div');
  modal.id = 'domain-modal';
  modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.72);z-index:9999;display:flex;align-items:center;justify-content:center;padding:1.5rem;';
  modal.innerHTML = `
    <div style="background:#111109;border:0.5px solid rgba(200,169,110,0.25);border-radius:16px;padding:1.5rem;width:100%;max-width:520px;color:#E8E4DC;">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:1rem;">
        <div>
          <h3 style="font-size:16px;font-weight:500;margin:0;color:#E8E4DC;">${isEdit ? 'Edit domain' : 'Add domain'}</h3>
          <p style="font-size:12px;color:rgba(200,169,110,0.5);margin:2px 0 0;">${escapeHtml(scope)}${industry ? ` · ${escapeHtml(industry)}` : ''}</p>
        </div>
        <button type="button" data-domain-modal-close style="background:none;border:none;color:rgba(232,228,220,0.45);font-size:20px;cursor:pointer;">x</button>
      </div>
      <form data-domain-form style="display:grid;gap:12px;">
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Name
          <input name="name" value="${escapeHtml(domain?.name || '')}" required style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;" />
        </label>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Key
          <input name="key" value="${escapeHtml(domain?.key || '')}" ${isEdit ? 'readonly' : ''} pattern="[a-z][a-z0-9_]*" required style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;font-family:monospace;" />
          <small style="font-size:11px;color:rgba(232,228,220,0.28);text-transform:none;letter-spacing:0;">Auto-generated from name. Cannot be changed after creation.</small>
        </label>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Category
          <select name="category" required style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;appearance:auto;">
            ${DOMAIN_CATEGORIES.map((category) => `<option value="${escapeHtml(category)}" ${String(domain?.category || '') === category ? 'selected' : ''}>${escapeHtml(category)}</option>`).join('')}
          </select>
        </label>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Description
          <textarea name="description" rows="3" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;">${escapeHtml(domain?.description || '')}</textarea>
        </label>
        <div data-domain-error style="display:none;background:rgba(224,100,80,0.08);border:0.5px solid rgba(224,100,80,0.35);border-radius:8px;padding:8px 12px;color:#E07B5A;font-size:12px;"></div>
        <div style="display:flex;gap:8px;">
          <button type="button" data-domain-modal-close style="flex:1;padding:9px;border:0.5px solid rgba(200,169,110,0.2);border-radius:8px;background:transparent;color:rgba(232,228,220,0.55);cursor:pointer;">Cancel</button>
          <button type="submit" style="flex:2;padding:9px;border:none;border-radius:8px;background:#C8A96E;color:#1a1608;font-weight:500;cursor:pointer;">Save domain</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);
  const close = () => modal.remove();
  modal.querySelectorAll('[data-domain-modal-close]').forEach((button) => button.addEventListener('click', close));
  modal.addEventListener('click', (event) => {
    if (event.target === modal) close();
  });
  const nameInput = modal.querySelector('input[name="name"]');
  const keyInput = modal.querySelector('input[name="key"]');
  if (!isEdit) {
    nameInput?.addEventListener('input', () => {
      keyInput.value = domainKeyFromName(nameInput.value);
    });
  }
  modal.querySelector('[data-domain-form]')?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    const errorEl = modal.querySelector('[data-domain-error]');
    const submit = event.currentTarget.querySelector('button[type="submit"]');
    const payload = {
      key: String(form.get('key') || '').trim(),
      name: String(form.get('name') || '').trim(),
      category: String(form.get('category') || '').trim(),
      description: String(form.get('description') || '').trim(),
      scope,
      industry
    };
    if (!/^[a-z][a-z0-9_]*$/.test(payload.key)) {
      errorEl.textContent = 'Key must be lowercase snake_case and start with a letter.';
      errorEl.style.display = 'block';
      return;
    }
    submit.disabled = true;
    submit.textContent = 'Saving...';
    errorEl.style.display = 'none';
    try {
      await saveDomainTaxonomy(isEdit ? domain.id : null, payload);
      close();
    } catch (error) {
      errorEl.textContent = error.message || 'Failed to save domain.';
      errorEl.style.display = 'block';
      submit.disabled = false;
      submit.textContent = 'Save domain';
    }
  });
  setTimeout(() => nameInput?.focus(), 50);
}

async function saveDomainTaxonomy(domainId, payload) {
  const res = await fetch(domainId ? `/api/domains/${encodeURIComponent(domainId)}` : '/api/domains', {
    method: domainId ? 'PATCH' : 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(domainId ? {
      name: payload.name,
      description: payload.description,
      category: payload.category
    } : payload)
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || data.message || 'Failed to save domain.');
  if (data.warning) showToast(data.warning, 'warning');
  await loadDomainTaxonomy();
}

async function toggleDomain(domainId, isActive) {
  const res = await fetch(`/api/domains/${encodeURIComponent(domainId)}`, {
    method: 'PATCH',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ is_active: !isActive })
  });
  const data = await res.json();
  if (!res.ok) {
    showToast(data.error || 'Failed to update domain.', 'error');
    return;
  }
  if (data.warning) showToast(data.warning, 'warning');
  await loadDomainTaxonomy();
}

async function deleteDomain(domainId) {
  const domain = platformState.domains.find((item) => String(item.id) === String(domainId));
  if (!domain) return;
  if (Number(domain.question_count || 0) > 0) {
    showToast(`Cannot delete — used by ${domain.question_count} questions. Deactivate instead.`, 'error');
    return;
  }
  if (!window.confirm(`Delete '${domain.name}'? Cannot be undone.`)) return;
  const res = await fetch(`/api/domains/${encodeURIComponent(domainId)}`, {
    method: 'DELETE',
    headers: authHeaders()
  });
  const data = await res.json();
  if (!res.ok) {
    showToast(data.message || data.error || 'Failed to delete domain.', 'error');
    return;
  }
  showToast('Domain deleted.');
  await loadDomainTaxonomy();
}

function showKpiModal({ mode = 'add', kpi = null } = {}) {
  const existing = document.getElementById('kpi-modal');
  if (existing) existing.remove();
  const isEdit = mode === 'edit' && kpi;
  const activities = platformState.frameworkActivities || [];
  const selectedActivities = new Set(Array.isArray(kpi?.applicable_activities) ? kpi.applicable_activities : []);
  const modal = document.createElement('div');
  modal.id = 'kpi-modal';
  modal.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,0.72);z-index:9999;display:flex;align-items:center;justify-content:center;padding:1.5rem;';
  modal.innerHTML = `
    <div style="background:#111109;border:0.5px solid rgba(200,169,110,0.25);border-radius:16px;padding:1.5rem;width:100%;max-width:720px;max-height:90vh;overflow:auto;color:#E8E4DC;">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;margin-bottom:1rem;">
        <div>
          <h3 style="font-size:16px;font-weight:500;margin:0;color:#E8E4DC;">${isEdit ? 'Edit KPI' : 'Add KPI'}</h3>
          <p style="font-size:12px;color:rgba(200,169,110,0.5);margin:2px 0 0;">tire_fleet_service</p>
        </div>
        <button type="button" data-kpi-modal-close style="background:none;border:none;color:rgba(232,228,220,0.45);font-size:20px;cursor:pointer;">x</button>
      </div>

      ${!isEdit ? `
        <div style="display:flex;gap:8px;margin-bottom:1rem;">
          <button type="button" data-kpi-mode="ai" style="flex:1;padding:8px;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;background:rgba(200,169,110,0.1);color:#E8E4DC;cursor:pointer;">Generate with AI</button>
          <button type="button" data-kpi-mode="manual" style="flex:1;padding:8px;border:0.5px solid rgba(200,169,110,0.18);border-radius:8px;background:transparent;color:rgba(232,228,220,0.55);cursor:pointer;">Define manually</button>
        </div>
        <div data-kpi-ai-panel style="display:grid;gap:8px;margin-bottom:1rem;padding:12px;border:0.5px solid rgba(200,169,110,0.12);border-radius:10px;background:rgba(200,169,110,0.04);">
          <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
            Describe what you want to measure
            <textarea data-kpi-ai-description rows="3" placeholder="e.g. How long it takes for a fleet customer's emergency tire call to be resolved on site" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;"></textarea>
          </label>
          <button type="button" data-kpi-ai-generate style="justify-self:start;padding:8px 12px;border:none;border-radius:8px;background:#C8A96E;color:#1a1608;font-weight:500;cursor:pointer;">Generate KPI</button>
        </div>
      ` : ''}

      <form data-kpi-form style="display:grid;gap:12px;">
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
            Name EN
            <input name="name" value="${escapeHtml(kpi?.name || '')}" required style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;" />
          </label>
          <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
            Name TR
            <input name="name_tr" value="${escapeHtml(kpi?.name_tr || '')}" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;" />
          </label>
        </div>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Key
          <input name="key" value="${escapeHtml(kpi?.key || '')}" ${isEdit ? 'readonly' : ''} pattern="[a-z][a-z0-9_]*" required style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;font-family:monospace;" />
        </label>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Description EN
          <textarea name="description" rows="2" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;">${escapeHtml(kpi?.description || '')}</textarea>
        </label>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Description TR
          <textarea name="description_tr" rows="2" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;">${escapeHtml(kpi?.description_tr || '')}</textarea>
        </label>
        <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
          Why it matters
          <textarea name="why_it_matters" rows="3" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;">${escapeHtml(kpi?.why_it_matters || '')}</textarea>
        </label>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
          <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
            Unit
            <select name="unit" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;appearance:auto;">
              ${KPI_UNITS.map((unit) => `<option value="${unit}" ${String(kpi?.unit || '') === unit ? 'selected' : ''}>${unit}</option>`).join('')}
            </select>
          </label>
          <label style="display:grid;gap:5px;font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">
            Target direction
            <select name="target_direction" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.3);border-radius:8px;padding:9px 12px;color:#E8E4DC;font-size:13px;outline:none;appearance:auto;">
              ${KPI_TARGET_DIRECTIONS.map((direction) => `<option value="${direction}" ${String(kpi?.target_direction || '') === direction ? 'selected' : ''}>${direction}</option>`).join('')}
            </select>
          </label>
        </div>
        <label style="display:flex;gap:8px;align-items:center;color:rgba(232,228,220,0.62);font-size:13px;">
          <input type="checkbox" name="is_default" ${kpi?.is_default !== false ? 'checked' : ''} />
          Default KPI
        </label>
        <div style="display:grid;gap:8px;">
          <div style="font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(232,228,220,0.35);">Applicable activities</div>
          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(190px,1fr));gap:8px;">
            ${activities.map((activity) => `
              <label style="display:flex;gap:8px;align-items:flex-start;padding:8px;border:0.5px solid rgba(200,169,110,0.12);border-radius:8px;color:rgba(232,228,220,0.62);font-size:12px;">
                <input type="checkbox" name="applicable_activities" value="${escapeHtml(activity.key)}" ${selectedActivities.has(activity.key) ? 'checked' : ''} />
                <span>${escapeHtml(activity.label || activity.key)}<br><small style="color:rgba(200,169,110,0.4);">${escapeHtml(activity.group_name || '')}</small></span>
              </label>
            `).join('')}
          </div>
        </div>
        <div data-kpi-error style="display:none;background:rgba(224,100,80,0.08);border:0.5px solid rgba(224,100,80,0.35);border-radius:8px;padding:8px 12px;color:#E07B5A;font-size:12px;"></div>
        <div style="display:flex;gap:8px;">
          <button type="button" data-kpi-modal-close style="flex:1;padding:9px;border:0.5px solid rgba(200,169,110,0.2);border-radius:8px;background:transparent;color:rgba(232,228,220,0.55);cursor:pointer;">Cancel</button>
          <button type="submit" style="flex:2;padding:9px;border:none;border-radius:8px;background:#C8A96E;color:#1a1608;font-weight:500;cursor:pointer;">Save KPI</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(modal);
  const close = () => modal.remove();
  modal.querySelectorAll('[data-kpi-modal-close]').forEach((button) => button.addEventListener('click', close));
  modal.addEventListener('click', (event) => {
    if (event.target === modal) close();
  });
  const formEl = modal.querySelector('[data-kpi-form]');
  const nameInput = formEl?.querySelector('input[name="name"]');
  const keyInput = formEl?.querySelector('input[name="key"]');
  if (!isEdit) {
    nameInput?.addEventListener('input', () => {
      if (keyInput) keyInput.value = domainKeyFromName(nameInput.value);
    });
  }
  modal.querySelectorAll('[data-kpi-mode]').forEach((button) => {
    button.addEventListener('click', () => {
      const aiPanel = modal.querySelector('[data-kpi-ai-panel]');
      const aiMode = button.dataset.kpiMode === 'ai';
      if (aiPanel) aiPanel.style.display = aiMode ? 'grid' : 'none';
      modal.querySelectorAll('[data-kpi-mode]').forEach((modeButton) => {
        const active = modeButton.dataset.kpiMode === button.dataset.kpiMode;
        modeButton.style.background = active ? 'rgba(200,169,110,0.1)' : 'transparent';
        modeButton.style.color = active ? '#E8E4DC' : 'rgba(232,228,220,0.55)';
      });
    });
  });
  modal.querySelector('[data-kpi-ai-generate]')?.addEventListener('click', async (event) => {
    const button = event.currentTarget;
    const description = modal.querySelector('[data-kpi-ai-description]')?.value?.trim();
    const errorEl = modal.querySelector('[data-kpi-error]');
    if (!description) {
      errorEl.textContent = 'Describe what this KPI should measure.';
      errorEl.style.display = 'block';
      return;
    }
    button.disabled = true;
    button.textContent = 'Generating...';
    errorEl.style.display = 'none';
    try {
      const generated = await generateKpiDefinition(description);
      fillKpiForm(formEl, generated);
    } catch (error) {
      errorEl.textContent = error.message || 'Failed to generate KPI.';
      errorEl.style.display = 'block';
    } finally {
      button.disabled = false;
      button.textContent = 'Generate KPI';
    }
  });
  formEl?.addEventListener('submit', async (event) => {
    event.preventDefault();
    const errorEl = modal.querySelector('[data-kpi-error]');
    const submit = event.currentTarget.querySelector('button[type="submit"]');
    const payload = readKpiForm(event.currentTarget);
    if (!/^[a-z][a-z0-9_]*$/.test(payload.key)) {
      errorEl.textContent = 'Key must be lowercase snake_case and start with a letter.';
      errorEl.style.display = 'block';
      return;
    }
    submit.disabled = true;
    submit.textContent = 'Saving...';
    errorEl.style.display = 'none';
    try {
      await saveKpiCatalog(isEdit ? kpi.id : null, payload);
      close();
    } catch (error) {
      errorEl.textContent = error.message || 'Failed to save KPI.';
      errorEl.style.display = 'block';
      submit.disabled = false;
      submit.textContent = 'Save KPI';
    }
  });
  setTimeout(() => (nameInput || modal.querySelector('[data-kpi-ai-description]'))?.focus(), 50);
}

function readKpiForm(formEl) {
  const form = new FormData(formEl);
  return {
    key: String(form.get('key') || '').trim(),
    name: String(form.get('name') || '').trim(),
    name_tr: String(form.get('name_tr') || '').trim(),
    description: String(form.get('description') || '').trim(),
    description_tr: String(form.get('description_tr') || '').trim(),
    why_it_matters: String(form.get('why_it_matters') || '').trim(),
    industry: 'tire_fleet_service',
    applicable_activities: form.getAll('applicable_activities').map(String),
    unit: String(form.get('unit') || '').trim(),
    target_direction: String(form.get('target_direction') || '').trim(),
    is_default: form.get('is_default') === 'on'
  };
}

function fillKpiForm(formEl, data = {}) {
  if (!formEl) return;
  const setValue = (name, value) => {
    const el = formEl.querySelector(`[name="${name}"]`);
    if (el) el.value = value || '';
  };
  setValue('key', data.key);
  setValue('name', data.name);
  setValue('name_tr', data.name_tr);
  setValue('description', data.description);
  setValue('description_tr', data.description_tr);
  setValue('why_it_matters', data.why_it_matters);
  setValue('unit', data.unit || 'percentage');
  setValue('target_direction', data.target_direction || 'higher_is_better');
  const selected = new Set(Array.isArray(data.applicable_activities) ? data.applicable_activities : []);
  formEl.querySelectorAll('input[name="applicable_activities"]').forEach((input) => {
    input.checked = selected.has(input.value);
  });
  const defaultEl = formEl.querySelector('input[name="is_default"]');
  if (defaultEl) defaultEl.checked = data.is_default !== false;
}

async function generateKpiDefinition(description) {
  const res = await fetch('/api/kpis/generate', {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ description, industry: 'tire_fleet_service' })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Failed to generate KPI.');
  return data.kpi || {};
}

async function saveKpiCatalog(kpiId, payload) {
  const res = await fetch(kpiId ? `/api/kpis/${encodeURIComponent(kpiId)}` : '/api/kpis', {
    method: kpiId ? 'PATCH' : 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(kpiId ? {
      name: payload.name,
      name_tr: payload.name_tr,
      description: payload.description,
      description_tr: payload.description_tr,
      why_it_matters: payload.why_it_matters,
      industry: payload.industry,
      applicable_activities: payload.applicable_activities,
      unit: payload.unit,
      target_direction: payload.target_direction,
      is_default: payload.is_default
    } : payload)
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || data.message || 'Failed to save KPI.');
  showToast('KPI saved.');
  await loadKpiCatalog();
}

async function toggleKpiCatalog(kpiId, isActive) {
  const res = await fetch(`/api/kpis/${encodeURIComponent(kpiId)}`, {
    method: 'PATCH',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ is_active: !isActive })
  });
  const data = await res.json();
  if (!res.ok) {
    showToast(data.error || 'Failed to update KPI.', 'error');
    return;
  }
  await loadKpiCatalog();
}

async function deleteKpiCatalog(kpiId) {
  const kpi = platformState.kpiCatalog.find((item) => String(item.id) === String(kpiId));
  if (!kpi) return;
  if (Number(kpi.question_count || 0) > 0) {
    showToast(`Cannot delete — linked to ${kpi.question_count} questions. Deactivate instead.`, 'error');
    return;
  }
  if (!window.confirm(`Delete '${kpi.name}'? Cannot be undone.`)) return;
  const res = await fetch(`/api/kpis/${encodeURIComponent(kpiId)}`, {
    method: 'DELETE',
    headers: authHeaders()
  });
  const data = await res.json();
  if (!res.ok) {
    showToast(data.message || data.error || 'Failed to delete KPI.', 'error');
    return;
  }
  showToast('KPI deleted.');
  await loadKpiCatalog();
}

async function addBankQuestion(data) {
  const fwId = platformState.selectedFrameworkId;
  const bankId = platformState.selectedBankId;
  await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/questions`, {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  await loadBankQuestions(bankId);
}

async function updateBankQuestion(id, data) {
  const fwId = platformState.selectedFrameworkId;
  const bankId = platformState.selectedBankId;
  await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/questions/${encodeURIComponent(id)}`, {
    method: 'PUT',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  await loadBankQuestions(bankId);
}

async function deleteBankQuestion(id) {
  const fwId = platformState.selectedFrameworkId;
  const bankId = platformState.selectedBankId;
  await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/questions/${encodeURIComponent(id)}`, {
    method: 'DELETE',
    headers: authHeaders()
  });
  await loadBankQuestions(bankId);
}

async function reorderBankQuestions(order) {
  const fwId = platformState.selectedFrameworkId;
  const bankId = platformState.selectedBankId;
  await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/questions/reorder`, {
    method: 'PATCH',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ order })
  });
  await loadBankQuestions(bankId);
}

async function activateBank(bankId) {
  const fwId = platformState.selectedFrameworkId;
  await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/activate`, {
    method: 'POST',
    headers: authHeaders()
  });
  await loadBankQuestions(bankId);
  await loadFrameworkDetail(fwId);
}

async function activateFramework(id) {
  platformState.frameworksLoading = true;
  renderPlatformView('frameworks');
  const res = await fetch(`/api/frameworks/${encodeURIComponent(id)}/activate`, {
    method: 'POST',
    headers: authHeaders()
  });
  const data = await res.json();
  if (data.error) platformState.frameworksError = data.error;
  else {
    platformState.selectedFramework = { ...platformState.selectedFramework, ...data.framework };
    showToast('Framework activated.');
  }
  platformState.frameworksLoading = false;
  renderPlatformView('frameworks');
}

async function generateQuestionsWithAI(formData = {}) {
  const fwId = platformState.selectedFrameworkId;
  const bankId = platformState.selectedBankId;
  platformState.generatingQuestions = true;
  platformState.generatedDraft = null;
  platformState.frameworksError = null;
  renderPlatformView('frameworks');
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/generate-questions`, {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify(formData)
    });
    console.log('[GENERATE] Response status:', res.status);
    const data = await res.json();
    console.log('[GENERATE] Response data:', JSON.stringify(data).slice(0, 200));
    if (data.error) {
      console.error('[GENERATE] Server error:', data.error);
      platformState.frameworksError = data.error;
    } else {
      platformState.generatedDraft = (data.questions || []).map((question) => ({
        ...question,
        _status: 'pending',
        _localId: globalThis.crypto?.randomUUID?.() || `draft-${Date.now()}-${Math.random().toString(16).slice(2)}`
      }));
      showToast(`${data.count} questions generated. Review and approve below.`);
    }
  } catch (err) {
    console.error('[GENERATE] Client error:', err.message, err);
    platformState.frameworksError = `Generation failed: ${err.message}`;
  }
  platformState.generatingQuestions = false;
  renderPlatformView('frameworks');
}

async function approveDraftQuestion(q) {
  if (!platformState.generatedDraft || !q) return;
  platformState.generatedDraft = platformState.generatedDraft.map((draft) =>
    draft._localId === q._localId ? { ...draft, _status: 'approved' } : draft
  );
  const fwId = platformState.selectedFrameworkId;
  const bankId = platformState.selectedBankId;
  const questionData = { ...q };
  delete questionData._status;
  delete questionData._localId;
  delete questionData.framework_id;
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/banks/${encodeURIComponent(bankId)}/questions`, {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify(questionData)
    });
    if (!res.ok) throw new Error('Failed to save question.');
    await loadBankQuestions(bankId);
  } catch (err) {
    showToast('Failed to save question.', 'error');
    platformState.generatedDraft = platformState.generatedDraft.map((draft) =>
      draft._localId === q._localId ? { ...draft, _status: 'pending' } : draft
    );
  }
  renderPlatformView('frameworks');
}

function rejectDraftQuestion(q) {
  if (!platformState.generatedDraft || !q) return;
  platformState.generatedDraft = platformState.generatedDraft.map((draft) =>
    draft._localId === q._localId ? { ...draft, _status: 'rejected' } : draft
  );
  renderPlatformView('frameworks');
}

async function approveAllDraftQuestions() {
  if (!platformState.generatedDraft) return;
  const pending = platformState.generatedDraft.filter((draft) => draft._status === 'pending');
  for (const q of pending) {
    await approveDraftQuestion(q);
  }
}

function clearGeneratedDraft() {
  platformState.generatedDraft = null;
  platformState.generatingQuestions = false;
  renderPlatformView('frameworks');
}

async function platformAuditAllBanks() {
  const fwId = platformState.selectedFrameworkId;
  if (!fwId) return;
  platformState.auditingBanks = true;
  platformState.auditResults = null;
  platformState.completionResults = null;
  platformState.frameworksError = null;
  renderPlatformView('frameworks');
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/audit-all`, {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' }
    });
    const data = await res.json();
    if (!res.ok || data.error) throw new Error(data.error || 'Audit failed.');
    platformState.auditResults = data.results || [];
    showToast(`Audit complete. ${data.total_remove || 0} questions recommended for removal.`);
  } catch (err) {
    platformState.frameworksError = `Audit failed: ${err.message}`;
    showToast(platformState.frameworksError, 'error');
  }
  platformState.auditingBanks = false;
  renderPlatformView('frameworks');
}

async function platformApplyAudit(results = platformState.auditResults, { clearAll = true } = {}) {
  const fwId = platformState.selectedFrameworkId;
  if (!fwId || !results?.length) return;
  const banks = results.map((result) => ({
    bank_id: result.bank_id,
    remove: (result.remove || []).map((item) => item.question_id),
    replace: (result.replace || []).map((item) => ({
      question_id: item.question_id,
      new_text: item.replacement_text
    }))
  }));
  platformState.frameworksLoading = true;
  renderPlatformView('frameworks');
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/audit-all/apply`, {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ banks })
    });
    const data = await res.json();
    if (!res.ok || data.error) throw new Error(data.error || 'Apply audit failed.');
    if (clearAll) {
      platformState.auditResults = null;
    } else {
      const appliedIds = new Set(results.map((result) => String(result.bank_id)));
      platformState.auditResults = (platformState.auditResults || []).filter((result) => !appliedIds.has(String(result.bank_id)));
    }
    showToast(`Applied: ${data.total_removed} removed, ${data.total_replaced} improved.`);
    await loadFrameworkDetail(fwId);
  } catch (err) {
    platformState.frameworksError = `Apply failed: ${err.message}`;
    showToast(platformState.frameworksError, 'error');
  }
  platformState.frameworksLoading = false;
  renderPlatformView('frameworks');
}

async function platformApplyBankAudit(bankId) {
  const result = (platformState.auditResults || []).find((bank) => String(bank.bank_id) === String(bankId));
  if (!result) return;
  await platformApplyAudit([result], { clearAll: false });
}

async function platformCompleteAllBanks() {
  const fwId = platformState.selectedFrameworkId;
  if (!fwId) return;
  platformState.completingBanks = true;
  platformState.frameworksError = null;
  renderPlatformView('frameworks');
  try {
    const res = await fetch(`/api/frameworks/${encodeURIComponent(fwId)}/complete-all-banks`, {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' }
    });
    const data = await res.json();
    if (!res.ok || data.error) throw new Error(data.error || 'Completion failed.');
    platformState.completionResults = data.banks || [];
    platformState.completionTotalGenerated = data.total_generated || 0;
    showToast(`Complete: ${data.total_generated || 0} questions added across ${(data.banks || []).length} banks.`);
    await loadFrameworkDetail(fwId);
  } catch (err) {
    platformState.frameworksError = `Completion failed: ${err.message}`;
    showToast(platformState.frameworksError, 'error');
  }
  platformState.completingBanks = false;
  renderPlatformView('frameworks');
}

function undoDraftQuestion(localId) {
  if (!platformState.generatedDraft) return;
  platformState.generatedDraft = platformState.generatedDraft.map((draft) =>
    draft._localId === localId ? { ...draft, _status: 'pending' } : draft
  );
  renderPlatformView('frameworks');
}

function updateDraftField(localId, field, value) {
  if (!platformState.generatedDraft) return;
  platformState.generatedDraft = platformState.generatedDraft.map((draft) =>
    draft._localId === localId ? { ...draft, [field]: value } : draft
  );
}

function formEntries(form) {
  const data = Object.fromEntries(new FormData(form).entries());
  const targetDomains = new FormData(form).getAll('target_domains').map((item) => String(item).trim()).filter(Boolean);
  if (targetDomains.length) data.target_domains = targetDomains;
  for (const key of ['kpi_outputs', 'problem_types_detectable', 'impact_dimensions', 'recommendation_triggers']) {
    if (data[key]) data[key] = String(data[key]).split(',').map((item) => item.trim()).filter(Boolean);
  }
  if (data.follow_up_questions) data.follow_up_questions = String(data.follow_up_questions).split('\n').map((item) => item.trim()).filter(Boolean);
  if (data.required !== undefined) data.required = data.required === 'true';
  if (data.follow_up_enabled !== undefined) data.follow_up_enabled = data.follow_up_enabled === 'true';
  if (data.gap_calculation_enabled !== undefined) data.gap_calculation_enabled = data.gap_calculation_enabled === 'true';
  for (const key of ['version', 'target_min', 'target_max', 'target_value', 'count']) {
    if (data[key] === '') delete data[key];
    else if (data[key] !== undefined) data[key] = Number(data[key]);
  }
  return data;
}

function showCreateFrameworkModal() {
  if (typeof window === 'undefined') return;
  const name = window.prompt('Framework name:');
  if (!name) return;
  const industry = window.prompt('Industry:');
  if (!industry) return;
  fetch('/api/frameworks', {
    method: 'POST',
    headers: { ...authHeaders(), 'Content-Type': 'application/json' },
    body: JSON.stringify({ name, industry })
  }).then(() => loadFrameworks());
}

function renderPlatformUsers() {
  const platform = getSlice('platform') || {};
  const users = Object.values(platform.users || {});
  const projects = Array.isArray(platform.projects) ? platform.projects : [];
  const roleLabel = (role = '') => String(role || '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase());
  const roleStyle = (role = '') => {
    const styles = {
      consultant: 'background: rgba(200,169,110,0.1); color: #C8A96E; border: 0.5px solid rgba(200,169,110,0.25);',
      company_owner: 'background: rgba(100,140,200,0.1); color: rgba(140,180,240,0.9); border: 0.5px solid rgba(100,140,200,0.25);',
      platform_owner: 'background: rgba(180,100,200,0.1); color: rgba(210,150,240,0.9); border: 0.5px solid rgba(180,100,200,0.25);',
      assessment_manager: 'background: rgba(100,180,140,0.1); color: rgba(140,210,170,0.9); border: 0.5px solid rgba(100,180,140,0.25);'
    };
    return styles[role] || 'background: rgba(232,228,220,0.06); color: rgba(232,228,220,0.7); border: 0.5px solid rgba(232,228,220,0.15);';
  };
  const organizationName = (user) => {
    const projectId = user.projectId || user.project_id || user.companyId || user.company_id;
    const project = projects.find((item) => String(item.id) === String(projectId));
    return user.organizationName || user.companyName || user.clientDisplayName || project?.clientDisplayName || project?.organizationName || project?.name || '';
  };
  const rows = users.map((user) => {
    const userId = user.id || user.email;
    const role = user.role || 'participant';
    const status = String(user.status || 'active').toLowerCase();
    const active = status !== 'disabled' && status !== 'inactive';
    const orgName = organizationName(user);
    const orgCell = orgName
      ? `<span style="font-size: 12px; color: rgba(232,228,220,0.6);">${escapeHtml(orgName)}</span>`
      : role === 'platform_owner'
        ? `<span style="font-size: 12px; color: rgba(232,228,220,0.2); font-style: italic;">Platform level</span>`
        : `<span style="font-size: 12px; color: rgba(232,228,220,0.2); font-style: italic;">No org assigned</span>`;
    return `
      <div style="display: grid; grid-template-columns: 2fr 2.5fr 1.5fr 1fr 1fr 160px; padding: 12px 1.25rem; border-bottom: 0.5px solid rgba(200,169,110,0.07); align-items: center;" onmouseover="this.style.background='rgba(200,169,110,0.03)'" onmouseout="this.style.background='transparent'">
        <div style="font-size: 13px; font-weight: 500; color: #E8E4DC;">${escapeHtml(user.name || user.fullName || user.email || 'Unnamed user')}</div>
        <div style="font-size: 12px; color: rgba(232,228,220,0.4);">${escapeHtml(user.email || '')}</div>
        <div>${orgCell}</div>
        <div>
          <span style="display: inline-flex; padding: 3px 9px; border-radius: 20px; font-size: 11px; font-weight: 500; ${roleStyle(role)}">${escapeHtml(roleLabel(role))}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 5px;">
          <span style="width: 6px; height: 6px; border-radius: 50%; background: ${active ? '#C8A96E' : '#444'};"></span>
          <span style="font-size: 12px; color: rgba(232,228,220,0.5);">${active ? 'Active' : 'Inactive'}</span>
        </div>
        <div style="display: flex; align-items: center; gap: 6px;">
          <button type="button" data-component-edit-user="${escapeHtml(userId)}" style="padding: 4px 9px; font-size: 11px; border: 0.5px solid rgba(200,169,110,0.2); border-radius: 6px; background: transparent; color: rgba(200,169,110,0.6); cursor: pointer;">Edit</button>
          <button type="button" data-component-send-credentials="${escapeHtml(userId)}" style="padding: 4px 9px; font-size: 11px; border: 0.5px solid rgba(200,169,110,0.2); border-radius: 6px; background: transparent; color: rgba(200,169,110,0.6); cursor: pointer;">Creds</button>
          <button type="button" data-component-disable-user="${escapeHtml(userId)}" style="padding: 4px 9px; font-size: 11px; border: 0.5px solid rgba(224,100,80,0.2); border-radius: 6px; background: transparent; color: rgba(224,100,80,0.5); cursor: pointer;">Disable</button>
        </div>
      </div>
    `;
  }).join('');
  updateViewContainer(`
    <section>
      <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 1.5rem;">
        <div>
          <h2 style="font-size: 18px; font-weight: 500; color: #E8E4DC; margin: 0;">Users & Access</h2>
          <p style="font-size: 13px; color: rgba(200,169,110,0.6); margin: 2px 0 0;">${users.length} users &middot; Platform owner only</p>
        </div>
        <button type="button" data-component-create-user style="background: #C8A96E; color: #1a1608; font-size: 13px; font-weight: 500; padding: 8px 14px; border-radius: 8px; border: none; display: flex; align-items: center; gap: 6px; cursor: pointer;">
          <i class="ti ti-plus" style="font-size: 15px;"></i>
          <span>New user</span>
        </button>
      </div>
      <div style="background: #111109; border: 0.5px solid rgba(200,169,110,0.18); border-radius: 12px; overflow: hidden;">
        <div style="display: grid; grid-template-columns: 2fr 2.5fr 1.5fr 1fr 1fr 160px; padding: 10px 1.25rem; border-bottom: 0.5px solid rgba(200,169,110,0.12);">
          ${['USER', 'EMAIL', 'ORGANIZATION', 'ROLE', 'STATUS', 'ACTIONS'].map((label) => `<div style="font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: rgba(200,169,110,0.4);">${label}</div>`).join('')}
        </div>
        ${rows || `<div style="padding: 1.25rem; color: rgba(232,228,220,0.45); font-size: 13px;">No users yet.</div>`}
      </div>
    </section>
  `);
}

function renderPlatformAssessmentWorkspace() {
  const assessment = getSlice('assessment') || {};
  const executive = getSlice('executive') || {};
  const platform = getSlice('platform') || {};
  const ops = getSlice('operations') || {};
  const projects = platform.projects || [];
  const selectedOrgId = platformState.selectedAssessmentOrgId;

  if (!selectedOrgId) {
    if ((!Array.isArray(projects) || projects.length === 0) && !platformAssessmentBootstrapPending) {
      bootstrapPlatformData().then(() => {
        if (platformState.activeView === 'assessment' && !platformState.selectedAssessmentOrgId) {
          renderPlatformView('assessment');
        }
      });
    }
    updateViewContainer(`
      <section class="panel">
        <div class="panel-header">
          <div>
            <span class="eyebrow">Assessment Workspaces</span>
            <h2>Select an organization</h2>
            <span>Open an organization's active assessment workspace.</span>
          </div>
          <button class="secondary-button" data-platform-view="organizations" type="button">Go to Organizations</button>
        </div>
        ${Array.isArray(projects) && projects.length ? `
          <div class="card-grid">
            ${projects.map((org) => {
              const orgName = org.clientDisplayName || org.client_display_name || org.organizationName || org.organization_name || org.name || 'Organization';
              const assessmentName = org.name || org.projectName || org.project_name || 'No active assessment';
              const status = org.status || 'not-started';
              return `
                <article class="card">
                  <div class="panel-header">
                    <div>
                      <h3>${escapeHtml(orgName)}</h3>
                      <span>${escapeHtml(assessmentName)}</span>
                    </div>
                    <span class="status-pill ${escapeHtml(statusClass(status))}">${escapeHtml(status)}</span>
                  </div>
                  <dl class="detail-list">
                    <div><dt>Industry</dt><dd>${escapeHtml(org.industryContext || org.industry_context || org.industry || 'Not set')}</dd></div>
                    <div><dt>Responses</dt><dd>${escapeHtml(org.responseCount ?? org.response_count ?? 0)}</dd></div>
                  </dl>
                  <div class="row-actions">
                    <button class="primary-button" data-platform-assessment-open="${escapeHtml(org.id)}" type="button">Open Workspace</button>
                  </div>
                </article>
              `;
            }).join('')}
          </div>
        ` : `
          ${renderScreenState('platform-assessment-orgs', 'empty', {
            title: 'No organizations yet.',
            message: 'Create an organization first.',
            compact: true
          })}
          <button class="primary-button" data-platform-view="organizations" type="button">Go to Organizations</button>
        `}
      </section>
    `);
    return;
  }

  const project = projects.find((item) => String(item.id) === String(selectedOrgId)) || null;
  const projectNeedsLoad = String(assessment.selectedProjectId || '') !== String(selectedOrgId);
  if (projectNeedsLoad && !assessment.loading && !platformAssessmentDataLoading) {
    loadOrgAssessmentData(selectedOrgId).then(() => {
      if (platformState.activeView === 'assessment' && String(platformState.selectedAssessmentOrgId || '') === String(selectedOrgId)) {
        renderPlatformView('assessment');
      }
    });
  }

  if (platformState.activeStage === 'operations') {
    const hasOperationsData = ops.krbOperationsState && Object.keys(ops.krbOperationsState).length > 0;
    if (!hasOperationsData && !ops.loading && !platformOperationsBootstrapPending) {
      bootstrapOperationsData('overview').then(() => {
        if (platformState.activeView === 'assessment' && platformState.activeStage === 'operations') {
          renderPlatformView('assessment');
        }
      });
    }
  }

  const profile = assessment.companyProfile || assessment.company_profile || null;
  const intake = assessment.projectContextIntake || assessment.project_context_intake || null;
  const organization = project
    ? {
        ...project,
        companyProfile: profile,
        projectContextIntake: intake,
        contextData: intake?.contextData || intake?.context_data || null
      }
    : {
        companyProfile: profile,
        projectContextIntake: intake,
        contextData: intake?.contextData || intake?.context_data || null
      };
  const activeAssessment = assessment.assessment || {
    ...assessment,
    id: assessment.activeAssessmentId || assessment.id
  };
  const progressData = platformState.progressIntelligenceByProject[selectedOrgId] || null;
  const healthSnapshots = progressData?.snapshots?.length
    ? progressData.snapshots
    : snapshotsFromProgressMemory(assessment.progressMemory);
  const organizationName = organization?.clientDisplayName || organization?.client_display_name || organization?.name || 'Selected organization';
  const workspaceHtml = renderAssessmentWorkspaceComponent(
    platformState.activeStage,
    organization,
    activeAssessment,
    assessment.blueprint,
    assessment.participants || [],
    assessment.sessions || [],
    assessment.findings || [],
    assessment.evidence || [],
    assessment.recommendations || [],
    assessment.roadmapItems || [],
    assessment.kpiGaps || [],
    assessment.clusters || [],
    assessment.coverage,
    assessment.progressMemory,
    assessment.uploadPreview,
    assessment.importSummary,
    assessment.invitationSummary,
    assessment.invitationPreview,
    assessment.reminderSummary,
    assessment.reminderPreview,
    platformState.filterState,
    platformState.selectedFindingId,
    platformState.reportToggles,
    executive.report,
    ops.krbOperationsState,
    '',
    {
      onStageChange: (stageId) => {
        platformState.activeStage = stageId;
        renderPlatformView('assessment');
      },
      onSelectFinding: (id) => {
        platformState.selectedFindingId = id;
        renderPlatformView('assessment');
      },
      onFilterChange: (key, val) => {
        platformState.filterState[key] = val;
        renderPlatformView('assessment');
      },
      onRunAnalysis: () => callbacks().onRunAnalysis?.(),
      onCreateAssessment: () => callbacks().onCreateAssessment?.(),
      onViewFramework: () => renderPlatformView('frameworks'),
      onOpenOperationsCenter: () => renderPlatformView('operations'),
      onGenerateReport: () => callbacks().onGenerateReport?.(),
      onToggleSection: (key, val) => {
        platformState.reportToggles[key] = val;
        renderPlatformView('assessment');
      },
      onExportReport: (type) => callbacks().onExportReport?.(type),
      onViewReport: () => {
        platformState.activeStage = 'executive';
        renderPlatformView('assessment');
      },
      onGenerateSnapshot: () => callbacks().onGenerateSnapshot?.(),
      onRegenerateSnapshot: () => callbacks().onRegenerateSnapshot?.(),
      selectedFindingIds: platformState.selectedFindingIds || [],
      selectedRecommendationIds: platformState.selectedRecommendationIds || [],
      onApproveFinding: (id) => callbacks().onApproveFinding?.(id),
      onRejectFinding: (id) => callbacks().onRejectFinding?.(id),
      onEditFinding: (id, text) => callbacks().onEditFinding?.(id, text),
      onFindingNotes: (id, notes) => callbacks().onFindingNotes?.(id, notes),
      onDeleteFinding: (id) => callbacks().onDeleteFinding?.(id),
      onMergeFindings: (ids) => callbacks().onMergeFindings?.(ids),
      onMergeCluster: (cluster) => callbacks().onMergeCluster?.(cluster),
      onApproveRecommendation: (id) => window.updateRecommendation?.(id, { status: 'approved' }),
      onRejectRecommendation: (id) => window.updateRecommendation?.(id, { status: 'rejected' }),
      onRecommendationStatus: (id, status) => window.updateRecommendation?.(id, { status }),
      onRecommendationNotes: (id, notes) => callbacks().onRecommendationNotes?.(id, notes),
      onTrackOutcome: (id, outcome) => callbacks().onTrackOutcome?.(id, outcome),
      onAddParticipant: (data) => callbacks().onAddParticipant?.(data),
      onEditParticipant: (id, data) => callbacks().onEditParticipant?.(id, data),
      onDeactivateParticipant: (id) => callbacks().onDeactivateParticipant?.(id),
      onCreateSession: (participantId) => callbacks().onCreateSession?.(participantId),
      onGenerateLink: (participantId) => callbacks().onGenerateLink?.(participantId),
      onCopyLink: (link) => callbacks().onCopyLink?.(link),
      onPreviewInvite: (id) => callbacks().onPreviewInvite?.(id),
      onSendInvite: (id, opts) => callbacks().onSendInvite?.(id, opts),
      onPreviewReminder: (id) => callbacks().onPreviewReminder?.(id),
      onSendReminder: (id, opts) => callbacks().onSendReminder?.(id, opts),
      onDownloadTemplate: () => callbacks().onDownloadTemplate?.(),
      onPreviewUpload: (file) => callbacks().onPreviewUpload?.(file),
      onConfirmImport: () => callbacks().onConfirmImport?.(),
      onCreateSessionsForImported: () => callbacks().onCreateSessionsForImported?.(),
      onDownloadErrors: () => callbacks().onDownloadErrors?.(),
      onFileSelected: (file) => callbacks().onFileSelected?.(file),
      onBulkSendInvites: () => callbacks().onBulkSendInvites?.(),
      onInviteScopeChange: (scope) => callbacks().onInviteScopeChange?.(scope),
      onBulkSendReminders: () => callbacks().onBulkSendReminders?.(),
      onReminderScopeChange: (scope) => callbacks().onReminderScopeChange?.(scope)
    }
  );
  updateViewContainer(`
    <section class="assessment-workspace-selected">
      <div class="panel-header">
        <div>
          <button class="text-button" data-platform-assessment-back type="button">← All organizations</button>
          <h2 class="workspace-title-with-health">${escapeHtml(organizationName)} ${healthSnapshots.length ? `<button class="health-pill-button" data-platform-progress-open="${escapeHtml(selectedOrgId)}" type="button">${renderHealthPill(healthSnapshots)}</button>` : ''}</h2>
          <span>${escapeHtml(activeAssessment?.name || activeAssessment?.title || organization?.name || 'Assessment workspace')}</span>
        </div>
        <div class="workspace-report-actions">
          <button class="secondary-button" data-platform-report-menu="${escapeHtml(selectedOrgId)}" type="button">↓ Reports ▾</button>
        </div>
      </div>
      ${assessment.loading || platformAssessmentDataLoading ? renderLoadingSkeleton('Loading assessment workspace', 4) : workspaceHtml}
    </section>
  `);
}

function renderDemoForm() {
  const config = platformState.selectedDemoConfig || {};
  return `
    <section class="panel">
      <div class="panel-header">
        <div>
          <span class="eyebrow">Demo generator</span>
          <h2>Create demo organization</h2>
          <span>Fleet & Logistics framework only. Demo data is isolated from production.</span>
        </div>
        <button class="text-button" data-demo-cancel type="button">Cancel</button>
      </div>
      ${platformState.demoError ? `<div class="warning-banner"><div class="warning-banner-body">${escapeHtml(platformState.demoError)}</div></div>` : ''}
      <div style="display:grid;gap:16px;max-width:720px;">
        <label>Company name
          <input data-demo-config="companyName" type="text" value="${escapeHtml(config.companyName || '')}" placeholder="e.g. Metro Fleet Services, Regional Logistics Co">
          <span style="display:block;margin-top:6px;color:var(--color-text-muted);font-size:12px;text-transform:none;letter-spacing:0;font-weight:400;">Use a fictional company name for demonstrations.</span>
        </label>
        <label>Company size
          <select data-demo-config="companySize">
            ${['Under 50', '51-100', '101-250', '251-500', '500+'].map((size) => `
              <option value="${escapeHtml(size)}" ${config.companySize === size ? 'selected' : ''}>${escapeHtml(size)}</option>
            `).join('')}
          </select>
        </label>
        <div>
          <span class="eyebrow" style="color:var(--color-text-muted);">Demo depth</span>
          <label class="card" style="display:flex;gap:12px;align-items:flex-start;margin-bottom:10px;cursor:pointer;">
            <input data-demo-config="depth" type="radio" name="demo-depth" value="quick" ${config.depth !== 'full' ? 'checked' : ''} style="width:auto;margin-top:3px;">
            <span><strong>Quick — Review ready</strong><span style="display:block;color:var(--color-text-muted);font-size:12px;margin-top:4px;text-transform:none;letter-spacing:0;font-weight:400;">Creates findings ready for consultant review. Best for demonstrating the consultant workflow live.</span></span>
          </label>
          <label class="card" style="display:flex;gap:12px;align-items:flex-start;cursor:pointer;">
            <input data-demo-config="depth" type="radio" name="demo-depth" value="full" ${config.depth === 'full' ? 'checked' : ''} style="width:auto;margin-top:3px;">
            <span><strong>Full — Fully delivered</strong><span style="display:block;color:var(--color-text-muted);font-size:12px;margin-top:4px;text-transform:none;letter-spacing:0;font-weight:400;">Creates approved findings, recommendations, delivered report, and progress snapshot. Best for showing the complete owner experience.</span></span>
          </label>
        </div>
        <button class="primary-button" data-demo-generate type="button" style="width:100%;justify-content:center;">Generate Demo</button>
      </div>
    </section>
  `;
}

function renderPlatformDemo() {
  if (platformState.demoLoading && !platformState.demoGenerating) {
    updateViewContainer(renderLoadingSkeleton('Loading demo organizations', 3));
    return;
  }
  if (platformState.demoGenerating) {
    updateViewContainer(`
      <section class="panel" style="min-height:360px;display:flex;align-items:center;justify-content:center;text-align:center;">
        <div>
          <i class="ti ti-loader-2" style="font-size:34px;color:var(--color-accent);display:inline-block;"></i>
          <h2 style="margin-top:16px;">Generating demo organization...</h2>
          <p>${escapeHtml(platformState.demoGenerateProgress || 'Creating organization profile...')}</p>
        </div>
      </section>
    `);
    return;
  }
  if (platformState.demoMode === 'create') {
    updateViewContainer(renderDemoForm());
    return;
  }
  if (platformState.demoMode === 'success' && platformState.lastGeneratedDemo) {
    const demo = platformState.lastGeneratedDemo;
    const created = demo.created || {};
    const credentials = platformState.demoCredentials || {};
    updateViewContainer(`
      <section class="panel">
        <div style="max-width:760px;">
          <span class="status-pill approved"><i class="ti ti-check"></i> Ready</span>
          <h2 style="margin-top:14px;">${escapeHtml(demo.name)} is ready.</h2>
          <p style="margin-top:8px;">${escapeHtml(created.participants || 0)} participants · ${escapeHtml(created.findings || 0)} findings${created.recommendations ? ` · ${escapeHtml(created.recommendations)} recommendations` : ''}${created.snapshot ? ' · Progress baseline' : ''}</p>
          <div class="card" style="margin-top:18px;">
            <h3>Demo credentials</h3>
            <dl class="detail-list" style="margin-top:12px;">
              <div><dt>Consultant</dt><dd>${escapeHtml(credentials.consultant?.email || 'demo.consultant@deriveglobal.com')} · ${escapeHtml(credentials.consultant?.password || 'DeriveDemo2026!')}</dd></div>
              <div><dt>Owner</dt><dd>${escapeHtml(credentials.owner?.email || `owner@${demoCompanySlug(demo.name)}-demo.com`)} · ${escapeHtml(credentials.owner?.password || 'DeriveDemo2026!')}</dd></div>
            </dl>
          </div>
          <div class="row-actions" style="margin-top:18px;">
            <button class="primary-button" data-demo-open-consultant="${escapeHtml(demo.id)}" type="button">Open as consultant</button>
            <button class="secondary-button" data-demo-owner-hint="${escapeHtml(demo.name)}" type="button">View as owner</button>
            <button class="text-button" data-demo-create type="button">Create another demo</button>
          </div>
        </div>
      </section>
    `);
    return;
  }

  const demoOrgs = platformState.demoOrgs || [];
  if (!demoOrgs.length) {
    updateViewContainer(`
      <section class="panel" style="min-height:420px;display:flex;align-items:center;justify-content:center;text-align:center;">
        <div style="max-width:520px;">
          <i class="ti ti-flask" style="font-size:44px;color:var(--color-text-faint);"></i>
          <h2 style="margin-top:18px;">No demo organizations yet</h2>
          <p style="margin:8px 0 22px;">Create a demo organization to showcase Derive to potential clients. Demo data is isolated from production.</p>
          <button class="primary-button" data-demo-create type="button">+ Create demo organization</button>
          ${platformState.demoError ? `<p style="color:var(--color-danger);margin-top:14px;">${escapeHtml(platformState.demoError)}</p>` : ''}
        </div>
      </section>
    `);
    return;
  }

  updateViewContainer(`
    <section>
      <div class="panel-header">
        <div>
          <span class="eyebrow">Demo</span>
          <h2>Demo organizations</h2>
          <span>Isolated from production. For demonstrations only.</span>
        </div>
        <button class="primary-button" data-demo-create type="button">+ New demo</button>
      </div>
      ${platformState.demoError ? `<div class="warning-banner"><div class="warning-banner-body">${escapeHtml(platformState.demoError)}</div></div>` : ''}
      <div class="card-grid">
        ${demoOrgs.map((org) => {
          const name = org.client_display_name || org.name || 'Demo organization';
          const isFull = Boolean(org.business_health_score || org.approved_recommendations_count);
          return `
            <article class="card" style="border-top:3px solid var(--color-accent);">
              <div class="panel-header" style="margin-bottom:14px;">
                <div>
                  <span class="status-pill production">DEMO</span>
                  <h3 style="margin-top:8px;">${escapeHtml(name)}</h3>
                  <span>Fleet & Logistics</span>
                </div>
                <span class="status-pill ${isFull ? 'approved' : 'in-progress'}">${isFull ? 'Fully delivered' : 'Review ready'}</span>
              </div>
              <dl class="detail-list">
                <div><dt>Size</dt><dd>${escapeHtml(org.employee_range || '—')}</dd></div>
                <div><dt>Assessment</dt><dd>${escapeHtml(org.assessment_status || org.status || 'active')}</dd></div>
                <div><dt>Created</dt><dd>${escapeHtml(formatSettingsDate(org.created_at))}</dd></div>
              </dl>
              ${isFull ? `
                <div class="metrics-grid" style="grid-template-columns:repeat(3,1fr);margin-top:14px;margin-bottom:14px;">
                  <article class="metric"><div class="metric-number accent">${escapeHtml(org.business_health_score || '—')}</div><div class="metric-label">Health</div></article>
                  <article class="metric"><div class="metric-number">${escapeHtml(org.total_findings || 0)}</div><div class="metric-label">Findings</div></article>
                  <article class="metric"><div class="metric-number success">${escapeHtml(org.approved_recommendations_count || 0)}</div><div class="metric-label">Recs</div></article>
                </div>
              ` : ''}
              <div class="row-actions">
                <button class="secondary-button" data-demo-open-consultant="${escapeHtml(org.id)}" type="button">Open as consultant</button>
                <button class="secondary-button" data-demo-owner-hint="${escapeHtml(name)}" type="button">View as owner</button>
                <button class="text-button" data-demo-delete="${escapeHtml(org.id)}" data-demo-name="${escapeHtml(name)}" type="button" style="color:var(--color-danger);">Delete</button>
              </div>
            </article>
          `;
        }).join('')}
      </div>
    </section>
  `);
}

function renderPlatformSettings() {
  if (platformState.settingsLoading) {
    updateViewContainer(`
      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Platform Settings</h2>
            <span>System configuration</span>
          </div>
        </div>
        ${renderLoadingSkeleton('Loading platform settings', 4)}
      </section>
    `);
    return;
  }

  if (platformState.settingsError) {
    updateViewContainer(`
      <section class="panel">
        <div class="panel-header">
          <div>
            <h2>Platform Settings</h2>
            <span>System configuration</span>
          </div>
        </div>
        ${renderScreenState('platform-settings', 'error', {
          title: 'Settings failed to load',
          message: platformState.settingsError,
          compact: true
        })}
      </section>
    `);
    return;
  }

  const settings = platformState.settings || {};
  const stats = settings.stats || {};
  const organizations = settings.organizations || [];
  const demoRequests = settings.demo_requests || [];
  const configuredPill = (configured) => configured
    ? platformStatusPill('Configured', 'active')
    : platformStatusPill('Not configured', 'danger');
  const demoStatusPill = (status) => {
    const normalized = String(status || 'new').toLowerCase();
    const tone = normalized === 'converted'
      ? 'active'
      : normalized === 'contacted'
        ? 'in-progress'
        : normalized === 'declined'
          ? 'draft'
          : 'warning';
    return platformStatusPill(normalized, tone);
  };
  const settingRow = (label, value) => `
    <div style="display:grid;grid-template-columns:180px 1fr;gap:16px;padding:12px 0;border-bottom:0.5px solid var(--color-border);">
      <span style="color:var(--color-text-muted);font-size:12px;">${escapeHtml(label)}</span>
      <strong style="font-weight:500;color:var(--color-text);">${escapeHtml(value || '—')}</strong>
    </div>
  `;
  const metric = (label, value) => `
    <article class="metric-card">
      <div class="metric-value">${Number(value || 0).toLocaleString()}</div>
      <div class="metric-label">${escapeHtml(label)}</div>
    </article>
  `;
  const renderGlossaryManagement = () => {
    const grouped = (platformState.glossary || []).reduce((groups, entry) => {
      const category = entry.category || 'general';
      groups[category] = groups[category] || [];
      groups[category].push(entry);
      return groups;
    }, {});
    const categories = Object.keys(grouped).sort();
    return `
      <section class="panel">
        <div class="owner-section-head">
          <div>
            <h3>Platform glossary</h3>
            <p style="margin:4px 0 0;color:var(--color-text-muted);font-size:12px;">Metric definitions, calculations, and interpretation text used by tooltips.</p>
          </div>
        </div>
        ${categories.length ? categories.map((category) => `
          <div style="margin-top:14px;">
            <div style="font-size:11px;text-transform:uppercase;letter-spacing:0.08em;color:rgba(200,169,110,0.4);padding:8px 0;border-bottom:0.5px solid rgba(200,169,110,0.08);">${escapeHtml(category)}</div>
            ${grouped[category].map((entry) => `
              <div style="display:grid;grid-template-columns:1fr 120px 80px;gap:12px;align-items:center;padding:10px 0;border-bottom:0.5px solid rgba(200,169,110,0.05);">
                <div>
                  <strong style="display:block;color:var(--color-text);font-size:13px;">${escapeHtml(entry.term)}</strong>
                  <span style="color:var(--color-text-muted);font-size:12px;">${escapeHtml(entry.key)}</span>
                </div>
                <span class="status-pill">${escapeHtml(entry.category)}</span>
                <button class="text-button" data-settings-action="edit-glossary" data-glossary-id="${escapeHtml(entry.id)}" type="button">Edit</button>
              </div>
            `).join('')}
          </div>
        `).join('') : renderScreenState('glossary', 'empty', {
          title: 'No glossary entries loaded.',
          message: 'Glossary entries appear here after schema initialization.',
          compact: true
        })}
      </section>
    `;
  };
  const renderGlossaryEditModal = () => {
    const entry = platformState.glossaryEditEntry;
    if (!entry) return '';
    const categoryOptions = ['finding', 'coverage', 'perception', 'sampling', 'kpi', 'assessment', 'general']
      .map((category) => `<option value="${category}" ${entry.category === category ? 'selected' : ''}>${category}</option>`)
      .join('');
    return `
      <div class="modal-backdrop" style="position:fixed;inset:0;background:rgba(0,0,0,0.62);z-index:9998;display:grid;place-items:center;padding:24px;">
        <form class="panel" data-settings-form="glossary-entry" style="width:min(720px,100%);max-height:90vh;overflow:auto;display:grid;gap:12px;">
          <div class="owner-section-head">
            <div>
              <h3>Edit glossary entry</h3>
              <p style="margin:4px 0 0;color:var(--color-text-muted);font-size:12px;">${escapeHtml(entry.key)}</p>
            </div>
            <button class="text-button" data-settings-action="close-glossary" type="button">Close</button>
          </div>
          <input type="hidden" name="id" value="${escapeHtml(entry.id)}">
          <label>Term <input name="term" value="${escapeHtml(entry.term)}" required></label>
          <label>Turkish term <input name="term_tr" value="${escapeHtml(entry.term_tr || '')}"></label>
          <label>Definition <textarea name="definition" rows="3" required>${escapeHtml(entry.definition)}</textarea></label>
          <label>Calculation <textarea name="calculation" rows="3">${escapeHtml(entry.calculation || '')}</textarea></label>
          <label>Interpretation <textarea name="interpretation" rows="3">${escapeHtml(entry.interpretation || '')}</textarea></label>
          <label>Example <textarea name="example" rows="3">${escapeHtml(entry.example || '')}</textarea></label>
          <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px;">
            <label>Category <select name="category">${categoryOptions}</select></label>
            <label>Sort order <input name="sort_order" type="number" value="${Number(entry.sort_order || 0)}"></label>
          </div>
          <label>Context <input name="context" value="${escapeHtml((entry.context || []).join(', '))}" placeholder="review, executive"></label>
          <label style="display:flex;align-items:center;gap:8px;"><input name="is_active" type="checkbox" ${entry.is_active !== false ? 'checked' : ''}> Active</label>
          <div class="row-actions">
            <button class="secondary-button" data-settings-action="close-glossary" type="button">Cancel</button>
            <button class="primary-button" type="submit" ${platformState.glossarySaving ? 'disabled' : ''}>${platformState.glossarySaving ? 'Saving...' : 'Save glossary entry'}</button>
          </div>
        </form>
      </div>
    `;
  };
  const orgOptions = organizations.map((org) => `
    <option value="${escapeHtml(org.id)}">${escapeHtml(org.client_display_name || org.name || 'Organization')}</option>
  `).join('');

  updateViewContainer(`
    <section class="platform-settings-screen" style="display:grid;gap:18px;">
      <div class="panel-header">
        <div>
          <span class="eyebrow">Settings</span>
          <h2>Platform Settings</h2>
          <span>System configuration</span>
        </div>
      </div>

      <section class="panel">
        <div class="owner-section-head">
          <div>
            <h3>General</h3>
          </div>
        </div>
        ${settingRow('Platform name', settings.platform_name || 'Derive')}
        ${settingRow('Support email', settings.support_email || 'contact@deriveglobal.com')}
        <p style="margin-top:14px;color:var(--color-text-muted);font-size:12px;">Contact your administrator to update platform configuration.</p>
      </section>

      <section class="panel">
        <div class="owner-section-head">
          <div>
            <h3>Email configuration</h3>
          </div>
        </div>
        ${settingRow('Provider', 'Microsoft 365')}
        ${settingRow('Sender', settings.sender_email || 'Not configured')}
        <div style="display:grid;grid-template-columns:180px 1fr;gap:16px;padding:12px 0;">
          <span style="color:var(--color-text-muted);font-size:12px;">Status</span>
          <span>${configuredPill(settings.microsoft_configured)}</span>
        </div>
      </section>

      <section class="panel">
        <div class="owner-section-head">
          <div>
            <h3>Integrations</h3>
          </div>
        </div>
        <div style="display:grid;gap:10px;">
          <article class="card" style="display:flex;align-items:center;justify-content:space-between;gap:16px;">
            <div style="display:flex;align-items:center;gap:12px;">
              <i class="ti ti-brain" style="color:var(--color-accent);font-size:18px;"></i>
              <div>
                <strong style="display:block;color:var(--color-text);font-weight:500;">Anthropic AI</strong>
                <span style="color:var(--color-text-muted);font-size:12px;">AI question generation in Framework Builder</span>
              </div>
            </div>
            ${configuredPill(settings.anthropic_configured)}
          </article>
          <article class="card" style="display:flex;align-items:center;justify-content:space-between;gap:16px;">
            <div style="display:flex;align-items:center;gap:12px;">
              <i class="ti ti-mail" style="color:var(--color-accent);font-size:18px;"></i>
              <div>
                <strong style="display:block;color:var(--color-text);font-weight:500;">Microsoft Graph</strong>
                <span style="color:var(--color-text-muted);font-size:12px;">Assessment invitations and notifications</span>
              </div>
            </div>
            ${configuredPill(settings.microsoft_configured)}
          </article>
        </div>
      </section>

      <section class="panel">
        <div class="owner-section-head">
          <div>
            <h3>Platform statistics</h3>
          </div>
        </div>
        <div class="metrics-grid">
          ${metric('Total organizations', stats.total_organizations)}
          ${metric('Total assessments', stats.total_assessments)}
          ${metric('Total findings', stats.total_findings)}
          ${metric('Total users', stats.total_users)}
        </div>
      </section>

      ${renderGlossaryManagement()}

      <section class="panel">
        <div class="owner-section-head">
          <div>
            <h3>Demo requests</h3>
          </div>
        </div>
        ${demoRequests.length ? `
          <div class="table-scroll">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Company</th>
                  <th>Size</th>
                  <th>Industry</th>
                  <th>Date</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                ${demoRequests.map((request) => `
                  <tr>
                    <td><strong>${escapeHtml(request.full_name)}</strong><br><span style="color:var(--color-text-muted);font-size:12px;">${escapeHtml(request.email)}</span></td>
                    <td>${escapeHtml(request.company_name)}</td>
                    <td>${escapeHtml(request.company_size)}</td>
                    <td>${escapeHtml(request.industry || '—')}</td>
                    <td>${escapeHtml(formatSettingsDate(request.created_at))}</td>
                    <td>${demoStatusPill(request.status)}</td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        ` : renderScreenState('demo-requests', 'empty', {
          title: 'No demo requests yet.',
          message: 'New demo requests from the homepage will appear here.',
          compact: true
        })}
      </section>
      ${renderGlossaryEditModal()}

      <section class="danger-zone" style="background:rgba(224,123,90,0.05);border:0.5px solid rgba(224,123,90,0.25);border-radius:var(--radius-lg);padding:24px;">
        <h3 style="font-size:13px;font-weight:500;color:var(--color-danger);margin-bottom:4px;">Danger zone</h3>
        <p style="font-size:12px;color:var(--color-text-muted);margin-bottom:24px;">These actions permanently delete data and cannot be undone. Organization identity, company profile, and framework are always preserved.</p>

        <div id="danger-form">
          <label style="display:block;margin-bottom:14px;">Select organization
            <select id="danger-org-select" style="margin-top:6px;">
              <option value="">Select organization</option>
              ${organizations.map((org) => `
                <option value="${escapeHtml(org.id)}">${escapeHtml(org.client_display_name || org.name || 'Organization')} · ${escapeHtml(org.id)}</option>
              `).join('')}
            </select>
          </label>

          <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:12px;margin-bottom:16px;">
            <label class="card" style="display:block;background:var(--color-surface-raised);border:0.5px solid var(--color-border);border-radius:var(--radius-lg);padding:16px 18px;cursor:pointer;">
              <span style="display:flex;gap:10px;align-items:center;color:var(--color-text);font-size:13px;font-weight:500;">
                <input name="danger-option" type="radio" value="responses" checked style="width:auto;">
                Clear assessment responses
              </span>
              <span style="display:block;font-size:12px;color:var(--color-text-muted);margin-top:8px;text-transform:none;letter-spacing:0;font-weight:400;">Removes all stakeholder responses, findings, recommendations, and roadmap. The participant list is preserved so you can re-invite the same people for the next assessment.</span>
              <span style="display:block;font-size:11px;color:var(--color-danger);background:rgba(224,123,90,0.08);border-radius:4px;padding:6px 8px;margin-top:10px;text-transform:none;letter-spacing:0;font-weight:400;">Removes: responses · sessions · findings · evidence · recommendations · roadmap · progress snapshots</span>
              <span style="display:block;font-size:11px;color:var(--color-success);background:rgba(107,184,138,0.08);border-radius:4px;padding:6px 8px;margin-top:6px;text-transform:none;letter-spacing:0;font-weight:400;">Keeps: participants · organization profile · framework · users</span>
            </label>

            <label class="card" style="display:block;background:var(--color-surface-raised);border:0.5px solid var(--color-border);border-radius:var(--radius-lg);padding:16px 18px;cursor:pointer;">
              <span style="display:flex;gap:10px;align-items:center;color:var(--color-text);font-size:13px;font-weight:500;">
                <input name="danger-option" type="radio" value="everything" style="width:auto;">
                Clear everything including participants
              </span>
              <span style="display:block;font-size:12px;color:var(--color-text-muted);margin-top:8px;text-transform:none;letter-spacing:0;font-weight:400;">Removes everything above plus the participant list and invitation history. Start completely fresh for the next assessment.</span>
              <span style="display:block;font-size:11px;color:var(--color-danger);background:rgba(224,123,90,0.08);border-radius:4px;padding:6px 8px;margin-top:10px;text-transform:none;letter-spacing:0;font-weight:400;">Removes: everything above + participants · invitations</span>
              <span style="display:block;font-size:11px;color:var(--color-success);background:rgba(107,184,138,0.08);border-radius:4px;padding:6px 8px;margin-top:6px;text-transform:none;letter-spacing:0;font-weight:400;">Keeps: organization profile · context intake · framework · users</span>
            </label>
          </div>

          <label style="display:block;margin-bottom:12px;">Type DELETE to confirm
            <input id="danger-confirm-input" type="text" placeholder='Type "DELETE" to confirm' style="font-family:var(--font-mono);margin-top:6px;">
          </label>

          <button class="primary-button" data-danger-open type="button" disabled style="background:var(--color-danger);color:white;width:100%;justify-content:center;padding:10px;border-radius:var(--radius-md);font-size:13px;font-weight:500;">Clear Selected Data</button>
        </div>

        <div id="danger-confirmation-card" class="hidden" style="background:rgba(224,123,90,0.08);border:0.5px solid rgba(224,123,90,0.3);border-radius:var(--radius-lg);padding:16px;margin-top:14px;"></div>
        <div id="danger-result"></div>
      </section>
    </section>
  `);
  updateDangerZoneControls();
}

function wirePlatformShell(container) {
  if (container.dataset.platformShellWired === 'true') return;
  container.dataset.platformShellWired = 'true';
  container.addEventListener?.('input', (event) => {
    if (event.target.matches?.('#danger-confirm-input')) {
      updateDangerZoneControls();
    }
  });
  container.addEventListener?.('change', (event) => {
    const kpiTracking = event.target.closest?.('[data-component-kpi-tracking]');
    if (kpiTracking) {
      const projectId = platformState.selectedAssessmentOrgId
        || getSlice('platform')?.activeProjectId;
      const key = kpiTracking.dataset.componentKpiTracking;
      const checked = kpiTracking.checked;
      saveProjectKpiTracking(projectId, key, checked).then(() => {
        updateLocalKpiTracking(key, checked);
        renderPlatformView('assessment');
      }).catch((error) => {
        kpiTracking.checked = !kpiTracking.checked;
        showToast(error.message || 'Failed to save KPI tracking.', 'error');
      });
      return;
    }

    if (event.target.matches?.('#danger-org-select, input[name="danger-option"]')) {
      updateDangerZoneControls();
    }
  });
  container.addEventListener?.('click', async (event) => {
    const closeProgress = event.target.closest?.('[data-progress-panel-close]');
    if (closeProgress) {
      closeProgressPanel();
      return;
    }
    const reportDownload = event.target.closest?.('[data-platform-report-download]');
    if (reportDownload) {
      downloadReport(reportDownload.dataset.projectId, reportDownload.dataset.platformReportDownload);
      closeReportMenu();
      return;
    }
    const reportMenu = event.target.closest?.('[data-platform-report-menu]');
    if (reportMenu) {
      openReportMenu(reportMenu.dataset.platformReportMenu, reportMenu);
      return;
    }
    const progressOpen = event.target.closest?.('[data-platform-progress-open]');
    if (progressOpen) {
      openProgressPanel(progressOpen.dataset.platformProgressOpen);
      return;
    }
    if (!event.target.closest?.('.platform-report-menu')) closeReportMenu();
    const settingsAction = event.target.closest?.('[data-settings-action]');
    if (settingsAction) {
      const action = settingsAction.dataset.settingsAction;
      if (action === 'edit-glossary') {
        platformState.glossaryEditEntry = (platformState.glossary || [])
          .find((entry) => String(entry.id) === String(settingsAction.dataset.glossaryId)) || null;
        renderPlatformSettings();
        return;
      }
      if (action === 'close-glossary') {
        platformState.glossaryEditEntry = null;
        renderPlatformSettings();
        return;
      }
    }
    const nav = event.target.closest?.('[data-platform-view]');
    if (nav) {
      if (nav.dataset.platformView === 'settings') {
        loadPlatformSettings();
        return;
      }
      if (nav.dataset.platformView === 'demo') {
        platformState.demoMode = 'list';
        loadDemoOrgs();
        return;
      }
      renderPlatformView(nav.dataset.platformView);
      return;
    }
    if (event.target.closest?.('[data-demo-create]')) {
      platformState.demoMode = 'create';
      platformState.demoError = null;
      platformState.selectedDemoConfig = {
        companyName: '',
        companySize: '51-100',
        depth: 'quick'
      };
      renderPlatformView('demo');
      return;
    }
    if (event.target.closest?.('[data-demo-cancel]')) {
      platformState.demoMode = 'list';
      platformState.demoError = null;
      renderPlatformView('demo');
      return;
    }
    if (event.target.closest?.('[data-demo-generate]')) {
      const formRoot = platformViewContainer || platformContainer;
      const config = {
        companyName: formRoot?.querySelector?.('[data-demo-config="companyName"]')?.value || '',
        companySize: formRoot?.querySelector?.('[data-demo-config="companySize"]')?.value || '51-100',
        depth: formRoot?.querySelector?.('[data-demo-config="depth"]:checked')?.value || 'quick'
      };
      generateDemo(config);
      return;
    }
    const demoOpen = event.target.closest?.('[data-demo-open-consultant]');
    if (demoOpen) {
      platformState.selectedAssessmentOrgId = demoOpen.dataset.demoOpenConsultant;
      platformState.activeStage = 'setup';
      platformAssessmentDataProjectId = null;
      renderPlatformView('assessment');
      return;
    }
    const demoOwner = event.target.closest?.('[data-demo-owner-hint]');
    if (demoOwner) {
      const name = demoOwner.dataset.demoOwnerHint || 'demo';
      showToast(`Owner preview uses owner@${demoCompanySlug(name)}-demo.com / DeriveDemo2026!`);
      return;
    }
    const demoDelete = event.target.closest?.('[data-demo-delete]');
    if (demoDelete) {
      deleteDemo(demoDelete.dataset.demoDelete, demoDelete.dataset.demoName || 'Demo organization');
      return;
    }
    const dangerOpen = event.target.closest?.('[data-danger-open]');
    if (dangerOpen) {
      openDangerConfirmation();
      return;
    }
    const dangerCancel = event.target.closest?.('[data-danger-cancel]');
    if (dangerCancel) {
      closeDangerConfirmation();
      return;
    }
    const dangerConfirm = event.target.closest?.('[data-danger-confirm]');
    if (dangerConfirm) {
      if (dangerConfirm.disabled) return;
      const selectedOption = document
        .querySelector('input[name="danger-option"]:checked')
        ?.value || 'responses';
      dangerConfirm.disabled = true;
      dangerConfirm.textContent = 'Deleting...';
      executeDangerZoneAction(selectedOption, dangerConfirm);
      return;
    }
    if (event.target.closest?.('[data-danger-reset]')) {
      loadPlatformSettings();
      return;
    }
    if (event.target.closest?.('[data-platform-logout]')) {
      handleLogout();
      return;
    }
    const assessmentOpen = event.target.closest?.('[data-platform-assessment-open]');
    if (assessmentOpen) {
      openPlatformAssessmentWorkspace(assessmentOpen.dataset.platformAssessmentOpen, 'assessment');
      return;
    }
    if (event.target.closest?.('[data-platform-assessment-back]')) {
      const returnView = platformState.assessmentReturnView || 'assessment';
      platformState.selectedAssessmentOrgId = null;
      platformState.assessmentReturnView = 'assessment';
      renderPlatformView(returnView);
      return;
    }
    const addDomain = event.target.closest?.('[data-component-add-domain]');
    if (addDomain) {
      showDomainModal({
        mode: 'add',
        scope: addDomain.dataset.scope || 'industry',
        industry: addDomain.dataset.industry || 'tire_fleet_service'
      });
      return;
    }
    const editDomain = event.target.closest?.('[data-component-edit-domain]');
    if (editDomain) {
      const domain = platformState.domains.find((item) => String(item.id) === String(editDomain.dataset.componentEditDomain));
      if (domain) showDomainModal({ mode: 'edit', scope: domain.scope, industry: domain.industry || 'tire_fleet_service', domain });
      return;
    }
    const toggleDomainButton = event.target.closest?.('[data-component-toggle-domain]');
    if (toggleDomainButton) {
      toggleDomain(toggleDomainButton.dataset.componentToggleDomain, toggleDomainButton.dataset.isActive !== 'false');
      return;
    }
    const deleteDomainButton = event.target.closest?.('[data-component-delete-domain]');
    if (deleteDomainButton) {
      deleteDomain(deleteDomainButton.dataset.componentDeleteDomain);
      return;
    }
    const addKpi = event.target.closest?.('[data-component-add-kpi]');
    if (addKpi) {
      if (!platformState.frameworkActivities?.length) loadFrameworkActivities(platformState.selectedFrameworkId, { render: false });
      showKpiModal({ mode: 'add' });
      return;
    }
    const editKpi = event.target.closest?.('[data-component-edit-kpi]');
    if (editKpi) {
      const kpi = platformState.kpiCatalog.find((item) => String(item.id) === String(editKpi.dataset.componentEditKpi));
      if (kpi) showKpiModal({ mode: 'edit', kpi });
      return;
    }
    const toggleKpiButton = event.target.closest?.('[data-component-toggle-kpi]');
    if (toggleKpiButton) {
      toggleKpiCatalog(toggleKpiButton.dataset.componentToggleKpi, toggleKpiButton.dataset.isActive !== 'false');
      return;
    }
    const deleteKpiButton = event.target.closest?.('[data-component-delete-kpi]');
    if (deleteKpiButton) {
      deleteKpiCatalog(deleteKpiButton.dataset.componentDeleteKpi);
      return;
    }
    const frameworkAction = event.target.closest?.('[data-framework-action]');
    if (frameworkAction) {
      const action = frameworkAction.dataset.frameworkAction;
      const frameworkId = frameworkAction.dataset.frameworkId;
      const bankId = frameworkAction.dataset.bankId;
      const questionId = frameworkAction.dataset.questionId;
      const kpiId = frameworkAction.dataset.kpiId;
      const draftId = frameworkAction.dataset.draftId;
      if (action === 'create') showCreateFrameworkModal();
      if (action === 'import-fleet') importFleetFramework();
      if (action === 'open') {
        platformState.selectedFrameworkId = frameworkId;
        platformState.frameworkBuilderView = 'editor';
        platformState.frameworkEditorTab = 'identity';
        loadFrameworkDetail(frameworkId);
      }
      if (action === 'back') {
        platformState.frameworkBuilderView = 'library';
        loadFrameworks();
      }
      if (action === 'open-bank') {
        platformState.selectedBankId = bankId;
        platformState.frameworkBuilderView = 'bank';
        platformState.questionBankPanelMode = 'editor';
        loadBankQuestions(bankId);
      }
      if (action === 'delete-bank' && bankId && window.confirm('Delete this role bank?')) deleteFrameworkBank(bankId);
      if (action === 'delete-kpi' && kpiId && window.confirm('Delete this KPI?')) deleteFrameworkKpi(kpiId);
      if (action === 'bank-back') {
        platformState.frameworkBuilderView = 'editor';
        platformState.frameworkEditorTab = 'roles';
        loadFrameworkDetail(platformState.selectedFrameworkId);
      }
      if (action === 'activate-bank' && bankId) activateBank(bankId);
      if (action === 'delete-question' && questionId && window.confirm('Delete this question?')) deleteBankQuestion(questionId);
      if (action === 'show-ai-panel') {
        platformState.questionBankPanelMode = 'ai';
        if (!platformState.domains?.length) loadDomainTaxonomy({ render: false });
        loadBankCoverage(platformState.selectedBankId, { render: true });
        renderPlatformView('frameworks');
      }
      if (action === 'scoring-settings') {
        platformState.frameworkBuilderView = 'editor';
        platformState.frameworkEditorTab = 'settings';
        renderPlatformView('frameworks');
      }
      if (action === 'reset-scoring' && window.confirm('Reset scoring settings to global defaults?')) {
        resetScoringSettings();
      }
      if (action === 'clear-error') {
        platformState.frameworksError = null;
        renderPlatformView('frameworks');
      }
      if (action === 'new-question') {
        platformState.questionBankPanelMode = 'editor';
        renderPlatformView('frameworks');
      }
      if (action === 'preview-back') {
        platformState.frameworkBuilderView = 'editor';
        renderPlatformView('frameworks');
      }
      if (action === 'activate-framework') activateFramework(platformState.selectedFrameworkId);
      if (action === 'audit-all-banks') platformAuditAllBanks();
      if (action === 'complete-all-banks') platformCompleteAllBanks();
      if (action === 'apply-audit' && window.confirm('Apply all audit recommendations?')) platformApplyAudit();
      if (action === 'apply-bank-audit' && bankId && window.confirm('Apply audit recommendations for this bank?')) platformApplyBankAudit(bankId);
      if (action === 'cancel-audit') {
        platformState.auditResults = null;
        renderPlatformView('frameworks');
      }
      if (action === 'approve-all-draft') approveAllDraftQuestions();
      if (action === 'approve-draft') approveDraftQuestion(platformState.generatedDraft?.find((draft) => draft._localId === draftId));
      if (action === 'reject-draft') rejectDraftQuestion(platformState.generatedDraft?.find((draft) => draft._localId === draftId));
      if (action === 'undo-draft') undoDraftQuestion(draftId);
      if (action === 'clear-draft') clearGeneratedDraft();
      return;
    }
    const frameworkTab = event.target.closest?.('[data-framework-tab]');
    if (frameworkTab) {
      platformState.frameworkEditorTab = frameworkTab.dataset.frameworkTab || 'identity';
      platformState.frameworkBuilderView = platformState.frameworkEditorTab === 'preview' ? 'preview' : 'editor';
      if (platformState.frameworkEditorTab === 'kpis') {
        loadDomainTaxonomy({ render: false });
        loadKpiCatalog({ render: false });
        loadFrameworkActivities(platformState.selectedFrameworkId, { render: false });
      }
      renderPlatformView('frameworks');
      return;
    }
    const frameworkSection = event.target.closest?.('[data-framework-section]');
    if (frameworkSection) {
      platformState.frameworkEditorSection = frameworkSection.dataset.frameworkSection || 'All';
      renderPlatformView('frameworks');
      return;
    }
    const assessmentStage = event.target.closest?.('[data-assessment-workspace-stage]');
    if (assessmentStage) {
      platformState.activeStage = assessmentStage.dataset.assessmentWorkspaceStage || 'setup';
      renderPlatformView('assessment');
      return;
    }
    const assessmentAction = event.target.closest?.('[data-assessment-action]');
    if (assessmentAction) {
      const action = assessmentAction.dataset.assessmentAction;
      if (action === 'create-assessment') callbacks().onCreateAssessment?.();
      if (action === 'view-framework') renderPlatformView('frameworks');
      if (action === 'run-analysis') callbacks().onRunAnalysis?.();
      if (action === 'open-operations-center') renderPlatformView('operations');
      return;
    }
    const classification = event.target.closest?.('[data-component-platform-classification-filter]');
    if (classification) {
      const filter = classification.dataset.componentPlatformClassificationFilter || 'production';
      platformState.classificationFilter = filter;
      setState('platform', 'classificationFilter', filter);
      callbacks().onSetClassificationFilter?.(filter);
      renderPlatformView('command-center');
      return;
    }
    if (event.target.closest?.('[data-component-platform-refresh]')) {
      callbacks().onRefresh?.();
      return;
    }
    if (event.target.closest?.('[data-component-platform-open-users]')) {
      renderPlatformView('users');
      return;
    }
    if (event.target.closest?.('[data-component-platform-open-operations]')) {
      renderPlatformView('operations');
      return;
    }
    if (event.target.closest?.('[data-component-platform-open-organizations]')) {
      renderPlatformView('organizations');
      return;
    }
    const selectFinding = event.target.closest?.('[data-component-select-finding]');
    if (selectFinding) {
      event.preventDefault();
      const list = container.querySelector('.review-finding-list');
      const scrollTop = list?.scrollTop || 0;
      platformState.selectedFindingId = selectFinding.dataset.componentSelectFinding;
      renderPlatformView('assessment');
      requestAnimationFrame(() => {
        const updatedList = container.querySelector('.review-finding-list');
        if (updatedList) updatedList.scrollTop = scrollTop;
      });
      return;
    }
    const toggleFindingMerge = event.target.closest?.('[data-component-merge-finding]');
    if (toggleFindingMerge) {
      const findingId = toggleFindingMerge.dataset.componentMergeFinding;
      platformState.selectedFindingIds = platformState.selectedFindingIds || [];
      const idx = platformState.selectedFindingIds.findIndex((id) => String(id) === String(findingId));
      if (toggleFindingMerge.checked && idx === -1) {
        platformState.selectedFindingIds.push(findingId);
      } else if (!toggleFindingMerge.checked && idx !== -1) {
        platformState.selectedFindingIds.splice(idx, 1);
      } else if (idx === -1) {
        platformState.selectedFindingIds.push(findingId);
      } else {
        platformState.selectedFindingIds.splice(idx, 1);
      }
      renderPlatformView('assessment');
      return;
    }
    const findingAction = event.target.closest?.('[data-component-finding-action]');
    if (findingAction) {
      const findingId = findingAction.dataset.findingId;
      const action = findingAction.dataset.componentFindingAction;
      if (action === 'approve') callbacks().onApproveFinding?.(findingId);
      if (action === 'reject') callbacks().onRejectFinding?.(findingId);
      if (action === 'delete') callbacks().onDeleteFinding?.(findingId);
      if (action === 'edit') callbacks().onEditFinding?.(findingId, '');
      if (action === 'notes') callbacks().onFindingNotes?.(findingId, '');
      return;
    }
    const findingsAction = event.target.closest?.('[data-findings-action]');
    if (findingsAction) {
      const action = findingsAction.dataset.findingsAction;
      const findings = getSlice('assessment')?.findings || platformState.findings || [];
      if (action === 'select-all') {
        platformState.selectedFindingIds = findings.map((finding) => finding.id).filter(Boolean);
        renderPlatformView('assessment');
        return;
      }
      if (action === 'unselect-all') {
        platformState.selectedFindingIds = [];
        renderPlatformView('assessment');
        return;
      }
      if (action === 'approve-selected') {
        const ids = platformState.selectedFindingIds || [];
        if (!ids.length) return;
        for (const id of ids) {
          await callbacks().onApproveFinding?.(id);
        }
        platformState.selectedFindingIds = [];
        renderPlatformView('assessment');
        return;
      }
      if (action === 'reject-selected') {
        const ids = platformState.selectedFindingIds || [];
        if (!ids.length) return;
        for (const id of ids) {
          await callbacks().onRejectFinding?.(id);
        }
        platformState.selectedFindingIds = [];
        renderPlatformView('assessment');
        return;
      }
    }
    if (event.target.closest?.('[data-component-merge-selected-findings]')) {
      const ids = [...container.querySelectorAll('[data-component-merge-finding]:checked')]
        .map((input) => input.dataset.componentMergeFinding)
        .filter((id) => id && String(id) !== String(platformState.selectedFindingId));
      if (platformState.selectedFindingId && ids.length) {
        callbacks().onMergeFindings?.([platformState.selectedFindingId, ...ids]);
      }
      return;
    }
    const recAction = event.target.closest?.('[data-component-rec-action]');
    if (recAction) {
      const recommendationId = recAction.dataset.recId;
      const action = recAction.dataset.componentRecAction;
      if (action === 'approve') callbacks().onApproveRecommendation?.(recommendationId);
      if (action === 'reject') callbacks().onRejectRecommendation?.(recommendationId);
      return;
    }
    const selectRecommendation = event.target.closest?.('[data-component-select-recommendation]');
    if (selectRecommendation) {
      const recommendationId = selectRecommendation.dataset.componentSelectRecommendation;
      platformState.selectedRecommendationIds = platformState.selectedRecommendationIds || [];
      const idx = platformState.selectedRecommendationIds.findIndex((id) => String(id) === String(recommendationId));
      if (selectRecommendation.checked && idx === -1) {
        platformState.selectedRecommendationIds.push(recommendationId);
      } else if (!selectRecommendation.checked && idx !== -1) {
        platformState.selectedRecommendationIds.splice(idx, 1);
      } else if (idx === -1) {
        platformState.selectedRecommendationIds.push(recommendationId);
      } else {
        platformState.selectedRecommendationIds.splice(idx, 1);
      }
      renderPlatformView('assessment');
      return;
    }
    const recommendationBulkAction = event.target.closest?.('[data-recommendations-action]');
    if (recommendationBulkAction) {
      const action = recommendationBulkAction.dataset.recommendationsAction;
      const recommendations = getSlice('assessment')?.recommendations || platformState.recommendations || [];
      if (action === 'select-all') {
        platformState.selectedRecommendationIds = recommendations.map((recommendation) => recommendation.id).filter(Boolean);
        renderPlatformView('assessment');
        return;
      }
      if (action === 'unselect-all') {
        platformState.selectedRecommendationIds = [];
        renderPlatformView('assessment');
        return;
      }
      if (action === 'approve-selected') {
        const ids = platformState.selectedRecommendationIds || [];
        if (!ids.length) return;
        for (const id of ids) {
          await callbacks().onApproveRecommendation?.(id);
        }
        platformState.selectedRecommendationIds = [];
        renderPlatformView('assessment');
        return;
      }
      if (action === 'reject-selected') {
        const ids = platformState.selectedRecommendationIds || [];
        if (!ids.length) return;
        for (const id of ids) {
          await callbacks().onRejectRecommendation?.(id);
        }
        platformState.selectedRecommendationIds = [];
        renderPlatformView('assessment');
        return;
      }
    }
    if (event.target.closest?.('[data-component-view-executive-report]')) {
      platformState.activeStage = 'executive';
      renderPlatformView('assessment');
      return;
    }
    const exportReportButton = event.target.closest?.('[data-component-export-report]');
    if (exportReportButton) {
      const type = exportReportButton.dataset.componentExportReport;
      if (type === 'executive-summary') {
        callbacks().onExportReport?.('executive-summary');
      } else {
        callbacks().onExportReport?.('full-report');
      }
      return;
    }
    const reportAction = event.target.closest?.('[data-component-report-action]');
    if (reportAction) {
      const action = reportAction.dataset.componentReportAction;
      if (action === 'generate') callbacks().onGenerateReport?.();
      if (action === 'export') callbacks().onExportReport?.();
      if (action === 'print' && typeof window !== 'undefined') window.print();
      return;
    }
    const heatmapCell = event.target.closest?.('[data-component-heatmap-cell]');
    if (heatmapCell) {
      platformState.filterState.selectedHeatmapCellKey = heatmapCell.dataset.componentHeatmapCell;
      renderPlatformView('assessment');
      return;
    }
    if (event.target.closest?.('[data-component-download-template]')) {
      callbacks().onDownloadTemplate?.();
      return;
    }
    if (event.target.closest?.('[data-component-preview-upload]')) {
      callbacks().onPreviewUpload?.();
      return;
    }
    if (event.target.closest?.('[data-component-confirm-import]')) {
      callbacks().onConfirmImport?.();
      return;
    }
    if (event.target.closest?.('[data-component-download-errors]')) {
      callbacks().onDownloadErrors?.();
      return;
    }
    if (event.target.closest?.('[data-component-create-uploaded-sessions]')) {
      callbacks().onCreateSessionsForImported?.();
      return;
    }
    if (event.target.closest?.('[data-component-send-bulk-invitations]')) {
      callbacks().onBulkSendInvites?.();
      return;
    }
    if (event.target.closest?.('[data-component-send-bulk-reminders]')) {
      callbacks().onBulkSendReminders?.();
      return;
    }
    const previewInvite = event.target.closest?.('[data-component-preview-invite]');
    if (previewInvite) {
      callbacks().onPreviewInvite?.(previewInvite.dataset.componentPreviewInvite);
      return;
    }
    const sendInvite = event.target.closest?.('[data-component-send-invite]');
    if (sendInvite) {
      callbacks().onSendInvite?.(sendInvite.dataset.componentSendInvite);
      return;
    }
    const previewReminder = event.target.closest?.('[data-component-preview-reminder]');
    if (previewReminder) {
      callbacks().onPreviewReminder?.(previewReminder.dataset.componentPreviewReminder);
      return;
    }
    const sendReminder = event.target.closest?.('[data-component-send-reminder]');
    if (sendReminder) {
      callbacks().onSendReminder?.(sendReminder.dataset.componentSendReminder);
      return;
    }
    const generateLink = event.target.closest?.('[data-component-generate-link]');
    if (generateLink) {
      callbacks().onGenerateLink?.(generateLink.dataset.componentGenerateLink);
      return;
    }
    const copyLink = event.target.closest?.('[data-component-copy-link]');
    if (copyLink) {
      callbacks().onCopyLink?.(copyLink.dataset.link || '');
      return;
    }
    const createSession = event.target.closest?.('[data-component-create-session]');
    if (createSession) {
      callbacks().onCreateSession?.(createSession.dataset.componentCreateSession);
      return;
    }
    const viewSession = event.target.closest?.('[data-component-view-session]');
    if (viewSession) {
      callbacks().onViewSession?.(viewSession.dataset.componentViewSession);
      return;
    }
    const editParticipant = event.target.closest?.('[data-component-edit-participant]');
    if (editParticipant) {
      const participantId = editParticipant.dataset.componentEditParticipant;
      if (callbacks().onEditParticipant) {
        callbacks().onEditParticipant(participantId);
      } else if (window.platformEditParticipant) {
        window.platformEditParticipant(participantId);
      } else if (window.consultantEditParticipant) {
        window.consultantEditParticipant(participantId);
      }
      return;
    }
    const deactivateParticipant = event.target.closest?.('[data-component-deactivate-participant]');
    if (deactivateParticipant) {
      const participantId = deactivateParticipant.dataset.componentDeactivateParticipant;
      if (callbacks().onDeactivateParticipant) {
        callbacks().onDeactivateParticipant(participantId);
      } else if (window.platformDeactivateParticipant) {
        window.platformDeactivateParticipant(participantId);
      } else if (window.consultantDeactivateParticipant) {
        window.consultantDeactivateParticipant(participantId);
      }
      return;
    }
    const openOrg = event.target.closest?.('[data-component-open-organization], [data-component-platform-open-organization]');
    if (openOrg) {
      openPlatformAssessmentWorkspace(
        openOrg.dataset.componentOpenOrganization || openOrg.dataset.componentPlatformOpenOrganization,
        'organizations'
      );
      return;
    }
    if (event.target.closest?.('[data-component-create-organization]')) {
      callbacks().onCreateOrganization?.();
      return;
    }
    const openReport = event.target.closest?.('[data-component-platform-open-report], [data-component-ops-open-report]');
    if (openReport) {
      callbacks().onOpenReport?.(openReport.dataset.componentPlatformOpenReport || openReport.dataset.componentOpsOpenReport);
      return;
    }
    const opsSection = event.target.closest?.('[data-component-ops-section]');
    if (opsSection) {
      platformState.operationsSection = opsSection.dataset.componentOpsSection || 'overview';
      callbacks().onOperationsSectionChange?.(platformState.operationsSection);
      renderPlatformView('operations');
      return;
    }
    if (event.target.closest?.('[data-component-ops-refresh]')) {
      callbacks().onRefreshOperations?.();
      return;
    }
    const opsWorkspace = event.target.closest?.('[data-component-ops-open-workspace]');
    if (opsWorkspace) {
      callbacks().onOpenAssessmentWorkspace?.(opsWorkspace.dataset.componentOpsOpenWorkspace);
      return;
    }
    const saveGenerated = event.target.closest?.('[data-component-ops-save-generated-issue]');
    if (saveGenerated) {
      callbacks().onCreateGeneratedIssue?.(saveGenerated.dataset.componentOpsSaveGeneratedIssue);
      return;
    }
    const resolveIssue = event.target.closest?.('[data-component-ops-resolve-issue]');
    if (resolveIssue) {
      callbacks().onResolveIssue?.(resolveIssue.dataset.componentOpsResolveIssue);
      return;
    }
    const participantAction = event.target.closest?.('[data-component-ops-participant-action]');
    if (participantAction) {
      callbacks().onParticipantAction?.(participantAction.dataset.componentOpsParticipantAction, participantAction.dataset.participantId);
      return;
    }
    const linkAction = event.target.closest?.('[data-component-ops-link-action]');
    if (linkAction) {
      callbacks().onLinkAction?.(linkAction.dataset.componentOpsLinkAction, linkAction.dataset.tokenId);
      return;
    }
    const questionRole = event.target.closest?.('[data-component-question-bank-role]');
    if (questionRole) {
      platformState.activeQuestionBankRole = questionRole.dataset.componentQuestionBankRole;
      setState('session', 'activeQuestionBankRole', platformState.activeQuestionBankRole);
      callbacks().onSelectQuestionBankRole?.(platformState.activeQuestionBankRole);
      renderPlatformView('frameworks');
      return;
    }
    const createUser = event.target.closest?.('[data-component-create-user]');
    if (createUser) {
      if (typeof callbacks().onCreateUser === 'function') {
        callbacks().onCreateUser();
      } else {
        console.warn('[DERIVE] onCreateUser callback not registered');
      }
      return;
    }
    const editUser = event.target.closest?.('[data-component-edit-user]');
    if (editUser) {
      callbacks().onEditUser?.(editUser.dataset.componentEditUser);
      return;
    }
    const sendCredentials = event.target.closest?.('[data-component-send-credentials]');
    if (sendCredentials) {
      callbacks().onSendCredentials?.(sendCredentials.dataset.componentSendCredentials);
      return;
    }
    const userStatus = event.target.closest?.('[data-component-user-status]');
    if (userStatus) {
      callbacks().onSetUserStatus?.(userStatus.dataset.componentUserStatus, userStatus.dataset.statusValue);
      return;
    }
    const disableUser = event.target.closest?.('[data-component-disable-user]');
    if (disableUser) {
      callbacks().onSetUserStatus?.(disableUser.dataset.componentDisableUser, 'disabled');
    }
  });

  container.addEventListener?.('change', (event) => {
    const demoConfig = event.target.closest?.('[data-demo-config]');
    if (demoConfig) {
      const key = demoConfig.dataset.demoConfig;
      platformState.selectedDemoConfig = {
        ...platformState.selectedDemoConfig,
        [key]: demoConfig.value
      };
      return;
    }
    const draftField = event.target.closest?.('[data-draft-field]');
    if (draftField) {
      updateDraftField(draftField.dataset.draftId, draftField.dataset.draftField, draftField.value);
      return;
    }
    const bankRequirement = event.target.closest?.('[data-framework-bank-requirement]');
    if (bankRequirement) {
      updateFrameworkBank(bankRequirement.dataset.frameworkBankRequirement, { requirement: bankRequirement.value });
      return;
    }
    const participantFilter = event.target.closest?.('[data-component-participant-filter]');
    if (participantFilter) {
      const keyMap = { group: 'group', role: 'role', status: 'status' };
      platformState.filterState[keyMap[participantFilter.dataset.componentParticipantFilter] || participantFilter.dataset.componentParticipantFilter] = participantFilter.value || null;
      renderPlatformView('assessment');
      return;
    }
    const heatmapFilter = event.target.closest?.('[data-component-heatmap-filter]');
    if (heatmapFilter) {
      const filterType = heatmapFilter.dataset.componentHeatmapFilter;
      const keyMap = {
        domain: 'heatmapDomain',
        group: 'heatmapGroup',
        'min-priority': 'heatmapMinPriority',
        misalignment: 'onlyMisalignment',
        'high-confidence': 'onlyHighConfidence'
      };
      platformState.filterState[keyMap[filterType] || filterType] = heatmapFilter.type === 'checkbox' ? heatmapFilter.checked : heatmapFilter.value;
      renderPlatformView('assessment');
      return;
    }
    const reportToggle = event.target.closest?.('[data-component-report-toggle]');
    if (reportToggle) {
      const key = reportToggle.dataset.componentReportToggle === 'evidence' ? 'showEvidence' : 'showAppendix';
      platformState.reportToggles[key] = reportToggle.checked;
      renderPlatformView('assessment');
      return;
    }
    const uploadFile = event.target.closest?.('[data-component-upload-file]');
    if (uploadFile) {
      callbacks().onFileSelected?.(uploadFile.files?.[0] || null);
      return;
    }
    const invitationScope = event.target.closest?.('[data-component-invitation-scope]');
    if (invitationScope) {
      callbacks().onInviteScopeChange?.(invitationScope.value);
      return;
    }
    const reminderScope = event.target.closest?.('[data-component-reminder-scope]');
    if (reminderScope) {
      callbacks().onReminderScopeChange?.(reminderScope.value);
      return;
    }
    const userProject = event.target.closest?.('[data-component-user-project]');
    if (userProject) {
      callbacks().onAssignProject?.(userProject.dataset.componentUserProject, userProject.value);
    }
  });

  container.addEventListener?.('input', (event) => {
    const demoConfig = event.target.closest?.('[data-demo-config]');
    if (demoConfig) {
      const key = demoConfig.dataset.demoConfig;
      platformState.selectedDemoConfig = {
        ...platformState.selectedDemoConfig,
        [key]: demoConfig.value
      };
      return;
    }
    const draftField = event.target.closest?.('[data-draft-field]');
    if (draftField) {
      updateDraftField(draftField.dataset.draftId, draftField.dataset.draftField, draftField.value);
    }
    const scoringForm = event.target.closest?.('[data-framework-form="scoring-settings"]');
    if (scoringForm) {
      const weightNames = ['breadth', 'quantity', 'depth', 'response_mix', 'activity_fit'];
      const total = weightNames.reduce((sum, name) => {
        return sum + Number(scoringForm.querySelector(`[name="${name}"]`)?.value || 0);
      }, 0);
      const submit = scoringForm.querySelector('button[type="submit"]');
      const errorEl = scoringForm.querySelector('[data-scoring-error]');
      if (submit) submit.disabled = total !== 100;
      if (errorEl) {
        errorEl.style.display = total === 100 ? 'none' : 'block';
        errorEl.textContent = `Weights must total 100%. Current total: ${total}%.`;
      }
    }
  });

  container.addEventListener?.('submit', (event) => {
    if (event.target.matches?.('[data-framework-form="identity"]')) {
      event.preventDefault();
      saveFrameworkIdentity(formEntries(event.target));
      return;
    }
    if (event.target.matches?.('[data-framework-form="scoring-settings"]')) {
      event.preventDefault();
      saveScoringSettings(formEntries(event.target));
      return;
    }
    if (event.target.matches?.('[data-settings-form="glossary-entry"]')) {
      event.preventDefault();
      saveGlossaryEntry(formEntries(event.target));
      return;
    }
    if (event.target.matches?.('[data-framework-form="bank"]')) {
      event.preventDefault();
      addFrameworkBank(formEntries(event.target));
      event.target.reset();
      return;
    }
    if (event.target.matches?.('[data-framework-form="kpi"]')) {
      event.preventDefault();
      const data = formEntries(event.target);
      addFrameworkKpi(data.domain_name, data);
      event.target.reset();
      return;
    }
    if (event.target.matches?.('[data-framework-form="question"]')) {
      event.preventDefault();
      addBankQuestion(formEntries(event.target));
      event.target.reset();
      return;
    }
    if (event.target.matches?.('[data-framework-form="ai-generate"]')) {
      event.preventDefault();
      generateQuestionsWithAI(formEntries(event.target));
      return;
    }
    if (event.target.matches?.('[data-component-participant-form]')) {
      event.preventDefault();
      callbacks().onAddParticipant?.(Object.fromEntries(new FormData(event.target).entries()));
      return;
    }
    if (event.target.matches?.('#user-role-form')) {
      event.preventDefault();
      callbacks().onSaveUser?.({
        name: event.target.querySelector('#role-user-name')?.value?.trim() || '',
        email: event.target.querySelector('#role-user-email')?.value?.trim() || '',
        role: event.target.querySelector('#role-user-role')?.value || 'participant',
        projectId: event.target.querySelector('#role-user-project')?.value || '',
        password: event.target.querySelector('#role-user-password')?.value?.trim() || ''
      });
      return;
    }
    if (event.target.matches?.('[data-component-ops-issue-form]')) {
      event.preventDefault();
      callbacks().onCreateIssue?.(Object.fromEntries(new FormData(event.target).entries()));
      return;
    }
    if (event.target.matches?.('[data-component-ops-qa-run-form]')) {
      event.preventDefault();
      callbacks().onRecordQaRun?.(Object.fromEntries(new FormData(event.target).entries()));
    }
  });
}

export function initPlatformSurface(container, callbacksArg = {}) {
  platformContainer = container;
  platformCallbacks = callbacksArg || {};
  if (typeof window !== 'undefined') {
    window.__platformSessionToken = platformCallbacks.sessionToken || '';
  }
  const platform = getSlice('platform') || {};
  const session = getSlice('session') || {};
  const operations = getSlice('operations') || {};
  platformState.classificationFilter = platform.classificationFilter || null;
  platformState.activeQuestionBankRole = session.activeQuestionBankRole || null;
  platformState.operationsSection = operations.section || 'overview';
  platformState.activeView = 'command-center';
  renderPlatformShell(container);
  wirePlatformShell(container);
  renderPlatformView('command-center');
  if (!platform.metrics || !Array.isArray(platform.projects) || platform.projects.length === 0) {
    bootstrapPlatformData().then(() => {
      renderPlatformView(platformState.activeView || 'command-center');
    });
  }
  loadFrameworks();
}

export function renderPlatformShell(container) {
  platformContainer = container;
  container.innerHTML = `
    <section class="platform-surface-shell">
      <aside class="platform-sidebar">
        <div class="platform-wordmark">
          Derive <span class="platform-wordmark-sub">intelligence</span>
        </div>
        ${renderContextStrip()}
        ${renderNav()}
        ${renderLogoutBlock()}
      </aside>
      <main class="platform-main">
        <div id="platform-surface-view" class="platform-surface-view">
          ${renderLoadingSkeleton('Loading platform workspace', 3)}
        </div>
      </main>
    </section>
  `;
  platformViewContainer = container.querySelector?.('#platform-surface-view') || null;
}

// ─── Derive Intelligence — Platform Owner view ────────────────────────────────
let intelligenceActiveTenantId = null;
let intelligenceBiDestroy = null;

async function renderPlatformIntelligence() {
  updateViewContainer('<p style="padding:24px;color:var(--text-muted)">Yükleniyor...</p>');

  let tenants = [];
  try {
    const res = await fetch('/api/platform/tenants', { headers: authHeaders() });
    const data = await res.json();
    tenants = Array.isArray(data) ? data.filter(t => t.status === 'active') : [];
  } catch (e) { tenants = []; }

  // Explicit entry: platform owner must pick a tenant (no silent auto-select).

  // Multi-tenant picker
  if (!intelligenceActiveTenantId) {
    updateViewContainer(`
      <div style="padding:32px;max-width:600px;margin:0 auto;">
        <h2 style="font-size:20px;font-weight:700;margin:0 0 20px;">Intelligence — Tenant Seç</h2>
        <div style="display:flex;flex-direction:column;gap:10px;">
          ${tenants.length
            ? tenants.map(t => `
                <button class="primary-button" data-intel-tenant="${escapeHtml(t.id)}" type="button"
                  style="justify-content:flex-start;gap:12px;">
                  🏢 ${escapeHtml(t.name)}
                </button>`).join('')
            : '<p style="color:var(--text-muted)">Aktif tenant bulunamadı.</p>'}
        </div>
      </div>`);
    platformViewContainer?.querySelectorAll('[data-intel-tenant]').forEach(btn => {
      btn.addEventListener('click', () => {
        intelligenceActiveTenantId = btn.dataset.intelTenant;
        renderPlatformIntelligence();
      });
    });
    return;
  }

  return _renderIntelligenceBiShell(tenants);
}

async function _renderIntelligenceBiShell(tenants = []) {
  // Destroy previous bi instance
  if (intelligenceBiDestroy) { try { intelligenceBiDestroy(); } catch(_){} intelligenceBiDestroy = null; }

  const tenant = tenants.find(t => t.id === intelligenceActiveTenantId)
    || { id: intelligenceActiveTenantId, name: 'Tenant' };

  // Tell the SERVER which tenant is being viewed (sets session.tenantId; RLS-safe impersonation)
  try {
    await fetch('/api/platform/enter-tenant', {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: tenant.id })
    });
  } catch (_) {}

  // Always-visible impersonation banner — never a silent default
  const contextBar = `
    <div style="display:flex;align-items:center;gap:10px;padding:8px 16px;border-bottom:1px solid #f59e0b;background:#fffbeb;color:#92400e;flex-shrink:0;font-size:13px;">
      <span>👁 Platform sahibi olarak görüntülüyorsunuz:</span>
      <strong>${escapeHtml(tenant.name)}</strong>
      <button class="text-button" id="intel-exit-tenant" style="margin-left:auto;font-size:13px;font-weight:600;color:#92400e;">Çıkış → Platform</button>
    </div>`;

  updateViewContainer(`
    <div style="display:flex;flex-direction:column;height:100%;overflow:hidden;">
      ${contextBar}
      <div id="bi-shell-mount" style="flex:1;min-height:0;overflow:auto;"></div>
    </div>`);

  platformViewContainer?.querySelector('#intel-exit-tenant')?.addEventListener('click', async () => {
    try { await fetch('/api/platform/exit-tenant', { method: 'POST', headers: authHeaders() }); } catch (_) {}
    intelligenceActiveTenantId = null;
    if (intelligenceBiDestroy) { try { intelligenceBiDestroy(); } catch(_){} intelligenceBiDestroy = null; }
    renderPlatformView('command-center');
  });

  const mount = platformViewContainer?.querySelector('#bi-shell-mount');
  if (!mount) return;

  const meBase = window.__currentUser || {};
  const me = { ...meBase, tenantId: tenant.id, tenantName: tenant.name };

  try {
    const { initBiSurface } = await import('./bi.js');
    const biCallbacks = {
      apiFetch: async (path, opts = {}) => {
        const sep = path.includes('?') ? '&' : '?';
        const res = await fetch(`${path}${sep}tenantId=${encodeURIComponent(tenant.id)}`,
          { ...opts, headers: { ...(opts.headers || {}), ...authHeaders() } });
        return res.json();
      },
      streamChat: async (dept, messages, onChunk) => {
        const res = await fetch(`/api/bi/department/${dept}/chat?tenantId=${encodeURIComponent(tenant.id)}`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', ...authHeaders() },
          body: JSON.stringify({ messages })
        });
        const reader = res.body.getReader();
        const dec = new TextDecoder();
        while (true) {
          const { done, value } = await reader.read();
          if (done) break;
          onChunk(dec.decode(value));
        }
      },
      logout: callbacks().logout || (() => { window.location.href = '/'; })
    };
    const result = initBiSurface(mount, me, { features: {}, permissions: {} }, biCallbacks);
    if (result?.destroy) intelligenceBiDestroy = result.destroy;
  } catch (err) {
    mount.innerHTML = `<p style="padding:24px;color:#e55;">BI modülü yüklenemedi: ${escapeHtml(err.message)}</p>`;
  }
}

export function renderPlatformView(viewId = 'command-center') {
  const nextView = PLATFORM_NAV.some((item) => item.id === viewId) ? viewId : 'command-center';
  platformState.activeView = nextView;
  window.__platformState = {
    activeView: nextView,
    selectedAssessmentOrgId: platformState.selectedAssessmentOrgId,
    activeProjectId: getSlice('platform')?.activeProjectId || platformState.selectedAssessmentOrgId || null,
    frameworkBuilderView: platformState.frameworkBuilderView,
    selectedFrameworkId: platformState.selectedFrameworkId
  };
  markActiveNav();

  if (nextView === 'command-center') renderPlatformCommandCenter();
  else if (nextView === 'organizations') renderPlatformOrganizations();
  else if (nextView === 'operations') renderPlatformOperations();
  else if (nextView === 'intelligence') renderPlatformIntelligence();
  else if (nextView === 'demo') renderPlatformDemo();
  else if (nextView === 'frameworks') renderPlatformFrameworks();
  else if (nextView === 'users') renderPlatformUsers();
  else if (nextView === 'assessment') renderPlatformAssessmentWorkspace();
  else if (!platformState.settings && !platformState.settingsLoading) loadPlatformSettings();
  else renderPlatformSettings();
}
