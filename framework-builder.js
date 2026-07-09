import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

function array(value) {
  return Array.isArray(value) ? value : [];
}

function countQuestions(framework = {}) {
  return array(framework.banks).reduce((sum, bank) => sum + Number(bank.question_count || 0), 0);
}

function flatKpis(kpis = []) {
  return array(kpis).flatMap((domain) => array(domain.kpis).map((kpi) => ({ ...kpi, domain_name: kpi.domain_name || domain.domain_name })));
}

function pill(value) {
  return `<span class="status-pill ${statusClass(value)}">${escapeHtml(value || 'Draft')}</span>`;
}

function coverageColor(gradeOrScore) {
  const score = typeof gradeOrScore === 'number' ? gradeOrScore : null;
  const grade = score === null ? String(gradeOrScore || '') : score >= 90 ? 'A' : score >= 80 ? 'B' : score >= 70 ? 'C' : score >= 60 ? 'D' : 'F';
  if (grade === 'A') return 'var(--color-success)';
  if (grade === 'B') return '#7BC99A';
  if (grade === 'C') return 'var(--color-accent)';
  if (grade === 'D') return '#D9974A';
  return 'var(--color-danger)';
}

function coverageBadge(coverage = {}, { compact = false } = {}) {
  if (!coverage || coverage.total === undefined && coverage.overall_score === undefined) return '';
  const score = Number(coverage.total ?? coverage.overall_score ?? 0);
  const grade = coverage.grade || (score >= 90 ? 'A' : score >= 80 ? 'B' : score >= 70 ? 'C' : score >= 60 ? 'D' : 'F');
  const flags = array(coverage.flags);
  return `
    <span class="status-pill" title="${flags.map(escapeHtml).join(', ')}" style="background:${coverageColor(score)}22;color:${coverageColor(score)};border-color:${coverageColor(score)}55;">
      ${compact ? '' : 'Coverage: '}${score}/100 ${escapeHtml(grade)}${flags.length ? ' !' : ''}
    </span>
  `;
}

function coverageComponentRow(label, component = {}) {
  const score = Number(component.score || 0);
  const max = Number(component.max || 25);
  const percent = max ? Math.round((score / max) * 100) : 0;
  const description = component.description || component.detail || '';
  return `
    <div title="${escapeHtml(description)}" style="display:grid;grid-template-columns:150px 1fr 70px;gap:10px;align-items:center;margin:10px 0;padding:8px 0;border-bottom:0.5px solid rgba(200,169,110,0.08);">
      <span style="font-size:12px;color:var(--color-text-muted);">${escapeHtml(label)}</span>
      <span style="height:7px;background:rgba(255,255,255,0.06);border-radius:999px;overflow:hidden;">
        <span style="display:block;height:100%;width:${percent}%;background:${coverageColor(score * 4)};"></span>
      </span>
      <strong style="font-size:12px;color:var(--color-text);">${score}/${max}</strong>
      ${description ? `<small style="grid-column:2 / 4;color:var(--color-text-faint);line-height:1.4;">${escapeHtml(description)}</small>` : ''}
      ${array(component.missing_domains).length ? `<small style="grid-column:2 / 4;color:#D9974A;line-height:1.4;">Missing: ${array(component.missing_domains).map(escapeHtml).join(', ')}</small>` : ''}
    </div>
  `;
}

function coverageComponentValue(component = {}, key, fallback = '') {
  const value = component[key];
  return value === undefined || value === null || value === '' ? fallback : value;
}

function renderQualityBreakdown(quality = {}) {
  const targetKpi = Number(quality.targets?.kpi_linkage_pct || 80);
  const targetFinding = Number(quality.targets?.finding_potential_pct || 80);
  const rows = [
    ['KPI linkage', Number(quality.kpi_linkage_pct || 0), targetKpi, `${Number(quality.kpi_linked || 0)}/${Number(quality.total_questions || 0)} questions linked to KPIs`],
    ['Finding potential', Number(quality.finding_potential_pct || 0), targetFinding, `${Number(quality.finding_potential || 0)}/${Number(quality.total_questions || 0)} questions can generate findings`]
  ];
  return `
    <section style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-radius:12px;padding:1rem;margin-top:12px;">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;">
        <strong style="font-size:13px;color:#E8E4DC;">Quality score</strong>
        <span class="status-pill">${Number(quality.score || 0)}/100</span>
      </div>
      ${rows.map(([label, pct, target, detail]) => `
        <div style="display:grid;grid-template-columns:130px 1fr 54px;gap:10px;align-items:center;margin:9px 0;">
          <span style="font-size:12px;color:var(--color-text-muted);">${escapeHtml(label)}</span>
          <span style="height:7px;background:rgba(255,255,255,0.06);border-radius:999px;overflow:hidden;">
            <span style="display:block;height:100%;width:${Math.min(100, pct)}%;background:${pct >= target ? 'var(--color-success)' : 'var(--color-accent)'};"></span>
          </span>
          <strong style="font-size:12px;color:var(--color-text);">${pct}%</strong>
          <small style="grid-column:2 / 4;color:var(--color-text-faint);">Target ${target}% · ${escapeHtml(detail)}</small>
        </div>
      `).join('')}
    </section>
  `;
}

function renderDomainCoverageMap(coverage = {}) {
  const expected = array(coverage.domains?.expected);
  const distribution = coverage.domain_distribution || {};
  const min = Number(coverage.components?.breadth?.description?.match(/(\d+)\+/)?.[1] || coverage.config?.breadthConfig?.min_questions_per_domain || 3);
  return `
    <section style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-radius:12px;padding:1rem;margin-top:12px;">
      <strong style="font-size:13px;color:#E8E4DC;">Domain coverage map</strong>
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:8px;margin-top:12px;">
        ${expected.map((domain) => {
          const count = Number(distribution[domain] || 0);
          const covered = count >= min;
          const pct = Math.min(100, Math.round((count / Math.max(min, 1)) * 100));
          return `
            <div style="border:0.5px solid ${covered ? 'rgba(100,180,100,0.25)' : 'rgba(200,169,110,0.12)'};border-radius:8px;padding:8px;background:${covered ? 'rgba(100,180,100,0.06)' : 'rgba(200,169,110,0.04)'};">
              <div style="display:flex;justify-content:space-between;gap:8px;align-items:center;">
                <span style="font-size:12px;color:#E8E4DC;">${covered ? 'Covered' : 'Needs'} ${escapeHtml(domain)}</span>
                <span style="font-size:11px;color:${covered ? 'rgba(140,210,140,0.9)' : '#D9974A'};">${count}</span>
              </div>
              <span style="display:block;height:5px;background:rgba(255,255,255,0.06);border-radius:999px;overflow:hidden;margin-top:7px;">
                <span style="display:block;height:100%;width:${pct}%;background:${covered ? 'var(--color-success)' : 'var(--color-accent)'};"></span>
              </span>
              ${covered ? '' : `<small style="display:block;margin-top:5px;color:var(--color-text-faint);">needs ${Math.max(0, min - count)} more</small>`}
            </div>
          `;
        }).join('')}
      </div>
    </section>
  `;
}

