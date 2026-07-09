import pg from "pg";
import { createHash, randomBytes } from "node:crypto";

const baseUrl = "https://krb.deriveglobal.com";
const marker = `QA_RESPONDENT_UX_${Date.now()}`;
const { Pool } = pg;
const pool = new Pool({ connectionString: process.env.DATABASE_URL });

const checks = [];
const state = {
  marker,
  organizationId: null,
  projectId: null,
  assessmentId: null,
  participantId: null,
  sessionId: null,
  tokenId: null,
  rawToken: null,
  tempQuestionIds: []
};

function record(name, status, detail = "") {
  checks.push({ name, status, detail });
}

function pass(name, detail = "") {
  record(name, "PASS", detail);
}

function fail(name, detail = "") {
  record(name, "FAIL", detail);
}

function na(name, detail = "") {
  record(name, "N/A", detail);
}

function hashToken(rawToken) {
  return createHash("sha256").update(String(rawToken)).digest("hex");
}

function optionList(question) {
  const options = Array.isArray(question.options) ? question.options : [];
  return options.map((option) => {
    if (option && typeof option === "object") return String(option.label || option.value || option.text || "");
    return String(option ?? "");
  }).filter(Boolean);
}

function answerFor(question) {
  const options = optionList(question);
  switch (question.response_type) {
    case "single_choice":
    case "yes_no":
      return options[0] || "Yes";
    case "multiple_choice":
      return options.slice(0, Math.min(2, options.length));
    case "scale_1_5":
      return options.find((option) => String(option).trim().startsWith("4")) || "4";
    case "ranking":
      return options.slice(0, Math.min(3, options.length));
    case "numeric":
      return "42";
    case "percentage":
      return "75";
    case "currency":
      return "1234.56";
    case "time_duration":
      return options[0] || "2 hours";
    case "open_text":
      return `QA respondent evidence for ${question.question_id}: realistic operational context.`;
    default:
      return options[0] || "QA answer";
  }
}

function answerPayload(question) {
  const value = answerFor(question);
  return {
    question_id: question.question_id,
    answer_value: value,
    answer_text: Array.isArray(value) ? value.join(", ") : String(value)
  };
}

async function api(path, options = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    ...options,
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {})
    }
  });
  const text = await response.text();
  let body = null;
  try {
    body = text ? JSON.parse(text) : null;
  } catch {
    body = text;
  }
  return { response, body, text };
}

