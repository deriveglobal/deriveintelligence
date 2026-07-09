import {
  escapeHtml,
  renderScreenState
} from '../shared.js';

function safeArray(value) {
  return Array.isArray(value) ? value : [];
}

function formatDate(value, options = {}) {
  if (!value) return 'Not dated';
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return 'Not dated';
  return date.toLocaleDateString([], options);
}

function monthLabel(value) {
  return formatDate(value, { month: 'short', year: 'numeric' }).toUpperCase();
}

function formatDomainLabel(raw) {
  return String(raw || '')
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (char) => char.toUpperCase())
    .trim();
}

function snapshotScore(snapshot = {}) {
  return Number(snapshot.business_health_score ?? snapshot.health_score ?? 0);
}

function severityClass(value) {
  const number = Number(value || 0);
  if (number >= 4) return 'danger';
  if (number >= 2) return 'warning';
  return 'success';
}

function severityColor(value) {
  const number = Number(value || 0);
  if (number >= 4) return '#E07B5A';
  if (number >= 2) return '#C8A96E';
  if (number >= 1) return '#6BB88A';
  return 'rgba(255,255,255,0.2)';
}

function normalizeFindingKey(finding = {}) {
  return String(
    finding.normalized_finding_key
    || finding.title
    || finding.id
    || ''
  ).toLowerCase().trim();
}

function latestSnapshotDate(snapshots = []) {
  const latest = snapshots[snapshots.length - 1];
  return latest?.snapshot_date || latest?.created_at || null;
}

function findingRows(data = {}) {
  const history = safeArray(data.findingHistory);
  const current = safeArray(data.currentFindings);
  if (history.length) return history;
  return current.map((finding) => ({
    ...finding,
    normalized_finding_key: normalizeFindingKey(finding),
    snapshot_date: latestSnapshotDate(safeArray(data.snapshots)),
    title: finding.title,
    business_domain: finding.business_domain,
    severity: finding.severity,
    status: 'Baseline'
  }));
}

function findingStatusForKey(rows = [], key, snapshots = []) {
  if (snapshots.length <= 1) return 'Baseline';
  const dates = snapshots.map((snapshot) => String(snapshot.snapshot_date || snapshot.created_at || '').slice(0, 10));
  const presentDates = new Set(rows.filter((row) => normalizeFindingKey(row) === key).map((row) => String(row.snapshot_date || '').slice(0, 10)));
  const first = dates[0];
  const last = dates[dates.length - 1];
  if (presentDates.has(first) && !presentDates.has(last)) return 'Resolved';
  if (!presentDates.has(first) && presentDates.has(last)) return 'New';
  if (presentDates.has(first) && presentDates.has(last)) return 'Persisted';
  return 'Baseline';
}

function statusPill(status) {
  const normalized = String(status || 'Baseline').toLowerCase();
  const cls = normalized === 'resolved'
    ? 'approved'
    : normalized === 'persisted'
      ? 'warning'
      : normalized === 'new'
        ? 'danger'
        : 'draft';
  return `<span class="status-pill ${cls}">${escapeHtml(status || 'Baseline')}</span>`;
}

export function renderHealthPill(snapshots = []) {
  const rows = safeArray(snapshots);
  if (!rows.length) return '';
  if (rows.length === 1) {
    return `
      <span class="health-pill">
        <span class="health-score">${escapeHtml(String(snapshotScore(rows[0])))}</span>
        <span class="health-base-label">Baseline</span>
      </span>
    `;
  }
  const scores = rows.map((snapshot) => snapshotScore(snapshot));
  const delta = scores[scores.length - 1] - scores[0];
  return `
    <span class="health-pill">
      <span class="health-score">${escapeHtml(scores.join(' → '))}</span>
      <span class="health-delta ${delta >= 0 ? 'positive' : 'negative'}">${delta >= 0 ? '+' : ''}${escapeHtml(String(delta))} pts</span>
    </span>
  `;
}