function renderCoverageBreakdown(coverage = {}) {
  if (!coverage || coverage.total === undefined) return '';
  const components = coverage.components || {
    quantity: coverage.quantity,
    breadth: coverage.breadth,
    kpi_linkage: coverage.kpi_linkage,
    finding_potential: coverage.finding_potential
  };
  return `
    <section class="card" style="margin-bottom:14px;">
      <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:1rem;margin-bottom:14px;">
        <div>
          <div style="font-size:34px;line-height:1;color:${coverageColor(Number(coverage.total || 0))};font-weight:600;">${Number(coverage.total || 0)}/100</div>
          <div style="font-size:12px;color:var(--color-text-muted);margin-top:4px;">Coverage score</div>
        </div>
        <span class="status-pill" style="background:${coverageColor(Number(coverage.total || 0))}22;color:${coverageColor(Number(coverage.total || 0))};border-color:${coverageColor(Number(coverage.total || 0))}55;">Grade ${escapeHtml(coverage.grade || '')}</span>
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px;margin-bottom:12px;">
        <div style="background:rgba(200,169,110,0.05);border:0.5px solid rgba(200,169,110,0.12);border-radius:8px;padding:10px;">
          <div style="font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(200,169,110,0.5);">Coverage</div>
          <strong style="font-size:18px;color:#E8E4DC;">${Number(coverage.total || 0)}/100</strong>
        </div>
        <div style="background:rgba(200,169,110,0.05);border:0.5px solid rgba(200,169,110,0.12);border-radius:8px;padding:10px;">
          <div style="font-size:11px;text-transform:uppercase;letter-spacing:0.05em;color:rgba(200,169,110,0.5);">Quality</div>
          <strong style="font-size:18px;color:#E8E4DC;">${Number(coverage.quality?.score || 0)}/100</strong>
        </div>
      </div>
      ${coverageComponentRow('Breadth', components.breadth)}
      <small style="display:block;margin:-4px 0 8px 160px;color:var(--color-text-faint);">${coverageComponentValue(components.breadth, 'covered_domains', 0)} of ${coverageComponentValue(components.breadth, 'expected_domains', 0)} expected domains covered</small>
      ${coverageComponentRow('Quantity', components.quantity)}
      <small style="display:block;margin:-4px 0 8px 160px;color:var(--color-text-faint);">Average ${coverageComponentValue(components.quantity, 'avg_per_domain', 0)} questions per covered domain</small>
      ${coverageComponentRow('Depth', components.depth)}
      <small style="display:block;margin:-4px 0 8px 160px;color:var(--color-text-faint);">${coverageComponentValue(components.depth, 'deep_domains', 0)} domains have deep coverage</small>
      ${coverageComponentRow('Response mix', components.response_mix)}
      <small style="display:block;margin:-4px 0 8px 160px;color:var(--color-text-faint);">${coverageComponentValue(components.response_mix, 'types_used', 0)} response types used</small>
      ${coverageComponentRow('Activity fit', components.activity_fit)}
      ${renderQualityBreakdown(coverage.quality || {})}
      ${renderDomainCoverageMap(coverage)}
      ${array(coverage.flags).length ? `
        <div style="margin-top:12px;">
          ${array(coverage.flags).map((flag) => `<span class="status-pill warning" style="margin:0 6px 6px 0;">${escapeHtml(flag)}</span>`).join('')}
        </div>
      ` : '<p class="upload-note">No coverage issues flagged.</p>'}
      <details style="margin-top:14px;">
        <summary style="cursor:pointer;color:var(--color-text-muted);font-size:12px;">How this score is calculated</summary>
        <div style="color:var(--color-text-muted);font-size:12px;line-height:1.6;margin-top:10px;">
          <p>The coverage score measures whether this question bank can detect organizational misalignment across all relevant dimensions.</p>
          <p>Score = Breadth (${Number(components.breadth?.max || 0)}%) + Quantity (${Number(components.quantity?.max || 0)}%) + Depth (${Number(components.depth?.max || 0)}%) + Response Mix (${Number(components.response_mix?.max || 0)}%) + Activity Fit (${Number(components.activity_fit?.max || 0)}%).</p>
          <p>Breadth measures how many core misalignment domains have meaningful coverage. Quantity measures average questions per covered domain. Depth measures domains with deep coverage. Response mix rewards varied formats. Activity fit measures relevance to declared business activities.</p>
          <p>Quality score is separate and measures KPI linkage plus finding potential. Target: 80%+ for both.</p>
          <button class="text-button" type="button" data-framework-action="scoring-settings">Adjust scoring weights -></button>
        </div>
      </details>
    </section>
  `;
}

function effectivenessTag(effectiveness = {}) {
  if (!effectiveness || !Number(effectiveness.times_asked || 0)) return '<span class="status-pill not-started">New</span>';
  const rate = Number(effectiveness.trigger_rate || 0);
  if (rate === 0 && Number(effectiveness.times_asked || 0) >= 3) return '<span class="status-pill warning">Review</span>';
  if (rate >= 0.5) return '<span class="status-pill approved">High impact</span>';
  if (rate >= 0.25) return '<span class="status-pill approved">Strong</span>';
  if (rate > 0) return '<span class="status-pill started">Used</span>';
  return '<span class="status-pill warning">Review</span>';
}

function option(value, label, activeValue) {
  return `<option value="${escapeHtml(value)}" ${String(activeValue || '') === String(value) ? 'selected' : ''}>${escapeHtml(label)}</option>`;
}

function groupByCategory(items = []) {
  return array(items).reduce((groups, item) => {
    const category = item.category || 'Uncategorized';
    groups[category] = groups[category] || [];
    groups[category].push(item);
    return groups;
  }, {});
}

function requirementLabel(value) {
  const labels = { required: 'Required', recommended: 'Recommended', optional: 'Optional', excluded: 'Excluded' };
  return labels[value] || 'Optional';
}

function estimateMinutes(questionCount) {
  const minutes = Math.max(5, Math.round((Number(questionCount || 0) * 45) / 60 / 5) * 5);
  return `${minutes} min`;
}

export function renderFrameworkLibrary(
  frameworks,
  loading,
  error,
  { onCreateFramework, onOpenFramework, onImportFleet } = {}
) {
  if (loading) return renderLoadingSkeleton('Loading frameworks', 4);
  if (error) return renderScreenState('frameworks', 'error', { title: 'Frameworks could not be loaded', message: error });
  const list = array(frameworks);
  const hasFleet = list.some((framework) => framework.name === 'Fleet & Service Operations');
  return `
    <section class="panel framework-builder">
      <div class="panel-header">
        <div>
          <h2>Frameworks</h2>
          <span>Build and manage assessment methodologies for each industry.</span>
        </div>
        ${onCreateFramework ? '<button class="primary-button" type="button" data-framework-action="create">+ New Framework</button>' : ''}
      </div>
      ${list.length === 0 ? `
        <div class="framework-builder-grid">
          <article class="card">
            <h3>Import Fleet Framework</h3>
            <p>Your existing Fleet & Service Operations question banks are ready to import. This brings all role banks into the Framework Builder where you can view, edit, and extend them.</p>
            ${onImportFleet ? '<button class="primary-button" type="button" data-framework-action="import-fleet">Import Fleet Framework</button>' : ''}
          </article>
          <article class="card">
            <h3>Build a new framework</h3>
            <p>Start from scratch for a new industry. Define roles, domains, KPIs, and generate questions with AI.</p>
            ${onCreateFramework ? '<button class="secondary-button" type="button" data-framework-action="create">New Framework</button>' : ''}
          </article>
        </div>
      ` : `
        ${!hasFleet && onImportFleet ? `
          <article class="card framework-import-card">
            <div>
              <h3>Import Fleet Framework</h3>
              <p>Your existing Fleet & Service Operations question banks are ready to import.</p>
            </div>
            <button class="secondary-button" type="button" data-framework-action="import-fleet">Import Fleet Framework</button>
          </article>
        ` : ''}
        <div class="framework-card-grid">
          ${list.map((framework) => {
            const requiredEmpty = Number(framework.required_role_count || 0) - Number(framework.active_bank_count || 0);
            return `
              <article class="card framework-card">
                <div class="card-kicker">${escapeHtml(framework.industry || 'Industry')}</div>
                <h3>${escapeHtml(framework.name)} ${coverageBadge(framework.coverage || {}, { compact: false })}</h3>
                <div class="meta-row">
                  <span>Version ${escapeHtml(framework.version || 1)}</span>
                  ${pill(framework.status)}
                </div>
                <p>${Number(framework.bank_count || 0)} roles · ${Number(framework.question_count || 0)} questions · ${Number(framework.kpi_count || 0)} KPIs</p>
                ${framework.status === 'draft' && requiredEmpty > 0 ? `<p class="warning-text">${requiredEmpty} required roles need question banks</p>` : ''}
                ${onOpenFramework ? `<button class="primary-button" type="button" data-framework-action="open" data-framework-id="${escapeHtml(framework.id)}">Open</button>` : ''}
              </article>
            `;
          }).join('')}
        </div>
      `}
    </section>
  `;
}

