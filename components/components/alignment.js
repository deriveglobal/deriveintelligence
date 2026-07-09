import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

const ownerHeatmapStakeholderGroups = [
  ["executive", "Executive"],
  ["management", "Management"],
  ["operations", "Operations"],
  ["support_functions", "Support Functions"],
  ["commercial", "Commercial"],
  ["customer", "Customer"],
  ["partner", "Partner"]
];

const ownerHeatmapBusinessDomains = [
  ["strategy", "Strategy"],
  ["governance", "Governance"],
  ["sales", "Sales"],
  ["customer_experience", "Customer Experience"],
  ["service_delivery", "Service Delivery"],
  ["field_operations", "Field Operations"],
  ["fleet_operations", "Fleet Operations"],
  ["branch_operations", "Branch Operations"],
  ["inventory_management", "Inventory Management"],
  ["procurement", "Procurement"],
  ["logistics", "Logistics"],
  ["warehouse_operations", "Warehouse Operations"],
  ["finance", "Finance"],
  ["profitability", "Profitability"],
  ["data_management", "Data Management"],
  ["reporting_analytics", "Reporting & Analytics"],
  ["technology", "Technology"],
  ["automation", "Automation"],
  ["workforce", "Workforce"],
  ["change_management", "Change Management"],
  ["compliance", "Compliance"],
  ["risk_management", "Risk Management"],
  ["innovation", "Innovation"]
];

