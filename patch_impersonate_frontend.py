# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# IMPERSONATE_FRONTEND — platform.js: explicit "enter tenant" for the Intelligence
# cockpit. (1) drop the silent single-tenant auto-select, (2) call enter-tenant so
# the SERVER session matches the chosen tenant, (3) always-on banner + Exit->exit-tenant.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/platform.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) remove silent single-tenant auto-select (require explicit pick)
rep(
"""  // Single tenant → go straight to VMO (no pointless picker)
  if (!intelligenceActiveTenantId && tenants.length === 1) {
    intelligenceActiveTenantId = tenants[0].id;
  }""",
"""  // Explicit entry: platform owner must pick a tenant (no silent auto-select).""",
    "drop-autoselect")

# 2) enter-tenant on mount + always-on banner
rep(
"""  // Only show the context bar when there are multiple tenants (single-tenant: no need)
  const contextBar = tenants.length > 1 ? `
    <div style="display:flex;align-items:center;gap:10px;padding:6px 16px;border-bottom:1px solid var(--border-subtle,#e5e7eb);background:var(--surface-raised,#fff);flex-shrink:0;font-size:12px;">
      <span style="color:var(--text-muted);">Platform Owner</span>
      <span style="color:var(--text-muted);">·</span>
      <strong>${escapeHtml(tenant.name)}</strong>
      <button class="text-button" id="intel-switch-tenant" style="margin-left:auto;font-size:12px;">Tenant değiştir</button>
    </div>` : '';""",
"""  // Tell the SERVER which tenant is being viewed (sets session.tenantId; RLS-safe impersonation)
  try {
    await fetch('/api/platform/enter-tenant', {
      method: 'POST',
      headers: { ...authHeaders(), 'Content-Type': 'application/json' },
      body: JSON.stringify({ tenantId: tenant.id })
    });
  } catch (_) {}

  // Always-visible impersonation banner — never a silent default
  const contextBar = `
    <div style="display:flex;align-items:center;gap:10px;padding:8px 16px;border-bottom:1px solid #f59e0b;background:#fffbeb;color:#92400e;flex-shrink:0;font-size:13px;">
      <span>👁 Platform sahibi olarak görüntülüyorsunuz:</span>
      <strong>${escapeHtml(tenant.name)}</strong>
      <button class="text-button" id="intel-exit-tenant" style="margin-left:auto;font-size:13px;font-weight:600;color:#92400e;">Çıkış → Platform</button>
    </div>`;""",
    "enter+banner")

# 3) Exit handler -> exit-tenant + back to platform
rep(
"""  platformViewContainer?.querySelector('#intel-switch-tenant')?.addEventListener('click', () => {
    intelligenceActiveTenantId = null;
    if (intelligenceBiDestroy) { try { intelligenceBiDestroy(); } catch(_){} intelligenceBiDestroy = null; }
    renderPlatformIntelligence();
  });""",
"""  platformViewContainer?.querySelector('#intel-exit-tenant')?.addEventListener('click', async () => {
    try { await fetch('/api/platform/exit-tenant', { method: 'POST', headers: authHeaders() }); } catch (_) {}
    intelligenceActiveTenantId = null;
    if (intelligenceBiDestroy) { try { intelligenceBiDestroy(); } catch(_){} intelligenceBiDestroy = null; }
    renderPlatformView('command-center');
  });""",
    "exit-handler")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