export function renderFrameworkEditor(
  framework,
  activeTab,
  loading,
  error,
  { onBack, onSaveIdentity, onAddBank, onUpdateBank, onDeleteBank, onAddKpi, onUpdateKpi, onDeleteKpi, onTabChange, onOpenQuestionBank, domains = [], scoringConfig = {} } = {}
) {
  if (loading && !framework) return renderLoadingSkeleton('Loading framework', 4);
  if (error) return renderScreenState('framework-editor', 'error', { title: 'Framework could not be loaded', message: error });
  if (!framework) return renderScreenState('framework-editor', 'empty', { title: 'No framework selected', message: 'Open a framework to edit its roles, KPIs, and question banks.' });
  const tab = activeTab || 'identity';
  const banks = array(framework.banks);
  const kpis = array(framework.kpis);
  return `
    <section class="panel framework-builder">
      <div class="panel-header">
        <div>
          ${onBack ? '<button class="text-button" type="button" data-framework-action="back">Back</button>' : ''}
          <h2>${escapeHtml(framework.name)}</h2>
          <span>${escapeHtml(framework.industry || '')}</span>
        </div>
        ${pill(framework.status)}
      </div>
      <div class="tabs">
        ${['identity', 'roles', 'kpis', 'settings', 'preview'].map((item) => `
          <button class="tab ${tab === item ? 'active' : ''}" type="button" data-framework-tab="${escapeHtml(item)}">
            ${escapeHtml(item === 'kpis' ? 'Domains & KPIs' : item[0].toUpperCase() + item.slice(1))}
          </button>
        `).join('')}
      </div>
      ${tab === 'identity' ? renderIdentityTab(framework, Boolean(onSaveIdentity)) : ''}
      ${tab === 'roles' ? renderRolesTab(framework, banks, { onAddBank, onUpdateBank, onDeleteBank, onOpenQuestionBank }) : ''}
      ${tab === 'kpis' ? renderKpiTab(kpis, { onAddKpi, onUpdateKpi, onDeleteKpi }, domains, framework.kpiCatalog || [], framework.activities || []) : ''}
      ${tab === 'settings' ? renderScoringSettings(scoringConfig) : ''}
      ${tab === 'preview' ? renderFrameworkPreview(framework, banks, kpis, framework.readiness || {}, loading, { onBack: null, onActivate: null, onOpenBank: onOpenQuestionBank }) : ''}
    </section>
  `;
}

function renderIdentityTab(framework, canSave) {
  return `
    <form class="form framework-identity-form" data-framework-form="identity">
      <div class="form-grid">
        <label>Framework name<input name="name" value="${escapeHtml(framework.name || '')}" /></label>
        <label>Industry<input name="industry" value="${escapeHtml(framework.industry || '')}" /></label>
        <label>Version<input name="version" type="number" min="1" value="${escapeHtml(framework.version || 1)}" /></label>
      </div>
      <label>Description<textarea name="description" rows="4">${escapeHtml(framework.description || '')}</textarea></label>
      ${canSave ? '<button class="primary-button" type="submit">Save</button>' : ''}
    </form>
  `;
}

function renderScoringSettings(config = {}) {
  const weights = config.weights || {};
  const breadth = config.breadthConfig || {};
  const quantity = config.quantityConfig || {};
  const depth = config.depthConfig || {};
  const quality = config.qualityTargets || {};
  const grades = config.gradeThresholds || {};
  const total = ['breadth', 'quantity', 'depth', 'response_mix', 'activity_fit']
    .reduce((sum, key) => sum + Number(weights[key] || 0), 0);
  const numberInput = (name, value, suffix = '%') => `
    <label style="display:grid;grid-template-columns:1fr 90px 20px;gap:10px;align-items:center;font-size:13px;color:var(--color-text-muted);">
      <span>${escapeHtml(name.replace(/_/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase()))}</span>
      <input name="${escapeHtml(name)}" type="number" min="0" max="100" value="${escapeHtml(value ?? 0)}" style="background:#1a1a18;border:0.5px solid rgba(200,169,110,0.25);border-radius:8px;padding:8px 10px;color:#E8E4DC;" />
      <span>${escapeHtml(suffix)}</span>
    </label>
  `;
  return `
    <form class="card form" data-framework-form="scoring-settings" style="display:grid;gap:1rem;">
      <div>
        <h3 style="margin:0;color:#E8E4DC;font-size:16px;">Scoring weights</h3>
        <p class="upload-note">Must total 100%. These weights control the bank coverage score.</p>
      </div>
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:1rem;">
        <section style="border:0.5px solid rgba(200,169,110,0.14);border-radius:10px;padding:1rem;">
          <h4 style="margin:0 0 10px;color:#E8E4DC;font-size:13px;">Weights</h4>
          ${numberInput('breadth', weights.breadth ?? 40)}
          ${numberInput('quantity', weights.quantity ?? 20)}
          ${numberInput('depth', weights.depth ?? 20)}
          ${numberInput('response_mix', weights.response_mix ?? 10)}
          ${numberInput('activity_fit', weights.activity_fit ?? 10)}
          <div style="margin-top:10px;font-size:12px;color:${total === 100 ? 'var(--color-success)' : 'var(--color-danger)'};">Total: <strong>${total}%</strong> ${total === 100 ? 'valid' : 'must equal 100%'}</div>
        </section>
        <section style="border:0.5px solid rgba(200,169,110,0.14);border-radius:10px;padding:1rem;">
          <h4 style="margin:0 0 10px;color:#E8E4DC;font-size:13px;">Thresholds</h4>
          ${numberInput('min_questions_per_domain', breadth.min_questions_per_domain ?? 3, '')}
          ${numberInput('target_per_domain', quantity.target_per_domain ?? 5, '')}
          ${numberInput('deep_domain_threshold', depth.deep_domain_threshold ?? 5, '')}
        </section>
        <section style="border:0.5px solid rgba(200,169,110,0.14);border-radius:10px;padding:1rem;">
          <h4 style="margin:0 0 10px;color:#E8E4DC;font-size:13px;">Quality targets</h4>
          ${numberInput('kpi_linkage_pct', quality.kpi_linkage_pct ?? 80)}
          ${numberInput('finding_potential_pct', quality.finding_potential_pct ?? 80)}
        </section>
        <section style="border:0.5px solid rgba(200,169,110,0.14);border-radius:10px;padding:1rem;">
          <h4 style="margin:0 0 10px;color:#E8E4DC;font-size:13px;">Grade boundaries</h4>
          ${numberInput('grade_a', grades.A ?? 90, '+')}
          ${numberInput('grade_b', grades.B ?? 75, '+')}
          ${numberInput('grade_c', grades.C ?? 60, '+')}
          ${numberInput('grade_d', grades.D ?? 45, '+')}
        </section>
      </div>
      <div data-scoring-error style="display:none;background:rgba(224,100,80,0.08);border:0.5px solid rgba(224,100,80,0.35);border-radius:8px;padding:10px 14px;color:#E07B5A;font-size:13px;"></div>
      <div style="display:flex;justify-content:flex-end;gap:10px;">
        <button type="button" class="secondary-button" data-framework-action="reset-scoring">Reset to defaults</button>
        <button type="submit" class="primary-button" ${total === 100 ? '' : 'disabled'}>Save changes</button>
      </div>
    </form>
  `;
}

