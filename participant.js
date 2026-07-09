import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass,
  participantStatusLabel
} from './shared.js';

const respondPathMatch = location.pathname.match(/^\/respond\/([^/?#]+)/);
const activeRespondToken = respondPathMatch ? decodeURIComponent(respondPathMatch[1]) : "";
let respondentAssessmentState = null;
let respondentSaveTimer = null;
let respondentValidationIssues = { missing_required_questions: [], invalid_answers: [] };
let respondentClientValidationIssues = {};
let respondentSaveStatus = "Your answers are saved automatically.";
let respondentLastSavedAt = "";
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

async function apiRequest(path, options = {}) {
  const response = await fetch(path, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {})
    },
    ...options
  });
  const payload = await response.json().catch(() => ({}));
  if (!response.ok) {
    const error = new Error(payload.message || payload.error || "Request failed");
    Object.assign(error, payload);
    throw error;
  }
  return payload;
}

export function respondentQuestionOptions(question = {}) {
  const normalizeOption = (option) => {
    if (option && typeof option === "object") return String(option.label || option.value || option.text || "");
    return String(option ?? "");
  };
  if (Array.isArray(question.options) && question.options.length) return question.options.map(normalizeOption).filter(Boolean);
  if (typeof question.options === "string") {
    try {
      const parsed = JSON.parse(question.options);
      return Array.isArray(parsed) ? parsed.map(normalizeOption).filter(Boolean) : [];
    } catch {
      return question.options ? [question.options] : [];
    }
  }
  if (question.response_type === "scale_1_5") return ["1", "2", "3", "4", "5"];
  if (question.response_type === "yes_no") return ["Yes", "No"];
  return [];
}

export function respondentAnswerFor(question = {}) {
  const response = respondentAssessmentState?.responses?.[question.question_id] || {};
  const rawValue = response.answer_value ?? "";
  if (Array.isArray(rawValue)) return rawValue;
  if (rawValue && typeof rawValue === "object") return rawValue;
  return response.answer_text ?? rawValue ?? "";
}

function percentageValidationMessage(value) {
  if (value === null || value === undefined || String(value).trim() === "") return "";
  const text = String(value).trim().replace(/%/g, "").replace(",", ".");
  if (!/^\d+(\.\d+)?$/.test(text)) return "Please enter a number between 0 and 100 (e.g. 85)";
  const number = Number(text);
  if (!Number.isFinite(number) || number < 0 || number > 100) return "Please enter a number between 0 and 100 (e.g. 85)";
  return "";
}

function validatePercentageAnswers() {
  const questions = respondentAssessmentState?.questions || [];
  const nextIssues = {};
  questions.forEach((question) => {
    if (question.response_type !== "percentage") return;
    const message = percentageValidationMessage(respondentAnswerFor(question));
    if (message) nextIssues[question.question_id] = message;
  });
  respondentClientValidationIssues = nextIssues;
  return nextIssues;
}

function setInlineValidationError(field, message) {
  const card = field?.closest("[data-question-card]");
  if (!card) return;
  const questionId = card.dataset.questionCard;
  card.classList.toggle("has-validation-error", Boolean(message));
  let error = card.querySelector(`[data-validation-error="${CSS.escape(questionId)}"]`);
  if (message && !error) {
    error = document.createElement("p");
    error.dataset.validationError = questionId;
    error.className = "respondent-field-error";
    field.insertAdjacentElement("afterend", error);
  }
  if (error) {
    error.textContent = message;
    if (!message) error.remove();
  }
}

export function respondentValueHasAnswer(value) {
  if (value === null || value === undefined) return false;
  if (Array.isArray(value)) return value.some((item) => String(item || "").trim());
  return String(value).trim() !== "";
}

export function respondentRequiredProgress(questions = []) {
  const required = questions.filter((question) => question.required);
  const answered = required.filter((question) => respondentValueHasAnswer(respondentAnswerFor(question)));
  const missingFromServer = new Set(respondentValidationIssues?.missing_required_questions || []);
  return {
    answered: answered.length,
    total: required.length,
    missing: Math.max(0, required.length - answered.length, missingFromServer.size)
  };
}

export function respondentSections(questions = []) {
  const sections = [];
  questions.forEach((question) => {
    const name = question.section || "Assessment";
    let section = sections.find((item) => item.name === name);
    if (!section) {
      section = { name, total: 0, answered: 0 };
      sections.push(section);
    }
    section.total += 1;
    if (respondentValueHasAnswer(respondentAnswerFor(question))) section.answered += 1;
  });
  return sections;
}

