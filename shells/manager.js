import { getSlice } from '../store.js';
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

let managerContainer = null;
let managerStepContainer = null;
let managerCallbacks = {};

export let managerState = {
  activeStep: 1,
  addMode: null,
  notificationSent: false,
  lockedMessage: null
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

const STEPS = [
  { id: 1, name: 'Build your participant list' },
  { id: 2, name: 'Send invitations' },
  { id: 3, name: 'Follow up with non-responders' },
  { id: 4, name: 'Confirm and hand back' },
  { id: 5, name: 'Done' }
];

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function normalizeStatus(status = '') {
  return String(status || '').toLowerCase().replace(/\s+/g, '_');
}

function labelFromId(value = '') {
  return String(value || '')
    .replace(/[_-]/g, ' ')
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function firstUsefulLabel(values = [], fallback = '') {
  return values.find((value) => String(value || '').trim()) || fallback;
}

function activeOrganization(platform = {}) {
  const projects = safeArray(platform.projects);
  if (platform.activeProjectId) {
    const match = projects.find((project) => String(project.id) === String(platform.activeProjectId));
    if (match) return match;
  }
  return projects[0] || {};
}

function organizationName(organization = {}) {
  return firstUsefulLabel([
    organization.clientDisplayName,
    organization.client_display_name,
    organization.displayName,
    organization.display_name,
    organization.organizationName,
    organization.organization_name,
    organization.name
  ], 'Organization');
}

function assessmentRecord(assessment = {}) {
  return assessment.assessment || assessment.activeAssessment || assessment.managerCommandCenterState?.active_assessment || {};
}

function assessmentName(assessment = {}) {
  const record = assessmentRecord(assessment);
  return firstUsefulLabel([
    record.title,
    record.name,
    record.assessment_name,
    assessment.blueprint?.assessment_name
  ], 'Assessment');
}

function assessmentDeadline(assessment = {}) {
  const record = assessmentRecord(assessment);
  return record.deadline_at
    || record.deadline
    || record.due_at
    || record.dueDate
    || record.due_date
    || assessment.blueprint?.deadline_at
    || null;
}

function participantId(participant = {}) {
  return participant.participant_id || participant.id;
}

function normalizedParticipant(participant = {}) {
  const id = participantId(participant);
  return {
    ...participant,
    participant_id: id,
    full_name: participant.full_name || participant.name || participant.label || id || 'Participant',
    stakeholder_role_id: participant.stakeholder_role_id || participant.role_id || participant.role,
    stakeholder_role_name: participant.stakeholder_role_name || participant.role_name || participant.role,
    stakeholder_group_id: participant.stakeholder_group_id || participant.group_id || participant.group,
    stakeholder_group_name: participant.stakeholder_group_name || participant.group_name || participant.group,
    status: normalizeStatus(participant.status || 'not_started')
  };
}

function participantsFromStore(assessment = {}) {
  return safeArray(assessment.participants).map(normalizedParticipant);
}

function isCompleted(participant = {}) {
  return normalizeStatus(participant.status) === 'completed';
}

function hasBeenInvited(participant = {}) {
  const status = normalizeStatus(participant.status);
  return !['not_started', 'not_invited'].includes(status)
    || Number(participant.invite_count || 0) > 0
    || Boolean(participant.invite_sent_at || participant.last_invite_sent_at);
}

function requiredRolesFromBlueprint(blueprint = {}, coverage = {}) {
  const values = safeArray(blueprint.requiredRoles)
    .concat(safeArray(blueprint.required_roles))
    .concat(safeArray(blueprint.required_stakeholder_roles))
    .concat(safeArray(coverage.required_roles));
  const seen = new Set();
  return values.map((role) => {
    const id = typeof role === 'string'
      ? role
      : role.id || role.role_id || role.stakeholder_role_id || role.name || role.role_name || role.label;
    const name = typeof role === 'string'
      ? role
      : role.name || role.role_name || role.label || labelFromId(id);
    return { id: String(id || name || ''), name: name || labelFromId(id), required: true };
  }).filter((role) => {
    if (!role.id || seen.has(role.id)) return false;
    seen.add(role.id);
    return true;
  });
}

function recommendedRolesFromBlueprint(blueprint = {}, coverage = {}) {
  const values = safeArray(blueprint.recommendedRoles)
    .concat(safeArray(blueprint.recommended_roles))
    .concat(safeArray(coverage.recommended_roles));
  const seen = new Set();
  return values.map((role) => {
    const id = typeof role === 'string'
      ? role
      : role.id || role.role_id || role.stakeholder_role_id || role.name || role.role_name || role.label;
    const name = typeof role === 'string'
      ? role
      : role.name || role.role_name || role.label || labelFromId(id);
    return { id: String(id || name || ''), name: name || labelFromId(id), required: false };
  }).filter((role) => {
    if (!role.id || seen.has(role.id)) return false;
    seen.add(role.id);
    return true;
  });
}

function roleOptionsFromAssessment(assessment = {}) {
  const roles = requiredRolesFromBlueprint(assessment.blueprint || {}, assessment.coverage || {})
    .concat(recommendedRolesFromBlueprint(assessment.blueprint || {}, assessment.coverage || {}));
  return roles.map((role) => ({ id: role.id, name: role.name }));
}

function roleMatchesParticipant(role = {}, participant = {}) {
  const roleId = String(role.id || role.name || '').toLowerCase();
  const roleName = String(role.name || role.id || '').toLowerCase();
  const participantRoleId = String(participant.stakeholder_role_id || participant.role || '').toLowerCase();
  const participantRoleName = String(participant.stakeholder_role_name || participant.role_name || participant.role || '').toLowerCase();
  return participantRoleId === roleId || participantRoleName === roleName || participantRoleId === roleName;
}

function roleCoverage(roles = [], participants = []) {
  return roles.map((role) => {
    const count = participants.filter((participant) => roleMatchesParticipant(role, participant)).length;
    return { ...role, count };
  });
}

function stepOneComplete(assessment = {}, participants = participantsFromStore(assessment)) {
  const required = requiredRolesFromBlueprint(assessment.blueprint || {}, assessment.coverage || {});
  if (!required.length) return participants.length > 0;
  return required.every((role) => participants.some((participant) => roleMatchesParticipant(role, participant)));
}

function participantStats(participants = []) {
  const total = participants.length;
  const completed = participants.filter(isCompleted).length;
  const notResponded = participants.filter((participant) => !isCompleted(participant));
  const overdue = notResponded.filter((participant) => participant.overdue).length;
  const notStarted = notResponded.filter((participant) => ['not_started', 'not_invited', 'invited'].includes(normalizeStatus(participant.status))).length;
  const invited = participants.filter(hasBeenInvited).length;
  return { total, completed, notResponded: notResponded.length, overdue, notStarted, invited };
}

function invitationSentCount(assessment = {}, participants = []) {
  const summary = assessment.invitationSummary || {};
  return Number(summary.totalSent || summary.total_sent || summary.sent || 0) || participants.filter(hasBeenInvited).length;
}

export function computeManagerStep() {
  const assessment = getSlice('assessment') || {};
  const participants = participantsFromStore(assessment);
  const allResponded = participants.length > 0 && participants.every((participant) => participant.status === 'completed');
  const anyInvited = invitationSentCount(assessment, participants) > 0
    || participants.some((participant) => participant.status !== 'not_started' && participant.status !== 'not_invited');

  if (allResponded && managerState.notificationSent) return 5;
  if (allResponded) return 4;
  if (anyInvited) return 3;
  if (participants.length > 0) return 2;
  return 1;
}

function statusForStep(stepNumber, currentStep) {
  if (stepNumber < currentStep) return 'complete';
  if (stepNumber === currentStep) return 'current';
  return 'locked';
}

function lockedMessageFor(stepNumber) {
  const previous = STEPS.find((step) => step.id === stepNumber - 1);
  return previous ? `Complete ${previous.name.toLowerCase()} first.` : 'Start with the first step.';
}

function updateStepContainer(html) {
  if (!managerStepContainer && managerContainer) {
    managerStepContainer = managerContainer.querySelector?.('#manager-guided-step') || null;
  }
  if (managerStepContainer) managerStepContainer.innerHTML = html;
}

function managerEmptyState(title, message) {
  return renderScreenState('manager', 'empty', {
    title,
    message,
    compact: true
  });
}

function stepHeader(stepNumber, headline, explanation, status = 'current') {
  return `
    <div class="manager-step-header">
      <span class="manager-step-kicker">${status === 'complete' ? 'Complete ✓' : status === 'locked' ? 'Locked 🔒' : `Step ${stepNumber}`}</span>
      <h2>${escapeHtml(headline)}</h2>
      <p>${escapeHtml(explanation)}</p>
    </div>
  `;
}

function renderStepList(currentStep) {
  return `
    <aside class="manager-step-list" aria-label="Assessment collection steps">
      ${STEPS.map((step) => {
        const status = statusForStep(step.id, currentStep);
        const icon = status === 'complete' ? '✓' : status === 'current' ? '→' : '🔒';
        return `
          <button class="manager-step-item ${status}" data-manager-step="${step.id}" type="button" aria-disabled="${status === 'locked'}">
            <span>${icon}</span>
            <strong>Step ${step.id}</strong>
            <em>${escapeHtml(step.name)}</em>
          </button>
        `;
      }).join('')}
    </aside>
  `;
}

function renderLockedStep(stepNumber) {
  const step = STEPS.find((item) => item.id === stepNumber);
  updateStepContainer(`
    <section class="manager-guided-card locked">
      ${stepHeader(stepNumber, step?.name || 'Locked step', lockedMessageFor(stepNumber), 'locked')}
      ${managerState.lockedMessage ? `<p class="upload-note">${escapeHtml(managerState.lockedMessage)}</p>` : ''}
    </section>
  `);
}

function renderContextStrip() {
  const assessment = getSlice('assessment') || {};
  const platform = getSlice('platform') || {};
  const organization = activeOrganization(platform);
  const deadline = assessmentDeadline(assessment);
  return `
    <div class="consultant-context-strip manager-context-strip">
      <article><span>Organization</span><strong>${escapeHtml(organizationName(organization))}</strong></article>
      <article><span>Assessment</span><strong>${escapeHtml(assessmentName(assessment))}</strong></article>
      ${deadline ? `<article><span>Deadline</span><strong>${escapeHtml(new Date(deadline).toLocaleDateString())}</strong></article>` : ''}
    </div>
  `;
}

function addParticipantForm(assessment = {}) {
  const options = roleOptionsFromAssessment(assessment)
    .map((role) => `<option value="${escapeHtml(role.id)}">${escapeHtml(role.name)}</option>`)
    .join('');
  return `
    <form class="participant-form manager-inline-add-form" data-manager-add-participant-form>
      <h4>Add one person</h4>
      <div class="form-grid compact">
        <label>Name<input name="full_name" type="text" required autocomplete="name"></label>
        <label>Email<input name="email" type="email" required autocomplete="email"></label>
        <label>Role<select name="stakeholder_role_id" required>${options}</select></label>
      </div>
      <button class="primary-button" type="submit">Add participant</button>
    </form>
  `;
}

function renderStepOne(status = 'current') {
  const assessment = getSlice('assessment') || {};
  const participants = participantsFromStore(assessment);
  const requiredRoles = requiredRolesFromBlueprint(assessment.blueprint || {}, assessment.coverage || {});
  const recommendedRoles = recommendedRolesFromBlueprint(assessment.blueprint || {}, assessment.coverage || {});
  const allRoles = requiredRoles.concat(recommendedRoles);
  const coverage = roleCoverage(allRoles, participants);
  const addedRoleCount = coverage.filter((role) => role.count > 0).length;
  const complete = stepOneComplete(assessment, participants);
  const readOnly = status === 'complete';

  if (assessment.blueprint === undefined) {
    updateStepContainer(`
      <section class="manager-guided-card">
        ${renderLoadingSkeleton('Loading your participant requirements...', 3)}
      </section>
    `);
    return;
  }

  if (!allRoles.length) {
    updateStepContainer(`
      <section class="manager-guided-card">
        ${managerEmptyState(
          "Your consultant hasn't defined the required roles yet",
          'Contact them before adding participants.'
        )}
      </section>
    `);
    return;
  }

  updateStepContainer(`
    <section class="manager-guided-card">
      ${stepHeader(
        1,
        'Who needs to take part?',
        'Start by adding everyone who should contribute to this assessment. Your consultant has defined the required roles. You need to make sure the right people are included for each one.',
        complete ? 'complete' : status
      )}
      <div class="manager-role-coverage-list">
        ${coverage.map((role) => `
          <article class="${role.count > 0 ? 'covered' : 'missing'}">
            <strong>${escapeHtml(role.name)}</strong>
            <span>${role.count} added (${role.required ? 'required' : 'recommended'})</span>
          </article>
        `).join('')}
      </div>
      ${complete ? `
        <article class="manager-step-complete">
          <strong>✓ ${participants.length} participants added across ${addedRoleCount} roles.</strong>
          ${status === 'current' ? `<button class="primary-button" data-manager-step="2" type="button">Continue to invitations →</button>` : ''}
        </article>
      ` : ''}
      ${readOnly ? '' : `
        <div class="manager-choice-row">
          <button class="primary-button" data-manager-add-mode="upload" type="button">Upload a list</button>
          <button class="ghost-button" data-manager-add-mode="manual" type="button">Add one by one</button>
        </div>
        <div class="manager-inline-panel ${managerState.addMode === 'upload' ? 'active' : ''}">
          ${managerState.addMode === 'upload' ? renderParticipantUploadPanelComponent(
            assessment.uploadPreview,
            assessment.importSummary,
            managerEmptyState(
              'Upload participant list',
              'Download the template, fill in your participant list, and upload it here.'
            ),
            {
              onDownloadTemplate: managerCallbacks.onDownloadTemplate,
              onPreviewUpload: managerCallbacks.onPreviewUpload,
              onConfirmImport: managerCallbacks.onConfirmImport,
              onDownloadErrors: managerCallbacks.onDownloadErrors,
              onCreateSessionsForImported: managerCallbacks.onCreateSessionsForImported,
              onFileSelected: managerCallbacks.onFileSelected
            }
          ) : ''}
        </div>
        <div class="manager-inline-panel ${managerState.addMode === 'manual' ? 'active' : ''}">
          ${managerState.addMode === 'manual' ? addParticipantForm(assessment) : ''}
        </div>
      `}
    </section>
  `);
}

function renderStepTwo(status = 'current') {
  const assessment = getSlice('assessment') || {};
  const participants = participantsFromStore(assessment);
  const sent = invitationSentCount(assessment, participants);
  const ready = participants.filter((participant) => participant.status !== 'deactivated').length;
  const complete = sent > 0;

  if (status === 'locked') {
    renderLockedStep(2);
    return;
  }

  updateStepContainer(`
    <section class="manager-guided-card">
      ${stepHeader(
        2,
        'Invite everyone to participate',
        "Each person will receive a secure private link by email. Their responses are confidential — they won't see each other's answers. This usually takes less than 20 minutes to complete.",
        complete ? 'complete' : status
      )}
      <div class="blueprint-score-grid manager-stat-grid">
        <article><span>Ready to Invite</span><strong>${ready}</strong></article>
        <article><span>Invitations Sent</span><strong>${sent}</strong></article>
      </div>
      <details class="manager-email-preview">
        <summary>Preview email</summary>
        ${renderInvitationPanelComponent(
          assessment.invitationSummary,
          assessment.invitationPreview,
          {
            onBulkSend: managerCallbacks.onBulkSendInvites,
            onScopeChange: managerCallbacks.onInviteScopeChange
          }
        )}
      </details>
      ${complete ? `
        <article class="manager-step-complete">
          <strong>Invitations sent to ${sent} ${sent === 1 ? 'person' : 'people'}.</strong>
          ${assessment.invitationSummary?.sent_at || assessment.invitationSummary?.last_sent_at ? `<p>${escapeHtml(new Date(assessment.invitationSummary.sent_at || assessment.invitationSummary.last_sent_at).toLocaleString())}</p>` : ''}
          ${status === 'current' ? `<button class="primary-button" data-manager-step="3" type="button">Continue to follow-up →</button>` : ''}
        </article>
      ` : `
        <button class="primary-button" data-component-send-bulk-invitations type="button">Send invitations to all ${ready} participants</button>
      `}
    </section>
  `);
}

function reminderHistory(assessment = {}) {
  const summary = assessment.reminderSummary || {};
  const history = safeArray(summary.history || summary.reminder_history);
  if (history.length) {
    return history.map((item) => `<li>Reminder sent to ${escapeHtml(item.count || item.sent || 0)} people on ${escapeHtml(new Date(item.sent_at || item.created_at || Date.now()).toLocaleDateString())}</li>`).join('');
  }
  if (summary.sent || summary.last_sent_at) {
    return `<li>Reminder sent to ${escapeHtml(summary.sent || 0)} people on ${escapeHtml(new Date(summary.last_sent_at || Date.now()).toLocaleDateString())}</li>`;
  }
  return '<li>No reminders have been sent yet.</li>';
}

function renderStepThree(status = 'current') {
  const assessment = getSlice('assessment') || {};
  const participants = participantsFromStore(assessment);
  const stats = participantStats(participants);
  const percent = stats.total ? Math.round((stats.completed / stats.total) * 100) : 0;
  const notResponded = participants.filter((participant) => !isCompleted(participant));

  if (status === 'locked') {
    renderLockedStep(3);
    return;
  }

  if (stats.total > 0 && stats.completed === stats.total && status === 'current') {
    renderManagerStep(4);
    return;
  }

  updateStepContainer(`
    <section class="manager-guided-card">
      ${stepHeader(
        3,
        'Check who has responded',
        "People sometimes need a reminder. Check back here daily and send reminders to anyone who hasn't responded yet.",
        status
      )}
      <div class="manager-completion-hero">
        <div class="manager-completion-ring" style="--manager-completion:${percent}%;" role="img" aria-label="${escapeHtml(`${stats.completed} of ${stats.total} responded`)}">
          <div>
            <strong>${stats.completed} of ${stats.total}</strong>
            <span>responded</span>
          </div>
        </div>
        <div class="manager-overview-copy">
          <span class="eyebrow">Live Completion</span>
          <h3>${stats.completed} of ${stats.total} responded</h3>
          <p>${stats.notResponded} have not responded yet.</p>
        </div>
      </div>
      <div class="manager-not-responded-list">
        ${notResponded.map((participant) => `
          <article>
            <div>
              <strong>${escapeHtml(participant.full_name)}</strong>
              <span>${escapeHtml(participant.stakeholder_role_name || labelFromId(participant.stakeholder_role_id))}${participant.days_since_invite !== undefined && participant.days_since_invite !== null ? ` | ${escapeHtml(participant.days_since_invite)} days since invited` : ''}</span>
            </div>
            <button class="ghost-button" data-component-send-reminder="${escapeHtml(participant.participant_id)}" type="button">Send reminder</button>
          </article>
        `).join('') || `
          <article class="manager-step-complete">
            <strong>Everyone has responded. Well done.</strong>
            <button class="primary-button" data-manager-step="4" type="button">Continue →</button>
          </article>
        `}
      </div>
      ${notResponded.length ? `<button class="primary-button" data-component-send-bulk-reminders type="button">Send reminder to all who haven't responded</button>` : ''}
      ${renderReminderPanelComponent(
        participants,
        assessment.reminderSummary,
        assessment.reminderPreview,
        assessment.managerCommandCenterState?.reminderLiveSummary || {},
        {
          onBulkSend: managerCallbacks.onBulkSendReminders,
          onScopeChange: managerCallbacks.onReminderScopeChange
        }
      )}
      <div class="manager-reminder-history">
        <h4>Reminder history</h4>
        <ul>${reminderHistory(assessment)}</ul>
      </div>
    </section>
  `);
}

function renderStepFour(status = 'current') {
  const assessment = getSlice('assessment') || {};
  const platform = getSlice('platform') || {};
  const participants = participantsFromStore(assessment);
  const organization = activeOrganization(platform);
  const completedDates = participants.map((participant) => participant.completed_at || participant.completedAt).filter(Boolean);
  const completionDate = completedDates.length ? new Date(completedDates.sort().at(-1)).toLocaleDateString() : new Date().toLocaleDateString();

  if (status === 'locked') {
    renderLockedStep(4);
    return;
  }

  updateStepContainer(`
    <section class="manager-guided-card">
      ${stepHeader(
        4,
        'Your part is done',
        `All ${participants.length} participants have completed their assessment. Your consultant will now review the responses and prepare the findings. You don't need to do anything else at this stage.`,
        managerState.notificationSent ? 'complete' : status
      )}
      <div class="blueprint-score-grid manager-stat-grid">
        <article><span>Total Participants</span><strong>${participants.length}</strong></article>
        <article><span>Completion Date</span><strong>${escapeHtml(completionDate)}</strong></article>
        <article><span>Assessment</span><strong>${escapeHtml(assessmentName(assessment))}</strong></article>
        <article><span>Organization</span><strong>${escapeHtml(organizationName(organization))}</strong></article>
      </div>
      ${managerState.notificationSent ? `
        <article class="manager-step-complete">
          <strong>Your consultant has been notified. They will take it from here.</strong>
          ${status === 'current' ? `<button class="primary-button" data-manager-step="5" type="button">Continue →</button>` : ''}
        </article>
      ` : `
        <button class="primary-button" data-manager-notify-consultant type="button">Notify consultant</button>
      `}
    </section>
  `);
}

function renderStepFive(status = 'current') {
  const assessment = getSlice('assessment') || {};
  const platform = getSlice('platform') || {};
  const participants = participantsFromStore(assessment);
  const organization = activeOrganization(platform);
  const completedDates = participants.map((participant) => participant.completed_at || participant.completedAt).filter(Boolean);
  const completionDate = completedDates.length ? new Date(completedDates.sort().at(-1)).toLocaleDateString() : new Date().toLocaleDateString();

  if (status === 'locked') {
    renderLockedStep(5);
    return;
  }

  updateStepContainer(`
    <section class="manager-guided-card">
      ${stepHeader(
        5,
        'Assessment collection complete',
        'This assessment is now in review. Your consultant is preparing the findings. You will be notified if anything further is needed from you.',
        status
      )}
      <article class="manager-summary-card">
        <strong>${escapeHtml(organizationName(organization))}</strong>
        <span>${escapeHtml(assessmentName(assessment))}</span>
        <p>${participants.length} participants | Completed ${escapeHtml(completionDate)}</p>
      </article>
    </section>
  `);
}

function wireManagerShell(container) {
  container.addEventListener?.('click', (event) => {
    if (event.target.closest?.('[data-manager-logout]')) {
      handleLogout();
      return;
    }

    const stepButton = event.target.closest?.('[data-manager-step]');
    if (stepButton) {
      const step = Number(stepButton.dataset.managerStep);
      const computed = computeManagerStep();
      if (step > computed) {
        managerState.lockedMessage = lockedMessageFor(step);
        renderManagerStep(step);
      } else {
        managerState.lockedMessage = null;
        renderManagerStep(step);
      }
      return;
    }

    const addMode = event.target.closest?.('[data-manager-add-mode]');
    if (addMode) {
      managerState.addMode = addMode.dataset.managerAddMode;
      renderManagerStep(1);
      return;
    }

    if (event.target.closest?.('[data-manager-notify-consultant]')) {
      managerCallbacks.onNotifyConsultant?.();
      managerState.notificationSent = true;
      renderManagerStep(5);
      return;
    }

    const participantAction = event.target.closest?.('[data-component-edit-participant], [data-component-deactivate-participant], [data-component-create-session], [data-component-view-session], [data-component-generate-link], [data-component-copy-link], [data-component-open-link], [data-component-preview-invite], [data-component-send-invite], [data-component-preview-reminder], [data-component-send-reminder]');
    if (participantAction) {
      const d = participantAction.dataset;
      if (d.componentEditParticipant) managerCallbacks.onEditParticipant?.(d.componentEditParticipant);
      if (d.componentDeactivateParticipant) managerCallbacks.onDeactivateParticipant?.(d.componentDeactivateParticipant);
      if (d.componentCreateSession) managerCallbacks.onCreateSession?.(d.componentCreateSession);
      if (d.componentViewSession) managerCallbacks.onViewSession?.(d.componentViewSession);
      if (d.componentGenerateLink) managerCallbacks.onGenerateLink?.(d.componentGenerateLink);
      if (d.componentCopyLink) managerCallbacks.onCopyLink?.(participantAction.dataset.link || '');
      if (d.componentOpenLink) managerCallbacks.onViewSession?.(d.componentOpenLink);
      if (d.componentPreviewInvite) managerCallbacks.onPreviewInvite?.(d.componentPreviewInvite);
      if (d.componentSendInvite) managerCallbacks.onSendInvite?.(d.componentSendInvite);
      if (d.componentPreviewReminder) managerCallbacks.onPreviewReminder?.(d.componentPreviewReminder);
      if (d.componentSendReminder) managerCallbacks.onSendReminder?.(d.componentSendReminder);
      return;
    }

    if (event.target.closest?.('[data-component-download-template]')) managerCallbacks.onDownloadTemplate?.();
    if (event.target.closest?.('[data-component-preview-upload]')) managerCallbacks.onPreviewUpload?.();
    if (event.target.closest?.('[data-component-confirm-import]')) managerCallbacks.onConfirmImport?.();
    if (event.target.closest?.('[data-component-download-errors]')) managerCallbacks.onDownloadErrors?.();
    if (event.target.closest?.('[data-component-create-uploaded-sessions]')) managerCallbacks.onCreateSessionsForImported?.();
    if (event.target.closest?.('[data-component-send-bulk-invitations]')) managerCallbacks.onBulkSendInvites?.();
    if (event.target.closest?.('[data-component-send-bulk-reminders]')) managerCallbacks.onBulkSendReminders?.();
  });

  container.addEventListener?.('submit', (event) => {
    const form = event.target.closest?.('[data-manager-add-participant-form]');
    if (!form) return;
    event.preventDefault();
    managerCallbacks.onAddParticipant?.(Object.fromEntries(new FormData(form).entries()));
    form.reset?.();
  });

  container.addEventListener?.('change', (event) => {
    const uploadFile = event.target.closest?.('[data-component-upload-file]');
    if (uploadFile) {
      managerCallbacks.onFileSelected?.(uploadFile.files?.[0] || null);
      return;
    }

    const invitationScope = event.target.closest?.('[data-component-invitation-scope]');
    if (invitationScope) {
      managerCallbacks.onInviteScopeChange?.(invitationScope.value);
      return;
    }

    const reminderScope = event.target.closest?.('[data-component-reminder-scope]');
    if (reminderScope) {
      managerCallbacks.onReminderScopeChange?.(reminderScope.value);
    }
  });
}

export function initManagerSurface(container, callbacks = {}) {
  managerContainer = container;
  managerCallbacks = callbacks || {};
  managerState.activeStep = computeManagerStep();
  managerState.addMode = null;
  renderManagerShell(container);
  wireManagerShell(container);
  renderManagerStep(managerState.activeStep);
}

export function renderManagerShell(container) {
  managerContainer = container;
  const computed = computeManagerStep();
  container.innerHTML = `
    <section class="manager-guided-shell">
      <div style="position: relative;">
        ${renderContextStrip()}
        <button class="text-button" data-manager-logout type="button" style="position: absolute; top: 14px; right: 32px; color: var(--color-text-muted);">
          <i class="ti ti-logout" aria-hidden="true"></i>
          <span>Sign out</span>
        </button>
      </div>
      <div class="manager-guided-layout">
        ${renderStepList(computed)}
        <div id="manager-guided-step" class="manager-guided-step">
          ${renderLoadingSkeleton('Loading your assessment collection step', 3)}
        </div>
      </div>
    </section>
  `;
  managerStepContainer = container.querySelector?.('#manager-guided-step') || null;
}

export function renderManagerStep(stepNumber = computeManagerStep()) {
  const computed = computeManagerStep();
  const requested = Number(stepNumber) || computed;
  const status = statusForStep(requested, computed);
  managerState.activeStep = requested > computed ? computed : requested;
  window.__managerState = { activeStep: managerState.activeStep };

  if (managerContainer) {
    managerContainer.querySelector?.('.manager-step-list')?.replaceWith?.(
      htmlToElement(renderStepList(computed))
    );
  }

  if (requested > computed) {
    renderLockedStep(requested);
    return;
  }

  if (requested === 1) renderStepOne(status);
  else if (requested === 2) renderStepTwo(status);
  else if (requested === 3) renderStepThree(status);
  else if (requested === 4) renderStepFour(status);
  else renderStepFive(status);
}

function htmlToElement(html) {
  if (typeof document === 'undefined') {
    return { outerHTML: html };
  }
  const template = document.createElement('template');
  template.innerHTML = html.trim();
  return template.content.firstElementChild;
}