function renderRolesTab(framework, banks, handlers) {
  return `
    <div class="section-copy">
      <p>Define who participates in this assessment. Required roles must have complete question banks before the framework can be activated. Requirement levels can be changed at any time and overridden per assessment.</p>
    </div>
    <div class="role-card-list">
      ${banks.map((bank) => `
        <article class="card role-bank-card">
          <div>
            <h3>${escapeHtml(bank.role_name)} ${coverageBadge(bank.coverage || {}, { compact: true })}</h3>
            <p>${Number(bank.question_count || 0)} questions · ${requirementLabel(bank.requirement)}</p>
            ${bank.coverage ? `
              <details style="margin-top:10px;">
                <summary style="cursor:pointer;color:var(--color-text-muted);font-size:12px;">Coverage details</summary>
                <div style="margin-top:10px;">
                  ${coverageComponentRow('Breadth', bank.coverage.breadth)}
                  ${coverageComponentRow('Quantity', bank.coverage.quantity)}
                  ${coverageComponentRow('Depth', bank.coverage.depth)}
                  ${coverageComponentRow('Response mix', bank.coverage.response_mix)}
                  ${coverageComponentRow('Activity fit', bank.coverage.activity_fit)}
                  <div style="
                    margin-top: 8px;
                    padding-top: 8px;
                    border-top: 0.5px solid rgba(200,169,110,0.1);
                  ">
                    <div style="font-size:11px;color:rgba(200,169,110,0.5);margin-bottom:4px;">Quality</div>
                    ${coverageComponentRow('KPI linkage', bank.coverage.kpi_linkage)}
                    ${coverageComponentRow('Finding potential', bank.coverage.finding_potential)}
                  </div>
                  ${array(bank.coverage.flags).map((flag) => `<span class="status-pill warning" style="margin:0 4px 4px 0;">${escapeHtml(flag)}</span>`).join('')}
                </div>
              </details>
            ` : ''}
          </div>
          <label>
            Requirement
            <select data-framework-bank-requirement="${escapeHtml(bank.id)}" ${handlers.onUpdateBank ? '' : 'disabled'}>
              ${option('required', 'Required', bank.requirement)}
              ${option('recommended', 'Recommended', bank.requirement)}
              ${option('optional', 'Optional', bank.requirement)}
            </select>
          </label>
          ${pill(Number(bank.question_count || 0) > 0 ? bank.status : 'Incomplete')}
          ${handlers.onOpenQuestionBank ? `<button class="secondary-button" type="button" data-framework-action="open-bank" data-bank-id="${escapeHtml(bank.id)}">Manage Questions</button>` : ''}
          ${framework.status === 'draft' && handlers.onDeleteBank ? `<button class="text-button danger" type="button" data-framework-action="delete-bank" data-bank-id="${escapeHtml(bank.id)}">Delete</button>` : ''}
        </article>
      `).join('') || renderScreenState('roles', 'empty', { title: 'No roles yet', message: 'Add roles to define who participates in this framework.', compact: true })}
    </div>
    ${handlers.onAddBank ? `
      <details class="card add-role-card">
        <summary>+ Add Role</summary>
        <form class="form" data-framework-form="bank">
          <div class="form-grid">
            <label>Role name<input name="role_name" required /></label>
            <label>Role key<input name="role_key" required pattern="[a-z_]+" placeholder="plant_manager" /></label>
            <label>Requirement<select name="requirement">${option('required', 'Required', 'required')}${option('recommended', 'Recommended')}${option('optional', 'Optional')}</select></label>
            <label>Stakeholder group<input name="stakeholder_group" /></label>
          </div>
          <button class="primary-button" type="submit">Add Role</button>
        </form>
      </details>
    ` : ''}
  `;
}

function renderKpiTab(domains, handlers, domainTaxonomy = [], kpiCatalog = [], activities = []) {
  return `
    ${renderDomainManagement(domainTaxonomy)}
    ${renderKpiManagement(kpiCatalog, activities)}
    <div class="section-copy">
      <p>Define what good looks like in this industry. KPI expectations tell the platform what organizations should be measuring and what targets indicate healthy performance.</p>
    </div>
    ${array(domains).map((domain) => `
      <section class="card kpi-domain">
        <h3>${escapeHtml(domain.domain_name || 'General')}</h3>
        <div class="kpi-list">
          ${array(domain.kpis).map((kpi) => `
            <article class="kpi-row">
              <div>
                <strong>${escapeHtml(kpi.kpi_name)}</strong>
                <span>${escapeHtml(kpi.kpi_description || '')}</span>
              </div>
              <span class="badge">${escapeHtml(kpi.expectation_type || 'tracked')}</span>
              <span>${formatTarget(kpi)}</span>
              ${handlers.onDeleteKpi ? `<button class="text-button danger" type="button" data-framework-action="delete-kpi" data-kpi-id="${escapeHtml(kpi.id)}">Delete</button>` : ''}
            </article>
          `).join('')}
        </div>
        ${handlers.onAddKpi ? renderKpiForm(domain.domain_name) : ''}
      </section>
    `).join('') || renderScreenState('kpis', 'empty', { title: 'No KPI domains yet', message: 'Add a KPI to create the first domain.', compact: true })}
    ${handlers.onAddKpi ? `
      <details class="card">
        <summary>+ Add Domain</summary>
        ${renderKpiForm('')}
      </details>
    ` : ''}
  `;
}

function renderKpiManagement(kpis = [], activities = []) {
  const list = array(kpis);
  const activityLabel = (key) => array(activities).find((activity) => activity.key === key)?.label || key;
  const grouped = list.reduce((groups, kpi) => {
    const keys = array(kpi.applicable_activities);
    const group = keys[0] || 'Universal';
    groups[group] = groups[group] || [];
    groups[group].push(kpi);
    return groups;
  }, {});
  return `
    <section style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-radius:12px;overflow:hidden;margin-bottom:12px;">
      <div style="display:flex;justify-content:space-between;align-items:center;padding:1rem 1.25rem;border-bottom:0.5px solid rgba(200,169,110,0.12);">
        <div>
          <h3 style="font-size:14px;font-weight:500;color:#E8E4DC;margin:0;">Key performance indicators</h3>
          <p style="font-size:12px;color:rgba(200,169,110,0.5);margin:2px 0 0;">${list.length} KPIs · tire_fleet_service</p>
        </div>
        <button type="button" data-component-add-kpi style="padding:5px 10px;font-size:12px;border:0.5px solid rgba(200,169,110,0.25);border-radius:6px;background:transparent;color:rgba(200,169,110,0.7);cursor:pointer;">+ Add KPI</button>
      </div>
      ${Object.entries(grouped).map(([group, items]) => `
        <div>
          <div style="font-size:11px;text-transform:uppercase;color:rgba(200,169,110,0.35);letter-spacing:0.08em;padding:10px 1.25rem 4px;border-bottom:0.5px solid rgba(200,169,110,0.08);">${escapeHtml(activityLabel(group))}</div>
          ${items.map((kpi) => `
            <div style="display:flex;align-items:center;gap:12px;padding:10px 1.25rem;border-bottom:0.5px solid rgba(200,169,110,0.06);">
              <div style="flex:1;min-width:0;">
                <div style="font-size:13px;font-weight:500;color:#E8E4DC;">${escapeHtml(kpi.name || kpi.key || '')}</div>
                ${kpi.name_tr ? `<div style="font-size:12px;color:rgba(200,169,110,0.5);margin-top:2px;">${escapeHtml(kpi.name_tr)}</div>` : ''}
                <div style="font-size:12px;color:rgba(232,228,220,0.35);margin-top:2px;line-height:1.5;">${escapeHtml(kpi.description || '')}</div>
              </div>
              <div style="display:flex;align-items:center;gap:6px;flex-wrap:wrap;justify-content:flex-end;max-width:360px;">
                ${kpi.unit ? `<span class="status-pill">${escapeHtml(kpi.unit)}</span>` : ''}
                <span class="status-pill" style="color:${kpi.target_direction === 'lower_is_better' ? '#D9974A' : 'rgba(140,210,140,0.9)'};">${kpi.target_direction === 'lower_is_better' ? 'down' : 'up'} ${escapeHtml(kpi.target_direction || '')}</span>
                ${array(kpi.applicable_activities).slice(0, 3).map((activity) => `<span style="padding:2px 8px;border-radius:12px;font-size:11px;background:rgba(200,169,110,0.06);border:0.5px solid rgba(200,169,110,0.15);color:rgba(200,169,110,0.65);">${escapeHtml(activityLabel(activity))}</span>`).join('')}
              </div>
              <div style="display:flex;align-items:center;gap:6px;">
                <button class="text-button" type="button" data-component-edit-kpi="${escapeHtml(kpi.id)}">Edit</button>
                <button class="text-button" type="button" data-component-toggle-kpi="${escapeHtml(kpi.id)}" data-is-active="${kpi.is_active === false ? 'false' : 'true'}">${kpi.is_active === false ? 'Activate' : 'Deactivate'}</button>
                ${Number(kpi.question_count || 0) === 0 ? `<button class="text-button danger" type="button" data-component-delete-kpi="${escapeHtml(kpi.id)}">Delete</button>` : `<span style="font-size:11px;color:rgba(232,228,220,0.25);">In use</span>`}
              </div>
            </div>
          `).join('')}
        </div>
      `).join('') || '<div style="padding:1rem 1.25rem;color:rgba(232,228,220,0.35);font-size:12px;">No KPIs found.</div>'}
    </section>
  `;
}