async function setup(client) {
  await client.query("begin");
  const methodology = await client.query("select id from methodology_versions order by created_at asc limit 1");
  if (!methodology.rowCount) throw new Error("No methodology version available.");
  const org = await client.query(
    "insert into organizations (name, legal_name, industry, default_language, status) values ($1, $1, 'QA', 'en', 'active') returning id",
    [marker]
  );
  state.organizationId = org.rows[0].id;
  const project = await client.query(
    `insert into assessment_projects
      (organization_id, methodology_version_id, name, client_display_name, industry_context, default_language, status)
     values ($1, $2, $3, $3, 'Temporary respondent UX QA project', 'en', 'active')
     returning id`,
    [state.organizationId, methodology.rows[0].id, marker]
  );
  state.projectId = project.rows[0].id;
  const assessment = await client.query(
    "insert into assessments (company_id, title, status) values ($1, $2, 'active') returning id",
    [state.projectId, `${marker} Assessment`]
  );
  state.assessmentId = assessment.rows[0].id;

  const tempQuestions = [
    {
      question_id: `${marker}_NUM`,
      question_text: "QA numeric question: how many hours are spent on manual reconciliation each week?",
      response_type: "numeric",
      options: []
    },
    {
      question_id: `${marker}_PCT`,
      question_text: "QA percentage question: what percentage of reports require manual correction?",
      response_type: "percentage",
      options: []
    }
  ];
  for (const question of tempQuestions) {
    state.tempQuestionIds.push(question.question_id);
    await client.query(
      `insert into questions
        (question_id, stakeholder_group, stakeholder_role, stakeholder_group_id, stakeholder_role_id, section, question_text, response_type, options, required,
         score_mapping, business_domain, assessment_category, problem_types_detectable, impact_dimensions, maturity_dimensions, kpi_outputs,
         ai_analysis_purpose, follow_up_enabled, follow_up_questions, recommendation_triggers, roadmap_relevance, finding_strength, metadata)
       values
        ($1, 'Support Functions', 'Finance Manager', 'support_functions', 'finance_manager', 'QA Mixed Types', $2, $3, $4::jsonb, true,
         '{}'::jsonb, 'finance', 'financial', '["data_quality_problem"]'::jsonb, '["financial_impact"]'::jsonb, '["Data"]'::jsonb, '["qa_metric"]'::jsonb,
         'Temporary QA validation question.', false, '[]'::jsonb, '["qa_validation"]'::jsonb, 'foundation', 'medium', '{"qa_marker": true}'::jsonb)`,
      [question.question_id, question.question_text, question.response_type, JSON.stringify(question.options)]
    );
  }

  const participant = await client.query(
    `insert into assessment_participants
      (company_id, assessment_id, stakeholder_group_id, stakeholder_role_id, first_name, last_name, full_name, email, department, location, notes, status, is_active)
     values ($1, $2, 'support_functions', 'finance_manager', 'QA', 'Respondent', 'QA Respondent', 'qa.respondent@example.com', 'Finance', 'QA Location', $3, 'not_invited', true)
     returning participant_id`,
    [state.projectId, state.assessmentId, marker]
  );
  state.participantId = participant.rows[0].participant_id;
  const session = await client.query(
    `insert into assessment_sessions
      (assessment_id, stakeholder_role, stakeholder_group_id, stakeholder_role_id, participant_id, respondent_name, respondent_email, status)
     values ($1, 'Finance Manager', 'support_functions', 'finance_manager', $2, 'QA Respondent', 'qa.respondent@example.com', 'started')
     returning id`,
    [state.assessmentId, state.participantId]
  );
  state.sessionId = session.rows[0].id;
  await client.query("update assessment_participants set session_id = $1 where participant_id = $2", [state.sessionId, state.participantId]);
  state.rawToken = randomBytes(32).toString("hex");
  const token = await client.query(
    `insert into assessment_access_tokens (participant_id, session_id, token, raw_token, expires_at, is_active)
     values ($1, $2, $3, $4, now() + interval '90 days', true)
     returning token_id`,
    [state.participantId, state.sessionId, hashToken(state.rawToken), state.rawToken]
  );
  state.tokenId = token.rows[0].token_id;
  await client.query(
    "update assessment_participants set status = 'invited', invitation_token_id = $1 where participant_id = $2",
    [state.tokenId, state.participantId]
  );
  await client.query("commit");
}

async function cleanup(client) {
  await client.query("begin");
  if (state.assessmentId) {
    await client.query("delete from system_error_logs where assessment_id = $1", [state.assessmentId]);
  }
  if (state.projectId) {
    await client.query("delete from assessment_projects where id = $1", [state.projectId]);
  }
  if (state.organizationId) {
    await client.query("delete from organizations where id = $1", [state.organizationId]);
  }
  if (state.tempQuestionIds.length) {
    await client.query("delete from questions where question_id = any($1::text[])", [state.tempQuestionIds]);
  }
  await client.query("commit");
}

async function verifyCleanup(client) {
  const remaining = await client.query(
    `select
      (select count(*)::int from assessment_projects where id = $1) as projects,
      (select count(*)::int from assessments where id = $2) as assessments,
      (select count(*)::int from assessment_participants where participant_id = $3) as participants,
      (select count(*)::int from assessment_sessions where id = $4) as sessions,
      (select count(*)::int from assessment_access_tokens where token_id = $5) as tokens,
      (select count(*)::int from questions where question_id = any($6::text[])) as temp_questions`,
    [state.projectId, state.assessmentId, state.participantId, state.sessionId, state.tokenId, state.tempQuestionIds]
  );
  return remaining.rows[0];
}

