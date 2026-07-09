const screenStateCopy = {
  respondent: {
    loading: {
      title: "Loading assessment",
      message: "Please wait while we verify your secure assessment link."
    },
    empty: {
      title: "No questions are available",
      message: "This role does not have an active question bank yet. Please contact the assessment administrator."
    },
    success: {
      title: "Assessment Completed",
      message: "Thank you. Your responses have been submitted."
    },
    error: {
      title: "Assessment link unavailable",
      message: "This link is invalid, expired, or has been regenerated. Please request a fresh link from the assessment administrator."
    }
  }
};

export function renderStateAction(config = {}) {
  if (!config.actionLabel) return "";
  const label = escapeHtml(config.actionLabel);
  if (config.actionView) return `<button class="primary-button state-action" data-state-view="${escapeHtml(config.actionView)}" type="button">${label}</button>`;
  if (config.actionId) return `<button class="primary-button state-action" data-state-target="${escapeHtml(config.actionId)}" type="button">${label}</button>`;
  return "";
}

export function renderScreenState(screenId, state = "empty", overrides = {}) {
  const config = {
    ...(screenStateCopy[screenId]?.[state] || {}),
    ...overrides
  };
  const status = state === "error" ? "error" : state === "warning" ? "warning" : state === "success" ? "success" : state === "loading" ? "loading" : state === "permission" ? "permission" : "empty";
  return `
    <article class="screen-state screen-state-${status} ${overrides.compact ? "compact" : ""}" role="${status === "error" || status === "warning" ? "alert" : "status"}">
      <span class="state-badge">${escapeHtml(status === "permission" ? "Permission Denied" : status)}</span>
      <strong>${escapeHtml(config.title || "No data available")}</strong>
      <p>${escapeHtml(config.message || "This screen will populate when the required data is available.")}</p>
      ${config.details ? `<small>${escapeHtml(config.details)}</small>` : ""}
      ${renderStateAction(config)}
    </article>
  `;
}

export function renderLoadingSkeleton(title = "Loading", rows = 4) {
  return `
    <article class="screen-state screen-state-loading" role="status">
      <span class="state-badge">loading</span>
      <strong>${escapeHtml(title)}</strong>
      <div class="state-skeleton-list">
        ${Array.from({ length: rows }).map(() => `<i></i>`).join("")}
      </div>
    </article>
  `;
}

export function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

export function renderGlossaryTooltip(key, term, shortDef = "") {
  return `
    <span
      class="glossary-tooltip"
      data-glossary-key="${escapeHtml(key)}"
      title="${escapeHtml(shortDef)}"
      style="display:inline-flex;align-items:center;gap:4px;cursor:help;border-bottom:1px dotted rgba(200,169,110,0.4);"
    >
      ${escapeHtml(term)}
      <svg width="12" height="12" viewBox="0 0 12 12" style="opacity:0.5" aria-hidden="true">
        <circle cx="6" cy="6" r="5" stroke="currentColor" stroke-width="1" fill="none"></circle>
        <text x="6" y="9" text-anchor="middle" font-size="8" fill="currentColor">i</text>
      </svg>
    </span>
  `;
}

export function statusClass(status = "Draft") {
  return String(status || "Draft").toLowerCase().replace(/[^a-z0-9]+/g, "-");
}

export function participantStatusLabel(status = "not_invited") {
  return String(status || "not_invited").replace(/_/g, " ").replace(/\b\w/g, (letter) => letter.toUpperCase());
}