function renderDomainManagement(domains = []) {
  const universal = array(domains).filter((domain) => domain.scope === 'universal');
  const industry = array(domains).filter((domain) => domain.scope === 'industry');
  return `
    <section style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-radius:12px;overflow:hidden;margin-bottom:12px;">
      <div style="display:flex;justify-content:space-between;align-items:center;padding:1rem 1.25rem;border-bottom:0.5px solid rgba(200,169,110,0.12);">
        <div>
          <h3 style="font-size:14px;font-weight:500;color:#E8E4DC;margin:0;">Universal domains</h3>
          <p style="font-size:12px;color:rgba(200,169,110,0.5);margin:2px 0 0;">Apply to every framework and industry · ${universal.length} domains</p>
        </div>
      </div>
      ${renderDomainCategoryGroups(universal, { universal: true })}
    </section>
    <section style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-radius:12px;overflow:hidden;margin-bottom:1.5rem;">
      <div style="display:flex;justify-content:space-between;align-items:center;padding:1rem 1.25rem;border-bottom:0.5px solid rgba(200,169,110,0.12);">
        <div>
          <h3 style="font-size:14px;font-weight:500;color:#E8E4DC;margin:0;">Fleet & Service Operations domains</h3>
          <p style="font-size:12px;color:rgba(200,169,110,0.5);margin:2px 0 0;">tire_fleet_service · ${industry.length} domains</p>
        </div>
        <button class="primary-button" type="button" data-component-add-domain data-scope="industry" data-industry="tire_fleet_service">+ Add domain</button>
      </div>
      ${renderDomainCategoryGroups(industry, { universal: false })}
    </section>
  `;
}

function renderDomainCategoryGroups(domains = [], { universal = false } = {}) {
  const groups = groupByCategory(domains);
  const categories = Object.keys(groups);
  if (!categories.length) {
    return `<div style="padding:1rem 1.25rem;color:rgba(232,228,220,0.35);font-size:12px;">No domains found.</div>`;
  }
  return categories.map((category) => `
    <div>
      <div style="font-size:10px;text-transform:uppercase;letter-spacing:0.1em;color:rgba(200,169,110,0.35);padding:10px 1.25rem 4px;border-bottom:0.5px solid rgba(200,169,110,0.08);">${escapeHtml(category)}</div>
      ${groups[category].map((domain) => renderDomainRow(domain, { universal })).join('')}
    </div>
  `).join('');
}

function renderDomainRow(domain = {}, { universal = false } = {}) {
  const questionCount = Number(domain.question_count || 0);
  return `
    <div style="display:flex;align-items:center;gap:12px;padding:10px 1.25rem;border-bottom:0.5px solid rgba(200,169,110,0.06);">
      <div style="flex:1;min-width:0;">
        <div style="font-size:13px;font-weight:500;color:#E8E4DC;">${escapeHtml(domain.name || '')}</div>
        <div style="font-size:11px;color:rgba(200,169,110,0.4);font-family:monospace;">${escapeHtml(domain.key || '')}</div>
        <div style="font-size:12px;color:rgba(232,228,220,0.35);margin-top:2px;">${escapeHtml(domain.description || '')}</div>
      </div>
      <div style="display:flex;align-items:center;gap:8px;flex-shrink:0;">
        <span style="font-size:11px;padding:2px 8px;border-radius:12px;background:rgba(200,169,110,0.08);color:rgba(200,169,110,0.6);border:0.5px solid rgba(200,169,110,0.15);">${escapeHtml(domain.category || '')}</span>
        <span style="font-size:11px;color:rgba(232,228,220,0.35);">${questionCount} questions</span>
        ${domain.is_active === false ? '<span style="font-size:11px;padding:2px 8px;border-radius:12px;background:rgba(224,100,80,0.08);color:rgba(224,100,80,0.7);border:0.5px solid rgba(224,100,80,0.2);">Inactive</span>' : ''}
      </div>
      <div style="display:flex;align-items:center;gap:6px;flex-shrink:0;">
        ${universal ? '' : `<button class="text-button" type="button" data-component-edit-domain="${escapeHtml(domain.id)}">Edit</button>`}
        <button class="text-button" type="button" data-component-toggle-domain="${escapeHtml(domain.id)}" data-is-active="${domain.is_active === false ? 'false' : 'true'}">${domain.is_active === false ? 'Activate' : 'Deactivate'}</button>
        ${!universal && questionCount === 0 ? `<button class="text-button danger" type="button" data-component-delete-domain="${escapeHtml(domain.id)}">Delete</button>` : ''}
        ${!universal && questionCount > 0 ? `<span style="font-size:11px;color:rgba(232,228,220,0.25);">In use</span>` : ''}
      </div>
    </div>
  `;
}

function renderKpiForm(domainName) {
  return `
    <form class="form compact-form" data-framework-form="kpi">
      <input name="domain_name" placeholder="Domain name" value="${escapeHtml(domainName || '')}" required />
      <input name="kpi_name" placeholder="KPI name" required />
      <textarea name="kpi_description" rows="2" placeholder="Description"></textarea>
      <select name="expectation_type">${option('tracked', 'Tracked', 'tracked')}${option('benchmarked', 'Benchmarked')}</select>
      <input name="target_min" type="number" step="any" placeholder="Target min" />
      <input name="target_max" type="number" step="any" placeholder="Target max" />
      <input name="target_unit" placeholder="Unit" />
      <button class="secondary-button" type="submit">Add KPI</button>
    </form>
  `;
}

function formatTarget(kpi) {
  if (kpi.target_min != null && kpi.target_max != null) return `${escapeHtml(kpi.target_min)} - ${escapeHtml(kpi.target_max)}${escapeHtml(kpi.target_unit || '')}`;
  if (kpi.target_value != null) return `> ${escapeHtml(kpi.target_value)}${escapeHtml(kpi.target_unit || '')}`;
  return '';
}

