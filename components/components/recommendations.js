import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

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

function renderRecommendationActionButton(label, action, recommendationId, callback) {
  return callback
    ? `<button class="ghost-button" data-component-rec-action="${action}" data-rec-id="${escapeHtml(recommendationId)}" type="button">${escapeHtml(label)}</button>`
    : "";
}

export function renderRecommendationsComponent(
  recommendations = [],
  showReportCta = false,
  emptyStateHtml = "",
  {
    onViewReport,
    onApprove,
    onAccept,
    onInProgress,
    onComplete,
    onReject,
    onTrackOutcome,
    onNotes
  } = {}
) {
  const reportCta = showReportCta
    ? `<article class="owner-report-cta recommendation-report-cta"><div><span class="eyebrow">Executive Report</span><h3>Ready for owner review?</h3><p>Open the formal report after recommendations are approved.</p></div>${onViewReport ? `<button class="primary-button" data-component-view-executive-report type="button">View Executive Report</button>` : ""}</article>`
    : "";
  return reportCta + (recommendations.length
    ? recommendations
        .map((item) => `
          <article class="recommendation-card">
            <span class="eyebrow">${escapeHtml(item.recommendation_type || "Recommendation")} · <span class="status-pill ${statusClass(item.status)}">${escapeHtml(item.status || "Draft")}</span></span>
            <h3>${escapeHtml(item.title)}</h3>
            <p>${escapeHtml(item.expected_benefit || item.description || item.recommended_action || "")}</p>
            ${item.why_recommendation_exists ? `<p class="muted-text">${escapeHtml(item.why_recommendation_exists)}</p>` : ""}
            <div class="recommendation-meta">
              <span>Priority: <strong>${Math.round(Number(item.priority_score || 0))}</strong></span>
              <span>Phase: <strong>${escapeHtml(item.roadmap_phase || "-")}</strong></span>
              <span>Confidence: <strong>${escapeHtml(item.recommendation_confidence_score || 3)}/5</strong></span>
              <span>Specificity: <strong>${escapeHtml(item.recommendation_specificity_score || 3)}/5</strong></span>
            </div>
            <div class="recommendation-meta">
              <span>Impact: <strong>${escapeHtml(item.expected_impact || "TBD")}</strong></span>
              <span>Owner: <strong>${escapeHtml(item.recommended_owner || "To be assigned")}</strong></span>
            </div>
            <div class="recommendation-meta">
              <span>Estimated Value: <strong>${formatEstimatedValue(item.estimated_business_value)}</strong></span>
              <span>Time Savings: <strong>${formatAnnualHours(item.estimated_time_savings)}</strong></span>
              <span>ROI Confidence: <strong>${escapeHtml(item.roi_confidence_score || 2)}/5</strong></span>
            </div>
            <div class="recommendation-meta outcome-tracking-meta">
              <span>Expected Value: <strong>${formatEstimatedValue(item.expected_value || item.estimated_business_value)}</strong></span>
              <span>Actual Value: <strong>${item.actual_value === null || item.actual_value === undefined ? "Not measured" : formatEstimatedValue(item.actual_value)}</strong></span>
              <span>Expected Time: <strong>${formatAnnualHours(item.expected_time_savings || item.estimated_time_savings)}</strong></span>
              <span>Actual Time: <strong>${item.actual_time_savings === null || item.actual_time_savings === undefined ? "Not measured" : formatAnnualHours(item.actual_time_savings)}</strong></span>
              <span>Accuracy: <strong>${item.recommendation_accuracy_score === null || item.recommendation_accuracy_score === undefined ? "Pending" : Math.round(Number(item.recommendation_accuracy_score)) + "%"}</strong></span>
            </div>
            ${item.expected_outcome || item.actual_outcome ? `<div class="recommendation-outcome"><p><strong>Expected outcome:</strong> ${escapeHtml(item.expected_outcome || "Not defined")}</p><p><strong>Actual outcome:</strong> ${escapeHtml(item.actual_outcome || "Not measured yet")}</p></div>` : ""}
            ${onApprove || onAccept || onInProgress || onComplete || onReject || onTrackOutcome || onNotes ? `
              <div class="meeting-actions">
                ${renderRecommendationActionButton("Approve", "approve", item.id, onApprove)}
                ${renderRecommendationActionButton("Accept", "accept", item.id, onAccept)}
                ${renderRecommendationActionButton("In Progress", "progress", item.id, onInProgress)}
                ${renderRecommendationActionButton("Complete", "complete", item.id, onComplete)}
                ${renderRecommendationActionButton("Reject", "reject", item.id, onReject)}
                ${renderRecommendationActionButton("Track Outcome", "outcome", item.id, onTrackOutcome)}
                ${renderRecommendationActionButton("Notes", "notes", item.id, onNotes)}
              </div>
            ` : ""}
          </article>
        `)
        .join("")
    : (emptyStateHtml || renderScreenState("recommendations", "empty")));
}
