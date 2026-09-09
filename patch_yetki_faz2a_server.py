# -*- coding: utf-8 -*-
# YETKI_FAZ2A (server) — Org Bölüm/Üyelik yönetim API'si (Yönetim › İzinler › Bölümler).
#   7 uç (requireTenantAdmin): bölüm list/create/patch/delete · üye get/post · şablon apply(push).
#   "apply" = şablon capabilities'ini üyelerin permissions_json.departments[]'ine yazar → enforcement
#   zaten çalışan _sahaCap/_enforceSahaDept üstünden gider (çekirdek auth'a dokunmaz).
#   TABLOLAR DDL ile ayrı kurulur (deploy). Taze CANLI server üstüne uygulanır.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YETKI_FAZ2A" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

ANCHOR = "// PATCH /api/tenant/users/:id/modules"
assert s.count(ANCHOR) == 1, "anchor=%d" % s.count(ANCHOR)

BLOCK = r'''// ── YETKI_FAZ2A — Org Bölüm/Üyelik (Yönetim › İzinler › Bölümler) ──
if (request.method === "GET" && url.pathname === "/api/tenant/departments") {  /* YETKI_FAZ2A */
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const d = await query(`SELECT d.id::text id, d.key, d.ad, d.ikon, d.template_json, d.aktif,
        (SELECT count(*) FROM tenant_department_membership m WHERE m.department_id=d.id)::int uye
        FROM tenant_department d WHERE d.tenant_id::text=$1::text ORDER BY d.aktif DESC, d.ad`, [session.tenantId]);
    sendJson(response, 200, { departments: d.rows });
  } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
  return;
}
if (request.method === "POST" && url.pathname === "/api/tenant/departments") {  /* YETKI_FAZ2A */
  try {
    const session = await requireTenantAdmin(request);
    if (!session.tenantId) { sendJson(response, 403, { error: "Tenant context required." }); return; }
    const b = await readJson(request) || {};
    const ad = String(b.ad || "").trim();
    if (!ad) { sendJson(response, 400, { error: "ad zorunlu" }); return; }
    const key = (String(b.key || ad).toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "").slice(0, 40)) || ("bolum-" + Math.abs(ad.length * 7 + 3));
    const ikon = String(b.ikon || "🏷️").slice(0, 8);
    const tpl = (b.template_json && typeof b.template_json === "object") ? b.template_json : { capabilities: [], scope: { level: "kendi", regions: [], segments: [] } };
    const r = await query(`INSERT INTO tenant_department (tenant_id, key, ad, ikon, template_json)
        VALUES ($1,$2,$3,$4,$5::jsonb) ON CONFLICT (tenant_id, key) DO UPDATE SET ad=EXCLUDED.ad, ikon=EXCLUDED.ikon
        RETURNING id::text id`, [session.tenantId, key, ad, ikon, JSON.stringify(tpl)]);
    sendJson(response, 201, { ok: true, id: r.rows[0].id, key });
  } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
  return;
}
{ const _md = url.pathname.match(/^\/api\/tenant\/departments\/([0-9a-f-]{36})$/);
  if (_md && request.method === "PATCH") {  /* YETKI_FAZ2A */
    try {
      const session = await requireTenantAdmin(request);
      const b = await readJson(request) || {}; const sets = [], vals = [session.tenantId, _md[1]]; let i = 3;
      if (b.ad != null) { sets.push(`ad=$${i++}`); vals.push(String(b.ad).trim()); }
      if (b.ikon != null) { sets.push(`ikon=$${i++}`); vals.push(String(b.ikon).slice(0, 8)); }
      if (b.template_json != null) { sets.push(`template_json=$${i++}::jsonb`); vals.push(JSON.stringify(b.template_json)); }
      if (b.aktif != null) { sets.push(`aktif=$${i++}`); vals.push(!!b.aktif); }
      if (!sets.length) { sendJson(response, 400, { error: "değişiklik yok" }); return; }
      await query(`UPDATE tenant_department SET ${sets.join(",")} WHERE tenant_id::text=$1::text AND id=$2`, vals);
      sendJson(response, 200, { ok: true });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
  if (_md && request.method === "DELETE") {  /* YETKI_FAZ2A */
    try {
      const session = await requireTenantAdmin(request);
      await query(`DELETE FROM tenant_department WHERE tenant_id::text=$1::text AND id=$2`, [session.tenantId, _md[1]]);
      sendJson(response, 200, { ok: true });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
}
{ const _mm = url.pathname.match(/^\/api\/tenant\/departments\/([0-9a-f-]{36})\/members$/);
  if (_mm && request.method === "GET") {  /* YETKI_FAZ2A */
    try {
      const session = await requireTenantAdmin(request);
      const u = await query(`SELECT u.id::text id, COALESCE(u.full_name,u.email,'—') ad, u.email,
          EXISTS(SELECT 1 FROM tenant_department_membership m WHERE m.department_id=$2 AND m.user_id=u.id) uye
          FROM users u WHERE u.id IN (SELECT user_id FROM tenant_user_modules WHERE tenant_id::text=$1::text)
          ORDER BY uye DESC, ad`, [session.tenantId, _mm[1]]);
      sendJson(response, 200, { users: u.rows });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
  if (_mm && request.method === "POST") {  /* YETKI_FAZ2A — üye ekle/çıkar */
    try {
      const session = await requireTenantAdmin(request); const did = _mm[1];
      const b = await readJson(request) || {}; const add = Array.isArray(b.add) ? b.add : []; const rem = Array.isArray(b.remove) ? b.remove : [];
      for (const uid of add) await query(`INSERT INTO tenant_department_membership (tenant_id, department_id, user_id) VALUES ($1,$2,$3) ON CONFLICT (tenant_id, department_id, user_id) DO NOTHING`, [session.tenantId, did, uid]);
      if (rem.length) await query(`DELETE FROM tenant_department_membership WHERE tenant_id::text=$1::text AND department_id=$2 AND user_id = ANY($3::uuid[])`, [session.tenantId, did, rem]);
      sendJson(response, 200, { ok: true, eklendi: add.length, cikarildi: rem.length });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
}
{ const _ma = url.pathname.match(/^\/api\/tenant\/departments\/([0-9a-f-]{36})\/apply$/);
  if (_ma && request.method === "POST") {  /* YETKI_FAZ2A — şablonu üyelere uygula (push) */
    try {
      const session = await requireTenantAdmin(request); const tid = session.tenantId; const did = _ma[1];
      const dr = await query(`SELECT template_json FROM tenant_department WHERE tenant_id::text=$1::text AND id=$2`, [tid, did]);
      if (!dr.rowCount) { sendJson(response, 404, { error: "bölüm yok" }); return; }
      const tpl = dr.rows[0].template_json || {}; const caps = Array.isArray(tpl.capabilities) ? tpl.capabilities : [];
      const scope = tpl.scope || { level: "kendi", regions: [], segments: [] };
      const upd = await query(`UPDATE tenant_user_modules t
          SET permissions_json = jsonb_set(
                jsonb_set(COALESCE(t.permissions_json,'{}'::jsonb), '{departments}',
                  COALESCE((SELECT jsonb_agg(DISTINCT e) FROM (
                      SELECT jsonb_array_elements_text(COALESCE(t.permissions_json->'departments','[]'::jsonb)) e
                      UNION SELECT jsonb_array_elements_text($2::jsonb) e) u), '[]'::jsonb)),
                '{scope}', $3::jsonb)
          WHERE t.tenant_id::text=$1::text AND t.module_id='saha'
            AND t.user_id IN (SELECT user_id FROM tenant_department_membership WHERE department_id=$4 AND tenant_id::text=$1::text)`,
        [tid, JSON.stringify(caps), JSON.stringify(scope), did]);
      sendJson(response, 200, { ok: true, uygulandi: upd.rowCount });
    } catch (e) { sendJson(response, e.statusCode || 500, { error: e.message }); }
    return;
  }
}

'''
s = s.replace(ANCHOR, BLOCK + ANCHOR, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YETKI_FAZ2A (server) — 7 bölüm/üyelik ucu eklendi")