export function renderQuestionBankManager(
  framework,
  bank,
  questions,
  domains,
  activeSection,
  generatingQuestions,
  generatedDraft,
  panelMode,
  loading,
  error,
  { onBack, onAddQuestion, onUpdateQuestion, onDeleteQuestion, onReorderQuestions, onActivateBank, onSectionChange, onGenerateQuestions, onApproveDraftQuestion, onRejectDraftQuestion, onApproveAllDraft, onClearDraft } = {}
) {
  if (loading && !bank) return renderLoadingSkeleton('Loading question bank', 4);
  if (error && !bank) return renderScreenState('question-bank-manager', 'error', { title: 'Question bank could not be loaded', message: error });
  if (!bank) return renderScreenState('question-bank-manager', 'empty', { title: 'No question bank selected', message: 'Open a role bank to manage its questions.' });
  const list = array(questions);
  const sections = ['All', ...new Set(list.map((question) => question.section_name || question.section || 'General'))];
  const section = activeSection || 'All';
  const mode = panelMode || 'editor';
  const visible = section === 'All' ? list : list.filter((question) => (question.section_name || question.section || 'General') === section);
  return `
    <section class="panel framework-builder question-bank-manager">
      <div class="panel-header">
        <div>
          ${onBack ? '<button class="text-button" type="button" data-framework-action="bank-back">Back</button>' : ''}
          <h2>${escapeHtml(bank.role_name)}</h2>
          <span>${escapeHtml(framework?.name || '')} / ${Number(list.length)} questions ${coverageBadge(bank.coverage || {}, { compact: true })}</span>
        </div>
        <div class="action-row">
          ${pill(bank.status)}
          ${bank.status === 'draft' && list.length >= 5 && onActivateBank ? `<button class="primary-button" type="button" data-framework-action="activate-bank" data-bank-id="${escapeHtml(bank.id)}">Activate Bank</button>` : ''}
        </div>
      </div>
      ${error ? `
        <div style="
          background: rgba(224,100,80,0.08);
          border: 0.5px solid rgba(224,100,80,0.35);
          border-radius: 8px;
          padding: 10px 14px;
          color: #E07B5A;
          font-size: 13px;
          margin-bottom: 1rem;
        ">
          <strong>Generation failed:</strong>
          ${escapeHtml(error)}
          <button
            data-framework-action="clear-error"
            style="
              margin-left: 12px;
              background: none;
              border: none;
              color: #E07B5A;
              cursor: pointer;
              font-size: 12px;
              text-decoration: underline;
            ">Dismiss</button>
        </div>
      ` : ''}
      <div class="framework-builder-split">
        <aside class="card question-list-panel">
          ${renderCoverageBreakdown(bank.coverage || {})}
          <div class="tabs compact-tabs">
            ${sections.map((item) => `<button class="tab ${section === item ? 'active' : ''}" type="button" data-framework-section="${escapeHtml(item)}">${escapeHtml(item)}</button>`).join('')}
          </div>
          <div class="question-list">
            <div class="question-row" style="display:grid;grid-template-columns:1fr 74px 74px;gap:8px;align-items:center;font-size:10px;color:var(--color-text-faint);text-transform:uppercase;letter-spacing:0.06em;">
              <span>Question</span><span>Used</span><span>Rate</span>
            </div>
            ${visible.map((question) => {
              const effectiveness = question.effectiveness || {};
              const timesAsked = Number(effectiveness.times_asked || 0);
              const rate = timesAsked ? Math.round(Number(effectiveness.trigger_rate || 0) * 100) : null;
              return `
              <article class="question-row">
                <div style="display:grid;grid-template-columns:1fr 74px 74px;gap:8px;align-items:start;width:100%;">
                  <div>
                    <span class="badge">${escapeHtml(question.question_id || question.id)}</span>
                    <strong>${escapeHtml(question.question_text || '')}</strong>
                    <small>${escapeHtml(question.business_domain || question.response_type || '')} · ${escapeHtml(question.finding_strength || 'medium')}</small>
                    ${timesAsked >= 3 && rate === 0 ? '<small style="color:var(--color-accent);">This question has never triggered a finding. Consider replacing.</small>' : ''}
                    ${timesAsked === 0 ? '<small style="color:var(--color-text-faint);">New question. No effectiveness data yet.</small>' : ''}
                  </div>
                  <span>${timesAsked}</span>
                  <span>${rate === null ? '-' : `${rate}%`} ${effectivenessTag(effectiveness)}</span>
                </div>
                <div class="action-row">
                  <button class="text-button" type="button" data-framework-action="edit-question" data-question-id="${escapeHtml(question.id || question.question_id)}">Edit</button>
                  ${onDeleteQuestion ? `<button class="text-button danger" type="button" data-framework-action="delete-question" data-question-id="${escapeHtml(question.id || question.question_id)}">Delete</button>` : ''}
                </div>
              </article>
            `;
            }).join('') || renderScreenState('questions', 'empty', { title: 'No questions in this section', message: 'Add a question or generate draft questions.', compact: true })}
          </div>
          ${onAddQuestion ? '<button class="secondary-button" type="button" data-framework-action="new-question">+ Add Question</button>' : ''}
          <button class="secondary-button" type="button" data-framework-action="show-ai-panel">Generate with AI</button>
        </aside>
        <main class="card question-editor-panel">
          ${generatedDraft
            ? renderDraftReviewPanel(generatedDraft, Boolean(onApproveDraftQuestion), Boolean(onRejectDraftQuestion), Boolean(onApproveAllDraft), Boolean(onClearDraft))
            : mode === 'ai'
              ? renderAiPanel(framework, bank, questions, domains, generatingQuestions, Boolean(onGenerateQuestions))
              : renderQuestionEditor(section, Boolean(onAddQuestion || onUpdateQuestion))}
        </main>
      </div>
    </section>
  `;
}

function renderQuestionEditor(section, canSave) {
  return `
    <section>
      <h3>Question editor</h3>
      <form class="form" data-framework-form="question">
        <label>Section name<input name="section_name" value="${escapeHtml(section === 'All' ? '' : section)}" /></label>
        <label>Question text<textarea name="question_text" rows="4" required></textarea></label>
        <div class="form-grid">
          <label>Response type<select name="response_type">${['likert', 'single_choice', 'multiple_choice', 'free_text', 'scale_1_5', 'yes_no', 'ranking'].map((type) => option(type, type.replaceAll('_', ' '))).join('')}</select></label>
          <label>Required<select name="required">${option('true', 'Required', 'true')}${option('false', 'Optional')}</select></label>
        </div>
        <details>
          <summary>Analysis metadata</summary>
          <div class="form-grid">
            <input name="business_domain" placeholder="Business domain" />
            <input name="assessment_category" placeholder="Assessment category" />
            <select name="finding_strength">${option('high', 'High')}${option('medium', 'Medium', 'medium')}${option('low', 'Low')}</select>
            <select name="roadmap_relevance">${['quick_win', 'short_term', 'medium_term', 'long_term', 'strategic'].map((item) => option(item, item.replaceAll('_', ' '))).join('')}</select>
          </div>
          <input name="kpi_outputs" placeholder="KPI outputs, comma separated" />
          <input name="problem_types_detectable" placeholder="Problem types, comma separated" />
          <input name="impact_dimensions" placeholder="Impact dimensions, comma separated" />
          <input name="recommendation_triggers" placeholder="Recommendation triggers, comma separated" />
          <textarea name="ai_analysis_purpose" rows="3" placeholder="AI analysis purpose"></textarea>
        </details>
        <details>
          <summary>Follow-up</summary>
          <select name="follow_up_enabled">${option('false', 'Disabled', 'false')}${option('true', 'Enabled')}</select>
          <textarea name="follow_up_questions" rows="3" placeholder="Follow-up questions, one per line"></textarea>
          <textarea name="follow_up_logic" rows="3" placeholder="Follow-up logic JSON"></textarea>
        </details>
        <details>
          <summary>Gap analysis</summary>
          <select name="gap_calculation_enabled">${option('false', 'Disabled', 'false')}${option('true', 'Enabled')}</select>
          <input name="current_state_value" placeholder="Current state value" />
          <input name="desired_state_value" placeholder="Desired state value" />
        </details>
        ${canSave ? '<button class="primary-button" type="submit">Save Question</button>' : ''}
        <button class="text-button" type="reset">Cancel</button>
      </form>
    </section>
  `;
}