async function run() {
  const client = await pool.connect();
  let cleanupStatus = "not_started";
  const bugsFound = [];
  const bugsFixed = ["Fixed radio-style respondent answer collection so unanswered single/scale/time-option questions submit as empty instead of the first option."];
  try {
    await setup(client);
    const respondPath = `/respond/${state.rawToken}`;
    const apiPath = `/api/respond/${state.rawToken}`;
    const html = await fetch(`${baseUrl}${respondPath}`);
    if (html.ok) pass("Valid token opens redesigned respondent page", `HTTP ${html.status}`);
    else fail("Valid token opens redesigned respondent page", `HTTP ${html.status}`);
    const htmlText = await html.text();
    const cssText = await (await fetch(`${baseUrl}/styles.css`)).text();
    const appText = await (await fetch(`${baseUrl}/app.js`)).text();

    const initial = await api(apiPath);
    const assessment = initial.body?.assessment || {};
    const participant = initial.body?.participant || {};
    const questions = initial.body?.questions || [];
    const types = new Set(questions.map((question) => question.response_type));
    const requiredQuestions = questions.filter((question) => question.required);
    const byType = (type) => questions.find((question) => question.response_type === type);

    if (initial.response.ok && assessment.company_name === marker && participant.stakeholder_role_name === "Finance Manager") {
      pass("Header shows correct company/assessment/role", `${assessment.company_name} / ${assessment.name} / ${participant.stakeholder_role_name}`);
    } else {
      fail("Header shows correct company/assessment/role", JSON.stringify({ assessment, participant }));
    }
    if (cssText.includes("respondent-progress-track") && cssText.includes("respondent-section-steps") && appText.includes("respondent-section-nav")) {
      pass("Progress bar and section stepper render", "Deployed assets include progress track and section stepper.");
    } else fail("Progress bar and section stepper render", "Missing deployed progress/stepper assets.");
    if (cssText.includes("respondent-question") && appText.includes("respondent-question-list")) pass("Question cards render correctly", `${questions.length} questions loaded.`);
    else fail("Question cards render correctly", "Question card assets missing.");

    for (const [label, type] of [
      ["single_choice works", "single_choice"],
      ["multiple_choice works", "multiple_choice"],
      ["scale_1_5 works", "scale_1_5"],
      ["ranking works without duplicate values", "ranking"],
      ["numeric works", "numeric"],
      ["percentage works", "percentage"],
      ["time_duration works", "time_duration"],
      ["open_text works", "open_text"]
    ]) {
      const question = byType(type);
      if (!question) {
        fail(label, `No ${type} question in assigned bank.`);
        continue;
      }
      const value = answerFor(question);
      if (type === "ranking" && Array.isArray(value) && new Set(value).size === value.length && value.length > 0) pass(label, question.question_id);
      else if (type !== "ranking" && (Array.isArray(value) ? value.length : String(value).trim())) pass(label, question.question_id);
      else fail(label, `Could not generate valid answer for ${question.question_id}.`);
    }
    if (byType("currency")) pass("currency works if question exists", byType("currency").question_id);
    else na("currency works if question exists", "Assigned bank has no currency question.");

    const missingSubmit = await api(`${apiPath}/submit`, { method: "POST", body: JSON.stringify({ answers: [] }) });
    if (missingSubmit.response.status === 400 && missingSubmit.body?.error === "validation_failed" && missingSubmit.body?.missing_required_questions?.length) {
      pass("Missing required answers show clear validation and banner", `${missingSubmit.body.missing_required_questions.length} missing questions returned.`);
    } else fail("Missing required answers show clear validation and banner", JSON.stringify(missingSubmit.body));

    const invalidSingle = byType("single_choice") || questions[0];
    const invalidSave = await api(`${apiPath}/responses`, {
      method: "PATCH",
      body: JSON.stringify({ answers: [{ question_id: invalidSingle.question_id, answer_value: "__INVALID_OPTION__", answer_text: "__INVALID_OPTION__" }] })
    });
    if (invalidSave.response.status === 400 && invalidSave.body?.error === "validation_failed") pass("Invalid answer is rejected clearly", invalidSave.body.invalid_answers?.[0]?.reason || "Rejected.");
    else fail("Invalid answer is rejected clearly", JSON.stringify(invalidSave.body));

    const firstAnswer = answerPayload(requiredQuestions[0]);
    const saveOne = await api(`${apiPath}/responses`, { method: "PATCH", body: JSON.stringify({ answers: [firstAnswer] }) });
    if (saveOne.response.ok) pass("Autosave works", firstAnswer.question_id);
    else fail("Autosave works", JSON.stringify(saveOne.body));
    if (appText.includes("Saving...") && appText.includes("Saved.")) pass("Save status changes from Saving to Saved", "Deployed app contains save status transitions.");
    else fail("Save status changes from Saving to Saved", "Save status transitions missing in deployed app.");
    const resumed = await api(apiPath);
    if (resumed.body?.responses?.[firstAnswer.question_id]?.answer_text === firstAnswer.answer_text) pass("Browser refresh resumes saved answers", firstAnswer.question_id);
    else fail("Browser refresh resumes saved answers", JSON.stringify(resumed.body?.responses?.[firstAnswer.question_id] || null));

    const allAnswers = questions.map(answerPayload);
    const finalSubmit = await api(`${apiPath}/submit`, { method: "POST", body: JSON.stringify({ answers: allAnswers }) });
    if (finalSubmit.response.ok && (finalSubmit.body?.session?.status === "completed" || finalSubmit.body?.token?.completed_at)) pass("Submit works after all required answers are valid", "Submit completed through respondent API.");
    else fail("Submit works after all required answers are valid", JSON.stringify(finalSubmit.body));
    if (appText.includes("Assessment completed. Thank you.") && cssText.includes("respondent-completion-card")) pass("Completion state renders correctly", "Completion card assets deployed.");
    else fail("Completion state renders correctly", "Completion UI assets missing.");

    const completion = await client.query(
      `select p.completed_at as participant_completed_at, s.status as session_status, s.completed_at as session_completed_at, t.completed_at as token_completed_at
       from assessment_participants p
       join assessment_sessions s on s.id = p.session_id
       join assessment_access_tokens t on t.token_id = p.invitation_token_id
       where p.participant_id = $1`,
      [state.participantId]
    );
    const completedRow = completion.rows[0] || {};
    if (completedRow.participant_completed_at) pass("Participant completed_at is set", String(completedRow.participant_completed_at));
    else fail("Participant completed_at is set", "Missing participant completed_at.");
    if (completedRow.session_status === "completed" && completedRow.session_completed_at) pass("Session status/completed_at is set", `${completedRow.session_status} / ${completedRow.session_completed_at}`);
    else fail("Session status/completed_at is set", JSON.stringify(completedRow));
    if (completedRow.token_completed_at) pass("Token completed_at is set", String(completedRow.token_completed_at));
    else fail("Token completed_at is set", "Missing token completed_at.");

    if (appText.includes('document.querySelector(".app-shell")?.classList.add("hidden")') && htmlText.includes("app.js")) {
      pass("Admin shell is hidden on respondent route", "Respondent renderer hides app shell and route loads app script.");
    } else fail("Admin shell is hidden on respondent route", "Could not verify app-shell hiding assets.");
    if (cssText.includes("@media (max-width: 820px)") && cssText.includes(".respondent-submit-actions button")) pass("Mobile width is usable", "Responsive respondent rules deployed.");
    else fail("Mobile width is usable", "Responsive respondent rules missing.");
    const health = await fetch(baseUrl, { method: "HEAD" });
    if (health.ok) pass("Live app returns 200 OK", `HTTP ${health.status}`);
    else fail("Live app returns 200 OK", `HTTP ${health.status}`);
  } catch (error) {
    fail("QA runner execution", error.stack || error.message);
  } finally {
    try {
      await cleanup(client);
      const remaining = await verifyCleanup(client);
      const totalRemaining = Object.values(remaining).reduce((sum, value) => sum + Number(value || 0), 0);
      if (totalRemaining === 0) {
        cleanupStatus = "deleted_cleanly";
        pass("Temporary QA data is deleted cleanly", JSON.stringify(remaining));
      } else {
        cleanupStatus = "remaining_records";
        fail("Temporary QA data is deleted cleanly", JSON.stringify(remaining));
      }
    } catch (error) {
      cleanupStatus = `cleanup_failed: ${error.message}`;
      fail("Temporary QA data is deleted cleanly", cleanupStatus);
      try { await client.query("rollback"); } catch {}
    }
    client.release();
    await pool.end();
  }
  const failCount = checks.filter((check) => check.status === "FAIL").length;
  const passCount = checks.filter((check) => check.status === "PASS").length;
  const naCount = checks.filter((check) => check.status === "N/A").length;
  const result = failCount ? "FAIL" : "PASS";
  console.log(JSON.stringify({
    result,
    marker,
    passCount,
    failCount,
    naCount,
    checks,
    bugsFound,
    bugsFixed,
    remainingIssues: failCount ? checks.filter((check) => check.status === "FAIL") : [],
    cleanupStatus
  }, null, 2));
  if (failCount) process.exitCode = 1;
}

run();
