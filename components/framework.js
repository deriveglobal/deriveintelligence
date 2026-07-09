import {
  renderScreenState,
  escapeHtml
} from '../shared.js';

export function renderQuestionBankCoverageComponent(
  roles = [],
  activeRoleId = '',
  emptyStateHtml = '',
  { onSelectRole } = {}
) {
  if (!roles.length) return emptyStateHtml || renderScreenState('question-bank', 'empty', { compact: true });
  const total = roles.reduce((sum, role) => sum + Number(role.questions?.length || 0), 0);
  const generated = roles.filter((role) => role.questions?.length).length;
  const groups = [...new Set(roles.map((role) => role.group || 'Ungrouped'))];
  return `
    <div class="question-bank-total">${total} questions · ${generated}/${roles.length} relevant roles ready</div>
    ${groups.map((group) => {
      const groupRoles = roles.filter((role) => (role.group || 'Ungrouped') === group);
      return `
        <section class="question-bank-group">
          <div class="question-bank-group-header">
            <h3>${escapeHtml(group)}</h3>
            <span>${groupRoles.filter((role) => role.questions?.length).length}/${groupRoles.length} ready</span>
          </div>
          <div class="question-bank-role-grid">
            ${groupRoles.map((role) => {
              const initials = String(role.role || role.name || '')
                .split(' ')
                .map((part) => part[0])
                .join('')
                .slice(0, 2)
                .toUpperCase();
              const statusText = role.questions?.length ? `${role.questions.length} Q` : 'Empty';
              const roleId = role.key || role.id || role.roleId || '';
              return `
                <button class="question-bank-role-card ${roleId === activeRoleId ? 'active' : ''} ${role.questions?.length ? 'ready' : 'empty'}" ${onSelectRole ? `data-component-question-bank-role="${escapeHtml(roleId)}"` : ''} type="button">
                  <span class="role-avatar">${escapeHtml(initials)}</span>
                  <span class="role-chip-copy">
                    <strong>${escapeHtml(role.role || role.name || roleId)}</strong>
                    <small>${escapeHtml(role.group || '')}</small>
                  </span>
                  <span class="role-chip-status">${escapeHtml(role.version === 'pending' ? statusText : role.version || statusText)}</span>
                </button>
              `;
            }).join('')}
          </div>
        </section>
      `;
    }).join('')}
  `;
}