function renderAiPanel(framework, bank, questions = [], domains = [], generatingQuestions, canGenerate) {
  const activeDomains = array(domains).filter((domain) => domain.is_active !== false);
  const coverage = bank?.coverage || {};
  const missingDomains = array(coverage.breadth?.missing_domains);
  const distribution = coverage.domain_distribution || {};
  const shallowDomains = Object.entries(distribution)
    .filter(([domain, count]) => Number(count || 0) > 0 && Number(count || 0) < 5 && !missingDomains.includes(domain))
    .map(([domain]) => domain);
  const selectedKeys = new Set([...missingDomains, ...shallowDomains]);
  const sortedDomains = [...activeDomains].sort((a, b) => {
    const aKey = a.key;
    const bKey = b.key;
    const aRank = missingDomains.includes(aKey) ? 0 : shallowDomains.includes(aKey) ? 1 : 2;
    const bRank = missingDomains.includes(bKey) ? 0 : shallowDomains.includes(bKey) ? 1 : 2;
    if (aRank !== bRank) return aRank - bRank;
    return String(aKey || '').localeCompare(String(bKey || ''));
  });
  const suggestedCount = Math.min(40, Math.max(10, (missingDomains.length * 3) + (shallowDomains.length * 2)));
  const existingInBank = array(questions).length;
  const topMissing = missingDomains.slice(0, 3).join(', ');
  return `
    <section class="ai-generation-panel">
      <h3>Generate questions with AI</h3>
      <p>The generator uses role context, framework context, existing bank questions, and the domain taxonomy automatically. Review every question before saving it.</p>
      <dl class="summary-list">
        <div><dt>Generate questions for</dt><dd>${escapeHtml(bank?.role_name || '')}</dd></div>
        <div><dt>Framework</dt><dd>${escapeHtml(framework?.name || '')}</dd></div>
        <div><dt>Industry</dt><dd>${escapeHtml(framework?.industry || '')}</dd></div>
        <div><dt>Existing in bank</dt><dd>${existingInBank} question${existingInBank === 1 ? '' : 's'}</dd></div>
      </dl>
      ${missingDomains.length > 0 ? `
        <div style="
          background: rgba(224,100,80,0.08);
          border: 0.5px solid rgba(224,100,80,0.3);
          border-radius: 8px;
          padding: 10px 14px;
          margin-bottom: 1rem;
          font-size: 12px;
          color: rgba(232,228,220,0.8);
        ">
          <strong style="color:#E07B5A;">Coverage gaps detected:</strong>
          ${missingDomains.length} domains need questions.
          Generator will prioritize:
          ${escapeHtml(topMissing)}
          ${missingDomains.length > 3 ? `and ${missingDomains.length - 3} more` : ''}
        </div>
      ` : `
        <div style="
          background: rgba(100,180,100,0.08);
          border: 0.5px solid rgba(100,180,100,0.3);
          border-radius: 8px;
          padding: 10px 14px;
          margin-bottom: 1rem;
          font-size: 12px;
          color: rgba(140,210,140,0.8);
        ">
          Good breadth coverage. Generator will focus on depth.
        </div>
      `}
      <form class="form" data-framework-form="ai-generate">
        <div>
          <label style="display:block;margin-bottom:8px;">Target domains <span style="color:var(--color-text-faint);font-weight:400;">auto-selected, editable</span></label>
          <div style="display:grid;gap:8px;max-height:260px;overflow:auto;border:0.5px solid var(--color-border);border-radius:var(--radius-md);padding:10px;background:rgba(255,255,255,0.02);">
            ${sortedDomains.map((domain) => {
              const count = Number(distribution[domain.key] ?? domain.question_count ?? 0);
              const checked = selectedKeys.has(domain.key);
              const status = missingDomains.includes(domain.key)
                ? { label: `${count} in bank, breadth gap`, color: '#E07B5A' }
                : shallowDomains.includes(domain.key)
                  ? { label: `${count} in bank, depth gap`, color: '#D9974A' }
                  : { label: `${count} in bank, well covered`, color: 'rgba(140,210,140,0.9)' };
              return `
                <label style="display:grid;grid-template-columns:auto 1fr;gap:9px;align-items:start;margin:0;color:var(--color-text);">
                  <input type="checkbox" name="target_domains" value="${escapeHtml(domain.key)}" ${checked ? 'checked' : ''} style="width:auto;margin-top:2px;" />
                  <span>
                    <strong style="font-size:12px;">${escapeHtml(domain.key)}</strong>
                    <small style="display:block;color:${status.color};">${escapeHtml(status.label)} · ${escapeHtml(domain.name || domain.category || '')}</small>
                  </span>
                </label>
              `;
            }).join('') || '<p class="upload-note">No domains loaded yet. Reopen the framework after domain taxonomy loads.</p>'}
          </div>
        </div>
        <label>Questions to generate
          <input type="range" name="count" min="5" max="40" step="1" value="${suggestedCount}" oninput="this.nextElementSibling.value = this.value" />
          <output>${suggestedCount}</output>
        </label>
        <div>
          <label style="display:block;margin-bottom:8px;">Finding strength</label>
          <div class="segmented-control">
            ${['High', 'Mixed', 'Low'].map((strength) => `<label><input type="radio" name="finding_strength_target" value="${strength.toLowerCase()}" ${strength === 'Mixed' ? 'checked' : ''} /> ${strength}</label>`).join('')}
          </div>
        </div>
        <button class="secondary-button" type="submit" ${canGenerate && !generatingQuestions ? '' : 'disabled'}>${generatingQuestions ? 'Generating questions...' : 'Generate Questions'}</button>
        ${generatingQuestions ? '<p class="upload-note"><span class="spinner"></span> Generating questions for review...</p>' : ''}
      </form>
    </section>
  `;
}

function renderDraftReviewPanel(generatedDraft, canApprove, canReject, canApproveAll, canClearDraft) {
  const drafts = array(generatedDraft);
  const approved = drafts.filter((question) => question._status === 'approved').length;
  const rejected = drafts.filter((question) => question._status === 'rejected').length;
  const pending = drafts.filter((question) => !question._status || question._status === 'pending').length;
  return `
    <section class="draft-review-panel">
      <div class="panel-header compact">
        <div>
          <h3>Review generated questions</h3>
          <span>Save questions to add them to the bank. Skip ones that don't fit. You can edit any question before saving.</span>
        </div>
        ${canApproveAll ? `<button class="primary-button" type="button" data-framework-action="approve-all-draft" ${pending > 0 ? '' : 'disabled'}>Save All Remaining</button>` : ''}
      </div>
      <div class="stats-row">
        <span>${drafts.length} questions generated</span>
        <span>${approved} saved</span>
        <span>${rejected} skipped</span>
      </div>
      <div class="draft-question-list">
        ${drafts.map((question, index) => renderDraftQuestionCard(question, index, { canApprove, canReject })).join('')}
      </div>
      <div class="action-row">
        ${canClearDraft ? '<button class="secondary-button" type="button" data-framework-action="clear-draft">← Back to generator</button>' : ''}
        ${canApproveAll ? `<button class="primary-button" type="button" data-framework-action="approve-all-draft" ${pending > 0 ? '' : 'disabled'}>Save all (${pending})</button>` : ''}
      </div>
    </section>
  `;
}

function renderDraftQuestionCard(question, index, { canApprove, canReject } = {}) {
  const status = question._status || 'pending';
  const localId = question._localId || String(index);
  return `
    <article class="card draft-question-card draft-${escapeHtml(status)}" data-draft-card="${escapeHtml(localId)}">
      <div class="meta-row">
        <span class="badge">${escapeHtml(status[0].toUpperCase() + status.slice(1))}</span>
        <span class="badge">DRAFT</span>
        <span class="badge">${escapeHtml(question.response_type || '')}</span>
        <span class="badge">${escapeHtml(question.finding_strength || 'medium')}</span>
      </div>
      <label>
        Question text
        <textarea rows="3" data-draft-field="question_text" data-draft-id="${escapeHtml(localId)}" ${status === 'rejected' ? 'disabled' : ''}>${escapeHtml(question.question_text || '')}</textarea>
      </label>
      <label>
        Section name
        <input data-draft-field="section_name" data-draft-id="${escapeHtml(localId)}" value="${escapeHtml(question.section_name || '')}" ${status === 'rejected' ? 'disabled' : ''} />
      </label>
      <details>
        <summary>Analysis metadata</summary>
        <dl class="summary-list">
          <div><dt>Business domain</dt><dd>${escapeHtml(question.business_domain || '')}</dd></div>
          <div><dt>Assessment category</dt><dd>${escapeHtml(question.assessment_category || '')}</dd></div>
          <div><dt>KPI outputs</dt><dd>${array(question.kpi_outputs).map((item) => `<span class="badge">${escapeHtml(item)}</span>`).join('')}</dd></div>
          <div><dt>Problem types</dt><dd>${array(question.problem_types_detectable).map((item) => `<span class="badge">${escapeHtml(item)}</span>`).join('')}</dd></div>
          <div><dt>Recommendation triggers</dt><dd>${array(question.recommendation_triggers).map((item) => `<span class="badge">${escapeHtml(item)}</span>`).join('')}</dd></div>
          <div><dt>Purpose</dt><dd>${escapeHtml(question.ai_analysis_purpose || '')}</dd></div>
        </dl>
      </details>
      <div class="action-row">
        ${status === 'pending' && canApprove ? `<button class="primary-button" type="button" data-framework-action="approve-draft" data-draft-id="${escapeHtml(localId)}">Save</button>` : ''}
        ${status === 'pending' && canReject ? `<button class="secondary-button" type="button" data-framework-action="reject-draft" data-draft-id="${escapeHtml(localId)}">Skip</button>` : ''}
        ${status !== 'pending' ? `<button class="text-button" type="button" data-framework-action="undo-draft" data-draft-id="${escapeHtml(localId)}">Undo</button>` : ''}
      </div>
    </article>
  `;
}

