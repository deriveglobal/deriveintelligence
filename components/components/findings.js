import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

function formatProblemType(problemType) {
  return String(problemType || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function getFindingSupportingRoleLabels(finding = {}) {
  return finding.supporting_stakeholder_role_names ||
    finding.supporting_stakeholder_roles ||
    (finding.stakeholder_role_name ? [finding.stakeholder_role_name] : []);
}

function getFindingSupportingGroupLabels(finding = {}) {
  return finding.supporting_stakeholder_group_names ||
    finding.supporting_stakeholder_groups ||
    (finding.stakeholder_group_name ? [finding.stakeholder_group_name] : []);
}

function renderFindingActionButton(label, action, findingId, callback) {
  return callback
    ? `<button data-component-finding-action="${action}" data-finding-id="${escapeHtml(findingId)}" type="button">${escapeHtml(label)}</button>`
    : "";
}

export function renderFindingsWorkbenchComponent(
  findings = [],
  recommendationsByFindingId = {},
  selectedFindingId = "",
  emptyStateHtml = "",
  {
    onSelectFinding,
    onApprove,
    onReject,
    onEdit,
    onNotes,
    onMergeSelected
  } = {}
) {
  if (!findings.length) {
    return emptyStateHtml || renderScreenState("findings", "empty");
  }
  const selectedId = selectedFindingId || String(findings[0]?.id || "");
  const mergeColumn = Boolean(onMergeSelected);
  return `
    <div class="findings-toolbar">
      <span>${findings.length} generated findings</span>
      ${onMergeSelected ? `<button class="ghost-button" data-component-merge-selected-findings type="button">Merge Selected Into Active</button>` : ""}
    </div>
    <div class="table-wrap compact-table findings-table-wrap">
      <table class="findings-table">
        <thead>
          <tr>
            ${mergeColumn ? "<th></th>" : ""}
            <th>Finding</th>
            <th>Domain</th>
            <th>Category</th>
            <th>Problem Types</th>
            <th>Severity</th>
            <th>Frequency</th>
            <th>Confidence</th>
            <th>Supporting Roles</th>
            <th>Supporting Groups</th>
            <th>Agreement</th>
            <th>Misalignment</th>
            <th>Evidence</th>
            <th>Priority</th>
            <th>Recommendation</th>
            <th>Phase</th>
            <th>Status</th>
            ${onApprove || onReject || onEdit || onNotes ? "<th>Actions</th>" : ""}
          </tr>
        </thead>
        <tbody>
          ${findings.map((finding) => {
            const recommendation = recommendationsByFindingId[String(finding.id)] || recommendationsByFindingId[finding.id];
            const isSelected = String(finding.id) === String(selectedId);
            return `
              <tr class="${isSelected ? "active-row" : ""}">
                ${mergeColumn ? `<td><input type="checkbox" data-component-merge-finding="${escapeHtml(finding.id)}" ${isSelected ? "disabled" : ""} /></td>` : ""}
                <td>${onSelectFinding ? `<button class="text-button" data-component-select-finding="${escapeHtml(finding.id)}" type="button">${escapeHtml(finding.title)}</button>` : escapeHtml(finding.title)}${finding.analyst_notes ? `<small>${escapeHtml(finding.analyst_notes)}</small>` : ""}</td>
                <td>${escapeHtml(finding.business_domain || "-")}</td>
                <td>${escapeHtml(finding.assessment_category || "-")}</td>
                <td>${(finding.problem_types || []).map((type) => `<span class="mini-chip">${escapeHtml(formatProblemType(type))}</span>`).join("")}</td>
                <td>${escapeHtml(finding.severity ?? "-")}</td>
                <td>${escapeHtml(finding.frequency ?? "-")}</td>
                <td><strong>${escapeHtml(finding.confidence ?? "-")}/5</strong></td>
                <td>${getFindingSupportingRoleLabels(finding).map((role) => `<span class="mini-chip">${escapeHtml(role)}</span>`).join("") || "-"}</td>
                <td>${getFindingSupportingGroupLabels(finding).map((group) => `<span class="mini-chip">${escapeHtml(group)}</span>`).join("") || "-"}</td>
                <td><strong>${escapeHtml(finding.overall_stakeholder_agreement_score || finding.stakeholder_agreement_score || 1)}/5</strong><small>Role ${escapeHtml(finding.stakeholder_role_agreement_score || 1)}/5 · Group ${escapeHtml(finding.stakeholder_group_agreement_score || 1)}/5</small></td>
                <td>${finding.contradiction_detected ? `<span class="status-pill rejected">Flagged</span>` : `<span class="status-pill approved">Clear</span>`}</td>
                <td>${escapeHtml(finding.evidence_count ?? 0)}</td>
                <td>${Math.round(Number(finding.priority_score || 0))}</td>
                <td>${escapeHtml(recommendation?.title || "-")}</td>
                <td>${escapeHtml(recommendation?.roadmap_phase || "-")}</td>
                <td><span class="status-pill ${statusClass(finding.status)}">${escapeHtml(finding.status || "Draft")}</span></td>
                ${onApprove || onReject || onEdit || onNotes ? `
                  <td>
                    <div class="row-actions">
                      ${renderFindingActionButton("Approve", "approve", finding.id, onApprove)}
                      ${renderFindingActionButton("Reject", "reject", finding.id, onReject)}
                      ${renderFindingActionButton("Edit", "edit", finding.id, onEdit)}
                      ${renderFindingActionButton("Notes", "notes", finding.id, onNotes)}
                    </div>
                  </td>
                ` : ""}
              </tr>
            `;
          }).join("")}
        </tbody>
      </table>
    </div>
  `;
}

function formatStakeholderId(value = "") {
  return String(value || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

export function renderEvidenceExplorerComponent(
  findings = [],
  evidence = [],
  selectedFindingId = "",
  emptyStateHtml = "",
  { onSelectFinding } = {}
) {
  const finding = (findings || []).find((item) => String(item.id) === String(selectedFindingId));
  const selectedEvidence = (evidence || []).filter((item) => String(item.finding_id) === String(selectedFindingId));
  if (!finding) {
    return emptyStateHtml || renderScreenState("evidence", "empty", { compact: true });
  }
  return `
    <div class="evidence-head">
      <div>
        <h3>${escapeHtml(finding.title)}</h3>
        <span>${escapeHtml(finding.trigger_rule || "rule_based_analysis")}</span>
      </div>
      <div class="evidence-score-stack">
        <strong>Confidence ${escapeHtml(finding.confidence ?? "-")}/5</strong>
        <span>Agreement ${escapeHtml(finding.stakeholder_agreement_score || 1)}/5</span>
        ${finding.contradiction_detected ? `<span class="misalignment-flag">Misalignment flagged</span>` : ""}
      </div>
    </div>
    ${finding.contradiction_detected ? `
      <article class="contradiction-card">
        <strong>Cross-level misalignment detected</strong>
        <p>Groups: ${escapeHtml((finding.contradiction_details?.stakeholder_group_names || []).join(", ") || "Multiple stakeholder groups")}.</p>
        <p>Roles: ${escapeHtml((finding.contradiction_details?.stakeholder_role_names || finding.contradiction_details?.stakeholders_involved || []).join(", ") || "Multiple stakeholders")} have conflicting views in ${escapeHtml(finding.business_domain || "this domain")}.</p>
        ${(finding.contradiction_details?.conflicting_responses || []).map((item) => `
          <small>${escapeHtml(item.stakeholder_group_name || formatStakeholderId(item.stakeholder_group_id) || "Group")} / ${escapeHtml(item.stakeholder_role_name || item.stakeholder_role || "Stakeholder")} (${escapeHtml(item.sentiment || "")}): ${escapeHtml(item.response || "")}</small>
        `).join("")}
      </article>
    ` : ""}
    <div class="evidence-list">
      ${selectedEvidence.map((item) => `
        <article class="evidence-card">
          <span>${escapeHtml(item.evidence_type || "Evidence")} · ${escapeHtml(item.stakeholder_group_name || formatStakeholderId(item.stakeholder_group_id) || "Group")} / ${escapeHtml(item.stakeholder_role_name || item.stakeholder_role || "Layer 1 / System")}</span>
          <strong>${escapeHtml(item.source_question || "Company profile / KPI model")}</strong>
          <p>${escapeHtml(item.source_response || item.description || "")}</p>
          <small>Trigger rule: ${escapeHtml(item.trigger_rule || finding.trigger_rule || "rule_based_analysis")}</small>
        </article>
      `).join("") || renderScreenState("evidence", "warning", {
        title: "No evidence records found for this finding",
        message: "This finding should be checked before approval because every major insight must be traceable to source responses.",
        compact: true
      })}
    </div>
  `;
}

export function renderFindingClustersComponent(
  clusters = [],
  emptyStateHtml = "",
  { onMergeCluster } = {}
) {
  return clusters?.length
    ? clusters.map((cluster, index) => `
      <article class="cluster-card">
        <div>
          <span>Parent Finding</span>
          <h3>${escapeHtml(cluster.title)}</h3>
          <p>${(cluster.childFindings || []).map((finding) => escapeHtml(finding.title)).join(" · ")}</p>
          ${onMergeCluster ? `<button class="ghost-button" data-component-merge-cluster="${index}" type="button">Merge Cluster</button>` : ""}
        </div>
        <div class="cluster-stats">
          <strong>${(cluster.childFindings || []).length}</strong><span>child findings</span>
          <strong>${escapeHtml(cluster.evidenceCount ?? 0)}</strong><span>evidence</span>
          <strong>${escapeHtml(cluster.confidence ?? "-")}/5</strong><span>confidence</span>
        </div>
      </article>
    `).join("")
    : (emptyStateHtml || renderScreenState("findings", "empty", {
      title: "No clusters detected yet",
      message: "When related findings appear, they will be grouped here for analyst review.",
      compact: true
    }));
}
