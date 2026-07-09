import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

function formatStakeholderId(value = "") {
  return String(value || "")
    .replace(/_/g, " ")
    .replace(/-/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function participantStatusLabel(status = "") {
  const labels = {
    not_invited: "Not Invited",
    invited: "Invited",
    started: "Started",
    completed: "Completed",
    deactivated: "Deactivated",
    incomplete: "Incomplete",
    no_email: "No Email",
    overdue: "Overdue",
    not_sent: "Not Sent",
    sent: "Sent",
    failed: "Failed",
    disabled: "Disabled",
    skipped: "Skipped"
  };
  return labels[status] || formatStakeholderId(status || "Unknown");
}

function stakeholderGroupLabel(id = "") {
  return formatStakeholderId(id || "group");
}

function stakeholderRoleLabel(id = "") {
  return formatStakeholderId(id || "role");
}

function normalizeRoleOptions(roleOptions = "") {
  if (typeof roleOptions === "string") return roleOptions;
  return (roleOptions || []).map((role) => `<option value="${escapeHtml(role.id || role.value)}">${escapeHtml(role.name || role.label || role.id || role.value)}</option>`).join("");
}

function participantCoverageRows(coverage = {}) {
  const groups = [
    ["required_roles", "Required"],
    ["recommended_roles", "Recommended"],
    ["optional_roles", "Optional"]
  ];
  const rows = groups.flatMap(([key, level]) => (coverage[key] || []).map((role) => ({ ...role, level })));
  return rows.length
    ? rows.map((role) => `
      <tr>
        <td>${escapeHtml(role.name || stakeholderRoleLabel(role.id))}</td>
        <td>${escapeHtml(role.level)}</td>
        <td>${Number(role.assigned_count || role.assigned || 0)}</td>
        <td>${Number(role.completed_count || role.completed || 0)}</td>
        <td><span class="status-pill ${statusClass(role.status || "missing")}">${participantStatusLabel(role.status || "missing")}</span></td>
        <td>${escapeHtml(role.question_bank || "-")}</td>
      </tr>
    `).join("")
    : `<tr><td colspan="6">Blueprint coverage will appear after the assessment blueprint is generated.</td></tr>`;
}

function filterParticipants(participants = [], filters = {}) {
  return participants.filter((participant) => {
    if (filters.group && participant.stakeholder_group_id !== filters.group) return false;
    if (filters.role && participant.stakeholder_role_id !== filters.role) return false;
    if (filters.status === "incomplete" && ["completed", "deactivated"].includes(participant.status)) return false;
    else if (filters.status === "no_email" && participant.email) return false;
    else if (filters.status === "overdue" && !participant.overdue) return false;
    else if (filters.status && !["incomplete", "no_email", "overdue"].includes(filters.status) && participant.status !== filters.status) return false;
    return true;
  });
}

export function renderParticipantsSectionComponent(
  assessment,
  participants = [],
  coverage = {},
  filters = {},
  participantAccessLinks = {},
  roleOptions = "",
  emptyStateHtml = "",
  {
    onAddParticipant,
    onEdit,
    onDeactivate,
    onCreateSession,
    onViewSession,
    onGenerateLink,
    onCopyLink,
    onOpenLink,
    onPreviewInvite,
    onSendInvite,
    onPreviewReminder,
    onSendReminder,
    onFilterChange
  } = {}
) {
  const summary = coverage.summary || {};
  const roleIds = [...new Set(participants.map((item) => item.stakeholder_role_id).filter(Boolean))];
  const groupIds = [...new Set(participants.map((item) => item.stakeholder_group_id).filter(Boolean))];
  const visibleParticipants = filterParticipants(participants, filters);
  if (!assessment?.id) {
    return `
      <section class="engine-block participants-panel">
        <div class="owner-section-head">
          <div><span class="eyebrow">Participants</span><h3>Assessment Participants</h3></div>
        </div>
        ${emptyStateHtml || renderScreenState("participants", "empty", {
          title: "Create an assessment first",
          message: "Participants are linked to a specific assessment. Create the assessment before adding real people.",
          actionLabel: "Create Assessment",
          actionId: "create-assessment-engine"
        })}
      </section>
    `;
  }
  return `
    <section class="engine-block participants-panel">
      <div class="owner-section-head">
        <div><span class="eyebrow">Participants</span><h3>Assessment Participants</h3></div>
        <span>${participants.length} total records</span>
      </div>
      <div class="blueprint-score-grid">
        <article><span>Total Participants</span><strong>${summary.total_participants || 0}</strong></article>
        <article><span>Required Assigned</span><strong>${summary.required_roles_assigned || 0}/${summary.required_roles_total || 0}</strong></article>
        <article><span>Required Completed</span><strong>${summary.required_roles_completed || 0}/${summary.required_roles_total || 0}</strong></article>
        <article><span>Participant Completion</span><strong>${summary.participant_completion_percent || 0}%</strong></article>
      </div>
      <div class="participant-layout">
        ${onAddParticipant ? `
          <form data-component-participant-form class="participant-form">
            <h4>Add Participant</h4>
            <div class="form-grid compact">
              <label>First Name<input name="first_name" type="text" autocomplete="given-name"></label>
              <label>Last Name<input name="last_name" type="text" autocomplete="family-name"></label>
              <label>Email<input name="email" type="email" autocomplete="email"></label>
              <label>Stakeholder Role<select name="stakeholder_role_id" required>${normalizeRoleOptions(roleOptions)}</select></label>
              <label>Department<input name="department" type="text"></label>
              <label>Location<input name="location" type="text"></label>
            </div>
            <label>Notes<textarea name="notes" rows="2"></textarea></label>
            <button class="primary-button" type="submit">Add Participant</button>
          </form>
        ` : ""}
        <div>
          <h4>Blueprint Role Coverage</h4>
          <div class="table-scroll">
            <table class="compact-table">
              <thead><tr><th>Role</th><th>Level</th><th>Assigned</th><th>Completed</th><th>Status</th><th>Question Bank</th></tr></thead>
              <tbody>${participantCoverageRows(coverage)}</tbody>
            </table>
          </div>
        </div>
      </div>
      ${onFilterChange ? `
        <div class="participant-filters">
          <label>Group
            <select data-component-participant-filter="group">
              <option value="">All groups</option>
              ${groupIds.map((id) => `<option value="${escapeHtml(id)}" ${filters.group === id ? "selected" : ""}>${escapeHtml(stakeholderGroupLabel(id))}</option>`).join("")}
            </select>
          </label>
          <label>Role
            <select data-component-participant-filter="role">
              <option value="">All roles</option>
              ${roleIds.map((id) => `<option value="${escapeHtml(id)}" ${filters.role === id ? "selected" : ""}>${escapeHtml(stakeholderRoleLabel(id))}</option>`).join("")}
            </select>
          </label>
          <label>Status
            <select data-component-participant-filter="status">
              <option value="">All statuses</option>
              ${["not_invited", "invited", "started", "completed", "incomplete", "no_email", "overdue", "deactivated"].map((status) => `<option value="${status}" ${filters.status === status ? "selected" : ""}>${participantStatusLabel(status)}</option>`).join("")}
            </select>
          </label>
        </div>
      ` : ""}
      <div class="table-scroll">
        <table class="compact-table">
          <thead>
            <tr><th>Name</th><th>Email</th><th>Group</th><th>Role</th><th>Status</th><th>Email</th><th>Reminder</th><th>Invites</th><th>Progress</th><th>Overdue</th><th>Session</th><th>Invite Actions</th><th>Actions</th></tr>
          </thead>
          <tbody>
            ${visibleParticipants.map((participant) => {
              const savedLink = participantAccessLinks[participant.participant_id] || "";
              return `
              <tr>
                <td><strong>${escapeHtml(participant.full_name || "-")}</strong></td>
                <td>${escapeHtml(participant.email || "-")}</td>
                <td>${escapeHtml(participant.stakeholder_group_name || stakeholderGroupLabel(participant.stakeholder_group_id))}</td>
                <td>${escapeHtml(participant.stakeholder_role_name || stakeholderRoleLabel(participant.stakeholder_role_id))}</td>
                <td><span class="status-pill ${statusClass(participant.status)}">${participantStatusLabel(participant.status)}</span></td>
                <td><span class="status-pill ${statusClass(participant.email_status || "not_sent")}">${participantStatusLabel(participant.email_status || "not_sent")}</span>${participant.email_error ? `<br><small>${escapeHtml(participant.email_error)}</small>` : ""}</td>
                <td><span class="status-pill ${statusClass(participant.reminder_status || "not_sent")}">${participantStatusLabel(participant.reminder_status || "not_sent")}</span><br><small>${participant.reminder_count || 0} sent${participant.last_reminder_sent_at ? ` · ${new Date(participant.last_reminder_sent_at).toLocaleDateString()}` : ""}</small></td>
                <td>${participant.invite_count || 0}</td>
                <td>${participant.completion_percent || 0}%</td>
                <td>${participant.overdue ? `<span class="status-pill rejected">Overdue</span>` : "-"}<br><small>${participant.days_since_invite !== null && participant.days_since_invite !== undefined ? `${participant.days_since_invite}d since invite` : ""}${participant.days_since_started !== null && participant.days_since_started !== undefined ? ` ${participant.days_since_started}d since start` : ""}</small></td>
                <td>${participant.session_id ? `<span>${escapeHtml(participant.session_status || "created")}</span>` : "<span>No session</span>"}</td>
                <td>
                  <div class="row-actions">
                    ${onPreviewInvite ? `<button class="ghost-button" data-component-preview-invite="${escapeHtml(participant.participant_id)}" type="button">Preview Email</button>` : ""}
                    ${onSendInvite ? `<button class="ghost-button" data-component-send-invite="${escapeHtml(participant.participant_id)}" type="button">${participant.invite_count ? "Resend Invite" : "Send Invite"}</button>` : ""}
                    ${onPreviewReminder ? `<button class="ghost-button" data-component-preview-reminder="${escapeHtml(participant.participant_id)}" type="button">Preview Reminder</button>` : ""}
                    ${onSendReminder ? `<button class="ghost-button" data-component-send-reminder="${escapeHtml(participant.participant_id)}" type="button">Send Reminder</button>` : ""}
                    ${onGenerateLink ? `<button class="ghost-button" data-component-generate-link="${escapeHtml(participant.participant_id)}" type="button">${participant.active_token_expires_at ? "Regenerate" : "Generate"} Link</button>` : ""}
                    ${savedLink && onCopyLink ? `<button class="ghost-button" data-component-copy-link="${escapeHtml(participant.participant_id)}" data-link="${escapeHtml(savedLink)}" type="button">Copy Link</button>` : ""}
                    ${savedLink && onOpenLink ? `<button class="ghost-button" data-component-open-link="${escapeHtml(participant.participant_id)}" data-link="${escapeHtml(savedLink)}" type="button">Open</button>` : ""}
                  </div>
                </td>
                <td>
                  <div class="row-actions">
                    ${onEdit ? `<button class="ghost-button" data-component-edit-participant="${escapeHtml(participant.participant_id)}" type="button">Edit</button>` : ""}
                    ${participant.session_id ? (onViewSession ? `<button class="ghost-button" data-component-view-session="${escapeHtml(participant.session_id)}" type="button">View Session</button>` : "") : (onCreateSession ? `<button class="ghost-button" data-component-create-session="${escapeHtml(participant.participant_id)}" type="button">Create Session</button>` : "")}
                    ${participant.status !== "deactivated" && onDeactivate ? `<button class="ghost-button" data-component-deactivate-participant="${escapeHtml(participant.participant_id)}" type="button">Deactivate</button>` : ""}
                  </div>
                </td>
              </tr>
            `;
            }).join("") || `<tr><td colspan="13">${emptyStateHtml || renderScreenState("participants", "empty", { compact: true })}</td></tr>`}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

export function renderParticipantUploadPanelComponent(
  uploadPreview = null,
  importSummary = null,
  emptyStateHtml = "",
  {
    onDownloadTemplate,
    onPreviewUpload,
    onConfirmImport,
    onDownloadErrors,
    onCreateSessionsForImported,
    onFileSelected
  } = {}
) {
  const preview = uploadPreview;
  const summary = importSummary;
  const hasProblemRows = preview?.rows?.some((row) => row.status !== "Ready");
  return `
    <section class="bulk-upload-panel">
      <div class="owner-section-head">
        <div>
          <span class="eyebrow">Bulk Upload</span>
          <h4>Upload Stakeholder List</h4>
          <p>CSV and Excel uploads create participants only. They do not send emails or generate invitation links.</p>
        </div>
        <div class="row-actions">
          ${onDownloadTemplate ? `<button class="ghost-button" data-component-download-template type="button">Download Template</button>` : ""}
          ${onPreviewUpload ? `<button class="ghost-button" data-component-preview-upload type="button">Preview Import</button>` : ""}
          ${onConfirmImport ? `<button class="primary-button" data-component-confirm-import type="button" ${preview?.upload_batch_id ? "" : "disabled"}>Import Valid Rows</button>` : ""}
        </div>
      </div>
      <div class="bulk-upload-controls">
        ${onFileSelected ? `
          <label class="file-button">
            Upload CSV / Excel
            <input data-component-upload-file type="file" accept=".csv,.xlsx,.xls" />
          </label>
        ` : ""}
        ${onDownloadErrors ? `<button class="ghost-button" data-component-download-errors type="button" ${hasProblemRows ? "" : "disabled"}>Download Error Report</button>` : ""}
        ${onCreateSessionsForImported ? `<button class="ghost-button" data-component-create-uploaded-sessions type="button">Create Sessions For Imported Participants</button>` : ""}
      </div>
      ${preview ? `
        <div class="blueprint-score-grid upload-summary-grid">
          <article><span>Rows Uploaded</span><strong>${preview.rows_uploaded || 0}</strong></article>
          <article><span>Ready</span><strong>${preview.valid_count || 0}</strong></article>
          <article><span>Warnings</span><strong>${preview.warning_count || 0}</strong></article>
          <article><span>Invalid</span><strong>${preview.invalid_count || 0}</strong></article>
          <article><span>Duplicates</span><strong>${preview.duplicate_count || 0}</strong></article>
        </div>
        ${preview.unknown_columns?.length ? `<p class="upload-note">Ignored unknown columns: ${preview.unknown_columns.map(escapeHtml).join(", ")}</p>` : ""}
        <div class="table-scroll">
          <table class="compact-table">
            <thead><tr><th>Row</th><th>Name</th><th>Email</th><th>Group</th><th>Role</th><th>Department</th><th>Location</th><th>Status</th><th>Issues</th></tr></thead>
            <tbody>
              ${(preview.rows || []).slice(0, 60).map((row) => `
                <tr>
                  <td>${row.row_number || "-"}</td>
                  <td><strong>${escapeHtml(row.full_name || `${row.first_name || ""} ${row.last_name || ""}`.trim() || "-")}</strong></td>
                  <td>${escapeHtml(row.email || "-")}</td>
                  <td>${escapeHtml(row.stakeholder_group_name || "-")}</td>
                  <td>${escapeHtml(row.stakeholder_role_name || row.stakeholder_role_input || "-")}</td>
                  <td>${escapeHtml(row.department || "-")}</td>
                  <td>${escapeHtml(row.location || "-")}</td>
                  <td><span class="status-pill ${statusClass(row.status)}">${escapeHtml(row.status || "-")}</span></td>
                  <td>${[...(row.issues || []), ...(row.warnings || [])].map((item) => `<span class="mini-chip">${escapeHtml(item)}</span>`).join("") || "-"}</td>
                </tr>
              `).join("")}
            </tbody>
          </table>
        </div>
      ` : (emptyStateHtml || renderScreenState("participant-upload", "empty"))}
      ${summary ? `
        <article class="upload-result">
          <strong>${summary.imported_participants ?? summary.created_sessions ?? 0} ${summary.created_sessions !== undefined ? "sessions created" : "participants imported"}</strong>
          <p>Rows uploaded: ${summary.rows_uploaded || 0} · Duplicates skipped: ${summary.duplicates_skipped || 0} · Invalid skipped: ${summary.invalid_skipped || 0} · Warnings skipped: ${summary.warnings_skipped || 0}</p>
        </article>
      ` : ""}
    </section>
  `;
}

export function renderInvitationPanelComponent(
  invitationSummary = null,
  invitationPreview = null,
  { onBulkSend, onScopeChange } = {}
) {
  const summary = invitationSummary;
  const preview = invitationPreview;
  return `
    <section class="bulk-upload-panel invitation-panel">
      <div class="owner-section-head">
        <div>
          <span class="eyebrow">Email Invitations</span>
          <h4>Send Assessment Links</h4>
          <p>Invitations use secure magic links and never expose admin pages. If email is disabled, copy links manually.</p>
        </div>
        ${onBulkSend || onScopeChange ? `
          <div class="bulk-upload-controls">
            <label>Bulk send
              <select data-component-invitation-scope>
                <option value="not_invited">All not invited</option>
                <option value="incomplete">Incomplete participants</option>
                <option value="required">Required roles only</option>
                <option value="recommended">Recommended roles only</option>
              </select>
            </label>
            ${onBulkSend ? `<button class="primary-button" data-component-send-bulk-invitations type="button">Send Invitations</button>` : ""}
          </div>
        ` : ""}
      </div>
      ${summary ? `
        <div class="blueprint-score-grid upload-summary-grid">
          <article><span>Sent</span><strong>${summary.sent || (summary.status === "sent" ? 1 : 0)}</strong></article>
          <article><span>Disabled</span><strong>${summary.disabled || (summary.status === "disabled" ? 1 : 0)}</strong></article>
          <article><span>Failed</span><strong>${summary.failed || (summary.status === "failed" ? 1 : 0)}</strong></article>
          <article><span>Skipped</span><strong>${summary.skipped || 0}</strong></article>
          <article><span>Missing Email</span><strong>${summary.missing_email || 0}</strong></article>
          <article><span>No Session</span><strong>${summary.no_session || 0}</strong></article>
        </div>
        ${summary.email_status_message || summary.error ? `<p class="upload-note">${escapeHtml(summary.email_status_message || summary.error)}</p>` : ""}
      ` : `<p class="upload-note">Create sessions before sending. Participants without sessions, emails, or active status are skipped.</p>`}
      ${preview ? `
        <article class="upload-result invitation-preview-card">
          <div class="owner-section-head">
            <div><span class="eyebrow">Preview Email</span><strong>${escapeHtml(preview.email?.subject || "")}</strong></div>
            <span>${escapeHtml(preview.participant?.full_name || "")}</span>
          </div>
          <pre>${escapeHtml(preview.email?.body || "")}</pre>
          ${preview.emailDelivery?.configured ? "" : `<p class="upload-note">Email sending is not configured. You can still copy the invitation link manually.</p>`}
        </article>
      ` : ""}
    </section>
  `;
}

export function renderReminderPanelComponent(
  participants = [],
  reminderSummary = null,
  reminderPreview = null,
  liveSummary = {},
  { onBulkSend, onScopeChange } = {}
) {
  const summary = reminderSummary;
  const preview = reminderPreview;
  return `
    <section class="bulk-upload-panel reminder-panel">
      <div class="owner-section-head">
        <div>
          <span class="eyebrow">Reminders</span>
          <h4>Improve Completion Rates</h4>
          <p>Send manual reminders to invited or started participants. No scheduled automation runs yet.</p>
        </div>
        ${onBulkSend || onScopeChange ? `
          <div class="bulk-upload-controls">
            <label>Bulk reminder
              <select data-component-reminder-scope>
                <option value="incomplete">All incomplete</option>
                <option value="invited">Invited, not started</option>
                <option value="started">Started, not completed</option>
                <option value="required">Required roles only</option>
                <option value="recommended">Recommended roles only</option>
              </select>
            </label>
            ${onBulkSend ? `<button class="primary-button" data-component-send-bulk-reminders type="button">Send Reminders</button>` : ""}
          </div>
        ` : ""}
      </div>
      <div class="blueprint-score-grid upload-summary-grid">
        <article><span>Incomplete</span><strong>${liveSummary.incomplete_participants || 0}</strong></article>
        <article><span>Overdue</span><strong>${liveSummary.overdue_participants || 0}</strong></article>
        <article><span>Reminders Sent</span><strong>${liveSummary.reminders_sent || 0}</strong></article>
        <article><span>Not Started</span><strong>${liveSummary.not_started_after_invite || 0}</strong></article>
        <article><span>Started</span><strong>${liveSummary.started_but_not_completed || 0}</strong></article>
      </div>
      ${summary ? `
        <div class="blueprint-score-grid upload-summary-grid">
          <article><span>Sent</span><strong>${summary.sent || (summary.status === "sent" ? 1 : 0)}</strong></article>
          <article><span>Disabled</span><strong>${summary.disabled || (summary.status === "disabled" ? 1 : 0)}</strong></article>
          <article><span>Failed</span><strong>${summary.failed || (summary.status === "failed" ? 1 : 0)}</strong></article>
          <article><span>Skipped Completed</span><strong>${summary.skipped_completed || 0}</strong></article>
          <article><span>No Email</span><strong>${summary.skipped_missing_email || 0}</strong></article>
          <article><span>No Session</span><strong>${summary.skipped_no_session || 0}</strong></article>
        </div>
        ${summary.reminder_status_message || summary.error ? `<p class="upload-note">${escapeHtml(summary.reminder_status_message || summary.error)}</p>` : ""}
      ` : ""}
      ${preview ? `
        <article class="upload-result invitation-preview-card">
          <div class="owner-section-head">
            <div><span class="eyebrow">Preview Reminder</span><strong>${escapeHtml(preview.email?.subject || "")}</strong></div>
            <span>${escapeHtml(preview.progress_percent || 0)}% progress</span>
          </div>
          <pre>${escapeHtml(preview.email?.body || "")}</pre>
          ${preview.emailDelivery?.configured ? "" : `<p class="upload-note">Email sending is not configured. You can copy the link manually.</p>`}
        </article>
      ` : ""}
    </section>
  `;
}
