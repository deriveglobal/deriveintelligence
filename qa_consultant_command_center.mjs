import { Client } from "pg";
import { createHash, randomUUID } from "crypto";

const pg = process.env.DATABASE_URL
  ? new Client({ connectionString: process.env.DATABASE_URL })
  : new Client({
      host: process.env.PGHOST || "postgres",
      port: Number(process.env.PGPORT || 5432),
      user: process.env.PGUSER || "postgres",
      password: process.env.PGPASSWORD || "postgres",
      database: process.env.PGDATABASE || "assessment_platform"
    });

const token = `qa-consultant-${Date.now()}`;
const tokenHash = createHash("sha256").update(token).digest("hex");
const suffix = Date.now();
const email = `qa.consultant.${suffix}@example.com`;

const ids = {
  user: randomUUID(),
  org: randomUUID(),
  project: randomUUID(),
  methodology: null,
  assessment: randomUUID(),
  session: randomUUID(),
  participant: randomUUID(),
  finding: randomUUID(),
  recommendation: randomUUID(),
  roadmap: randomUUID()
};

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

await pg.connect();

let setupCommitted = false;

try {
  await pg.query("begin");
  const methodology = await pg.query("select id from methodology_versions order by created_at asc limit 1");
  ids.methodology = methodology.rows[0]?.id;
  if (!ids.methodology) {
    const created = await pg.query(
      "insert into methodology_versions (name, description) values ($1, $2) returning id",
      ["QA Framework", "Temporary QA framework"]
    );
    ids.methodology = created.rows[0].id;
  }
  await pg.query(
    "insert into users (id, email, name, full_name, role, password_hash, status) values ($1, $2, $3, $3, 'consultant', 'qa-disabled', 'active')",
    [ids.user, email, "QA Consultant"]
  );
  await pg.query(
    "insert into user_sessions (user_id, token_hash, expires_at, metadata) values ($1, $2, now() + interval '30 minutes', $3)",
    [ids.user, tokenHash, { qa: true }]
  );
  await pg.query(
    "insert into organizations (id, name, industry, default_language) values ($1, $2, $3, 'en')",
    [ids.org, `QA Consultant Org ${suffix}`, "QA"]
  );
  await pg.query(
    "insert into assessment_projects (id, organization_id, methodology_version_id, name, client_display_name, industry_context, default_language, status) values ($1, $2, $3, $4, $5, 'QA', 'en', 'active')",
    [ids.project, ids.org, ids.methodology, "QA Consultant Assessment", `QA Consultant Org ${suffix}`]
  );
  await pg.query(
    "insert into consultant_company_assignments (consultant_user_id, company_id, assigned_by_user_id, is_active) values ($1, $2, $1, true)",
    [ids.user, ids.project]
  );
  await pg.query(
    "insert into assessments (id, company_id, title, status) values ($1, $2, 'QA Consultant Assessment', 'active')",
    [ids.assessment, ids.project]
  );
  await pg.query(
    "insert into assessment_blueprints (assessment_project_id, assessment_id, assessment_completeness_score, assessment_confidence_score) values ($1, $2, 72, 81)",
    [ids.project, ids.assessment]
  );
  await pg.query(
    "insert into assessment_sessions (id, assessment_id, stakeholder_role, respondent_name, respondent_email, status, completed_at) values ($1, $2, 'Operations Manager', 'QA Ops', 'qa.ops@example.com', 'completed', now())",
    [ids.session, ids.assessment]
  );
  await pg.query(
    "insert into assessment_participants (participant_id, company_id, assessment_id, stakeholder_group_id, stakeholder_role_id, full_name, email, status, session_id, is_active, invite_sent_at, completed_at) values ($1, $2, $3, 'management', 'operations_manager', 'QA Ops', 'qa.ops@example.com', 'completed', $4, true, now() - interval '5 days', now())",
    [ids.participant, ids.project, ids.assessment, ids.session]
  );
  await pg.query(
    "insert into findings (id, assessment_id, title, description, status, priority_score, evidence_count, severity, frequency, confidence) values ($1, $2, 'QA Finding Awaiting Approval', 'QA finding', 'Draft', 88, 2, 4, 4, 4)",
    [ids.finding, ids.assessment]
  );
  await pg.query(
    "insert into recommendations (id, organization_id, assessment_project_id, assessment_id, finding_id, title, recommended_action, description, status, priority_score, estimated_business_value) values ($1, $2, $3, $4, $5, 'QA Recommendation Awaiting Approval', 'Review QA recommendation', 'QA recommendation', 'Proposed', 82, 25000)",
    [ids.recommendation, ids.org, ids.project, ids.assessment, ids.finding]
  );
  await pg.query(
    "insert into roadmap_items (id, organization_id, assessment_project_id, assessment_id, recommendation_id, title, phase, priority_score) values ($1, $2, $3, $4, $5, 'QA Roadmap Item', 'Foundation', 82)",
    [ids.roadmap, ids.org, ids.project, ids.assessment, ids.recommendation]
  );
  await pg.query("commit");
  setupCommitted = true;

  const response = await fetch("https://krb.deriveglobal.com/api/consultant-command-center", {
    headers: { Authorization: `Bearer ${token}` }
  });
  const payload = await response.json();
  assert(response.ok, `Endpoint failed: ${response.status} ${JSON.stringify(payload)}`);
  assert(Array.isArray(payload.assigned_organizations), "assigned_organizations missing");
  assert(payload.assigned_organizations.some((item) => item.project_id === ids.project), "temporary assigned organization not returned");
  assert(Array.isArray(payload.needs_attention), "needs_attention missing");
  assert(payload.needs_attention.some((item) => item.type === "findings_approval"), "findings approval attention item missing");
  assert(Array.isArray(payload.my_queue), "my_queue missing");
  assert(payload.my_queue.some((item) => item.task === "Review findings"), "review findings task missing");
  assert(payload.lifecycle_pipeline && typeof payload.lifecycle_pipeline === "object", "pipeline missing");
  assert(payload.next_best_action, "next_best_action missing");

  console.log(JSON.stringify({
    ok: true,
    assigned_organizations: payload.assigned_organizations.length,
    needs_attention: payload.needs_attention.length,
    my_queue: payload.my_queue.length,
    next_best_action: payload.next_best_action.task || payload.next_best_action.label
  }, null, 2));
} catch (error) {
  if (!setupCommitted) {
    await pg.query("rollback").catch(() => {});
  }
  console.error(error);
  throw error;
} finally {
  await pg.query("begin");
  await pg.query("delete from roadmap_items where id = $1", [ids.roadmap]);
  await pg.query("delete from recommendations where id = $1", [ids.recommendation]);
  await pg.query("delete from findings where id = $1", [ids.finding]);
  await pg.query("delete from assessment_participants where participant_id = $1", [ids.participant]);
  await pg.query("delete from assessment_sessions where id = $1", [ids.session]);
  await pg.query("delete from assessment_blueprints where assessment_project_id = $1", [ids.project]);
  await pg.query("delete from assessments where id = $1", [ids.assessment]);
  await pg.query("delete from consultant_company_assignments where consultant_user_id = $1 and company_id = $2", [ids.user, ids.project]);
  await pg.query("delete from assessment_projects where id = $1", [ids.project]);
  await pg.query("delete from organizations where id = $1", [ids.org]);
  await pg.query("delete from user_sessions where user_id = $1", [ids.user]);
  await pg.query("delete from users where id = $1", [ids.user]);
  await pg.query("commit");
  await pg.end();
}
