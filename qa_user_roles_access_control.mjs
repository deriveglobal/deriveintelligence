import pg from "pg";

const baseUrl = "http://127.0.0.1:3000";
const pool = new pg.Pool({ connectionString: process.env.DATABASE_URL });
const qaTag = `qa_access_${Date.now()}`;
const emails = {
  consultantA: `${qaTag}_consultant_a@example.com`,
  consultantB: `${qaTag}_consultant_b@example.com`,
  companyOwner: `${qaTag}_company_owner@example.com`,
  assessmentManager: `${qaTag}_assessment_manager@example.com`,
  deactivated: `${qaTag}_deactivated@example.com`
};
const password = "AccessQa!2345";
const results = [];

function record(name, pass, details = "") {
  results.push({ name, result: pass ? "PASS" : "FAIL", details });
}

async function api(path, { method = "GET", token = "", body = null } = {}) {
  const response = await fetch(`${baseUrl}${path}`, {
    method,
    headers: {
      "Content-Type": "application/json",
      ...(token ? { Authorization: `Bearer ${token}` } : {})
    },
    body: body ? JSON.stringify(body) : undefined
  });
  const text = await response.text();
  let json = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch {
    json = { raw: text };
  }
  return { status: response.status, json };
}

async function login(email, passwordValue = password) {
  return api("/api/auth/login", { method: "POST", body: { email, password: passwordValue } });
}

async function createUser(token, projectId, role, email, name) {
  return api("/api/users", {
    method: "POST",
    token,
    body: { name, email, role, password, projectId }
  });
}

async function cleanup() {
  const client = await pool.connect();
  try {
    await client.query("begin");
    await client.query("delete from user_sessions where user_id in (select id from users where email = any($1))", [Object.values(emails)]);
    await client.query("delete from password_reset_tokens where user_id in (select id from users where email = any($1))", [Object.values(emails)]);
    await client.query("delete from consultant_company_assignments where consultant_user_id in (select id from users where email = any($1))", [Object.values(emails)]);
    await client.query("delete from company_user_assignments where user_id in (select id from users where email = any($1))", [Object.values(emails)]);
    await client.query("delete from project_memberships where user_id in (select id from users where email = any($1))", [Object.values(emails)]);
    await client.query("delete from organization_memberships where user_id in (select id from users where email = any($1))", [Object.values(emails)]);
    await client.query("delete from users where email = any($1)", [Object.values(emails)]);
    await client.query("delete from assessment_projects where client_display_name = $1", [`${qaTag} Demo Company`]);
    await client.query("delete from organizations where name = $1", [`${qaTag} Demo Company`]);
    await client.query("commit");
  } catch (error) {
    await client.query("rollback");
    throw error;
  } finally {
    client.release();
  }
}