export function renderFrameworkPreview(
  framework,
  banks,
  kpis,
  readiness,
  activating,
  { onBack, onActivate, onOpenBank } = {}
) {
  const bankList = array(banks);
  const kpiList = flatKpis(kpis);
  const requiredBanks = bankList.filter((bank) => bank.requirement === 'required');
  const recommendedBanks = bankList.filter((bank) => bank.requirement === 'recommended');
  const optionalBanks = bankList.filter((bank) => bank.requirement === 'optional');
  const totalQuestions = bankList.reduce((sum, bank) => sum + Number(bank.question_count || 0), 0);
  const domains = new Set(kpiList.map((kpi) => kpi.domain_name).filter(Boolean));
  const readyRequired = requiredBanks.filter((bank) => bank.status === 'active' && Number(bank.question_count || 0) >= 5).length;
  const blockers = array(readiness?.blockers);
  return `
    <section class="panel framework-builder framework-preview">
      <div class="panel-header">
        <div>
          ${onBack ? '<button class="text-button" type="button" data-framework-action="preview-back">Back</button>' : ''}
          <h2>${escapeHtml(framework?.name || 'Framework Preview')}</h2>
          <span>Readiness checklist</span>
        </div>
        ${pill(framework?.status)}
      </div>
      <section class="card">
        <h3>Roles</h3>
        ${renderBankChecklist(requiredBanks, 'Required', onOpenBank)}
        ${renderBankChecklist(recommendedBanks, 'Recommended', onOpenBank)}
        ${renderBankChecklist(optionalBanks, 'Optional', onOpenBank)}
      </section>
      <section class="card">
        <h3>Domains & KPIs</h3>
        <p>${domains.size > 0 ? 'Complete' : 'Missing'} - ${domains.size} domains defined</p>
        <p>${kpiList.length > 0 ? 'Complete' : 'Missing'} - ${kpiList.length} KPI expectations set</p>
      </section>
      <section class="card">
        <h3>Summary</h3>
        <p>Total participants expected: ${requiredBanks.length + recommendedBanks.length}</p>
        <p>Total questions: ${totalQuestions}</p>
        <p>Estimated completion time: ${estimateMinutes(totalQuestions)}</p>
        <p>Coverage: ${readyRequired} of ${requiredBanks.length} required roles ready</p>
      </section>
      ${renderFrameworkCoverageReport(bankList, onOpenBank)}
      ${readiness?.ready_to_activate ? `
        <section class="success-banner">
          <h3>This framework is ready to activate.</h3>
          <p>Once active, consultants can select it when setting up new assessments. Existing assessments are not affected.</p>
          ${onActivate ? `<button class="primary-button" type="button" data-framework-action="activate-framework" ${activating ? 'disabled' : ''}>${activating ? 'Activating...' : 'Activate Framework'}</button>` : ''}
        </section>
      ` : `
        <section class="warning-banner">
          <h3>This framework cannot be activated yet.</h3>
          <ul>${blockers.map((blocker) => `<li>${escapeHtml(blocker)} ${onOpenBank ? '<span>Fix</span>' : ''}</li>`).join('') || '<li>Complete the required roles and KPI expectations.</li>'}</ul>
        </section>
      `}
    </section>
  `;
}

function renderFrameworkCoverageReport(banks, onOpenBank) {
  const scored = array(banks).filter((bank) => bank.coverage);
  if (!scored.length) return '';
  const overall = Math.round(scored.reduce((sum, bank) => sum + Number(bank.coverage.total || 0), 0) / scored.length);
  const overallGrade = overall >= 90 ? 'A' : overall >= 80 ? 'B' : overall >= 70 ? 'C' : overall >= 60 ? 'D' : 'F';
  const flagged = scored.filter((bank) => ['D', 'F'].includes(bank.coverage.grade) || array(bank.coverage.flags).length);
  return `
    <section class="card framework-coverage-report">
      <div class="panel-header compact">
        <div>
          <h3>Framework coverage analysis</h3>
          <span>Overall score: ${overall}/100 ${escapeHtml(overallGrade)}</span>
        </div>
        ${coverageBadge({ overall_score: overall, grade: overallGrade })}
      </div>
      <div style="height:8px;background:rgba(255,255,255,0.06);border-radius:999px;overflow:hidden;margin:12px 0 18px;">
        <span style="display:block;height:100%;width:${overall}%;background:${coverageColor(overall)};"></span>
      </div>
      <div class="table-scroll">
        <table class="compact-table">
          <thead><tr><th>Role</th><th>Questions</th><th>Domains</th><th>Score</th><th>Grade</th></tr></thead>
          <tbody>
            ${scored.map((bank) => `
              <tr>
                <td>${escapeHtml(bank.role_name)}</td>
                <td>${Number(bank.question_count || 0)}</td>
                <td>${array(bank.coverage.domains?.covered).length}/9</td>
                <td>${Number(bank.coverage.total || 0)}</td>
                <td>${coverageBadge(bank.coverage, { compact: true })}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
      </div>
      ${flagged.length ? `
        <div style="margin-top:18px;">
          <h4>Issues requiring attention</h4>
          <ul>${flagged.map((bank) => `<li>${escapeHtml(bank.role_name)}: ${array(bank.coverage.flags).map(escapeHtml).join(', ') || `Grade ${escapeHtml(bank.coverage.grade)}`}</li>`).join('')}</ul>
        </div>
        <div style="margin-top:18px;">
          <h4>Recommendations</h4>
          ${flagged.map((bank) => `
            <article class="upload-result" style="margin-top:8px;">
              <strong>${escapeHtml(bank.role_name)} bank needs attention</strong>
              <p>${array(bank.coverage.flags).map(escapeHtml).join(', ') || 'Coverage score needs improvement.'}</p>
              ${onOpenBank ? `<button class="secondary-button" type="button" data-framework-action="open-bank" data-bank-id="${escapeHtml(bank.id)}">Generate questions for ${escapeHtml(bank.role_name)} →</button>` : ''}
            </article>
          `).join('')}
        </div>
      ` : '<p class="upload-note">No coverage issues require attention.</p>'}
    </section>
  `;
}

function renderBankChecklist(banks, label, onOpenBank) {
  if (!banks.length) return '';
  return `
    <div class="bank-checklist">
      <h4>${escapeHtml(label)}</h4>
      ${banks.map((bank) => {
        const ready = bank.status === 'active' && Number(bank.question_count || 0) >= 5;
        return `
          <div class="check-row">
            <span>${ready ? 'Complete' : label === 'Required' ? 'Needs work' : 'Optional'}</span>
            <strong>${escapeHtml(bank.role_name)}</strong>
            <span>${Number(bank.question_count || 0)} questions</span>
            ${onOpenBank ? `<button class="text-button" type="button" data-framework-action="open-bank" data-bank-id="${escapeHtml(bank.id)}">Fix</button>` : ''}
          </div>
        `;
      }).join('')}
    </div>
  `;
}