function renderTimeline(data = {}) {
  const snapshots = safeArray(data.snapshots);
  if (!snapshots.length) {
    return renderScreenState('progress-intelligence', 'empty', {
      title: 'No progress baseline yet.',
      message: 'Generate a progress snapshot from the Deliver stage to establish the baseline.',
      compact: true
    });
  }
  if (snapshots.length === 1) {
    const snapshot = snapshots[0];
    return `
      <article class="progress-baseline-card">
        <span class="eyebrow">Baseline</span>
        <h3>${escapeHtml(formatDate(snapshot.snapshot_date))}</h3>
        <div class="progress-baseline-metrics">
          <span><strong>${escapeHtml(String(snapshotScore(snapshot)))}</strong> Health score</span>
          <span><strong>${escapeHtml(String(snapshot.total_findings || 0))}</strong> Findings</span>
          <span><strong>${escapeHtml(String(snapshot.approved_recommendations_count || 0))}</strong> Recommendations</span>
        </div>
        <p>This is the baseline. After the next assessment, Derive will show what improved.</p>
      </article>
    `;
  }
  return `
    <div class="progress-timeline">
      ${snapshots.map((snapshot, index) => {
        const previous = snapshots[index - 1];
        const delta = previous ? snapshotScore(snapshot) - snapshotScore(previous) : 0;
        return `
          <article class="${index === snapshots.length - 1 ? 'active' : ''}">
            <span>${escapeHtml(monthLabel(snapshot.snapshot_date))}</span>
            <strong>${escapeHtml(String(snapshotScore(snapshot)))}</strong>
            ${index > 0 ? `<small class="${delta >= 0 ? 'positive' : 'negative'}">${delta >= 0 ? '↑ +' : '↓ '}${escapeHtml(String(delta))} pts</small>` : '<small>Baseline</small>'}
            <em>${escapeHtml(String(snapshot.total_findings || 0))} findings</em>
          </article>
        `;
      }).join('')}
    </div>
  `;
}

function renderChangedSection(data = {}) {
  const snapshots = safeArray(data.snapshots);
  const history = safeArray(data.findingHistory);
  if (snapshots.length < 2 || !history.length) return '';
  const rowsByKey = history.reduce((acc, row) => {
    const key = normalizeFindingKey(row);
    acc[key] ||= [];
    acc[key].push(row);
    return acc;
  }, {});
  const groups = { Resolved: [], Persisted: [], New: [] };
  Object.entries(rowsByKey).forEach(([key, rows]) => {
    const status = findingStatusForKey(history, key, snapshots);
    if (groups[status]) groups[status].push(rows[rows.length - 1]);
  });
  const column = (label, cls, items, empty) => `
    <article class="progress-change-column ${cls}">
      <h4><span></span>${escapeHtml(label)}</h4>
      ${items.length ? items.slice(0, 8).map((item) => `
        <div>
          <strong>${escapeHtml(item.title || 'Finding')}</strong>
          <small>${escapeHtml(label === 'Persisted' ? 'Still present' : label === 'New' ? 'Emerged this assessment' : formatDomainLabel(item.business_domain))}</small>
        </div>
      `).join('') : `<p>${escapeHtml(empty)}</p>`}
    </article>
  `;
  return `
    <section class="progress-intelligence-section">
      <h3>What changed</h3>
      <div class="progress-change-grid">
        ${column('Resolved', 'resolved', groups.Resolved, 'No resolved findings yet.')}
        ${column('Persisted', 'persisted', groups.Persisted, 'No persisted findings yet.')}
        ${column('New', 'new', groups.New, 'No new findings yet.')}
      </div>
    </section>
  `;
}

