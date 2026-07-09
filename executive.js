import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';
import { renderReportProgressMemory, renderProgressMemorySectionComponent } from './progress.js';
import { renderAlignmentHeatmapComponent } from './alignment.js';

function formatProblemType(problemType) {
  return String(problemType || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function ownerDomainLabel(domain = "") {
  const labels = {
    strategy: "Strategy",
    governance: "Governance",
    sales: "Sales",
    customer_experience: "Customer Experience",
    service_delivery: "Service Delivery",
    field_operations: "Field Operations",
    fleet_operations: "Fleet Operations",
    branch_operations: "Branch Operations",
    inventory_management: "Inventory Management",
    procurement: "Procurement",
    logistics: "Logistics",
    warehouse_operations: "Warehouse Operations",
    finance: "Finance",
    profitability: "Profitability",
    data_management: "Data Management",
    reporting_analytics: "Reporting & Analytics",
    technology: "Technology",
    automation: "Automation",
    workforce: "Workforce",
    change_management: "Change Management",
    compliance: "Compliance",
    risk_management: "Risk Management",
    innovation: "Innovation"
  };
  return labels[domain] || formatProblemType(domain || "Unclassified");
}

function formatEstimatedValue(value = 0) {
  const amount = Number(value || 0);
  if (!amount) return "Value TBD";
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency: "USD",
    maximumFractionDigits: 0
  }).format(amount) + "/year";
}

function formatAnnualHours(value = 0) {
  const hours = Math.round(Number(value || 0));
  return hours ? `${hours.toLocaleString()} hrs/year` : "Hours TBD";
}

function reportDate(value) {
  return value ? new Date(value).toLocaleDateString(undefined, { year: "numeric", month: "short", day: "numeric" }) : new Date().toLocaleDateString();
}

function reportScore(value = 0) {
  return Math.round(Number(value || 0));
}

function reportList(values = [], fallback = "Not available") {
  const list = Array.isArray(values) ? values.filter(Boolean) : [];
  return list.length ? list.map((item) => `<li>${escapeHtml(typeof item === "string" ? item : item.name || item.title || item.id || "")}</li>`).join("") : `<li>${escapeHtml(fallback)}</li>`;
}

function reportChipList(values = [], fallback = "None") {
  const list = Array.isArray(values) ? values.filter(Boolean) : [];
  return list.length ? list.map((item) => `<span>${escapeHtml(typeof item === "string" ? item : item.name || item.title || item.id || "")}</span>`).join("") : `<span>${escapeHtml(fallback)}</span>`;
}

function reportEvidenceReference(reference) {
  return reference ? `${Number(reference.evidence_count || 0)} evidence record(s)` : "Evidence reference pending";
}

function labelList(values = [], fallback = "Not captured") {
  const list = Array.isArray(values) ? values.filter(Boolean) : [];
  if (!list.length) return fallback;
  return list.map((item) => typeof item === "string" ? item : item.name || item.title || item.id || "").filter(Boolean).join(", ");
}

function getFindingSupportingGroupLabels(finding = {}) {
  return finding.supporting_stakeholder_group_names ||
    finding.supporting_stakeholder_groups ||
    (finding.stakeholder_group_name ? [finding.stakeholder_group_name] : []);
}

function captureMethodForKpi(finding = {}) {
  const domain = finding.business_domain;
  if (["service_delivery", "field_operations"].includes(domain)) return "Capture timestamps and service status in digital work orders.";
  if (domain === "inventory_management") return "Capture inventory movements through branch/warehouse stock transactions.";
  if (domain === "reporting_analytics" || domain === "data_management") return "Assign KPI ownership and connect reports to a governed source table.";
  if (domain === "customer_experience") return "Capture customer feedback and status events in the service workflow.";
  return "Define the KPI owner, required fields, source system, and reporting cadence.";
}

function metricCard(label, valueText, note = "") {
  return `<article class="report-metric-card"><span>${escapeHtml(label)}</span><strong>${escapeHtml(String(valueText))}</strong>${note ? `<small>${escapeHtml(note)}</small>` : ""}</article>`;
}

function insightList(items, fallback) {
  const list = Array.isArray(items) ? items.filter(Boolean).slice(0, 4) : [];
  return list.length ? `<ul>${reportList(list)}</ul>` : `<p>${escapeHtml(fallback)}</p>`;
}