export function renderQuestionBankDetailComponent(activeRole, emptyStateHtml = '') {
  if (!activeRole) return emptyStateHtml || renderScreenState('question-bank', 'empty', { compact: true });
  const questions = activeRole.questions || [];
  if (!questions.length) {
    return `
      <article class="question-bank-empty">
        <strong>${escapeHtml(activeRole.role || activeRole.name || 'Selected role')} question bank has not been generated yet.</strong>
        <p>This role is intentionally visible so the platform shows the full assessment architecture. We will add questions stakeholder by stakeholder instead of creating weak generic content.</p>
      </article>
    `;
  }
  const sections = [...new Set(questions.map((question) => question.section || 'General'))];
  const responseTypeCounts = questions.reduce((acc, question) => {
    acc[question.response_type || 'open_text'] = (acc[question.response_type || 'open_text'] || 0) + 1;
    return acc;
  }, {});
  return `
    <div class="question-bank-header">
      <h3>${escapeHtml(`${activeRole.role || activeRole.name || ''} ${activeRole.version === 'pending' ? '' : activeRole.version || ''}`.trim())}</h3>
      <span>${questions.length} production questions · ${escapeHtml(activeRole.group || '')}</span>
    </div>
    <div class="question-bank-summary">
      <article><strong>${questions.length}</strong><span>Total Questions</span></article>
      <article><strong>${sections.length}</strong><span>Sections</span></article>
      <article><strong>${Object.keys(responseTypeCounts).length}</strong><span>Response Types</span></article>
      <article><strong>${questions.filter((question) => Object.keys(question.score_mapping || {}).length).length}</strong><span>Scored Questions</span></article>
    </div>
    <div class="tag-list question-bank-types">
      ${Object.entries(responseTypeCounts).map(([type, count]) => `<span>${escapeHtml(type)}: ${count}</span>`).join('')}
    </div>
    ${sections.map((section) => `
      <section class="question-bank-section">
        <div class="question-bank-section-header">
          <h3>${escapeHtml(section)}</h3>
          <span>${questions.filter((question) => (question.section || 'General') === section).length} questions</span>
        </div>
        <div class="question-bank-question-list">
          ${questions.filter((question) => (question.section || 'General') === section).map((question) => `
            <article class="question-bank-question">
              <div class="question-bank-question-main">
                <span class="eyebrow">${escapeHtml(question.question_id || '')} · ${escapeHtml(question.response_type || '')}</span>
                <h4>${escapeHtml(question.question_text || '')}</h4>
                <div class="tag-list">
                  <span>${escapeHtml(question.business_domain || '')}</span>
                  <span>${escapeHtml(question.assessment_category || '')}</span>
                  <span>${escapeHtml(question.roadmap_relevance || '')}</span>
                  <span>${escapeHtml(question.finding_strength || 'medium')} strength</span>
                </div>
              </div>
              <div class="question-bank-meta-grid">
                <div><strong>KPI Outputs</strong><span>${(question.kpi_outputs || []).map(escapeHtml).join(', ') || 'None'}</span></div>
                <div><strong>Problem Types</strong><span>${(question.problem_types_detectable || []).map(escapeHtml).join(', ') || 'None'}</span></div>
                <div><strong>Impact</strong><span>${(question.impact_dimensions || []).map(escapeHtml).join(', ') || 'None'}</span></div>
                <div><strong>Maturity</strong><span>${(question.maturity_dimensions || []).map(escapeHtml).join(', ') || 'None'}</span></div>
              </div>
              <details class="question-bank-details">
                <summary>AI metadata and follow-ups</summary>
                <p>${escapeHtml(question.ai_analysis_purpose || '')}</p>
                <div class="question-bank-meta-grid">
                  <div><strong>Options</strong><span>${(question.options || []).map(escapeHtml).join(', ') || 'Free response'}</span></div>
                  <div><strong>Score Mapping</strong><span>${Object.keys(question.score_mapping || {}).length ? escapeHtml(JSON.stringify(question.score_mapping)) : 'No direct score mapping'}</span></div>
                  <div><strong>Follow-ups</strong><span>${(question.follow_up_questions || []).map(escapeHtml).join(' | ') || 'None'}</span></div>
                  <div><strong>Recommendation Triggers</strong><span>${(question.recommendation_triggers || []).map(escapeHtml).join(', ') || 'None'}</span></div>
                  <div><strong>Finding Strength</strong><span>${escapeHtml(question.finding_strength || 'medium')}</span></div>
                  <div><strong>Gap Logic</strong><span>${question.gap_analysis ? `${escapeHtml(question.gap_analysis.current_state_value)} -> ${escapeHtml(question.gap_analysis.desired_state_value)}; ${escapeHtml(question.gap_analysis.gap_value)}` : 'Not applicable'}</span></div>
                </div>
              </details>
            </article>
          `).join('')}
        </div>
      </section>
    `).join('')}
  `;
}

export function renderQuestionBankComponent(
  roles = [],
  activeRoleId = '',
  activeRole = null,
  emptyStateHtml = '',
  { onSelectRole } = {}
) {
  return `
    <section class="framework-workspace">
      <div id="question-bank-coverage">
        ${renderQuestionBankCoverageComponent(roles, activeRoleId, emptyStateHtml, { onSelectRole })}
      </div>
      <div id="question-bank-detail">
        ${renderQuestionBankDetailComponent(activeRole, emptyStateHtml)}
      </div>
    </section>
  `;
}