export function renderRespondentSavedIndicator(question = {}) {
  return respondentValueHasAnswer(respondentAnswerFor(question))
    ? '<small class="respondent-saved-indicator">Saved</small>'
    : '<small class="respondent-saved-indicator pending">Not answered yet</small>';
}

export function renderRespondentField(question = {}) {
  const id = `respondent-${question.question_id}`;
  const value = respondentAnswerFor(question);
  const options = respondentQuestionOptions(question);
  const responseType = question.response_type || "open_text";
  if (responseType === "multiple_choice") {
    return `
      <div class="respondent-option-grid" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}">
        ${options.map((option) => {
          const checked = Array.isArray(value) && value.includes(option);
          return `<label class="respondent-option"><input class="respondent-field" type="checkbox" value="${escapeHtml(option)}" ${checked ? "checked" : ""}>${escapeHtml(option)}</label>`;
        }).join("")}
      </div>
    `;
  }
  if (responseType === "ranking") {
    const ranked = Array.isArray(value) ? value : [];
    return `
      <div class="respondent-ranking-control" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}">
        <p>Tap options in priority order. Tap again to remove.</p>
        <div class="respondent-ranking-selected">
          ${ranked.length ? ranked.map((option, index) => `<span data-rank-selected="${escapeHtml(option)}">${index + 1}. ${escapeHtml(option)}</span>`).join("") : '<small>No ranking selected yet.</small>'}
        </div>
        <div class="respondent-option-grid">
          ${options.map((option) => {
            const active = ranked.includes(option);
            const rank = ranked.indexOf(option) + 1;
            return `<button class="respondent-rank-option ${active ? "active" : ""}" type="button" data-rank-option="${escapeHtml(option)}">${active ? `${rank}. ` : ""}${escapeHtml(option)}</button>`;
          }).join("")}
        </div>
      </div>
    `;
  }
  if (["single_choice", "scale_1_5", "yes_no"].includes(responseType) || (options.length && responseType === "time_duration")) {
    return `
      <div class="respondent-choice-grid ${responseType === "scale_1_5" ? "respondent-scale-grid" : ""}" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}">
        ${options.map((option) => {
          const checked = String(value) === String(option);
          return `<label class="respondent-choice"><input class="respondent-field" name="${escapeHtml(id)}" type="radio" value="${escapeHtml(option)}" ${checked ? "checked" : ""} ${question.required ? "required" : ""}><span>${escapeHtml(option)}</span></label>`;
        }).join("")}
      </div>
    `;
  }
  if (["numeric", "percentage", "currency", "time_duration"].includes(responseType)) {
    const inputMode = responseType === "time_duration" ? "text" : "decimal";
    const placeholder = responseType === "percentage" ? "0-100" : responseType === "currency" ? "Amount" : responseType === "time_duration" ? "Example: 2 hours" : "Enter a number";
    const helper = responseType === "percentage"
      ? `<small class="respondent-field-helper">Enter a number between 0 and 100</small>`
      : "";
    return `<input class="respondent-field" id="${escapeHtml(id)}" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}" type="text" inputmode="${inputMode}" placeholder="${placeholder}" value="${escapeHtml(value)}" ${question.required ? "required" : ""}>${helper}`;
  }
  return `<textarea class="respondent-field" id="${escapeHtml(id)}" data-question-id="${escapeHtml(question.question_id)}" data-response-type="${escapeHtml(responseType)}" rows="5" placeholder="Share the practical reality here..." ${question.required ? "required" : ""}>${escapeHtml(value)}</textarea>`;
}

export function collectRespondentAnswers() {
  const answers = [];
  document.querySelectorAll("[data-question-card]").forEach((card) => {
    const questionId = card.dataset.questionCard;
    const ranking = card.querySelector(".respondent-ranking-control");
    if (ranking) {
      const selected = [...ranking.querySelectorAll("[data-rank-selected]")].map((item) => item.dataset.rankSelected);
      answers.push({ question_id: questionId, answer_value: selected, answer_text: selected.join(", ") });
      return;
    }
    const multiple = card.querySelector(".respondent-option-grid");
    if (multiple) {
      const selected = [...multiple.querySelectorAll("input:checked")].map((input) => input.value);
      answers.push({ question_id: questionId, answer_value: selected, answer_text: selected.join(", ") });
      return;
    }
    const choice = card.querySelector(".respondent-choice-grid");
    if (choice) {
      const selected = choice.querySelector(".respondent-field:checked")?.value || "";
      answers.push({ question_id: questionId, answer_value: selected, answer_text: selected });
      return;
    }
    const field = card.querySelector(".respondent-field");
    if (!field) return;
    const value = field.value;
    answers.push({ question_id: questionId, answer_value: value, answer_text: value });
  });
  return answers;
}