export function renderExecutiveReportComponent(
  report,
  findings = [],
  recommendations = [],
  progressMemory = {},
  reportToggles = {},
  emptyStateHtml = "",
  {
    onGenerate,
    onToggleSection,
    onNavigateSection,
    onPrint,
    onExport
  } = {}
) {
  if (!report) {
    return emptyStateHtml || renderScreenState("executive-report", "empty", {
      title: "No executive report generated yet",
      message: "Generate a structured executive report once approved findings and recommendations are available.",
      compact: true
    });
  }
  const showEvidence = reportToggles.showEvidence !== false;
  const showAppendix = reportToggles.showAppendix !== false;
  const summary = report.executive_summary || {};
  const dna = report.company_dna || {};
  const coverage = report.assessment_coverage || {};
  const value = report.business_value_summary || {};
  const reportFindings = (report.top_findings || findings || []).slice(0, 8);
  const reportRecommendations = (report.recommendations || recommendations || []).slice(0, 8);
  const kpiGaps = report.kpi_gaps || [];
  const evidenceSummary = report.evidence_summary || [];
  const agreement = report.agreement_summary || {};
  const roadmap = report.roadmap || {};
  const alignment = report.alignment_summary || {};
  const nextActions = report.next_best_actions || [];
  const appendix = report.appendix || {};
  const completedRoles = (coverage.completed_stakeholder_roles || []).map((role) => role.name);
  const missingRequiredRoles = (coverage.coverage_gaps || []).filter((gap) => gap.type === "missing_required_stakeholder").map((gap) => gap.role_name || gap.role);
  const missingKpiSets = (coverage.coverage_gaps || []).filter((gap) => gap.type === "missing_required_kpi_set").map((gap) => gap.kpi_set);
  const topRisks = (summary.top_risks || []).slice(0, 3);
  const topOpportunities = (summary.top_opportunities || []).slice(0, 3);
  const topKpis = kpiGaps.slice(0, 8);
  const topValueOpportunities = (value.top_opportunities_by_value || []).slice(0, 5);
  const roadmapPhases = ["Quick Wins", "Foundation", "Optimization", "Transformation"];
  const reportSections = [
    ["summary", "Executive Summary"],
    ["dna", "Organization Profile"],
    ["coverage", "Coverage"],
    ["findings", "Findings"],
    ...(showEvidence ? [["evidence", "Evidence"]] : []),
    ["agreement", "Alignment"],
    ["kpis", "KPI Radar"],
    ["recommendations", "Opportunities"],
    ["roadmap", "Roadmap"],
    ["value", "Value"],
    ["progress", "Progress"],
    ["actions", "Next Actions"],
    ...(showAppendix ? [["appendix", "Appendix"]] : [])
  ];
  const controls = [
    onToggleSection ? `<label><input data-component-report-toggle="evidence" type="checkbox" ${showEvidence ? "checked" : ""} /> Evidence</label>` : "",
    onToggleSection ? `<label><input data-component-report-toggle="appendix" type="checkbox" ${showAppendix ? "checked" : ""} /> Appendix</label>` : "",
    onPrint ? `<button class="ghost-button" data-component-report-action="print" type="button">Print</button>` : "",
    onExport ? `<button class="ghost-button" data-component-report-action="export" type="button">Export</button>` : "",
    onGenerate ? `<button class="ghost-button" data-component-report-action="generate" type="button">Regenerate</button>` : ""
  ].join("");
  return `
    ${controls ? `<div class="report-toolbar">${controls}</div>` : ""}
    <article class="report-document report-consulting">
      <nav class="report-nav">
        ${reportSections.map(([id, label]) => onNavigateSection ? `<button data-component-report-nav="${id}" type="button">${escapeHtml(label)}</button>` : `<a href="#report-${id}">${escapeHtml(label)}</a>`).join("")}
      </nav>
      <section class="report-cover report-page">
        <div class="report-cover-kicker">Business Intelligence & Digital Transformation Assessment Report</div>
        <div class="report-cover-layout">
          <div>
            <span class="eyebrow">Executive Deliverable</span>
            <h1>${escapeHtml(report.company_name || dna.companyName || "Company")}</h1>
            <p>${escapeHtml(report.report_subtitle || "Evidence-based findings, KPI gaps, recommendations, and transformation roadmap.")}</p>
          </div>
          <aside class="report-cover-facts">
            <div><span>Assessment</span><strong>${escapeHtml(report.assessment_name || "Assessment")}</strong></div>
            <div><span>Date</span><strong>${reportDate(report.generated_at)}</strong></div>
            <div><span>Prepared By</span><strong>${escapeHtml(report.prepared_by || "Derive Assessment Platform")}</strong></div>
          </aside>
        </div>
        <div class="report-cover-grid report-hero-metrics">
          ${metricCard("Assessment Confidence", `${coverage.assessment_confidence_score || summary.assessment_confidence_score || 0}/100`, "Evidence depth and stakeholder coverage")}
          ${metricCard("Assessment Completeness", `${coverage.assessment_completeness_score || summary.assessment_completeness_score || 0}/100`, "Required roles, KPI sets, and domains")}
          ${metricCard("Estimated Annual Value", formatEstimatedValue(value.total_estimated_annual_business_value), "Directional value estimate")}
        </div>
      </section>
      <section id="report-summary" class="report-section report-page report-executive-summary">
        <div class="report-section-heading"><span class="eyebrow">Executive Summary</span><h2>The owner story in one page</h2></div>
        <p class="report-lead">${escapeHtml(summary.overall_business_health_summary || "Assessment findings will appear after review.")}</p>
        <div class="report-scorecards report-summary-scorecards">
          ${metricCard("Business Health", summary.business_health_label || `${reportFindings.length} priority findings`, "Based on approved findings")}
          ${metricCard("Top Risks", String(topRisks.length || 0), "Issues requiring executive attention")}
          ${metricCard("Top Opportunities", String(topOpportunities.length || reportRecommendations.length), "Approved actions ready for review")}
          ${metricCard("Estimated Value", formatEstimatedValue(value.total_estimated_annual_business_value), "Estimated annual benefit")}
        </div>
        <div class="report-insight-grid">
          <article><span>What is happening</span><h3>Top Findings</h3>${insightList(summary.top_findings || reportFindings.map((finding) => finding.title), "No approved findings are available yet.")}</article>
          <article><span>Why it matters</span><h3>Top Risks</h3>${insightList(topRisks, "No major risks have been isolated yet.")}</article>
          <article><span>What to do next</span><h3>Top Opportunities</h3>${insightList(topOpportunities, "Approved recommendations will appear here.")}</article>
          <article><span>What is missing</span><h3>Top KPI Gaps</h3>${insightList(summary.top_missing_kpis || topKpis.map((finding) => finding.title), "No approved KPI gaps detected.")}</article>
        </div>
      </section>
      <section id="report-dna" class="report-section report-page">
        <div class="report-section-heading"><span class="eyebrow">Organization Profile</span><h2>The business context behind every recommendation</h2></div>
        <div class="report-profile-card">
          <div><span>Business Model</span><strong>${escapeHtml(dna.industry || "Industry not defined")}</strong><p>${escapeHtml(labelList(dna.businessActivities || [], "Business activities not captured"))}</p></div>
          <div><span>Operating Model</span><strong>${escapeHtml(labelList(dna.operationalCharacteristics || [], "Operational characteristics not captured"))}</strong></div>
          <div><span>Workforce & Locations</span><strong>${escapeHtml(dna.employeeRange || "Size not defined")}</strong><p>${escapeHtml(String(dna.locationCount || "Location count not defined"))} locations</p></div>
          <div><span>Strategic Priorities</span><strong>${escapeHtml(labelList(dna.strategicPriorities || [], "Strategic priorities not captured"))}</strong></div>
        </div>
      </section>
      <section id="report-coverage" class="report-section report-page">
        <div class="report-section-heading"><span class="eyebrow">Assessment Coverage</span><h2>How much trust to place in the findings</h2></div>
        <div class="report-scorecards">
          ${metricCard("Completeness", `${coverage.assessment_completeness_score || 0}/100`, "Required assessment coverage")}
          ${metricCard("Confidence", `${coverage.assessment_confidence_score || 0}/100`, "Evidence and stakeholder strength")}
          ${metricCard("Completed Roles", String(completedRoles.length), "Stakeholders represented")}
          ${metricCard("Coverage Gaps", String((coverage.coverage_gaps || []).length), "Remaining trust limits")}
        </div>
        <div class="report-two-column report-subsection-grid">
          <article><h3>Required Roles</h3><ul>${reportList((coverage.required_stakeholder_roles || []).map((role) => role.name))}</ul></article>
          <article><h3>Completed Roles</h3><ul>${reportList(completedRoles)}</ul></article>
          <article><h3>Missing Critical Roles</h3><ul>${reportList(missingRequiredRoles, "No critical role gaps")}</ul></article>
          <article><h3>Missing KPI Sets</h3><ul>${reportList(missingKpiSets.slice(0, 12), "No critical KPI set gaps")}</ul></article>
        </div>
      </section>
      <section id="report-findings" class="report-section report-page">
        <div class="report-section-heading"><span class="eyebrow">Top Findings</span><h2>The highest-priority issues and opportunities</h2></div>
        <div class="report-finding-list">${reportFindings.map((finding, index) => `
          <article class="report-finding-card">
            <div class="report-card-head"><span>${index + 1}</span><h3>${escapeHtml(finding.title)}</h3><strong>${reportScore(finding.priority_score)}</strong></div>
            <p>${escapeHtml(finding.description || "")}</p>
            <div class="report-chip-row">${reportChipList([ownerDomainLabel(finding.business_domain), ...(finding.problem_types || []).slice(0, 4).map(formatProblemType)])}</div>
            <div class="report-metrics-row"><span>Severity ${escapeHtml(finding.severity ?? "-")}/5</span><span>Frequency ${escapeHtml(finding.frequency ?? "-")}/5</span><span>Confidence ${escapeHtml(finding.confidence ?? "-")}/5</span><span>Evidence ${escapeHtml(finding.evidence_count ?? 0)}</span></div>
            <p><strong>Stakeholders:</strong> ${escapeHtml(getFindingSupportingGroupLabels(finding).join(", ") || "Single source")}</p>
            <small>${escapeHtml(reportEvidenceReference(finding.evidence_reference))}</small>
          </article>`).join("") || (emptyStateHtml || renderScreenState("executive-report", "empty", { title: "No approved findings available for this report.", compact: true }))}</div>
      </section>
      ${showEvidence ? `<section id="report-evidence" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Evidence Summary</span><h2>Why the findings are credible</h2></div><div class="report-evidence-board">${evidenceSummary.slice(0, 8).map((item) => `<article class="report-evidence-card"><div class="report-evidence-meta"><span>${escapeHtml(item.evidence_count ?? 0)} evidence records</span><span>${escapeHtml((item.source_stakeholder_groups || []).join(", ") || "Stakeholder group pending")}</span></div><h3>${escapeHtml(item.finding_title)}</h3><p>Supported by ${escapeHtml((item.source_stakeholder_roles || []).join(", ") || "source roles pending")}.</p></article>`).join("") || "<p>No evidence details available.</p>"}</div></section>` : ""}
      <section id="report-agreement" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Organizational Alignment</span><h2>Where the organization agrees and disagrees</h2></div><div class="report-alignment-board"><article><span>Agreement</span><h3>Strongly supported areas</h3>${(agreement.areas_of_strong_agreement || []).slice(0, 5).map((finding) => `<p><strong>${escapeHtml(finding.title)}</strong><small>Groups: ${escapeHtml(getFindingSupportingGroupLabels(finding).join(", ") || "-")} · Confidence ${escapeHtml(finding.confidence ?? "-")}/5</small></p>`).join("") || "<p>No cross-stakeholder agreement yet.</p>"}</article><article><span>Misalignment</span><h3>Conflicting operating reality</h3>${(agreement.areas_of_misalignment || []).slice(0, 5).map((finding) => `<p><strong>${escapeHtml(finding.title)}</strong><small>${ownerDomainLabel(finding.business_domain)} · Severity ${escapeHtml(finding.severity ?? "-")}/5</small></p>`).join("") || "<p>No approved misalignment detected.</p>"}</article><article><span>Heatmap Signal</span><h3>Domain concentration</h3><p><strong>${escapeHtml(alignment.most_misaligned_domain?.domain_name || alignment.highest_priority_domain?.domain_name || "No concentration yet")}</strong><small>Most aligned: ${escapeHtml(alignment.most_aligned_domain?.domain_name || "-")} · Most findings: ${escapeHtml(alignment.stakeholder_group_with_most_findings?.name || "-")}</small></p></article></div></section>
      <section id="report-kpis" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Missing KPI Radar</span><h2>The visibility gaps that limit management control</h2></div><div class="report-kpi-radar">${topKpis.map((finding) => `<article><span>${ownerDomainLabel(finding.business_domain)}</span><h3>${escapeHtml(finding.title)}</h3><p>${escapeHtml(finding.description || "Missing KPI limits management visibility.")}</p><small>Capture method: ${escapeHtml(captureMethodForKpi(finding))}</small><strong>Priority ${reportScore(finding.priority_score)}</strong></article>`).join("") || renderScreenState("executive-report", "empty", { title: "No approved KPI gaps detected.", compact: true })}</div></section>
      <section id="report-recommendations" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Opportunity Portfolio</span><h2>Approved recommendations ready for action</h2></div><div class="report-opportunity-portfolio">${reportRecommendations.map((rec) => `<article class="report-recommendation-card"><div class="report-card-head"><h3>${escapeHtml(rec.title)}</h3><strong>${reportScore(rec.priority_score)}</strong></div><p>${escapeHtml(rec.why_recommendation_exists || rec.description || "")}</p><div class="report-opportunity-meta"><span>Value ${formatEstimatedValue(rec.expected_value || rec.estimated_business_value)}</span><span>Owner ${escapeHtml(rec.recommended_owner || "To be assigned")}</span><span>Timeline ${escapeHtml(rec.estimated_timeline || rec.roadmap_phase || "Foundation")}</span><span>Confidence ${escapeHtml(rec.recommendation_confidence_score ?? 3)}/5</span></div></article>`).join("") || renderScreenState("executive-report", "empty", { title: "Approved recommendations will appear after findings are reviewed.", compact: true })}</div></section>
      <section id="report-roadmap" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Roadmap</span><h2>Sequenced path from quick wins to transformation</h2></div><div class="report-roadmap-grid report-roadmap-timeline">${roadmapPhases.map((phase, index) => `<article><span>${String(index + 1).padStart(2, "0")}</span><h3>${phase}</h3>${(roadmap[phase] || []).slice(0, 4).map((item) => `<div><strong>${escapeHtml(item.title)}</strong><p>${escapeHtml(item.description || "")}</p><small>${escapeHtml(item.estimated_timeline || "")} · Priority ${reportScore(item.priority_score)} · ${escapeHtml(item.business_value || "")}</small></div>`).join("") || "<p>No approved roadmap items.</p>"}</article>`).join("")}</div></section>
      <section id="report-value" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Value Summary</span><h2>Estimated business value and ROI confidence</h2></div><div class="report-scorecards report-value-scorecards">${metricCard("Annual Value", formatEstimatedValue(value.total_estimated_annual_business_value), "Estimated")}${metricCard("Time Savings", formatAnnualHours(value.total_estimated_time_savings), "Estimated")}${metricCard("Cost Savings", formatEstimatedValue(value.total_estimated_cost_savings), "Estimated")}${metricCard("Revenue Opportunity", formatEstimatedValue(value.total_estimated_revenue_opportunity), "Estimated")}${metricCard("Risk Reduction", formatEstimatedValue(value.total_estimated_risk_reduction), "Estimated")}${metricCard("ROI Confidence", `${value.average_roi_confidence_score || 0}/5`, "Evidence-based estimate")}</div><div class="report-table-wrap"><table><thead><tr><th>Opportunity</th><th>Related Finding</th><th>Estimated Value</th><th>Time</th><th>Cost</th><th>Revenue</th><th>Risk</th><th>Confidence</th></tr></thead><tbody>${topValueOpportunities.map((item) => `<tr><td>${escapeHtml(item.title)}</td><td>${escapeHtml(item.related_finding || "")}</td><td>${formatEstimatedValue(item.estimated_annual_value)}</td><td>${formatAnnualHours(item.time_savings)}</td><td>${formatEstimatedValue(item.cost_savings)}</td><td>${formatEstimatedValue(item.revenue_opportunity)}</td><td>${formatEstimatedValue(item.risk_reduction)}</td><td>${escapeHtml(item.roi_confidence ?? "-")}/5</td></tr>`).join("") || '<tr><td colspan="8">No value estimates available.</td></tr>'}</tbody></table></div></section>
      <section id="report-progress" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Progress Memory</span><h2>What changed since the last assessment</h2></div>${renderReportProgressMemory(progressMemory)}</section>
      <section id="report-actions" class="report-section report-page"><div class="report-section-heading"><span class="eyebrow">Next Best Actions</span><h2>What leadership should do next</h2></div><div class="report-next-actions">${nextActions.slice(0, 3).map((action, index) => `<article class="report-action-card"><span class="eyebrow">Action ${index + 1}</span><h3>${escapeHtml(action.title)}</h3><p>${escapeHtml(action.why_it_matters || "")}</p><div class="report-two-column compact"><p><strong>Expected benefit:</strong> ${escapeHtml(action.expected_benefit || "")}</p><p><strong>Owner:</strong> ${escapeHtml(action.recommended_owner || "")}</p></div></article>`).join("") || "<p>No next actions available yet.</p>"}</div></section>
      ${showAppendix ? `<section id="report-appendix" class="report-section report-page"><h2>Appendix</h2><div class="report-two-column"><article><h3>Methodology</h3><p>${escapeHtml(appendix.methodology || "")}</p></article><article><h3>Stakeholder Roles Included</h3><ul>${reportList(appendix.stakeholder_roles_included || [])}</ul></article><article><h3>Question Banks Used</h3><ul>${reportList(appendix.question_banks_used || [])}</ul></article><article><h3>Evidence References</h3><p>${escapeHtml(appendix.evidence_reference_count ?? 0)} evidence records are linked to approved findings.</p></article></div></section>` : ""}
    </article>
  `;
}

