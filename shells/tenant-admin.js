// shells/tenant-admin.js — Derive Platform Tenant Admin Shell  v2
// Exported: initTenantAdminSurface(container, me, callbacks)
//
// Views: Overview · Team · Invite · Permissions
// v2 adds: role change, deactivate/reactivate, pending invitations management

export function initTenantAdminSurface(container, me, callbacks) {
  const { apiFetch, switchToModule } = callbacks;
  let currentView = "overview";
  let tenantData = null;
  let usersData = [];

  // ─── Render skeleton ───────────────────────────────────────────────────
  container.innerHTML = `
    <aside class="ta-sidebar">
      <div class="ta-logo">
        <svg width="28" height="28" viewBox="0 0 32 32" fill="none">
          <rect width="32" height="32" rx="8" fill="#1a1a2e"/>
          <path d="M8 16h4l3-8 4 16 3-8h4" stroke="#e2b04a" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
        </svg>
        <span>Tenant Admin</span>
      </div>
      <nav class="ta-nav">
        <button class="ta-nav-btn active" data-view="overview">
          <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><rect x="3" y="3" width="7" height="7" rx="1"/><rect x="14" y="3" width="7" height="7" rx="1"/><rect x="3" y="14" width="7" height="7" rx="1"/><rect x="14" y="14" width="7" height="7" rx="1"/></svg>
          Genel Bakış
        </button>
        <button class="ta-nav-btn" data-view="team">
          <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><path d="M17 21v-2a4 4 0 00-4-4H5a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 00-3-3.87M16 3.13a4 4 0 010 7.75"/></svg>
          Ekip
        </button>
        <button class="ta-nav-btn" data-view="invite">
          <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><path d="M16 21v-2a4 4 0 00-4-4H6a4 4 0 00-4 4v2"/><circle cx="9" cy="7" r="4"/><line x1="19" y1="8" x2="19" y2="14"/><line x1="22" y1="11" x2="16" y2="11"/></svg>
          Davet Et
        </button>
        <button class="ta-nav-btn" data-view="permissions">
          <svg width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.8" viewBox="0 0 24 24"><rect x="3" y="11" width="18" height="11" rx="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
          İzinler
        </button>
      </nav>
      <div class="ta-sidebar-footer">
        <span class="ta-tenant-badge">${esc(me.tenantName || "Şirket")}</span>
        // [patch: admin-back-btn]
        <button class="ta-back-btn" id="ta-back-btn" title="Intelligence'a Dön">
          <svg width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" viewBox="0 0 24 24"><path d="M19 12H5M12 5l-7 7 7 7"/></svg>
          Intelligence
        </button>
      </div>
    </aside>
    <main class="ta-main">
      <header class="ta-header">
        <h1 class="ta-title" id="ta-view-title">Genel Bakış</h1>
        <div class="ta-header-actions" id="ta-header-actions"></div>
      </header>
      <div class="ta-content" id="ta-content">
        <div class="ta-loading">Yükleniyor…</div>
      </div>
    </main>
    <style>${taStyles()}</style>
  `;

  // ─── Nav routing ───────────────────────────────────────────────────────
  container.querySelectorAll(".ta-nav-btn").forEach(btn => {
    btn.addEventListener("click", () => {
      container.querySelectorAll(".ta-nav-btn").forEach(b => b.classList.remove("active"));
      btn.classList.add("active");
      currentView = btn.dataset.view;
      renderView(currentView);
    });
  });

  renderView("overview");

  container.querySelector("#ta-back-btn")?.addEventListener("click", () => {
    container.style.display = "none";
    const biSurface = document.getElementById("bi-surface");
    if (biSurface) biSurface.style.display = "block";
    else if (typeof callbacks.switchToModule === "function") callbacks.switchToModule("intelligence");
  });

  // ─── View dispatcher ───────────────────────────────────────────────────
  async function renderView(view) {
    const content = document.getElementById("ta-content");
    const title   = document.getElementById("ta-view-title");
    const actions = document.getElementById("ta-header-actions");
    content.innerHTML = `<div class="ta-loading">Yükleniyor…</div>`;
    actions.innerHTML = "";

    const viewMap = {
      overview:    { label: "Genel Bakış",       fn: renderOverview },
      team:        { label: "Ekip Yönetimi",      fn: renderTeam },
      invite:      { label: "Kullanıcı Davet Et", fn: renderInvite },
      permissions: { label: "Modül İzinleri",     fn: renderPermissions }
    };
    const v = viewMap[view];
    if (!v) return;
    title.textContent = v.label;
    try { await v.fn(content, actions); }
    catch (err) {
      content.innerHTML = `<div class="ta-error">Yüklenemedi: ${esc(err.message)}</div>`;
    }
  }

  // ─── Overview ──────────────────────────────────────────────────────────
  async function renderOverview(content) {
    const [tenant, usage] = await Promise.all([
      apiFetch("/api/tenant/me"),
      apiFetch("/api/tenant/usage")
    ]);
    tenantData = tenant;

    const subs = tenant.subscriptions || [];
    const moduleCards = subs.map(s => {
      const used     = usage.find(u => u.module_id === s.module_id);
      const seats    = used?.seats_used || 0;
      const max      = used?.max_seats || "∞";
      const lastIngest = used?.last_ingest
        ? new Date(used.last_ingest).toLocaleDateString("tr-TR") : "—";
      return `
        <div class="ta-card ta-module-card">
          <div class="ta-card-header">
            <span class="ta-badge ta-badge-${s.status}">${s.status.toUpperCase()}</span>
            <strong>${moduleLabel(s.module_id)}</strong>
          </div>
          <div class="ta-card-body">
            <div class="ta-stat"><label>Plan</label><span>${esc(s.plan_key)}</span></div>
            <div class="ta-stat"><label>Kullanıcı</label><span>${seats} / ${max}</span></div>
            <div class="ta-stat"><label>Son Veri</label><span>${lastIngest}</span></div>
            ${s.expires ? `<div class="ta-stat"><label>Bitiş</label><span>${new Date(s.expires).toLocaleDateString("tr-TR")}</span></div>` : ""}
          </div>
          ${s.module_id === "intelligence" ? `<button class="ta-btn ta-btn-sm" onclick="window.__switchTAModule('intelligence')">Modüle Git →</button>` : ""}
        </div>
      `;
    }).join("") || `<div class="ta-empty">Henüz aktif modül aboneliği yok.</div>`;

    content.innerHTML = `
      <section class="ta-section">
        <h2>Abonelikler</h2>
        <div class="ta-card-grid">${moduleCards}</div>
      </section>
      <section class="ta-section">
        <h2>Hızlı Bilgiler</h2>
        <div class="ta-card-grid">
          <div class="ta-card">
            <div class="ta-stat-big">${tenant.seats_used || 0}</div>
            <div class="ta-stat-label">Aktif Kullanıcı</div>
          </div>
          <div class="ta-card">
            <div class="ta-stat-big">${subs.length}</div>
            <div class="ta-stat-label">Aktif Modül</div>
          </div>
          <div class="ta-card">
            <div class="ta-stat-big">${tenant.timezone || "Europe/Istanbul"}</div>
            <div class="ta-stat-label">Zaman Dilimi</div>
          </div>
        </div>
      </section>
    `;

    window.__switchTAModule = (moduleId) => switchToModule(moduleId);
  }

  // ─── Team ──────────────────────────────────────────────────────────────
  async function renderTeam(content, actions) {
    usersData = await apiFetch("/api/tenant/users");

    actions.innerHTML = `<button class="ta-btn ta-btn-primary" id="ta-invite-btn">+ Davet Et</button>`;
    actions.querySelector("#ta-invite-btn").onclick = () => {
      container.querySelector('[data-view="invite"]').click();
    };

    if (!usersData.length) {
      content.innerHTML = `<div class="ta-empty">Henüz ekip üyesi yok. Davet Et butonuna basın.</div>`;
      return;
    }

    // Current user id for self-action guards
    const myId = window.__platformMe?.userId || window.__platformMe?.id || "";

    const rows = usersData.map(u => {
      const isMe       = u.id === myId;
      const isActive   = u.tenant_active !== false;
      const isAdmin    = u.tenant_role === "tenant_admin";
      const modules    = (u.module_access || [])
        .filter(m => m.active)
        .map(m => `<span class="ta-tag">${moduleLabel(m.module_id)}</span>`).join("");
      const lastLogin  = u.last_login_at
        ? new Date(u.last_login_at).toLocaleDateString("tr-TR") : "Hiç";
      const roleBadge  = `<span class="ta-badge ta-badge-${isAdmin ? "admin" : "member"}">${isAdmin ? "Admin" : "Üye"}</span>`;
      const statusBadge = isActive
        ? `<span class="ta-badge ta-badge-active">Aktif</span>`
        : `<span class="ta-badge ta-badge-suspended">Pasif</span>`;

      const roleBtn = !isMe
        ? `<button class="ta-btn ta-btn-sm ta-btn-secondary"
              data-userid="${esc(u.id)}"
              data-current-role="${esc(u.tenant_role)}"
              data-action="change-role">${isAdmin ? "Üye Yap" : "Admin Yap"}</button>`
        : "";
      const activeBtn = !isMe
        ? `<button class="ta-btn ta-btn-sm ${isActive ? "ta-btn-danger" : "ta-btn-success"}"
              data-userid="${esc(u.id)}"
              data-current-active="${isActive}"
              data-username="${esc(u.full_name || u.name || u.email)}"
              data-action="toggle-active">${isActive ? "Devre Dışı" : "Aktif Et"}</button>`
        : "";

      return `
        <tr class="${isActive ? "" : "ta-row-inactive"}">
          <td>
            <strong>${esc(u.full_name || u.name || u.email)}</strong>
            <br><small>${esc(u.email)}</small>
            ${isMe ? `<span class="ta-self-badge">sen</span>` : ""}
          </td>
          <td>${roleBadge}</td>
          <td>${statusBadge}</td>
          <td>${modules || "<span class='ta-muted'>—</span>"}</td>
          <td>${lastLogin}</td>
          <td class="ta-action-cell">
            <button class="ta-btn ta-btn-sm" data-userid="${esc(u.id)}" data-action="edit-modules">Modüller</button>
            ${roleBtn}
            ${activeBtn}
          </td>
        </tr>
      `;
    }).join("");

    content.innerHTML = `
      <table class="ta-table">
        <thead>
          <tr>
            <th>Kullanıcı</th>
            <th>Rol</th>
            <th>Durum</th>
            <th>Modüller</th>
            <th>Son Giriş</th>
            <th>İşlemler</th>
          </tr>
        </thead>
        <tbody>${rows}</tbody>
      </table>
    `;

    content.querySelectorAll('[data-action="edit-modules"]').forEach(btn => {
      btn.addEventListener("click", () => openModuleEditor(btn.dataset.userid));
    });

    content.querySelectorAll('[data-action="change-role"]').forEach(btn => {
      btn.addEventListener("click", () => changeUserRole(btn.dataset.userid, btn.dataset.currentRole, content));
    });

    content.querySelectorAll('[data-action="toggle-active"]').forEach(btn => {
      btn.addEventListener("click", () => toggleUserActive(
        btn.dataset.userid,
        btn.dataset.currentActive === "true",
        btn.dataset.username,
        content
      ));
    });
  }

  // ─── Change role ───────────────────────────────────────────────────────
  async function changeUserRole(userId, currentRole, content) {
    const newRole    = currentRole === "tenant_admin" ? "member" : "tenant_admin";
    const newLabel   = newRole === "tenant_admin" ? "Admin" : "Üye";
    const user       = usersData.find(u => u.id === userId);
    const userName   = user ? esc(user.full_name || user.name || user.email) : userId;

    if (!confirm(`${userName} kullanıcısını "${newLabel}" yapmak istediğinize emin misiniz?`)) return;

    try {
      await apiFetch(`/api/tenant/users/${userId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ tenant_role: newRole })
      });
      renderView("team");
    } catch (err) {
      alert(`Hata: ${err.message}`);
    }
  }

  // ─── Toggle active ─────────────────────────────────────────────────────
  async function toggleUserActive(userId, currentActive, userName, content) {
    const action = currentActive ? "devre dışı bırakmak" : "yeniden aktif etmek";
    if (!confirm(`${userName} kullanıcısını ${action} istediğinize emin misiniz?`)) return;

    try {
      await apiFetch(`/api/tenant/users/${userId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ active: !currentActive })
      });
      renderView("team");
    } catch (err) {
      alert(`Hata: ${err.message}`);
    }
  }

  // ─── Module permission editor (inline modal) ───────────────────────────
  async function openModuleEditor(userId) {
    const user = usersData.find(u => u.id === userId);
    if (!user) return;

    const me2            = window.__platformMe;
    const availableModules = me2?.subscriptions?.map(s => s.moduleId) || [];
    const existingAccess = {};
    (user.module_access || []).forEach(m => { existingAccess[m.module_id] = m; });

    const moduleRows = availableModules.map(modId => {
      const acc     = existingAccess[modId];
      const checked = acc?.active ? "checked" : "";
      const role    = acc?.module_role || "viewer";
      const depts   = (acc?.permissions?.departments || []).join(",");
      return `
        <div class="ta-module-row">
          <label class="ta-checkbox-label">
            <input type="checkbox" name="mod_active" value="${modId}" ${checked}>
            ${moduleLabel(modId)}
          </label>
          <select name="mod_role_${modId}" class="ta-select">
            <option value="viewer"  ${role==="viewer" ?"selected":""}>Görüntüleyici</option>
            <option value="analyst" ${role==="analyst"?"selected":""}>Analist</option>
            <option value="manager" ${role==="manager"?"selected":""}>Yönetici</option>
          </select>
          ${modId === "intelligence" ? `
            <div class="ta-dept-checks">
              <label>Bölümler:</label>
              ${["sales","pricing","warehouse","it"].map(d => `
                <label class="ta-checkbox-label">
                  <input type="checkbox" name="dept_${modId}" value="${d}"
                    ${depts.includes(d)?"checked":""}> ${deptLabel(d)}
                </label>`).join("")}
            </div>` : ""}
        </div>
      `;
    }).join("") || "<p>Bu hesapta aktif modül aboneliği yok.</p>";

    const modal = document.createElement("div");
    modal.className = "ta-modal-overlay";
    modal.innerHTML = `
      <div class="ta-modal">
        <h3>${esc(user.full_name || user.email)} — Modül Erişimi</h3>
        <form id="ta-mod-form">${moduleRows}</form>
        <div class="ta-modal-actions">
          <button class="ta-btn ta-btn-ghost" id="ta-modal-cancel">İptal</button>
          <button class="ta-btn ta-btn-primary" id="ta-modal-save">Kaydet</button>
        </div>
      </div>
    `;
    document.body.appendChild(modal);

    modal.querySelector("#ta-modal-cancel").onclick = () => modal.remove();
    modal.querySelector("#ta-modal-save").onclick = async () => {
      const form          = modal.querySelector("#ta-mod-form");
      const activeModules = [...form.querySelectorAll("input[name='mod_active']:checked")].map(i => i.value);

      for (const modId of availableModules) {
        const isActive  = activeModules.includes(modId);
        const roleEl    = form.querySelector(`select[name="mod_role_${modId}"]`);
        const role      = roleEl?.value || "viewer";
        const deptEls   = form.querySelectorAll(`input[name="dept_${modId}"]:checked`);
        const departments = [...deptEls].map(i => i.value);

        try {
          await apiFetch(`/api/tenant/users/${userId}/modules`, {
            method: "PATCH",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              module_id: modId, module_role: role,
              permissions_json: departments.length ? { departments } : {},
              active: isActive
            })
          });
        } catch (err) {
          alert(`Hata (${modId}): ${err.message}`);
          return;
        }
      }
      modal.remove();
      renderView("team");
    };
  }

  // ─── Invite ────────────────────────────────────────────────────────────
  async function renderInvite(content) {
    const me2         = window.__platformMe;
    const moduleOptions = (me2?.subscriptions || []).map(s =>
      `<option value="${esc(s.moduleId)}">${moduleLabel(s.moduleId)}</option>`
    ).join("");

    content.innerHTML = `
      <div class="ta-two-col">
        <!-- Invite form -->
        <div class="ta-invite-form">
          <p>Kullanıcıya modül erişimi vermek için e-posta davet bağlantısı oluşturun.</p>
          <form id="ta-invite-form">
            <label class="ta-form-label">E-posta Adresi *</label>
            <input type="email" id="inv-email" class="ta-input" placeholder="kullanici@sirket.com" required>

            <label class="ta-form-label">Modül</label>
            <select id="inv-module" class="ta-select">
              <option value="">— Sadece tenant üyesi —</option>
              ${moduleOptions}
            </select>

            <label class="ta-form-label">Modül Rolü</label>
            <select id="inv-role" class="ta-select">
              <option value="viewer">Görüntüleyici</option>
              <option value="analyst">Analist</option>
              <option value="manager">Yönetici</option>
            </select>

            <div id="inv-dept-section" style="display:none">
              <label class="ta-form-label">Bölüm Erişimi (Derive Intelligence)</label>
              <div class="ta-dept-checks">
                ${["sales","pricing","warehouse","it"].map(d => `
                  <label class="ta-checkbox-label">
                    <input type="checkbox" class="inv-dept" value="${d}"> ${deptLabel(d)}
                  </label>`).join("")}
              </div>
            </div>

            <button type="submit" class="ta-btn ta-btn-primary ta-btn-full">Davet Bağlantısı Oluştur</button>
          </form>
          <div id="invite-result"></div>
        </div>

        <!-- Pending invitations -->
        <div>
          <h3 class="ta-section-title">Bekleyen Davetler</h3>
          <div id="ta-pending-invites"><div class="ta-loading">Yükleniyor…</div></div>
        </div>
      </div>
    `;

    // Module select → show/hide dept section
    const moduleSelect = content.querySelector("#inv-module");
    const deptSection  = content.querySelector("#inv-dept-section");
    moduleSelect.addEventListener("change", () => {
      deptSection.style.display = moduleSelect.value === "intelligence" ? "block" : "none";
    });

    // Invite form submit
    content.querySelector("#ta-invite-form").addEventListener("submit", async e => {
      e.preventDefault();
      const email  = content.querySelector("#inv-email").value.trim();
      const modId  = content.querySelector("#inv-module").value;
      const role   = content.querySelector("#inv-role").value;
      const depts  = [...content.querySelectorAll(".inv-dept:checked")].map(i => i.value);
      const result = content.querySelector("#invite-result");

      result.innerHTML = `<div class="ta-loading">Oluşturuluyor…</div>`;
      try {
        const data = await apiFetch("/api/tenant/users/invite", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            email,
            module_id: modId || undefined,
            module_role: role,
            permissions_json: depts.length ? { departments: depts } : {}
          })
        });
        result.innerHTML = `
          <div class="ta-success-box">
            <strong>Davet oluşturuldu!</strong><br>
            <small>Bağlantıyı kopyalayıp e-postayla gönderin:</small>
            <div class="ta-invite-link">${esc(data.inviteUrl)}</div>
            <button class="ta-btn ta-btn-sm" onclick="navigator.clipboard.writeText('${esc(data.inviteUrl)}')">Kopyala</button>
            <small class="ta-muted">${esc(data.expiresIn)} içinde geçersiz olur.</small>
          </div>`;
        // Refresh pending list
        loadPendingInvites(content.querySelector("#ta-pending-invites"));
      } catch (err) {
        result.innerHTML = `<div class="ta-error">${esc(err.message)}</div>`;
      }
    });

    // Load pending invitations panel
    loadPendingInvites(content.querySelector("#ta-pending-invites"));
  }

  async function loadPendingInvites(panel) {
    try {
      const invites = await apiFetch("/api/tenant/invitations");
      if (!invites.length) {
        panel.innerHTML = `<div class="ta-empty-sm">Bekleyen davet yok.</div>`;
        return;
      }
      const rows = invites.map(inv => {
        const created = new Date(inv.created_at).toLocaleDateString("tr-TR");
        const expires = new Date(inv.expires_at).toLocaleDateString("tr-TR");
        const modInfo = inv.module_id
          ? `${moduleLabel(inv.module_id)} / ${inv.module_role}` : "—";
        return `
          <tr>
            <td>${esc(inv.invited_email)}</td>
            <td>${modInfo}</td>
            <td>${created}</td>
            <td>${expires}</td>
            <td>
              <button class="ta-btn ta-btn-sm ta-btn-danger"
                data-invid="${esc(inv.id)}"
                data-email="${esc(inv.invited_email)}"
                data-action="cancel-invite">İptal</button>
            </td>
          </tr>
        `;
      }).join("");

      panel.innerHTML = `
        <table class="ta-table ta-table-compact">
          <thead>
            <tr>
              <th>E-posta</th>
              <th>Modül / Rol</th>
              <th>Gönderildi</th>
              <th>Son Geçerlilik</th>
              <th></th>
            </tr>
          </thead>
          <tbody>${rows}</tbody>
        </table>
      `;

      panel.querySelectorAll('[data-action="cancel-invite"]').forEach(btn => {
        btn.addEventListener("click", async () => {
          if (!confirm(`${btn.dataset.email} davetini iptal etmek istiyor musunuz?`)) return;
          try {
            await apiFetch(`/api/tenant/invitations/${btn.dataset.invid}`, { method: "DELETE" });
            loadPendingInvites(panel);
          } catch (err) {
            alert(`Hata: ${err.message}`);
          }
        });
      });
    } catch (err) {
      panel.innerHTML = `<div class="ta-error">Davetler yüklenemedi: ${esc(err.message)}</div>`;
    }
  }

  // ─── Permissions overview ──────────────────────────────────────────────
  async function renderPermissions(content) {
    const users = await apiFetch("/api/tenant/users");
    usersData = users;

    const me2    = window.__platformMe;
    const modules = (me2?.subscriptions || []).map(s => s.moduleId);

    if (!modules.length) {
      content.innerHTML = `<div class="ta-empty">Aktif modül aboneliği yok.</div>`;
      return;
    }

    const moduleHeaders = modules.map(m => `<th>${moduleLabel(m)}</th>`).join("");
    const rows = users.map(u => {
      const isActive = u.tenant_active !== false;
      const accMap   = {};
      (u.module_access || []).forEach(m => { accMap[m.module_id] = m; });
      const cells = modules.map(modId => {
        const acc = accMap[modId];
        if (!acc || !acc.active) return `<td><span class="ta-muted">—</span></td>`;
        const depts = acc.permissions?.departments;
        return `<td>
          <span class="ta-badge ta-badge-member">${esc(acc.module_role)}</span>
          ${depts?.length ? `<br><small>${depts.map(deptLabel).join(", ")}</small>` : ""}
        </td>`;
      }).join("");
      return `
        <tr class="${isActive ? "" : "ta-row-inactive"}">
          <td>
            <strong>${esc(u.full_name || u.name || u.email)}</strong>
            <br><small>${esc(u.email)}</small>
            ${!isActive ? `<span class="ta-badge ta-badge-suspended" style="font-size:10px;margin-left:4px">Pasif</span>` : ""}
          </td>
          ${cells}
          <td><button class="ta-btn ta-btn-sm" data-userid="${esc(u.id)}" data-action="edit-modules">Düzenle</button></td>
        </tr>
      `;
    }).join("");

    content.innerHTML = `
      <table class="ta-table">
        <thead><tr><th>Kullanıcı</th>${moduleHeaders}<th></th></tr></thead>
        <tbody>${rows}</tbody>
      </table>
    `;

    content.querySelectorAll('[data-action="edit-modules"]').forEach(btn => {
      btn.addEventListener("click", () => openModuleEditor(btn.dataset.userid));
    });
  }

  // ─── Utilities ─────────────────────────────────────────────────────────
  function moduleLabel(id) {
    return { assessment: "Assessment", intelligence: "Intelligence" }[id] || id;
  }
  function deptLabel(d) {
    return { sales: "Satış", pricing: "Fiyatlandırma", warehouse: "Depo", it: "IT" }[d] || d;
  }
  function esc(s) {
    return String(s || "")
      .replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;").replace(/"/g,"&quot;");
  }
}