function formatStakeholderId(value = "") {
  return String(value || "")
    .replace(/_/g, " ")
    .replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function uniqueClientValues(values = []) {
  return [...new Set(values.filter(Boolean).map((value) => String(value)))];
}

function getFindingSupportingGroupIds(finding = {}) {
  return Array.isArray(finding.supporting_stakeholder_groups) ? finding.supporting_stakeholder_groups : [];
}

function heatmapFindingGroups(finding = {}) {
  return uniqueClientValues([
    ...getFindingSupportingGroupIds(finding),
    finding.stakeholder_group_id
  ]);
}

function heatmapContradictionGroups(finding = {}) {
  return uniqueClientValues([
    ...((finding.contradiction_details?.stakeholder_group_ids || [])),
    ...(finding.contradiction_details?.conflicting_responses || []).map((item) => item.stakeholder_group_id)
  ]);
}

function heatmapCellKey(domainId, groupId) {
  return `${domainId}::${groupId}`;
}

function heatmapCellStatus({ findingCount = 0, averagePriority = 0, contradictionCount = 0, crossLevelMisalignment = false } = {}) {
  if (!findingCount && !contradictionCount) return "gray";
  if (averagePriority >= 75 || contradictionCount >= 2 || crossLevelMisalignment) return "red";
  if ((averagePriority >= 50 && averagePriority <= 74) || contradictionCount === 1) return "yellow";
  return "green";
}

function evidenceFromFinding(finding = {}) {
  return finding.evidence || finding.evidence_items || finding.evidence_reference?.snippets || [];
}

function buildOrganizationalAlignmentHeatmap(findings = [], selectedHeatmapCellKey = "") {
  const cells = new Map();
  ownerHeatmapBusinessDomains.forEach(([domainId, domainLabel]) => {
    ownerHeatmapStakeholderGroups.forEach(([groupId, groupLabel]) => {
      cells.set(heatmapCellKey(domainId, groupId), {
        key: heatmapCellKey(domainId, groupId),
        domainId,
        domainLabel,
        groupId,
        groupLabel,
        findings: [],
        contradictionFindings: []
      });
    });
  });

  findings.forEach((finding) => {
    const domainId = finding.business_domain || "unclassified";
    heatmapFindingGroups(finding).forEach((groupId) => {
      const key = heatmapCellKey(domainId, groupId);
      if (cells.has(key)) cells.get(key).findings.push(finding);
    });
    if (finding.contradiction_detected) {
      heatmapContradictionGroups(finding).forEach((groupId) => {
        const key = heatmapCellKey(domainId, groupId);
        if (cells.has(key)) cells.get(key).contradictionFindings.push(finding);
      });
    }
  });

  const rows = ownerHeatmapBusinessDomains.map(([domainId, domainLabel]) => {
    const rowCells = ownerHeatmapStakeholderGroups.map(([groupId]) => {
      const cell = cells.get(heatmapCellKey(domainId, groupId));
      const findingCount = cell.findings.length;
      const contradictionCount = uniqueClientValues(cell.contradictionFindings.map((finding) => finding.id)).length;
      const crossLevelMisalignment = cell.contradictionFindings.some((finding) => heatmapContradictionGroups(finding).length >= 3);
      const averageConfidence = findingCount ? cell.findings.reduce((sum, finding) => sum + Number(finding.confidence || 0), 0) / findingCount : 0;
      const averagePriority = findingCount ? cell.findings.reduce((sum, finding) => sum + Number(finding.priority_score || 0), 0) / findingCount : 0;
      return {
        ...cell,
        findingCount,
        averageConfidence: Math.round(averageConfidence * 10) / 10,
        averagePriority: Math.round(averagePriority),
        contradictionCount,
        crossLevelMisalignment,
        status: heatmapCellStatus({ findingCount, averagePriority, contradictionCount, crossLevelMisalignment }),
        topFindings: [...cell.findings].sort((a, b) => Number(b.priority_score || 0) - Number(a.priority_score || 0)).slice(0, 3),
        topEvidence: cell.findings.flatMap((finding) => evidenceFromFinding(finding).slice(0, 2)).slice(0, 3)
      };
    });
    return { domainId, domainLabel, cells: rowCells };
  });

  const allCells = rows.flatMap((row) => row.cells);
  const activeCells = allCells.filter((cell) => cell.findingCount || cell.contradictionCount);
  const domainStats = ownerHeatmapBusinessDomains.map(([domainId, domainLabel]) => {
    const domainCells = allCells.filter((cell) => cell.domainId === domainId);
    const findingCount = domainCells.reduce((sum, cell) => sum + cell.findingCount, 0);
    const contradictionCount = domainCells.reduce((sum, cell) => sum + cell.contradictionCount, 0);
    const averagePriority = findingCount ? Math.round(domainCells.reduce((sum, cell) => sum + (cell.averagePriority * cell.findingCount), 0) / findingCount) : 0;
    const averageConfidence = findingCount ? Math.round((domainCells.reduce((sum, cell) => sum + (cell.averageConfidence * cell.findingCount), 0) / findingCount) * 10) / 10 : 0;
    const greenCells = domainCells.filter((cell) => cell.status === "green").length;
    const redCells = domainCells.filter((cell) => cell.status === "red").length;
    return { domainId, domainLabel, findingCount, contradictionCount, averagePriority, averageConfidence, greenCells, redCells };
  });
  const groupStats = ownerHeatmapStakeholderGroups.map(([groupId, groupLabel]) => {
    const groupCells = allCells.filter((cell) => cell.groupId === groupId);
    return {
      groupId,
      groupLabel,
      findingCount: groupCells.reduce((sum, cell) => sum + cell.findingCount, 0),
      contradictionCount: groupCells.reduce((sum, cell) => sum + cell.contradictionCount, 0)
    };
  });
  const selectedCell = allCells.find((cell) => cell.key === selectedHeatmapCellKey) || activeCells[0] || allCells[0];
  return {
    rows,
    allCells,
    selectedCell,
    summary: {
      mostAlignedDomain: [...domainStats].filter((item) => item.findingCount).sort((a, b) => b.greenCells - a.greenCells || b.averageConfidence - a.averageConfidence)[0] || null,
      mostMisalignedDomain: [...domainStats].filter((item) => item.contradictionCount || item.redCells).sort((a, b) => b.contradictionCount - a.contradictionCount || b.redCells - a.redCells || b.averagePriority - a.averagePriority)[0] || null,
      highestPriorityDomain: [...domainStats].filter((item) => item.findingCount).sort((a, b) => b.averagePriority - a.averagePriority)[0] || null,
      groupWithMostFindings: [...groupStats].filter((item) => item.findingCount).sort((a, b) => b.findingCount - a.findingCount)[0] || null,
      groupWithMostMisalignment: [...groupStats].filter((item) => item.contradictionCount).sort((a, b) => b.contradictionCount - a.contradictionCount)[0] || null,
      topAlignedAreas: activeCells.filter((cell) => cell.status === "green" || (cell.findingCount && !cell.contradictionCount && cell.averageConfidence >= 4)).sort((a, b) => b.averageConfidence - a.averageConfidence || b.findingCount - a.findingCount).slice(0, 3),
      topMisalignedAreas: activeCells.filter((cell) => cell.contradictionCount || cell.status === "red").sort((a, b) => b.contradictionCount - a.contradictionCount || b.averagePriority - a.averagePriority).slice(0, 3),
      topPriorityDomains: [...domainStats].filter((item) => item.findingCount).sort((a, b) => b.averagePriority - a.averagePriority).slice(0, 3)
    }
  };
}

function heatmapFilteredRows(heatmap, filterState = {}) {
  const minPriority = Number(filterState.heatmapMinPriority || 0);
  return heatmap.rows
    .filter((row) => !filterState.heatmapDomain || row.domainId === filterState.heatmapDomain)
    .map((row) => ({
      ...row,
      cells: row.cells.filter((cell) => {
        if (filterState.heatmapGroup && cell.groupId !== filterState.heatmapGroup) return false;
        if (minPriority && cell.averagePriority < minPriority) return false;
        if (filterState.onlyMisalignment && !cell.contradictionCount && cell.status !== "red") return false;
        if (filterState.onlyHighConfidence && cell.averageConfidence < 4) return false;
        return true;
      })
    }))
    .filter((row) => row.cells.length);
}

function heatmapSummaryCard(label, value, detail = "") {
  return `<article><span>${escapeHtml(label)}</span><strong>${escapeHtml(value || "No data")}</strong>${detail ? `<small>${escapeHtml(detail)}</small>` : ""}</article>`;
}

export function renderAlignmentHeatmapComponent(
  findings = [],
  filterState = {},
  emptyStateHtml = "",
  {
    onDomainFilterChange,
    onGroupFilterChange,
    onMinPriorityChange,
    onMisalignmentToggle,
    onHighConfidenceToggle,
    onCellSelect,
    onSelectFinding
  } = {}
) {
  const heatmap = buildOrganizationalAlignmentHeatmap(findings, filterState.selectedHeatmapCellKey);
  const rows = heatmapFilteredRows(heatmap, filterState);
  const selected = heatmap.selectedCell;
  const summary = heatmap.summary;
  const filterControls = [
    onDomainFilterChange ? '<label>Business Domain<select data-component-heatmap-filter="domain"><option value="">All Domains</option>' + ownerHeatmapBusinessDomains.map(([id, label]) => '<option value="' + id + '" ' + (filterState.heatmapDomain === id ? 'selected' : '') + '>' + label + '</option>').join('') + '</select></label>' : '',
    onGroupFilterChange ? '<label>Stakeholder Group<select data-component-heatmap-filter="group"><option value="">All Groups</option>' + ownerHeatmapStakeholderGroups.map(([id, label]) => '<option value="' + id + '" ' + (filterState.heatmapGroup === id ? 'selected' : '') + '>' + label + '</option>').join('') + '</select></label>' : '',
    onMinPriorityChange ? '<label>Minimum Priority<input data-component-heatmap-filter="min-priority" type="number" min="0" max="100" step="5" value="' + escapeHtml(filterState.heatmapMinPriority || "0") + '" /></label>' : '',
    onMisalignmentToggle ? '<label class="owner-heatmap-toggle"><input data-component-heatmap-filter="misalignment" type="checkbox" ' + (filterState.onlyMisalignment ? 'checked' : '') + ' /> Misalignment only</label>' : '',
    onHighConfidenceToggle ? '<label class="owner-heatmap-toggle"><input data-component-heatmap-filter="high-confidence" type="checkbox" ' + (filterState.onlyHighConfidence ? 'checked' : '') + ' /> High confidence only</label>' : ''
  ].join('');
  return '<section class="owner-section owner-alignment-section">' +
    '<div class="owner-section-head"><div><span class="eyebrow">Organizational Alignment Heatmap</span><h3>Where the organization agrees or disagrees</h3></div><small>See where leadership, management, operations, and support teams agree or disagree across the business.</small></div>' +
    '<div class="owner-alignment-summary">' +
      heatmapSummaryCard("Most Aligned Domain", summary.mostAlignedDomain?.domainLabel, summary.mostAlignedDomain ? `Confidence ${summary.mostAlignedDomain.averageConfidence}/5` : "") +
      heatmapSummaryCard("Most Misaligned Domain", summary.mostMisalignedDomain?.domainLabel, summary.mostMisalignedDomain ? `${summary.mostMisalignedDomain.contradictionCount} contradictions` : "") +
      heatmapSummaryCard("Highest Priority Domain", summary.highestPriorityDomain?.domainLabel, summary.highestPriorityDomain ? `Avg priority ${summary.highestPriorityDomain.averagePriority}` : "") +
      heatmapSummaryCard("Most Findings", summary.groupWithMostFindings?.groupLabel, summary.groupWithMostFindings ? `${summary.groupWithMostFindings.findingCount} findings` : "") +
      heatmapSummaryCard("Most Misalignment", summary.groupWithMostMisalignment?.groupLabel, summary.groupWithMostMisalignment ? `${summary.groupWithMostMisalignment.contradictionCount} contradictions` : "") +
    '</div>' +
    (filterControls ? '<div class="owner-heatmap-filters">' + filterControls + '</div>' : '') +
    '<div class="owner-heatmap-wrap"><table class="owner-heatmap-table"><thead><tr><th>Business Domain</th>' + ownerHeatmapStakeholderGroups.filter(([groupId]) => !filterState.heatmapGroup || filterState.heatmapGroup === groupId).map(([, label]) => '<th>' + label + '</th>').join('') + '</tr></thead><tbody>' +
      (rows.length ? rows.map((row) => '<tr><th>' + row.domainLabel + '</th>' + row.cells.map((cell) => {
        const title = `${cell.domainLabel} / ${cell.groupLabel}\nFindings: ${cell.findingCount}\nConfidence: ${cell.averageConfidence || 0}/5\nPriority: ${cell.averagePriority || 0}\nContradictions: ${cell.contradictionCount}`;
        const cellContent = '<strong>' + (cell.findingCount || cell.contradictionCount || '') + '</strong><span>' + (cell.averagePriority || '') + '</span>';
        return '<td>' + (onCellSelect
          ? '<button type="button" title="' + escapeHtml(title) + '" class="owner-heatmap-cell status-' + cell.status + ' ' + (selected?.key === cell.key ? 'selected' : '') + '" data-component-heatmap-cell="' + cell.key + '">' + cellContent + '</button>'
          : '<span title="' + escapeHtml(title) + '" class="owner-heatmap-cell status-' + cell.status + ' ' + (selected?.key === cell.key ? 'selected' : '') + '">' + cellContent + '</span>') + '</td>';
      }).join('') + '</tr>').join('') : '<tr><td colspan="8">No heatmap cells match the selected filters.</td></tr>') +
    '</tbody></table></div>' +
    '<div class="owner-heatmap-detail">' +
      (selected ? '<article><div><span class="eyebrow">Selected Cell</span><h4>' + selected.domainLabel + ' / ' + selected.groupLabel + '</h4></div><div class="owner-problem-meta"><span>Findings ' + selected.findingCount + '</span><span>Confidence ' + (selected.averageConfidence || 0) + '/5</span><span>Priority ' + (selected.averagePriority || 0) + '</span><span>Contradictions ' + selected.contradictionCount + '</span><strong>' + selected.status.toUpperCase() + '</strong></div>' +
        '<div class="owner-heatmap-detail-grid"><div><h5>Top Findings</h5>' + (selected.topFindings.length ? selected.topFindings.map((finding) => (onSelectFinding ? '<button type="button" data-component-select-finding="' + finding.id + '">' : '<span class="owner-mini-row">') + escapeHtml(finding.title) + '<span>Priority ' + Math.round(Number(finding.priority_score || 0)) + ' · Confidence ' + finding.confidence + '/5</span>' + (onSelectFinding ? '</button>' : '</span>')).join('') : '<p>No approved findings in this cell.</p>') + '</div>' +
        '<div><h5>Top Evidence Sources</h5>' + (selected.topEvidence.length ? selected.topEvidence.map((item) => '<article><strong>' + escapeHtml(item.source_question || item.evidence_type || 'Evidence') + '</strong><p>' + escapeHtml(item.source_response || item.description || '') + '</p><span>' + (item.stakeholder_group_name || formatStakeholderId(item.stakeholder_group_id) || selected.groupLabel) + ' / ' + (item.stakeholder_role_name || formatStakeholderId(item.stakeholder_role_id) || 'Role') + '</span></article>').join('') : '<p>No evidence records found for this cell.</p>') + '</div></div></article>' : (emptyStateHtml || renderScreenState("owner-dashboard", "empty", { title: "Heatmap details will appear after approved findings are available.", compact: true }))) +
    '</div>' +
    '<div class="owner-executive-alignment-preview">' +
      '<article><h4>Top 3 Aligned Areas</h4>' + (summary.topAlignedAreas.length ? summary.topAlignedAreas.map((cell) => '<span>' + cell.domainLabel + ' / ' + cell.groupLabel + ' · Confidence ' + cell.averageConfidence + '/5</span>').join('') : '<p>No aligned areas detected yet.</p>') + '</article>' +
      '<article><h4>Top 3 Misaligned Areas</h4>' + (summary.topMisalignedAreas.length ? summary.topMisalignedAreas.map((cell) => '<span>' + cell.domainLabel + ' / ' + cell.groupLabel + ' · ' + cell.contradictionCount + ' contradictions</span>').join('') : '<p>No misalignment detected yet.</p>') + '</article>' +
      '<article><h4>Top 3 High-Priority Domains</h4>' + (summary.topPriorityDomains.length ? summary.topPriorityDomains.map((domain) => '<span>' + domain.domainLabel + ' · Avg priority ' + domain.averagePriority + '</span>').join('') : '<p>No high-priority domains detected yet.</p>') + '</article>' +
    '</div>' +
  '</section>';
}