function ownerPriorityLabel(finding = {}) {
  const priority = Number(finding.priority_score || 0);
  if (priority >= 80) return "Critical";
  if (priority >= 60) return "High";
  if (priority >= 40) return "Medium";
  return "Monitor";
}

function ownerRecommendationCategory(category = "") {
  const normalized = String(category || "").toLowerCase();
  if (normalized.includes("automation")) return "Automation";
  if (normalized.includes("analytics") || normalized.includes("report")) return "Reporting & Analytics";
  if (normalized.includes("customer")) return "Customer Experience";
  if (normalized.includes("inventory")) return "Inventory Optimization";
  if (normalized.includes("workforce")) return "Workforce Productivity";
  if (normalized.includes("risk")) return "Risk Reduction";
  return "Process Improvement";
}

function ownerKpiFindings(findings = []) {
  return findings.filter((finding) => {
    const problemTypes = finding.problem_types || [];
    const text = `${finding.title || ""} ${finding.description || ""}`.toLowerCase();
    return problemTypes.includes("reporting_gap") || text.includes("kpi") || text.includes("not measured") || text.includes("measurement");
  });
}

function calculateOwnerSnapshot(findings = [], recommendations = [], roadmapItems = [], missingKpis = []) {
  const avgPriority = findings.length ? findings.reduce((sum, finding) => sum + Number(finding.priority_score || 0), 0) / findings.length : 0;
  const avgConfidence = findings.length ? findings.reduce((sum, finding) => sum + Number(finding.confidence || 0), 0) / findings.length : 0;
  const avgRisk = findings.length ? findings.reduce((sum, finding) => sum + Number(finding.risk_impact || 0), 0) / findings.length : 0;
  return {
    businessHealthScore: Math.max(0, Math.min(100, Math.round(100 - avgPriority * 0.55 - avgRisk * 5 + avgConfidence * 4))),
    digitalMaturityScore: Math.max(0, Math.min(100, Math.round(72 - missingKpis.length * 4 - findings.filter((finding) => Number(finding.automation_potential || 0) >= 4).length * 2 + recommendations.length * 2))),
    criticalIssues: findings.filter((finding) => ownerPriorityLabel(finding) === "Critical").length,
    quickWins: roadmapItems.filter((item) => item.phase === "Quick Wins").length || recommendations.filter((item) => item.roadmap_phase === "Quick Wins").length,
    missingKpis: missingKpis.length,
    approvedRecommendations: recommendations.length
  };
}