export function respondentIssueForQuestion(questionId) {
  const missing = respondentValidationIssues?.missing_required_questions || [];
  const invalid = respondentValidationIssues?.invalid_answers || [];
  const invalidItem = invalid.find((item) => String(item.question_id) === String(questionId));
  if (missing.includes(questionId)) return "This required question needs an answer.";
  if (respondentClientValidationIssues?.[questionId]) return respondentClientValidationIssues[questionId];
  if (invalidItem) return invalidItem.reason || "This answer is invalid.";
  return "";
}

function ensureRespondentRoot() {
  let root = document.querySelector("#respondent-root");
  if (!root) {
    root = document.createElement("main");
    root.id = "respondent-root";
    root.className = "respondent-shell";
    document.body.appendChild(root);
  }
  return root;
}

function answeredCountForState(state = respondentAssessmentState) {
  const progress = state?.progress || {};
  const responses = state?.responses || {};
  const questions = state?.questions || [];
  return Number(progress.answered_count || 0)
    || Object.keys(responses).filter((key) => respondentValueHasAnswer(responses[key]?.answer_value ?? responses[key]?.answer_text)).length
    || Number(progress.total_questions || 0)
    || questions.length
    || 15;
}

function renderSubmissionConfirmation(answeredCount) {
  const root = document.querySelector("#respondent-root");
  if (!root) return;

  root.innerHTML = `
    <div style="
      min-height: 100vh;
      background: #0A0A08;
      display: flex;
      align-items: center;
      justify-content: center;
      padding: 3rem 1.5rem;
      font-family: sans-serif;
    ">
      <div style="
        background: #111109;
        border: 0.5px solid rgba(200,169,110,0.2);
        border-radius: 16px;
        padding: 3rem 2.5rem;
        max-width: 520px;
        width: 100%;
        text-align: center;
      ">
        <div style="
          width: 64px;
          height: 64px;
          border-radius: 50%;
          background: rgba(200,169,110,0.1);
          border: 0.5px solid rgba(200,169,110,0.3);
          display: flex;
          align-items: center;
          justify-content: center;
          margin: 0 auto 1.5rem;
        ">
          <svg width="28" height="28" viewBox="0 0 24 24"
            fill="none" stroke="#C8A96E"
            stroke-width="2" stroke-linecap="round"
            stroke-linejoin="round">
            <polyline points="20 6 9 17 4 12"></polyline>
          </svg>
        </div>

        <div style="
          font-size: 11px;
          letter-spacing: 0.1em;
          text-transform: uppercase;
          color: rgba(200,169,110,0.5);
          margin-bottom: 0.75rem;
        ">Assessment complete</div>

        <div style="
          font-size: 22px;
          font-weight: 500;
          color: #E8E4DC;
          margin-bottom: 0.75rem;
          line-height: 1.3;
        ">Thank you for your responses</div>

        <div style="
          font-size: 14px;
          color: rgba(232,228,220,0.5);
          line-height: 1.6;
          margin-bottom: 2rem;
        ">Your perspective has been recorded.
        The assessment team will review all
        responses and prepare findings for
        your organization.</div>

        <div style="
          height: 0.5px;
          background: rgba(200,169,110,0.12);
          margin: 0 0 1.5rem;
        "></div>

        <div style="
          display: flex;
          justify-content: center;
          gap: 2.5rem;
          margin-bottom: 2rem;
        ">
          <div>
            <div style="
              font-size: 22px;
              font-weight: 500;
              color: #C8A96E;
              line-height: 1;
            ">${Number(answeredCount) || 15}</div>
            <div style="
              font-size: 11px;
              color: rgba(232,228,220,0.35);
              text-transform: uppercase;
              letter-spacing: 0.05em;
              margin-top: 4px;
            ">Answered</div>
          </div>
          <div>
            <div style="
              font-size: 22px;
              font-weight: 500;
              color: #C8A96E;
              line-height: 1;
            ">100%</div>
            <div style="
              font-size: 11px;
              color: rgba(232,228,220,0.35);
              text-transform: uppercase;
              letter-spacing: 0.05em;
              margin-top: 4px;
            ">Complete</div>
          </div>
        </div>

        <div style="
          font-size: 12px;
          color: rgba(232,228,220,0.3);
          line-height: 1.5;
        ">You can safely close this window.
        Your responses have been saved and
        cannot be changed after submission.</div>
      </div>
    </div>
  `;
}

