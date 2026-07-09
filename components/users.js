import {
  renderScreenState,
  escapeHtml
} from '../shared.js';

function roleDisplayName(role = '') {
  const labels = {
    platform_owner: 'Platform Owner',
    consultant: 'Consultant',
    company_owner: 'Company Owner',
    assessment_manager: 'Assessment Manager',
    participant: 'Participant'
  };
  return labels[role] || String(role || '').replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function projectDisplayName(project = {}) {
  return project.clientDisplayName || project.organizationName || project.name || 'Organization';
}

export function renderProjectAccessOptionsComponent(projects = [], activeProjectId = '') {
  const currentId = activeProjectId || projects[0]?.id || '';
  return projects
    .map((project) => `<option value="${escapeHtml(project.id)}" ${String(project.id) === String(currentId) ? 'selected' : ''}>${escapeHtml(projectDisplayName(project))}</option>`)
    .join('');
}

export function renderUserRolesComponent(
  users = {},
  projects = [],
  activeProjectId = '',
  emptyStateHtml = '',
  {
    onEditUser,
    onSendCredentials,
    onSetUserStatus,
    onAssignProject
  } = {}
) {
  const rows = Array.isArray(users) ? users : Object.values(users || {});
  const projectById = new Map((projects || []).map((project) => [String(project.id), project]));
  if (!rows.length) {
    return emptyStateHtml || `<tr><td colspan="6">No users yet. Create users from this screen and assign them to a project.</td></tr>`;
  }
  return rows.map((user) => {
    const userKey = user.email || user.id || '';
    const assignedProject = projectById.get(String(user.projectId || user.project_id || '')) || projectById.get(String(activeProjectId || ''));
    return `
      <tr>
        <td>${escapeHtml(user.name || '-')}</td>
        <td>${escapeHtml(user.email || '-')}</td>
        <td>
          ${onAssignProject ? `
            <select data-component-user-project="${escapeHtml(user.id || userKey)}">
              ${renderProjectAccessOptionsComponent(projects, user.projectId || user.project_id || activeProjectId)}
            </select>
          ` : escapeHtml(projectDisplayName(assignedProject || {}))}
        </td>
        <td>${escapeHtml(roleDisplayName(user.role))}</td>
        <td>${escapeHtml(user.status || '-')}${user.credentialsSentAt ? `<br><small>Sent ${new Date(user.credentialsSentAt).toLocaleString()}</small>` : ''}</td>
        <td>
          <div class="row-actions">
            ${onEditUser ? `<button class="ghost-button" data-component-edit-user="${escapeHtml(userKey)}" type="button">Edit</button>` : ''}
            ${onSendCredentials ? `<button class="ghost-button" data-component-send-credentials="${escapeHtml(user.id || userKey)}" type="button">Send Credentials</button>` : ''}
            ${onSetUserStatus ? (user.status === 'disabled'
              ? `<button class="ghost-button" data-component-user-status="${escapeHtml(user.id || userKey)}" data-status-value="active" type="button">Reactivate</button>`
              : `<button class="ghost-button" data-component-user-status="${escapeHtml(user.id || userKey)}" data-status-value="disabled" type="button">Disable</button>`)
              : ''}
          </div>
        </td>
      </tr>
    `;
  }).join('');
}