function getFindingSupportingRoleLabels(finding = {}) {
  return finding.supporting_stakeholder_role_names ||
    finding.supporting_stakeholder_roles ||
    (finding.stakeholder_role_name ? [finding.stakeholder_role_name] : []);
}

function evidenceForPreviewFinding(evidence = [], findingId = "") {
  return (evidence || []).filter((item) => String(item.finding_id) === String(findingId));
}

function formatStakeholderId(value = "") {
  return String(value || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function shortText(value = "", length = 140) {
  const text = String(value || "").trim();
  if (!text) return "";
  return text.length > length ? `${text.slice(0, length - 3)}...` : text;
}

function scoreDisplay(value) {
  const score = Number(value || 0);
  return Number.isFinite(score) ? Math.round(score * 10) / 10 : 0;
}

function generatePerceptionInsight(accurateGaps, blindSpots) {
  if (!blindSpots.length) {
    return "Your self-assessment was accurate across all measured domains.";
  }
  const worst = blindSpots[0];
  const accurate = accurateGaps[0];
  let insight = "";
  if (accurate) {
    insight += `Your instincts about ${accurate.domain_name} are accurate. The assessment confirms your view. `;
  }
  insight += `Your most significant blind spot is ${worst.domain_name}: you rated it ${scoreDisplay(worst.owner_baseline_score)}/5 but your organization experiences it as ${scoreDisplay(worst.participant_avg_score)}/5. This gap of ${Math.abs(Number(worst.perception_gap || 0)).toFixed(1)} points is where the most important work begins.`;
  return insight;
}

function renderExecutiveGapRow(gap) {
  const gapValue = Number(gap.perception_gap || 0);
  const ownerScore = Number(gap.owner_baseline_score || 0);
  const realityScore = Number(gap.participant_avg_score || 0);
  const ownerWidth = Math.max(0, Math.min(100, (ownerScore / 5) * 100));
  const realityWidth = Math.max(0, Math.min(100, (realityScore / 5) * 100));
  const rowClass = gapValue > 0 ? "exec-gap-blindspot" : "exec-gap-accurate";
  const deltaClass = gapValue > 0.5
    ? "exec-gap-delta-bad"
    : gapValue < -0.3
      ? "exec-gap-delta-under"
      : "exec-gap-delta-ok";
  return `
    <div class="exec-gap-row ${rowClass}">
      <div class="exec-gap-header">
        <span class="exec-gap-domain">${escapeHtml(gap.domain_name)}</span>
        <span class="exec-gap-delta ${deltaClass}">
          ${gapValue > 0 ? "▼ " : "▲ "}${Math.abs(gapValue).toFixed(1)} pts
        </span>
      </div>
      <div class="exec-gap-bars">
        <div class="exec-gap-bar-row">
          <span class="exec-gap-bar-label">You rated</span>
          <div class="exec-gap-bar-track">
            <div class="exec-gap-bar exec-gap-bar-owner" style="width: ${ownerWidth}%"></div>
          </div>
          <span class="exec-gap-bar-value">${escapeHtml(gap.owner_baseline_score)}/5</span>
        </div>
        <div class="exec-gap-bar-row">
          <span class="exec-gap-bar-label">Reality</span>
          <div class="exec-gap-bar-track">
            <div class="exec-gap-bar exec-gap-bar-reality" style="width: ${realityWidth}%"></div>
          </div>
          <span class="exec-gap-bar-value">${escapeHtml(gap.participant_avg_score)}/5</span>
        </div>
      </div>
    </div>
  `;
}

function generatePriorityContext(ownerPriority, topFinding) {
  if (!ownerPriority || !topFinding) return "";
  return "Your stated priority and our top finding point to the same underlying challenge: the organization's operational infrastructure needs attention before strategic priorities can be effectively pursued.";
}

export function renderExecutivePreviewComponent(
  organization,
  assessment,
  profile,
  blueprint,
  findings = [],
  recommendations = [],
  roadmapItems = [],
  evidence = [],
  progressMemory = {},
  selectedFindingId = "",
  filterState = {},
  emptyStateHtml = "",
  executiveReport = null,
  {
    onSelectFinding,
    onViewReport,
    onFilterChange,
    onHeatmapCellSelect,
    onNavigate
  } = {}
) {
  const safeProgressMemory = progressMemory || {};
  if (!findings.length && !recommendations.length) {
    return emptyStateHtml || renderScreenState("owner-dashboard", "empty", {
      title: "Assessment is still in progress",
      message: "Owner insights will appear after approved findings and recommendations are available.",
      compact: true
    });
  }
  const companyName = organization?.clientDisplayName || organization?.organizationName || organization?.name || profile?.companyName || "Organization";
  const frameworkName = blueprint?.framework_name || blueprint?.name || executiveReport?.assessment_coverage?.framework_name || "Fleet & Service Operations";
  const approvedFindings = findings || [];
  const approvedRecs = recommendations || [];
  const kpiGapFindings = ownerKpiFindings(approvedFindings);
  const reportGaps = Array.isArray(executiveReport?.perceptionGaps) ? executiveReport.perceptionGaps : [];
  const perceptionGaps = reportGaps
    .filter((gap) => gap.owner_baseline_score !== null && gap.owner_baseline_score !== undefined && gap.participant_avg_score !== null && gap.participant_avg_score !== undefined)
    .map((gap) => ({
      ...gap,
      owner_baseline_score: scoreDisplay(gap.owner_baseline_score),
      participant_avg_score: scoreDisplay(gap.participant_avg_score),
      perception_gap: Number(gap.perception_gap || 0),
      domain_name: gap.domain_name || ownerDomainLabel(gap.domain_key)
    }));
  const accurateGaps = perceptionGaps
    .filter((gap) => Math.abs(Number(gap.perception_gap || 0)) < 0.3)
    .slice(0, 4);
  const blindSpots = perceptionGaps
    .filter((gap) => Math.abs(Number(gap.perception_gap || 0)) >= 0.3)
    .sort((a, b) => Number(b.perception_gap || 0) - Number(a.perception_gap || 0))
    .slice(0, 6);
  const intakeExpectations = executiveReport?.intakeExpectations || null;
  const top3Findings = [...approvedFindings]
    .sort((a, b) => Number(b.severity || 0) - Number(a.severity || 0) || Number(b.confidence || 0) - Number(a.confidence || 0))
    .slice(0, 3);
  const topFinding = top3Findings[0] || null;
  const topRec = [...approvedRecs]
    .sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0))
    [0] || null;
  const phaseNames = ["Quick Wins", "Foundation", "Optimization", "Transformation"];
  const roadmapPhases = phaseNames.map((name) => ({
    name,
    items: (roadmapItems || [])
      .filter((item) => (item.phase || item.roadmap_phase || "Foundation") === name)
      .sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0))
  }));
  for (const rec of approvedRecs) {
    const phase = rec.roadmap_phase || "Foundation";
    const group = roadmapPhases.find((item) => item.name === phase);
    if (group && !group.items.some((item) => String(item.recommendation_id || item.id) === String(rec.id))) {
      group.items.push(rec);
    }
  }
  const activePhases = roadmapPhases.filter((phase) => phase.items.length);
  const avgSeverity = approvedFindings.length
    ? approvedFindings.reduce((sum, finding) => sum + Number(finding.severity || 0), 0) / approvedFindings.length
    : 0;
  const avgConfidence = approvedFindings.length
    ? approvedFindings.reduce((sum, finding) => sum + Number(finding.confidence || 0), 0) / approvedFindings.length
    : 0;
  const alignmentScore = Math.max(0, Math.min(100, Math.round(82 - avgSeverity * 8 + avgConfidence * 6 - blindSpots.length * 4)));
  return `
    <section class="exec-header">
      <div class="exec-header-meta">
        <span class="exec-company-name">${escapeHtml(companyName)}</span>
        <span class="exec-date">${escapeHtml(reportDate(assessment?.created_at || assessment?.createdAt || assessment?.updated_at))}</span>
        <span class="exec-framework">${escapeHtml(frameworkName)}</span>
      </div>
      <div class="exec-headline">
        <div>
          <div class="exec-score-block">
            <span class="exec-score-number">${escapeHtml(alignmentScore)}</span>
            <span class="exec-score-label">/100</span>
          </div>
          <span class="exec-score-sublabel">Organizational alignment</span>
        </div>
        <div class="exec-headline-stats">
          <div class="exec-stat"><strong>${escapeHtml(approvedFindings.length)}</strong><span>findings identified</span></div>
          <div class="exec-stat"><strong>${escapeHtml(approvedRecs.length)}</strong><span>recommendations ready</span></div>
          <div class="exec-stat"><strong>${escapeHtml(kpiGapFindings.length)}</strong><span>measurement blind spots</span></div>
        </div>
      </div>
    </section>

    ${perceptionGaps.length ? `
      <section class="exec-section">
        <div class="exec-section-label">Before this assessment, you rated your organization in several areas. Here is what we found.</div>
        <div class="exec-perception-grid">
          <div class="exec-perception-group">
            <h4>Where your instincts were accurate</h4>
            ${accurateGaps.length ? accurateGaps.map((gap) => `
              ${renderExecutiveGapRow(gap)}
            `).join("") : `<p class="exec-muted">No close matches yet. Recalculate perception gaps after the next analysis run.</p>`}
          </div>
          <div class="exec-perception-group">
            <h4>Your blind spots</h4>
            ${blindSpots.length ? blindSpots.map((gap) => `
              ${renderExecutiveGapRow(gap)}
            `).join("") : `<p class="exec-muted">No major blind spots found in the current recalculated data.</p>`}
          </div>
        </div>
        <div class="exec-perception-insight">${escapeHtml(generatePerceptionInsight(accurateGaps, blindSpots))}</div>
      </section>
    ` : ""}

    ${intakeExpectations ? `
      <section class="exec-section">
        <div class="exec-section-label">What you told us at the start of this assessment</div>
        <div class="exec-expectations-grid">
          <div class="exec-expectation-row">
            <div class="exec-expectation-left">
              <span class="exec-exp-label">You said your most urgent priority was:</span>
              <span class="exec-exp-value">"${escapeHtml(intakeExpectations.most_urgent_priority || "Not captured")}"</span>
            </div>
            <div class="exec-expectation-right">
              <span class="exec-exp-label">What we found:</span>
              <span class="exec-exp-finding">${escapeHtml(topFinding?.title || "Review approved findings")}</span>
              <span class="exec-exp-context">${escapeHtml(generatePriorityContext(intakeExpectations.most_urgent_priority, topFinding))}</span>
            </div>
          </div>
          <div class="exec-expectation-row">
            <div class="exec-expectation-left">
              <span class="exec-exp-label">You said success looks like:</span>
              <span class="exec-exp-value">"${escapeHtml(intakeExpectations.success_looks_like || "Not captured")}"</span>
            </div>
            <div class="exec-expectation-right">
              <span class="exec-exp-label">What we delivered:</span>
              <span class="exec-exp-finding">${escapeHtml(approvedRecs.length)} recommendations across ${escapeHtml(activePhases.length || 1)} phases</span>
              <span class="exec-exp-context">Starting with: ${escapeHtml(topRec?.title || "Review recommendations")}</span>
            </div>
          </div>
        </div>
      </section>
    ` : ""}

    <section class="exec-section">
      <div class="exec-section-label">The findings that need your attention first</div>
      <div class="exec-findings-grid">
        ${top3Findings.map((finding, index) => `
          <article class="exec-finding-card">
            <div class="exec-finding-number">0${index + 1}</div>
            <div class="exec-finding-body">
              <h3>${escapeHtml(finding.title)}</h3>
              <p>${escapeHtml(shortText(finding.description || ""))}</p>
              <div class="exec-finding-meta">
                <span class="exec-domain-pill">${escapeHtml(ownerDomainLabel(finding.business_domain))}</span>
                <span class="exec-severity-pill severity-${escapeHtml(finding.severity || 0)}">Severity ${escapeHtml(finding.severity || 0)}/5</span>
                <span class="exec-confidence">Confidence ${escapeHtml(finding.confidence || 0)}/5</span>
              </div>
            </div>
          </article>
        `).join("") || renderScreenState("executive-preview", "empty", { title: "Approve findings to build the executive view.", compact: true })}
      </div>
    </section>

    <section class="exec-section">
      <div class="exec-section-label">Metrics critical to your business that you currently do not track</div>
      <div class="exec-kpi-grid">
        ${kpiGapFindings.length ? kpiGapFindings.map((kpi) => `
          <div class="exec-kpi-item">
            <span class="exec-kpi-name">${escapeHtml(String(kpi.title || "").replace(/ Not Measured/gi, "").replace(/Missing /gi, ""))}</span>
            <span class="exec-kpi-domain">${escapeHtml(ownerDomainLabel(kpi.business_domain))}</span>
          </div>
        `).join("") : renderScreenState("executive-preview", "empty", { title: "No approved KPI blind spots yet.", compact: true })}
      </div>
      <p class="exec-kpi-note">Each unmeasured metric is a blind spot. You cannot manage what you do not measure.</p>
    </section>

    <section class="exec-section">
      <div class="exec-section-label">Recommendations sequenced by impact and effort</div>
      <div class="exec-roadmap-grid">
        ${roadmapPhases.map((phase) => `
          <article class="exec-phase-card">
            <span class="exec-phase-label">${escapeHtml(phase.name)}</span>
            <strong class="exec-phase-count">${escapeHtml(phase.items.length)}</strong>
            <span class="exec-phase-sublabel">recommendations</span>
            ${phase.items[0] ? `<div class="exec-phase-top"><span>Starting with:</span><strong>${escapeHtml(phase.items[0].title)}</strong></div>` : ""}
          </article>
        `).join("")}
      </div>
    </section>

    <section class="exec-section exec-section-report">
      <div class="exec-section-label">Your organizational intelligence report</div>
      <div class="exec-report-actions">
        <button class="primary-button" data-component-export-report="executive-summary" type="button">↓ Executive Summary PDF</button>
        <button class="ghost-button" data-component-export-report="full-report" type="button">↓ Full Intelligence Report PDF</button>
      </div>
      <p class="exec-report-note">Reports contain approved findings and recommendations only. Prepared by Derive Organizational Intelligence Platform.</p>
    </section>
  `;
  const assessmentName = assessment?.name || assessment?.title || organization?.activeAssessmentName || "Business Assessment";
  const missingKpis = ownerKpiFindings(findings);
  const snapshot = calculateOwnerSnapshot(findings, recommendations, roadmapItems, missingKpis);
  const topFindings = [...findings].sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0)).slice(0, 5);
  const selectedId = selectedFindingId && findings.some((finding) => String(finding.id) === String(selectedFindingId))
    ? selectedFindingId
    : String(topFindings[0]?.id || "");
  const selectedFinding = findings.find((finding) => String(finding.id) === String(selectedId));
  const selectedEvidence = selectedFinding ? evidenceForPreviewFinding(evidence, selectedFinding.id) : [];
  const confidenceScore = blueprint?.assessment_confidence_score || assessment?.assessment_confidence_score || snapshot.businessHealthScore || 0;
  const completenessScore = blueprint?.assessment_completeness_score || assessment?.assessment_completeness_score || 0;
  const lastUpdated = assessment?.updated_at || assessment?.last_updated || organization?.updated_at || new Date().toISOString();
  const executiveSummary = findings.length
    ? `${companyName} shows ${snapshot.criticalIssues ? "urgent" : "clear"} operational opportunity, with visibility gaps concentrated in ${topFindings.slice(0, 3).map((finding) => ownerDomainLabel(finding.business_domain)).join(", ")}.`
    : "Assessment is still in progress. Owner insights will appear after approved findings and recommendations are available.";
  const topIssues = topFindings.slice(0, 3);
  const topOpportunities = [...recommendations]
    .sort((a, b) => Number(b.estimated_business_value || 0) - Number(a.estimated_business_value || 0) || Number(b.priority_score || 0) - Number(a.priority_score || 0))
    .slice(0, 3);
  const agreementFindings = [...findings]
    .filter((finding) => Number(finding.stakeholder_agreement_score || 0) >= 2)
    .sort((a, b) => Number(b.stakeholder_agreement_score || 0) - Number(a.stakeholder_agreement_score || 0) || Number(b.confidence || 0) - Number(a.confidence || 0))
    .slice(0, 5);
  const misalignmentFindings = findings.filter((finding) => finding.contradiction_detected).sort((a, b) => Number(b.severity || 0) - Number(a.severity || 0)).slice(0, 5);
  const roadmapGroups = ["Quick Wins", "Foundation", "Optimization", "Transformation"].map((phase) => ({
    phase,
    items: roadmapItems.filter((item) => (item.phase || item.roadmap_phase) === phase).sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0)).slice(0, 5)
  }));
  const roadmapPreview = roadmapGroups.map((group) => ({ ...group, topItem: group.items[0] }));
  const highestPriorityKpis = [...missingKpis].sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0)).slice(0, 8);
  const valueTotals = recommendations.reduce((totals, recommendation) => ({
    value: totals.value + Number(recommendation.estimated_business_value || 0),
    time: totals.time + Number(recommendation.estimated_time_savings || 0),
    cost: totals.cost + Number(recommendation.estimated_cost_savings || 0),
    revenue: totals.revenue + Number(recommendation.estimated_revenue_opportunity || 0),
    risk: totals.risk + Number(recommendation.estimated_risk_reduction || 0),
    roiConfidence: totals.roiConfidence + Number(recommendation.roi_confidence_score || 0),
    roiCount: totals.roiCount + (recommendation.roi_confidence_score ? 1 : 0)
  }), { value: 0, time: 0, cost: 0, revenue: 0, risk: 0, roiConfidence: 0, roiCount: 0 });
  const progressInsights = safeProgressMemory.progress_insights || safeProgressMemory.insights || [];
  const progressSummary = {
    improved: progressInsights.filter((item) => item.insight_type === "improved").length,
    worsened: progressInsights.filter((item) => item.insight_type === "worsened").length,
    recurring: progressInsights.filter((item) => item.insight_type === "recurring_issue").length,
    resolved: progressInsights.filter((item) => item.insight_type === "resolved_issue").length,
    valueRealized: progressInsights.filter((item) => item.insight_type === "value_realized" || item.insight_type === "completed_recommendation").length
  };
  const heatmapCallbacks = {};
  if (onFilterChange) {
    heatmapCallbacks.onDomainFilterChange = (value) => onFilterChange("heatmapDomain", value);
    heatmapCallbacks.onGroupFilterChange = (value) => onFilterChange("heatmapGroup", value);
    heatmapCallbacks.onMinPriorityChange = (value) => onFilterChange("heatmapMinPriority", value);
    heatmapCallbacks.onMisalignmentToggle = (value) => onFilterChange("onlyMisalignment", value);
    heatmapCallbacks.onHighConfidenceToggle = (value) => onFilterChange("onlyHighConfidence", value);
  }
  if (onHeatmapCellSelect) heatmapCallbacks.onCellSelect = (key) => onHeatmapCellSelect(key);
  if (onSelectFinding) heatmapCallbacks.onSelectFinding = (findingId) => onSelectFinding(findingId);
  const alignmentSection = renderAlignmentHeatmapComponent(findings, filterState, emptyStateHtml, heatmapCallbacks);
  const progressSection = renderProgressMemorySectionComponent(safeProgressMemory, emptyStateHtml, false, {});
  return `
    <section class="owner-command-header">
      <div class="owner-command-copy">
        <span class="eyebrow">Owner Command Center</span>
        <h2>${escapeHtml(companyName)}</h2>
        <p>${escapeHtml(executiveSummary)}</p>
        <div class="owner-command-meta">
          <span>Assessment: ${escapeHtml(assessmentName)}</span>
          <span>Status: ${escapeHtml(assessment?.status || organization?.status || "active")}</span>
          <span>Confidence ${escapeHtml(confidenceScore)}/100</span>
          <span>Completeness ${escapeHtml(completenessScore)}/100</span>
          <span>Updated ${new Date(lastUpdated).toLocaleDateString()}</span>
        </div>
      </div>
      ${onViewReport ? '<div class="owner-command-actions"><button class="primary-button" data-component-view-report type="button">View Executive Report</button></div>' : ""}
    </section>
    <section class="owner-section owner-decision-snapshot">
      <div class="owner-section-head"><div><span class="eyebrow">Decision Snapshot</span><h3>The six signals that matter now</h3></div><small>Calculated from approved findings, approved recommendations, evidence, KPI gaps, and roadmap items.</small></div>
      <div class="owner-decision-grid">
        ${[["Business Health", `${snapshot.businessHealthScore}/100`, "Calculated health signal"], ["Assessment Confidence", `${confidenceScore}/100`, "Coverage and evidence quality"], ["Findings Approved", findings.length, "Rejected and draft findings excluded"], ["Estimated Annual Value", formatEstimatedValue(valueTotals.value), "Directional estimate"], ["Critical Risks", snapshot.criticalIssues, "High-priority approved risks"], ["Recommendations Ready", recommendations.length, "Approved action candidates"]]
          .map(([label, value, detail]) => `<article class="owner-metric-card"><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong><small>${escapeHtml(detail)}</small></article>`).join("")}
      </div>
    </section>
    <section class="owner-section owner-attention-section">
      <div class="owner-section-head"><div><span class="eyebrow">What Needs Attention First</span><h3>Top priority issues</h3></div><small>Showing the top three approved findings only.</small></div>
      <div class="owner-priority-grid">
        ${topIssues.length ? topIssues.map((finding) => `
          <article class="owner-issue-card ${String(finding.id) === String(selectedId) ? "active" : ""}">
            <div class="owner-card-topline"><span>${ownerDomainLabel(finding.business_domain)}</span><strong>${ownerPriorityLabel(finding)}</strong></div>
            <h4>${escapeHtml(finding.title)}</h4>
            <p>${escapeHtml(finding.description || "Approved evidence indicates this issue is affecting performance, visibility, or risk.")}</p>
            <div class="owner-signal-row"><span>Confidence ${escapeHtml(finding.confidence ?? 0)}/5</span><span>Agreement ${escapeHtml(finding.overall_stakeholder_agreement_score || finding.stakeholder_agreement_score || 1)}/5</span><span>Evidence ${escapeHtml(finding.evidence_count ?? 0)}</span></div>
            <div class="owner-chip-row">${(finding.problem_types || []).slice(0, 3).map((type) => `<span>${formatProblemType(type)}</span>`).join("")}</div>
            ${onSelectFinding ? `<button class="ghost-button" data-component-select-finding="${escapeHtml(finding.id)}" type="button">View Evidence</button>` : ""}
          </article>
        `).join("") : renderScreenState("owner-dashboard", "empty", { title: "Assessment findings will appear here after stakeholder responses are analyzed and approved.", compact: true })}
      </div>
    </section>
    <div class="owner-two-column">
      <section class="owner-section owner-opportunities-section">
        <div class="owner-section-head"><div><span class="eyebrow">Top Opportunities</span><h3>Highest value recommendations</h3></div><small>Approved recommendations ranked by estimated value and priority.</small></div>
        <div class="owner-opportunity-strip">${topOpportunities.length ? topOpportunities.map((recommendation) => {
          const finding = findings.find((item) => String(item.id) === String(recommendation.finding_id));
          return `<article class="owner-opportunity-card"><span>${formatEstimatedValue(recommendation.estimated_business_value)}</span><h4>${escapeHtml(recommendation.title)}</h4><p>${escapeHtml(recommendation.expected_operational_benefit || recommendation.expected_benefit || recommendation.description || "Approved recommendation ready for owner review.")}</p><div class="owner-signal-row"><span>Owner ${escapeHtml(recommendation.recommended_owner || "TBD")}</span><span>${escapeHtml(recommendation.recommended_timeline || recommendation.estimated_timeline || "Timeline TBD")}</span><span>Confidence ${escapeHtml(recommendation.recommendation_confidence_score ?? 3)}/5</span></div><small>Related finding: ${escapeHtml(finding?.title || "Approved finding")}</small>${onNavigate ? '<button class="ghost-button" data-component-navigate="recommendations" type="button">Review Recommendation</button>' : ""}</article>`;
        }).join("") : renderScreenState("owner-dashboard", "empty", { title: "Approved recommendations will appear here after findings are reviewed.", compact: true })}</div>
      </section>
      <section class="owner-section owner-alignment-simple"><div class="owner-section-head"><div><span class="eyebrow">Organizational Alignment</span><h3>Agreement and misalignment</h3></div></div><div class="owner-alignment-lists"><div><h4>Top agreement</h4>${agreementFindings.slice(0, 3).map((finding) => `<span class="owner-mini-row"><strong>${escapeHtml(finding.title)}</strong><span>${escapeHtml(getFindingSupportingGroupLabels(finding).join(", ") || "Single group")}</span></span>`).join("") || "<p>No approved cross-stakeholder agreement yet.</p>"}</div><div><h4>Top misalignment</h4>${misalignmentFindings.slice(0, 3).map((finding) => `<span class="owner-mini-row warning"><strong>${escapeHtml(finding.title)}</strong><span>${ownerDomainLabel(finding.business_domain)}</span></span>`).join("") || "<p>No approved contradictions detected yet.</p>"}</div></div></section>
    </div>
    <section class="owner-section owner-kpi-radar"><div class="owner-section-head"><div><span class="eyebrow">Missing KPI Radar</span><h3>Measurements the business should not fly without</h3></div><small>Highest-priority KPI gaps generated from approved findings and Organization Profile.</small></div><div class="owner-kpi-radar-grid">${highestPriorityKpis.length ? highestPriorityKpis.map((finding) => `<span class="owner-kpi-radar-item"><span>${ownerDomainLabel(finding.business_domain)}</span><strong>${escapeHtml(String(finding.title || "").replace(/ not measured/ig, "").replace(/missing /ig, ""))}</strong><p>${escapeHtml(finding.description || "This missing KPI limits management visibility.")}</p><small>Capture: ${escapeHtml(captureMethodForKpi(finding))}</small><small>Roadmap: ${escapeHtml(finding.roadmap_relevance || "foundation")}</small></span>`).join("") : renderScreenState("owner-dashboard", "empty", { title: "No critical KPI gaps detected yet.", compact: true })}</div></section>
    ${alignmentSection}
    <section class="owner-section owner-roadmap-preview"><div class="owner-section-head"><div><span class="eyebrow">Roadmap Preview</span><h3>Sequence, not a wish list</h3></div>${onNavigate ? '<button class="ghost-button" data-component-navigate="roadmap" type="button">Open Roadmap</button>' : ""}</div><div class="owner-roadmap-phases">${roadmapPreview.map((group) => `<article><div><span>${group.phase}</span><strong>${group.items.length}</strong></div>${group.topItem ? `<h4>${escapeHtml(group.topItem.title)}</h4><p>${escapeHtml(group.topItem.theme || group.topItem.description || "Approved roadmap item")}</p><small>Priority ${Math.round(Number(group.topItem.priority_score || 0))} · ${escapeHtml(group.topItem.estimated_timeline || "Timeline TBD")}</small>` : "<p>No approved items yet.</p>"}</article>`).join("")}</div></section>
    <section class="owner-section owner-value-summary"><div class="owner-section-head"><div><span class="eyebrow">Value & ROI Summary</span><h3>Estimated value at stake</h3></div><small>Estimates are directional and should be validated during implementation planning.</small></div><div class="owner-value-grid">${[["Estimated Annual Value", formatEstimatedValue(valueTotals.value)], ["Time Savings", formatAnnualHours(valueTotals.time)], ["Cost Savings", formatEstimatedValue(valueTotals.cost)], ["Revenue Opportunity", formatEstimatedValue(valueTotals.revenue)], ["Risk Reduction", formatEstimatedValue(valueTotals.risk)], ["ROI Confidence", `${valueTotals.roiCount ? Math.round((valueTotals.roiConfidence / valueTotals.roiCount) * 10) / 10 : 0}/5`]].map(([label, value]) => `<article><span>${escapeHtml(label)}</span><strong>${escapeHtml(value)}</strong></article>`).join("")}</div></section>
    ${progressSection}
    <div class="owner-two-column">
      <section class="owner-section owner-evidence-drawer" id="owner-evidence-drawer"><div class="owner-section-head"><div><span class="eyebrow">Evidence-Backed Insight</span><h3>${selectedFinding ? escapeHtml(selectedFinding.title) : "Select a finding"}</h3></div></div>${selectedFinding ? `<div class="owner-insight-panel"><p>${escapeHtml(selectedFinding.description || "")}</p><div class="owner-problem-meta"><span>Evidence ${escapeHtml(selectedFinding.evidence_count ?? 0)}</span><span>Confidence ${escapeHtml(selectedFinding.confidence ?? "-")}/5</span><span>Overall Agreement ${escapeHtml(selectedFinding.overall_stakeholder_agreement_score || selectedFinding.stakeholder_agreement_score || 1)}/5</span></div><p><strong>Supporting groups:</strong> ${escapeHtml(getFindingSupportingGroupLabels(selectedFinding).join(", ") || "None yet")}</p><p><strong>Supporting roles:</strong> ${escapeHtml(getFindingSupportingRoleLabels(selectedFinding).join(", ") || "None yet")}</p><div class="evidence-list">${selectedEvidence.length ? selectedEvidence.map((item) => `<article class="evidence-card"><span>${escapeHtml(item.evidence_type || "Evidence")} · ${escapeHtml(item.stakeholder_group_name || formatStakeholderId(item.stakeholder_group_id) || "Group")} / ${escapeHtml(item.stakeholder_role_name || item.stakeholder_role || formatStakeholderId(item.stakeholder_role_id) || "Role")}</span><strong>${escapeHtml(item.source_question || "KPI / company model")}</strong><p>${escapeHtml(item.source_response || item.description || "")}</p><small>Trigger rule: ${escapeHtml(item.trigger_rule || selectedFinding.trigger_rule || "rule_based_analysis")}</small></article>`).join("") : "<p>No evidence records found for this finding.</p>"}</div></div>` : renderScreenState("owner-dashboard", "empty", { title: "Select a top problem to inspect its evidence.", compact: true })}</section>
      <section class="owner-section owner-next-action-panel"><div class="owner-section-head"><div><span class="eyebrow">Next Best Action</span><h3>One move to make next</h3></div></div>${topOpportunities[0] ? `<article class="owner-next-action-card"><h4>${escapeHtml(topOpportunities[0].title)}</h4><p>${escapeHtml(topOpportunities[0].expected_operational_benefit || topOpportunities[0].description || "Review this recommendation first because it combines value, confidence, and feasible implementation.")}</p><strong>${formatEstimatedValue(topOpportunities[0].estimated_business_value)}</strong>${onNavigate ? '<button class="primary-button" data-component-navigate="recommendations" type="button">Review Top Recommendation</button>' : ""}</article>` : renderScreenState("owner-dashboard", "empty", { title: "Approve recommendations to reveal the next best action.", compact: true })}</section>
    </div>
  `;
}