export function renderRespondentAssessment() {
  document.querySelector("#auth-screen")?.classList.add("hidden");
  document.querySelector(".app-shell")?.classList.add("hidden");
  const root = ensureRespondentRoot();
  if (!respondentAssessmentState) {
    root.innerHTML = `<section class="respondent-card respondent-loading">${renderLoadingSkeleton(screenStateCopy.respondent.loading.title, 3)}</section>`;
    return;
  }
  if (respondentAssessmentState.error) {
    root.innerHTML = `<section class="respondent-card respondent-error">${renderScreenState("respondent", "error", { message: respondentAssessmentState.error })}</section>`;
    return;
  }
  const questions = respondentAssessmentState.questions || [];
  const progress = respondentAssessmentState.progress || {};
  const participant = respondentAssessmentState.participant || {};
  const session = respondentAssessmentState.session || {};
  const assessment = respondentAssessmentState.assessment || {};
  const completed = ["submitted", "completed"].includes(session.status) || respondentAssessmentState.token?.completed_at;
  if (completed) {
    renderSubmissionConfirmation(answeredCountForState());
    return;
  }
  const issueCount = (respondentValidationIssues?.missing_required_questions || []).length + (respondentValidationIssues?.invalid_answers || []).length;
  const requiredProgress = respondentRequiredProgress(questions);
  const totalQuestionCount = Number(progress.total_questions || questions.length || 0);
  const answeredQuestionCount = Number(progress.answered_count || 0);
  const currentQuestionNumber = totalQuestionCount
    ? Math.min(totalQuestionCount, answeredQuestionCount + 1)
    : 0;
  const estimatedMinutes = totalQuestionCount
    ? Math.max(1, Math.round(totalQuestionCount * 0.6))
    : 0;
  const sections = respondentSections(questions);
  const currentSection = sections.find((section) => section.answered < section.total)?.name || sections[sections.length - 1]?.name || "Assessment";
  const saveStatusClass = respondentSaveStatus.toLowerCase().includes("unable") || respondentSaveStatus.toLowerCase().includes("fix") ? "error" : respondentSaveStatus.toLowerCase().includes("saving") || respondentSaveStatus.toLowerCase().includes("submitting") ? "saving" : "saved";
  root.innerHTML = `
    <section class="respondent-hero respondent-header">
      <div class="respondent-title-block">
        <p class="eyebrow">Secure Assessment</p>
        <h1>${escapeHtml(assessment.company_name || "Company Assessment")} — ${escapeHtml(participant.stakeholder_role_name || "Participant")}</h1>
        <p>${escapeHtml(assessment.name || "Business Assessment")}${participant.full_name ? ` · ${escapeHtml(participant.full_name)}` : ""}</p>
        <div class="respondent-save-pill ${saveStatusClass}">
          <span>${escapeHtml(respondentSaveStatus)}</span>
          ${respondentLastSavedAt ? `<small>Last saved ${escapeHtml(respondentLastSavedAt)}</small>` : ""}
        </div>
      </div>
      <div class="respondent-progress-card">
        <span>${totalQuestionCount ? `Question ${currentQuestionNumber} of ${totalQuestionCount}` : "Progress"}</span>
        <strong>${progress.completion_percent || 0}%</strong>
        <div class="respondent-progress-track"><i style="width:${Math.min(100, Number(progress.completion_percent || 0))}%"></i></div>
        <small>${estimatedMinutes ? `About ${estimatedMinutes} minutes total · ` : ""}${requiredProgress.answered}/${requiredProgress.total} required answered</small>
      </div>
    </section>
    <section class="respondent-section-nav">
      <div>
        <span>Current section</span>
        <strong>${escapeHtml(currentSection)}</strong>
      </div>
      <div class="respondent-section-steps">
        ${sections.map((section) => `<span class="${section.answered >= section.total ? "complete" : section.name === currentSection ? "active" : ""}">${escapeHtml(section.name)} <small>${section.answered}/${section.total}</small></span>`).join("")}
      </div>
    </section>
    <section class="respondent-card">
      <div class="respondent-welcome">
        <div>
          <h2>Welcome, ${escapeHtml(participant.full_name || "Participant")}</h2>
          <p>Answer from your role's point of view. Your progress is saved automatically, and required questions are checked before submission.</p>
        </div>
        <span class="status-pill ${statusClass(participant.status || "invited")}">${participantStatusLabel(participant.status || "invited")}</span>
      </div>
      ${questions.length ? `
        <form id="respondent-assessment-form">
          ${issueCount ? `
            <div class="respondent-validation-banner" role="alert">
              <strong>Please complete the highlighted required questions before submitting.</strong>
              <p>${issueCount} issue${issueCount === 1 ? "" : "s"} need attention. Valid saved answers are kept.</p>
            </div>
          ` : ""}
          <div class="respondent-question-list">
            ${questions.map((question, index) => {
              const issue = respondentIssueForQuestion(question.question_id);
              return `
              <article class="respondent-question ${issue ? "has-validation-error" : ""}" data-question-card="${escapeHtml(question.question_id)}">
                <div class="respondent-question-head">
                  <div><span>${String(index + 1).padStart(2, "0")}</span><small>${escapeHtml(question.section || "")}</small></div>
                  <div class="respondent-question-badges">${question.required ? '<small class="required">Required</small>' : '<small>Optional</small>'}${renderRespondentSavedIndicator(question)}</div>
                </div>
                <label for="respondent-${escapeHtml(question.question_id)}">${escapeHtml(question.question_text || "")}</label>
                ${question.ai_analysis_purpose ? `<p class="respondent-question-helper">${escapeHtml(question.ai_analysis_purpose)}</p>` : ""}
                ${renderRespondentField(question)}
                ${issue ? `<p class="respondent-field-error">${escapeHtml(issue)}</p>` : ""}
              </article>
            `;
            }).join("")}
          </div>
          <div class="respondent-actions respondent-submit-card">
            <div>
              <strong>${requiredProgress.missing ? `${requiredProgress.missing} required question${requiredProgress.missing === 1 ? "" : "s"} remaining` : "Ready to submit"}</strong>
              <span>${requiredProgress.answered}/${requiredProgress.total} required answered. You can continue later with the same link.</span>
            </div>
            <div class="respondent-submit-actions">
              <button class="ghost-button" id="respondent-save" type="button">Save</button>
              <button class="ghost-button" id="respondent-continue-later" type="button">Continue Later</button>
              <button class="primary-button" id="respondent-submit" type="submit">Submit Assessment</button>
            </div>
          </div>
          <p class="respondent-save-status ${saveStatusClass}" id="respondent-save-status">${escapeHtml(respondentSaveStatus)}</p>
        </form>
      ` : renderScreenState("respondent", "empty")}
    </section>
  `;
}