// ─── Styles ────────────────────────────────────────────────────────────────────
function taStyles() {
  return `
    #tenant-admin-surface { display:flex; height:100vh; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif; font-size:14px; background:#f7f8fa; }
    .ta-sidebar { width:220px; min-width:220px; background:#1a1a2e; display:flex; flex-direction:column; }
    .ta-logo { display:flex; align-items:center; gap:10px; padding:20px 16px 16px; color:#fff; font-weight:700; font-size:15px; border-bottom:1px solid rgba(255,255,255,0.08); }
    .ta-nav { flex:1; padding:12px 8px; display:flex; flex-direction:column; gap:2px; }
    .ta-nav-btn { display:flex; align-items:center; gap:10px; padding:10px 12px; border:none; border-radius:8px; background:transparent; color:rgba(255,255,255,0.6); cursor:pointer; font-size:14px; text-align:left; transition:all .15s; }
    .ta-nav-btn:hover { background:rgba(255,255,255,0.08); color:#fff; }
    .ta-nav-btn.active { background:rgba(226,176,74,0.18); color:#e2b04a; }
    .ta-sidebar-footer { padding:16px; border-top:1px solid rgba(255,255,255,0.08); }
    
    .ta-back-btn { display:flex; align-items:center; gap:6px; margin-top:8px; padding:7px 10px; border:none; border-radius:8px; background:rgba(255,255,255,0.06); color:rgba(255,255,255,0.5); cursor:pointer; font-size:12px; width:100%; transition:all .15s; }
    .ta-back-btn:hover { background:rgba(226,176,74,0.18); color:#e2b04a; }
    .ta-tenant-badge { font-size:12px; color:rgba(255,255,255,0.45); display:block; text-overflow:ellipsis; overflow:hidden; white-space:nowrap; }
    .ta-main { flex:1; display:flex; flex-direction:column; overflow:hidden; }
    .ta-header { display:flex; align-items:center; justify-content:space-between; padding:20px 28px; background:#fff; border-bottom:1px solid #e8eaed; }
    .ta-title { margin:0; font-size:20px; font-weight:700; color:#1a1a2e; }
    .ta-header-actions { display:flex; gap:10px; }
    .ta-content { flex:1; overflow-y:auto; padding:28px; }
    .ta-section { margin-bottom:32px; }
    .ta-section h2 { font-size:15px; font-weight:600; color:#555; margin:0 0 14px; text-transform:uppercase; letter-spacing:.04em; }
    .ta-section-title { font-size:14px; font-weight:600; color:#555; margin:0 0 12px; text-transform:uppercase; letter-spacing:.04em; }
    .ta-card-grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(280px,1fr)); gap:16px; }
    .ta-card { background:#fff; border-radius:12px; border:1px solid #e8eaed; padding:20px; }
    .ta-module-card .ta-card-header { display:flex; align-items:center; gap:10px; margin-bottom:14px; font-size:15px; }
    .ta-card-body { display:grid; grid-template-columns:1fr 1fr; gap:8px; margin-bottom:16px; }
    .ta-stat { display:flex; flex-direction:column; }
    .ta-stat label { font-size:11px; color:#888; text-transform:uppercase; letter-spacing:.04em; }
    .ta-stat span { font-weight:600; color:#222; margin-top:2px; }
    .ta-stat-big { font-size:32px; font-weight:700; color:#1a1a2e; line-height:1; }
    .ta-stat-label { font-size:13px; color:#888; margin-top:6px; }
    .ta-badge { display:inline-block; padding:2px 8px; border-radius:20px; font-size:11px; font-weight:600; letter-spacing:.04em; }
    .ta-badge-active    { background:#d1fae5; color:#065f46; }
    .ta-badge-trial     { background:#fef3c7; color:#92400e; }
    .ta-badge-suspended { background:#fee2e2; color:#991b1b; }
    .ta-badge-admin     { background:#ede9fe; color:#5b21b6; }
    .ta-badge-member    { background:#e0f2fe; color:#0369a1; }
    .ta-table { width:100%; border-collapse:collapse; background:#fff; border-radius:12px; overflow:hidden; border:1px solid #e8eaed; }
    .ta-table th { padding:12px 16px; text-align:left; font-size:11px; text-transform:uppercase; letter-spacing:.04em; color:#888; background:#f9fafb; border-bottom:1px solid #e8eaed; font-weight:600; }
    .ta-table td { padding:12px 16px; border-bottom:1px solid #f0f2f4; vertical-align:middle; color:#333; }
    .ta-table tr:last-child td { border-bottom:none; }
    .ta-table tr:hover td { background:#f9fafb; }
    .ta-table-compact th, .ta-table-compact td { padding:8px 12px; font-size:13px; }
    .ta-row-inactive td { opacity:.5; }
    .ta-action-cell { white-space:nowrap; display:flex; gap:6px; align-items:center; flex-wrap:wrap; }
    .ta-self-badge { display:inline-block; padding:1px 6px; background:#f0f4ff; color:#3730a3; border-radius:4px; font-size:10px; margin-left:4px; vertical-align:middle; }
    .ta-tag { display:inline-block; padding:2px 8px; background:#f0f4ff; color:#3730a3; border-radius:4px; font-size:11px; font-weight:500; margin:1px; }
    .ta-btn { padding:8px 16px; border-radius:8px; border:1px solid #e0e0e0; background:#fff; cursor:pointer; font-size:14px; font-weight:500; transition:all .15s; }
    .ta-btn:hover { background:#f5f5f5; }
    .ta-btn-primary   { background:#1a1a2e; color:#fff; border-color:#1a1a2e; }
    .ta-btn-primary:hover { background:#252540; }
    .ta-btn-secondary { background:#f0f4ff; color:#3730a3; border-color:#c7d2fe; }
    .ta-btn-secondary:hover { background:#e0e7ff; }
    .ta-btn-danger    { background:#fee2e2; color:#991b1b; border-color:#fca5a5; }
    .ta-btn-danger:hover { background:#fecaca; }
    .ta-btn-success   { background:#d1fae5; color:#065f46; border-color:#6ee7b7; }
    .ta-btn-success:hover { background:#a7f3d0; }
    .ta-btn-ghost  { background:transparent; border-color:transparent; }
    .ta-btn-ghost:hover { background:#f0f0f0; }
    .ta-btn-sm   { padding:5px 10px; font-size:12px; }
    .ta-btn-full { width:100%; margin-top:16px; padding:12px; }
    .ta-two-col { display:grid; grid-template-columns:1fr 1fr; gap:28px; align-items:start; }
    @media (max-width:900px) { .ta-two-col { grid-template-columns:1fr; } }
    .ta-invite-form { background:#fff; border-radius:12px; border:1px solid #e8eaed; padding:28px; }
    .ta-form-label { display:block; font-weight:600; font-size:13px; color:#444; margin:16px 0 6px; }
    .ta-form-label:first-child { margin-top:0; }
    .ta-input { width:100%; padding:10px 12px; border:1px solid #d0d5dd; border-radius:8px; font-size:14px; outline:none; box-sizing:border-box; }
    .ta-input:focus { border-color:#1a1a2e; box-shadow:0 0 0 3px rgba(26,26,46,.08); }
    .ta-select { width:100%; padding:10px 12px; border:1px solid #d0d5dd; border-radius:8px; font-size:14px; background:#fff; outline:none; }
    .ta-dept-checks { display:flex; flex-wrap:wrap; gap:8px; margin-top:8px; }
    .ta-checkbox-label { display:flex; align-items:center; gap:6px; cursor:pointer; font-size:13px; }
    .ta-success-box { background:#d1fae5; border:1px solid #6ee7b7; border-radius:8px; padding:16px; margin-top:16px; }
    .ta-invite-link { font-family:monospace; font-size:12px; background:#fff; border:1px solid #d0d5dd; border-radius:6px; padding:8px 10px; margin:8px 0; word-break:break-all; }
    .ta-modal-overlay { position:fixed; inset:0; background:rgba(0,0,0,.45); display:flex; align-items:center; justify-content:center; z-index:9999; }
    .ta-modal { background:#fff; border-radius:16px; padding:28px; width:480px; max-width:95vw; max-height:80vh; overflow-y:auto; }
    .ta-modal h3 { margin:0 0 20px; font-size:17px; }
    .ta-modal-actions { display:flex; justify-content:flex-end; gap:10px; margin-top:20px; }
    .ta-module-row { border:1px solid #e8eaed; border-radius:8px; padding:14px; margin-bottom:10px; }
    .ta-loading { padding:40px; text-align:center; color:#888; }
    .ta-error { padding:16px; background:#fee2e2; color:#991b1b; border-radius:8px; margin-top:8px; }
    .ta-empty  { padding:40px; text-align:center; color:#aaa; }
    .ta-empty-sm { padding:16px; text-align:center; color:#aaa; font-size:13px; }
    .ta-muted  { color:#aaa; }
  `;
}
