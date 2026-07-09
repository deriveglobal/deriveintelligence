import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml
  , statusClass
} from '../shared.js';

function formatProblemType(problemType) {
  return String(problemType || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function ownerDomainLabel(domain = "") {
  const labels = {
    service_delivery: "Service Delivery",
    field_operations: "Field Operations",
    inventory_management: "Inventory Management",
    reporting_analytics: "Reporting & Analytics",
    data_management: "Data Management",
    technology: "Technology",
    workforce: "Workforce",
    customer_experience: "Customer Experience",
    risk_management: "Risk Management",
    finance: "Finance",
    branch_operations: "Branch Operations",
    warehouse_operations: "Warehouse Operations",
    automation: "Automation"
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

function signedNumber(value) {
  const number = Number(value || 0);
  return `${number > 0 ? '+' : ''}${number}`;
}

function progressInsightList(title, items, emptyText) {
  return '<article><h4>' + title + '</h4>' + (items.length
    ? items.map((item) => '<div><strong>' + escapeHtml(item.title) + '</strong><span>' + escapeHtml(ownerDomainLabel(item.business_domain || item.change_direction || item.insight_type)) + '</span><small>' + escapeHtml(item.description || '') + '</small></div>').join('')
    : '<p>' + emptyText + '</p>') + '</article>';
}

export function renderReportProgressMemory(progressMemory = {}) {
  const latest = progressMemory.latest_snapshot;
  if (!latest) return '<p>No progress snapshot has been generated yet.</p>';
  if (!progressMemory.previous_snapshot) {
    return '<article class="report-callout"><h3>Baseline assessment</h3><p>This is the baseline assessment. Future assessments will compare progress against this baseline.</p></article>';
  }
  const insights = progressMemory.progress_insights || [];
  const group = (types) => insights.filter((item) => types.includes(item.insight_type)).slice(0, 6);
  return '<div class="report-scorecards">' +
      '<article><span>Business Health Change</span><strong>' + signedNumber(progressMemory.summary?.business_health_change || 0) + '</strong></article>' +
      '<article><span>Digital Maturity Change</span><strong>' + signedNumber(progressMemory.summary?.digital_maturity_change || 0) + '</strong></article>' +
      '<article><span>Actual Value Realized</span><strong>' + formatEstimatedValue(latest.total_actual_value || 0) + '</strong></article>' +
      '<article><span>Recommendation Accuracy</span><strong>' + (latest.average_recommendation_accuracy === null || latest.average_recommendation_accuracy === undefined ? 'Pending' : Math.round(Number(latest.average_recommendation_accuracy)) + '%') + '</strong></article>' +
    '</div><div class="report-two-column">' +
      progressInsightList('Improved Areas', group(['improved', 'risk_reduced', 'kpi_now_measured', 'kpi_gap_reduced']), 'No improvements detected yet.') +
      progressInsightList('Worsened Areas', group(['worsened', 'risk_increased', 'kpi_gap_increased', 'new_issue']), 'No worsened areas detected.') +
      progressInsightList('Recurring Issues', group(['recurring_issue']), 'No recurring issues detected.') +
      progressInsightList('Value Realized', group(['value_realized', 'completed_recommendation']), 'No completed value records yet.') +
    '</div>';
}

export function renderProgressMemorySectionComponent(
  progressMemory = {},
  emptyStateHtml = "",
  showActions = false,
  { onGenerateSnapshot, onRegenerateSnapshot } = {}
) {
  const latest = progressMemory.latest_snapshot;
  const previous = progressMemory.previous_snapshot;
  const insights = progressMemory.progress_insights || [];
  const improved = insights.filter((item) => ["improved", "risk_reduced", "kpi_now_measured", "kpi_gap_reduced"].includes(item.insight_type)).slice(0, 5);
  const worsened = insights.filter((item) => ["worsened", "risk_increased", "kpi_gap_increased", "new_issue"].includes(item.insight_type)).slice(0, 5);
  const recurring = insights.filter((item) => item.insight_type === "recurring_issue").slice(0, 5);
  const value = insights.filter((item) => ["value_realized", "completed_recommendation"].includes(item.insight_type)).slice(0, 5);
  const baseline = !previous;
  const fallbackEmpty = emptyStateHtml || renderScreenState("progress", "empty", {
    title: "No progress snapshot yet",
    message: "Generate a progress snapshot after an assessment to establish organizational memory.",
    compact: true
  });
  const actions = showActions
    ? '<div class="meeting-actions">' +
        (onGenerateSnapshot ? '<button class="ghost-button" data-progress-action="generate" type="button">Generate Progress Snapshot</button>' : '') +
        (onRegenerateSnapshot ? '<button class="ghost-button" data-progress-action="regenerate" type="button">Regenerate Progress Snapshot</button>' : '') +
      '</div>'
    : '';
  return '<section class="owner-section owner-progress-memory">' +
    '<div class="owner-section-head"><div><span class="eyebrow">Progress Since Last Assessment</span><h3>Organizational memory</h3></div><small>Tracks what improved, worsened, repeated, disappeared, and created actual value.</small></div>' +
    (latest ? (
      '<div class="owner-snapshot-grid">' +
        '<article><span>Business Health Change</span><strong>' + (baseline ? 'Baseline' : signedNumber(progressMemory.summary?.business_health_change || 0)) + '</strong></article>' +
        '<article><span>Digital Maturity Change</span><strong>' + (baseline ? 'Baseline' : signedNumber(progressMemory.summary?.digital_maturity_change || 0)) + '</strong></article>' +
        '<article><span>Critical Findings Change</span><strong>' + (baseline ? 'Baseline' : signedNumber(progressMemory.summary?.critical_findings_change || 0)) + '</strong></article>' +
        '<article><span>Recommendations Completed</span><strong>' + (latest.completed_recommendations_count || 0) + '</strong></article>' +
        '<article><span>Actual Value Realized</span><strong>' + formatEstimatedValue(latest.total_actual_value || 0) + '</strong></article>' +
        '<article><span>Recommendation Accuracy</span><strong>' + (latest.average_recommendation_accuracy === null || latest.average_recommendation_accuracy === undefined ? 'Pending' : Math.round(Number(latest.average_recommendation_accuracy)) + '%') + '</strong></article>' +
      '</div>' +
      (baseline ? '<article class="engine-empty"><strong>Baseline assessment</strong><p>This is the baseline assessment. Future assessments will compare progress against this snapshot.</p></article>' : '') +
      '<div class="owner-progress-grid">' +
        progressInsightList('What Improved', improved, 'No improvements detected yet.') +
        progressInsightList('What Got Worse', worsened, 'No worsened areas detected.') +
        progressInsightList('Recurring Issues', recurring, 'No recurring issues detected yet.') +
        progressInsightList('Value Realized', value, 'No completed value records yet.') +
      '</div>'
    ) : fallbackEmpty) +
    actions +
  '</section>';
}