export async function loadRespondentAssessment() {
  renderRespondentAssessment();
  try {
    respondentAssessmentState = await apiRequest(`/api/respond/${encodeURIComponent(activeRespondToken)}`);
    respondentValidationIssues = { missing_required_questions: [], invalid_answers: [] };
  } catch (error) {
    respondentAssessmentState = { error: error.message };
  }
  renderRespondentAssessment();
}

export async function saveRespondentProgress({ complete = false } = {}) {
  if (!activeRespondToken || ["submitted", "completed"].includes(respondentAssessmentState?.session?.status)) return;
  validatePercentageAnswers();
  const status = document.querySelector("#respondent-save-status");
  respondentSaveStatus = complete ? "Submitting..." : "Saving...";
  if (status) status.textContent = respondentSaveStatus;
  const endpoint = complete
    ? `/api/respond/${encodeURIComponent(activeRespondToken)}/submit`
    : `/api/respond/${encodeURIComponent(activeRespondToken)}/responses`;
  try {
    respondentAssessmentState = await apiRequest(endpoint, {
      method: complete ? "POST" : "PATCH",
      body: JSON.stringify({ answers: collectRespondentAnswers() })
    });
    respondentValidationIssues = { missing_required_questions: [], invalid_answers: [] };
    respondentSaveStatus = "Saved.";
    respondentLastSavedAt = new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
    if (complete) {
      renderSubmissionConfirmation(answeredCountForState(respondentAssessmentState));
      return;
    }
    renderRespondentAssessment();
    const refreshedStatus = document.querySelector("#respondent-save-status");
    if (refreshedStatus) refreshedStatus.textContent = respondentSaveStatus;
  } catch (error) {
    if (error.error === "validation_failed") {
      respondentValidationIssues = {
        missing_required_questions: error.missing_required_questions || [],
        invalid_answers: error.invalid_answers || []
      };
      respondentSaveStatus = error.message || "Please fix the highlighted answers.";
      renderRespondentAssessment();
      const firstIssue = document.querySelector(".respondent-question.has-validation-error");
      firstIssue?.scrollIntoView({ behavior: "smooth", block: "center" });
      const refreshedStatus = document.querySelector("#respondent-save-status");
      if (refreshedStatus) refreshedStatus.textContent = respondentSaveStatus;
      return;
    }
    respondentSaveStatus = "Unable to save. Please check your connection and try again.";
    if (status) status.textContent = respondentSaveStatus;
  }
}