try {
  const ownerLogin = await login("fatih@deriveglobal.com", "qa");
  const ownerToken = ownerLogin.json.sessionToken;
  record("Platform owner login returns platform_owner", ownerLogin.status === 200 && ownerLogin.json.user?.role === "platform_owner", ownerLogin.json.user?.role || ownerLogin.json.error);

  const initialProjects = await api("/api/projects", { token: ownerToken });
  const krbProject = initialProjects.json.projects?.[0];
  record("Platform owner sees existing companies", initialProjects.status === 200 && initialProjects.json.projects?.length >= 1, `${initialProjects.json.projects?.length || 0} projects`);

  const demoCreate = await api("/api/projects", {
    method: "POST",
    token: ownerToken,
    body: { organizationName: `${qaTag} Demo Company`, name: "QA Access Assessment", defaultLanguage: "en" }
  });
  const demoProject = demoCreate.json.project;
  record("Platform owner can create QA company", demoCreate.status === 201 && demoProject?.id, demoCreate.json.error || demoProject?.id || "");

  await createUser(ownerToken, krbProject.id, "consultant", emails.consultantA, "QA Consultant A");
  await createUser(ownerToken, demoProject.id, "consultant", emails.consultantB, "QA Consultant B");
  await createUser(ownerToken, krbProject.id, "company_owner", emails.companyOwner, "QA Company Owner");
  await createUser(ownerToken, krbProject.id, "assessment_manager", emails.assessmentManager, "QA Assessment Manager");
  const disabledUser = await createUser(ownerToken, krbProject.id, "consultant", emails.deactivated, "QA Disabled User");
  await api(`/api/users/${encodeURIComponent(disabledUser.json.user.id)}`, {
    method: "PATCH",
    token: ownerToken,
    body: { status: "disabled", role: "consultant", projectId: krbProject.id }
  });

  const consultantALogin = await login(emails.consultantA);
  const consultantBLogin = await login(emails.consultantB);
  const companyOwnerLogin = await login(emails.companyOwner);
  const managerLogin = await login(emails.assessmentManager);
  const disabledLogin = await login(emails.deactivated);

  record("Consultant A login works", consultantALogin.status === 200 && consultantALogin.json.user?.role === "consultant");
  record("Consultant B login works", consultantBLogin.status === 200 && consultantBLogin.json.user?.role === "consultant");
  record("Company owner login works", companyOwnerLogin.status === 200 && companyOwnerLogin.json.user?.role === "company_owner");
  record("Assessment manager login works", managerLogin.status === 200 && managerLogin.json.user?.role === "assessment_manager");
  record("Deactivated user cannot log in", disabledLogin.status === 401);

  const consultantAProjects = await api("/api/projects", { token: consultantALogin.json.sessionToken });
  const consultantBProjects = await api("/api/projects", { token: consultantBLogin.json.sessionToken });
  record("Consultant A sees only assigned KRB company", consultantAProjects.status === 200 && consultantAProjects.json.projects?.length === 1 && consultantAProjects.json.projects[0].id === krbProject.id, JSON.stringify(consultantAProjects.json.projects?.map((p) => p.clientDisplayName)));
  record("Consultant B sees only assigned Demo company", consultantBProjects.status === 200 && consultantBProjects.json.projects?.length === 1 && consultantBProjects.json.projects[0].id === demoProject.id, JSON.stringify(consultantBProjects.json.projects?.map((p) => p.clientDisplayName)));

  const consultantADemoAccess = await api(`/api/assessment-engine?projectId=${encodeURIComponent(demoProject.id)}`, { token: consultantALogin.json.sessionToken });
  record("Consultant A cannot access Demo by URL", consultantADemoAccess.status === 403, consultantADemoAccess.json.error || String(consultantADemoAccess.status));

  const companyOwnerProjects = await api("/api/projects", { token: companyOwnerLogin.json.sessionToken });
  record("Company owner sees only assigned company", companyOwnerProjects.status === 200 && companyOwnerProjects.json.projects?.length === 1 && companyOwnerProjects.json.projects[0].id === krbProject.id, JSON.stringify(companyOwnerProjects.json.projects?.map((p) => p.clientDisplayName)));

  const companyOwnerParticipants = await api(`/api/project-participants?projectId=${encodeURIComponent(krbProject.id)}`, { token: companyOwnerLogin.json.sessionToken });
  record("Company owner cannot access participant admin data", companyOwnerParticipants.status === 403, companyOwnerParticipants.json.error || String(companyOwnerParticipants.status));

  const companyOwnerReport = await api(`/api/executive-report?projectId=${encodeURIComponent(krbProject.id)}`, { token: companyOwnerLogin.json.sessionToken });
  record("Company owner can access executive report", companyOwnerReport.status === 200, companyOwnerReport.json.error || String(companyOwnerReport.status));

  const managerParticipants = await api(`/api/project-participants?projectId=${encodeURIComponent(krbProject.id)}`, { token: managerLogin.json.sessionToken });
  record("Assessment manager can manage participant area", managerParticipants.status === 200, managerParticipants.json.error || String(managerParticipants.status));

  const managerAnalyze = await api("/api/assessment-engine/analyze", {
    method: "POST",
    token: managerLogin.json.sessionToken,
    body: { projectId: krbProject.id }
  });
  record("Assessment manager cannot run analysis/approval path", managerAnalyze.status === 403, managerAnalyze.json.error || String(managerAnalyze.status));

  const anonymousUsers = await api("/api/users");
  record("Anonymous user cannot access user management", anonymousUsers.status === 401, anonymousUsers.json.error || String(anonymousUsers.status));

  const health = await api("/");
  record("Live app root returns 200", health.status === 200);
} finally {
  await cleanup();
  await pool.end();
}

console.log(JSON.stringify({
  qa_tag: qaTag,
  total: results.length,
  passed: results.filter((item) => item.result === "PASS").length,
  failed: results.filter((item) => item.result === "FAIL").length,
  results,
  cleanup: "completed"
}, null, 2));
