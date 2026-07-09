import {
  renderScreenState,
  escapeHtml
} from '../shared.js';

function organizationDisplayName(project = {}) {
  return project.clientDisplayName || project.organizationName || project.name || 'Organization';
}

function getOrgMonogram(name) {
  if (!name) return '??';
  const words = name.trim().split(/\s+/);
  return words
    .map((word) => word[0] || '')
    .join('')
    .toUpperCase()
    .slice(0, 3);
}

function truncateMeta(value = '', maxLength = 60) {
  const text = String(value || '').trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 3)).trim()}...`;
}

function organizationHealthScore(project = {}) {
  return project.healthScore
    ?? project.businessHealthScore
    ?? project.business_health_score
    ?? project.health_score
    ?? null;
}

export function renderOrganizationsComponent(
  projects = [],
  activeProjectId = '',
  emptyStateHtml = '',
  {
    onOpenOrganization,
    onCreateOrganization
  } = {}
) {
  const organizationCount = Number(projects.length || 0);
  const createButton = onCreateOrganization ? `
    <button
      data-component-create-organization
      type="button"
      style="background:#C8A96E;color:#1a1608;font-size:13px;font-weight:500;padding:8px 14px;border-radius:8px;border:none;display:flex;align-items:center;gap:6px;cursor:pointer;"
    >
      <i class="ti ti-plus" style="font-size:15px;"></i>
      <span>New organization</span>
    </button>
  ` : '';

  if (!projects.length) {
    return `
      <section class="organization-list" style="display:flex;flex-direction:column;gap:10px;">
        <div class="organization-list-header" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem;">
          <div>
            <h2 style="font-size:18px;font-weight:500;color:#E8E4DC;margin:0;">Organization Workspaces</h2>
            <p style="font-size:13px;color:rgba(200,169,110,0.6);margin:2px 0 0;">0 organizations &middot; Platform workspace</p>
          </div>
          ${createButton}
        </div>
        ${emptyStateHtml || renderScreenState('projects', 'empty')}
      </section>
    `;
  }

  return `
    <section class="organization-list" style="display:flex;flex-direction:column;gap:10px;">
      <div class="organization-list-header" style="display:flex;justify-content:space-between;align-items:center;margin-bottom:1.5rem;">
        <div>
          <h2 style="font-size:18px;font-weight:500;color:#E8E4DC;margin:0;">Organization Workspaces</h2>
          <p style="font-size:13px;color:rgba(200,169,110,0.6);margin:2px 0 0;">${organizationCount} ${organizationCount === 1 ? 'organization' : 'organizations'} &middot; Platform workspace</p>
        </div>
        ${createButton}
      </div>
      ${projects.map((project) => {
        const name = organizationDisplayName(project);
        const language = String(project.defaultLanguage || 'en').toUpperCase();
        const responseCount = Number(project.responseCount || 0);
        const assignmentCount = Number(project.assignmentCount || 0);
        const healthScore = organizationHealthScore(project);
        const status = String(project.status || 'active');
        const isActive = status.toLowerCase() === 'active';
        const isSelected = String(activeProjectId || '') === String(project.id || '');
        return `
        <article
          class="org-card ${isSelected ? 'active' : ''}"
          data-component-open-organization="${escapeHtml(project.id)}"
          role="${onOpenOrganization ? 'button' : 'article'}"
          tabindex="${onOpenOrganization ? '0' : '-1'}"
          style="background:#111109;border:0.5px solid rgba(200,169,110,0.18);border-left:3px solid #C8A96E;border-radius:12px;padding:1rem 1.25rem;display:flex;align-items:center;gap:1rem;cursor:${onOpenOrganization ? 'pointer' : 'default'};transition:border-color 0.15s;margin-bottom:10px;"
          onmouseenter="this.style.borderColor='rgba(200,169,110,0.45)';this.querySelector('.org-arrow').style.color='#C8A96E';"
          onmouseleave="this.style.borderColor='rgba(200,169,110,0.18)';this.querySelector('.org-arrow').style.color='rgba(200,169,110,0.4)';"
        >
          <div class="org-accent" style="width:38px;height:38px;border-radius:8px;background:rgba(200,169,110,0.12);display:flex;align-items:center;justify-content:center;flex-shrink:0;">
            <span style="font-size:13px;font-weight:500;color:#C8A96E;letter-spacing:0.02em;">${escapeHtml(getOrgMonogram(name))}</span>
          </div>

          <div class="org-main" style="flex:1;min-width:0;">
            <div style="display:flex;align-items:center;min-width:0;">
              <span style="font-size:15px;font-weight:500;color:#E8E4DC;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(name)}</span>
              <span style="display:inline-flex;padding:2px 7px;font-size:11px;border-radius:4px;background:rgba(200,169,110,0.08);color:rgba(200,169,110,0.5);border:0.5px solid rgba(200,169,110,0.15);margin-left:6px;flex-shrink:0;">${escapeHtml(language)}</span>
            </div>
            <p style="font-size:12px;color:rgba(200,169,110,0.6);margin:2px 0 0;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">${escapeHtml(truncateMeta(project.industryContext || 'Digital transformation assessment workspace.'))}</p>
          </div>

          <div class="org-stats" style="display:flex;align-items:center;gap:20px;flex-shrink:0;">
            <div class="stat" style="text-align:center;">
              <div class="stat-val" style="font-size:18px;font-weight:500;color:${responseCount > 0 ? '#C8A96E' : '#E8E4DC'};line-height:1;">${responseCount}</div>
              <div class="stat-lbl" style="font-size:11px;color:rgba(232,228,220,0.35);margin-top:3px;letter-spacing:0.04em;text-transform:uppercase;">Responses</div>
            </div>
            <div style="width:0.5px;height:28px;background:rgba(200,169,110,0.15);"></div>
            <div class="stat" style="text-align:center;">
              <div class="stat-val" style="font-size:18px;font-weight:500;color:#E8E4DC;line-height:1;">${assignmentCount}</div>
              <div class="stat-lbl" style="font-size:11px;color:rgba(232,228,220,0.35);margin-top:3px;letter-spacing:0.04em;text-transform:uppercase;">Assigned</div>
            </div>
            <div style="width:0.5px;height:28px;background:rgba(200,169,110,0.15);"></div>
            <div class="stat" style="text-align:center;">
              <div class="stat-val" style="font-size:18px;font-weight:500;color:#E8E4DC;line-height:1;">${healthScore === null || healthScore === undefined || healthScore === '' ? '&mdash;' : escapeHtml(healthScore)}</div>
              <div class="stat-lbl" style="font-size:11px;color:rgba(232,228,220,0.35);margin-top:3px;letter-spacing:0.04em;text-transform:uppercase;">Health</div>
            </div>
          </div>

          <div class="org-status" style="display:flex;align-items:center;gap:6px;margin-left:8px;flex-shrink:0;">
            <span style="width:6px;height:6px;border-radius:50%;background:${isActive ? '#C8A96E' : '#444'};"></span>
            <span style="font-size:11px;letter-spacing:0.05em;text-transform:uppercase;color:${isActive ? 'rgba(200,169,110,0.6)' : 'rgba(200,200,200,0.3)'};">${escapeHtml(status)}</span>
          </div>

          <i class="ti ti-chevron-right org-arrow" style="font-size:18px;color:rgba(200,169,110,0.4);margin-left:8px;flex-shrink:0;"></i>
        </article>
      `;
      }).join('')}
    </section>
  `;
}