export function init() {
  if (!activeRespondToken) return;
  document.querySelector("#auth-screen")?.classList.add("hidden");
  document.querySelector(".app-shell")?.classList.add("hidden");
  document.addEventListener("input", (event) => {
    if (!event.target.closest("#respondent-assessment-form")) return;
    if (event.target.matches('.respondent-field[data-response-type="percentage"]')) {
      const message = percentageValidationMessage(event.target.value);
      respondentClientValidationIssues[event.target.dataset.questionId] = message;
      if (!message) delete respondentClientValidationIssues[event.target.dataset.questionId];
      setInlineValidationError(event.target, message);
    }
    window.clearTimeout(respondentSaveTimer);
    respondentSaveTimer = window.setTimeout(() => saveRespondentProgress(), 700);
  });
  document.addEventListener("change", (event) => {
    if (!event.target.closest("#respondent-assessment-form")) return;
    if (event.target.matches('.respondent-field[data-response-type="percentage"]')) {
      const message = percentageValidationMessage(event.target.value);
      respondentClientValidationIssues[event.target.dataset.questionId] = message;
      if (!message) delete respondentClientValidationIssues[event.target.dataset.questionId];
      setInlineValidationError(event.target, message);
    }
    window.clearTimeout(respondentSaveTimer);
    respondentSaveTimer = window.setTimeout(() => saveRespondentProgress(), 200);
  });
  document.addEventListener("click", (event) => {
    const rankButton = event.target.closest(".respondent-rank-option");
    if (rankButton) {
      const control = rankButton.closest(".respondent-ranking-control");
      if (!control || respondentAssessmentState?.session?.status === "completed") return;
      const current = [...control.querySelectorAll("[data-rank-selected]")].map((item) => item.dataset.rankSelected);
      const value = rankButton.dataset.rankOption;
      const next = current.includes(value) ? current.filter((item) => item !== value) : [...current, value];
      const selected = control.querySelector(".respondent-ranking-selected");
      selected.innerHTML = next.length
        ? next.map((item, index) => `<span data-rank-selected="${escapeHtml(item)}">${index + 1}. ${escapeHtml(item)}</span>`).join("")
        : "<small>No ranking selected yet.</small>";
      control.querySelectorAll(".respondent-rank-option").forEach((button) => {
        const rankIndex = next.indexOf(button.dataset.rankOption);
        button.classList.toggle("active", rankIndex >= 0);
        button.textContent = rankIndex >= 0 ? `${rankIndex + 1}. ${button.dataset.rankOption}` : button.dataset.rankOption;
      });
      window.clearTimeout(respondentSaveTimer);
      respondentSaveTimer = window.setTimeout(() => saveRespondentProgress(), 300);
      return;
    }
    if (event.target.closest("#respondent-save")) {
      event.preventDefault();
      saveRespondentProgress();
    }
    if (event.target.closest("#respondent-continue-later")) {
      event.preventDefault();
      saveRespondentProgress();
      window.alert("Your progress has been saved. You can continue later using this same link.");
    }
  });
  document.addEventListener("submit", (event) => {
    if (event.target.id !== "respondent-assessment-form") return;
    event.preventDefault();
    saveRespondentProgress({ complete: true });
  });
  loadRespondentAssessment();
}

window.ParticipantSurface = {
  init,
  loadRespondentAssessment,
  saveRespondentProgress
};