function renderBenchmarkTable(data = {}) {
  const snapshots = safeArray(data.snapshots);
  const rows = findingRows(data);
  const containerStyle = 'background:#161614;border:0.5px solid rgba(255,255,255,0.07);border-radius:8px;overflow:hidden;';
  const tableStyle = 'background:transparent;width:100%;border-collapse:collapse;';
  const headerRowStyle = 'background:rgba(255,255,255,0.03);';
  const headerCellStyle = 'background:transparent;color:rgba(255,255,255,0.3);font-size:10px;font-weight:500;letter-spacing:0.06em;text-transform:uppercase;padding:8px 12px;border:none;text-align:left;';
  const rowStyle = 'background:transparent;border-bottom:0.5px solid rgba(255,255,255,0.07);';
  const cellStyle = 'background:transparent;color:#F0EDE6;padding:10px 12px;border:none;';
  const rowsByKey = rows.reduce((acc, row) => {
    const key = normalizeFindingKey(row);
    if (!key) return acc;
    acc[key] ||= [];
    acc[key].push(row);
    return acc;
  }, {});
  if (!Object.keys(rowsByKey).length) {
    return renderScreenState('progress-findings', 'empty', {
      title: 'No tracked findings yet',
      message: 'Approved findings will appear here once an assessment has been reviewed.',
      compact: true
    });
  }
  const columns = snapshots.length
    ? snapshots
    : [{ snapshot_date: new Date().toISOString() }];
  return `
    <div class="table-scroll" style="${containerStyle}">
      <table class="compact-table progress-benchmark-table" style="${tableStyle}">
        <thead>
          <tr style="${headerRowStyle}">
            <th style="${headerCellStyle}">Finding</th>
            ${columns.map((snapshot) => `<th style="${headerCellStyle}">${escapeHtml(monthLabel(snapshot.snapshot_date))}</th>`).join('')}
            <th style="${headerCellStyle}">Status</th>
          </tr>
        </thead>
        <tbody>
          ${Object.entries(rowsByKey).map(([key, groupedRows]) => {
            const latest = groupedRows[groupedRows.length - 1] || {};
            const status = findingStatusForKey(rows, key, columns);
            return `
              <tr style="${rowStyle}">
                <td style="${cellStyle}"><strong style="display:block;color:#F0EDE6;font-weight:500;">${escapeHtml(latest.title || 'Finding')}</strong><small style="display:block;color:rgba(255,255,255,0.4);margin-top:2px;">${escapeHtml(formatDomainLabel(latest.business_domain))}</small></td>
                ${columns.map((snapshot) => {
                  const dateKey = String(snapshot.snapshot_date || snapshot.created_at || '').slice(0, 10);
                  const match = groupedRows.find((row) => String(row.snapshot_date || '').slice(0, 10) === dateKey) || (columns.length === 1 ? latest : null);
                  const severity = match?.severity;
                  return `<td style="${cellStyle}">${severity ? `<span class="severity-score ${severityClass(severity)}" style="color:${severityColor(severity)};background:transparent;font-weight:600;">${escapeHtml(String(severity))}/5</span>` : '<span class="muted-dash" style="color:rgba(255,255,255,0.2);background:transparent;">—</span>'}</td>`;
                }).join('')}
                <td style="${cellStyle}">${statusPill(status)}</td>
              </tr>
            `;
          }).join('')}
        </tbody>
      </table>
    </div>
  `;
}

export function renderProgressIntelligence(data = {}, options = {}) {
  const organization = data.organization || {};
  return `
    <section class="progress-intelligence ${options.compact ? 'compact' : ''}">
      <section class="progress-intelligence-section">
        <div class="owner-section-head">
          <div>
            <span class="eyebrow">Assessment timeline</span>
            <h3>${escapeHtml(organization.name || 'Organization')}</h3>
            <p>${escapeHtml(formatDomainLabel(organization.industry) || 'Progress baseline and comparison history')}</p>
          </div>
        </div>
        ${renderTimeline(data)}
      </section>

      ${renderChangedSection(data)}

      <section class="progress-intelligence-section">
        <h3>Finding benchmark table</h3>
        ${renderBenchmarkTable(data)}
      </section>
    </section>
  `;
}
