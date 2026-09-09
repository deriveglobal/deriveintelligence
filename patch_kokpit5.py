#!/usr/bin/env python3
# omurga_74 — kokpit ETKILESIM: (1) duzen kaliciligi  (2) bekleyen-duzeltme ogrenme dongusu.
# server_container.mjs'e iki route ekler: /api/bi/kokpit-layout (GET/POST) + /api/bi/kokpit-duzeltme (GET/POST).
# Kendi kendine yeten: govde-parse inline, kullanici-anahtari defansif, tablolar lazy CREATE IF NOT EXISTS.
# Yedekli + node --check'li + basarisizsa GERI ALIR. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

if "/api/bi/kokpit-duzeltme" in srv:
    sys.exit("ZATEN VAR: kokpit-duzeltme route mevcut — elle bak.")

# --- kokpit-data route blogunun SONUNU bul (patch4 ile ayni yontem) ---
p = srv.index('url.pathname === "/api/bi/kokpit-data"')
a = srv.rindex('if (', 0, p)
kd = srv.index('[kokpit-data]', a)
ret = srv.index('return;', kd)
b = srv.index('}', ret) + 1   # kokpit-data route blogunun bitisi

ROUTES = r'''

  // ---- omurga_74: kokpit duzen kaliciligi ----
  if (url.pathname === "/api/bi/kokpit-layout") {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const U = String(session.userId || session.kullaniciId || session.kullanici || session.email || session.eposta || "ortak");
      await query(`CREATE TABLE IF NOT EXISTS bi_kokpit_tercih (
        tenant_id text NOT NULL, kullanici text NOT NULL,
        layout jsonb NOT NULL DEFAULT '{}'::jsonb, ts timestamptz NOT NULL DEFAULT now(),
        PRIMARY KEY (tenant_id, kullanici))`);
      if (request.method === "POST") {
        let _b = ""; await new Promise(r => { request.on("data", c => _b += c); request.on("end", r); });
        let _j = {}; try { _j = JSON.parse(_b || "{}"); } catch (e) {}
        const lay = _j.layout || {};
        await query(`INSERT INTO bi_kokpit_tercih(tenant_id,kullanici,layout,ts)
          VALUES($1,$2,$3::jsonb,now())
          ON CONFLICT (tenant_id,kullanici) DO UPDATE SET layout=EXCLUDED.layout, ts=now()`,
          [String(T), U, JSON.stringify(lay)]);
        sendJson(response, 200, { ok: true });
        return;
      }
      const r = await query(`SELECT layout FROM bi_kokpit_tercih WHERE tenant_id::text=$1 AND kullanici=$2`, [String(T), U]);
      sendJson(response, 200, { layout: (r.rows[0] && r.rows[0].layout) || {} });
    } catch (e) { console.error("[kokpit-layout]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }

  // ---- omurga_74: bekleyen-duzeltme ogrenme dongusu (organizma tartar, otomatik uygulanmaz) ----
  if (url.pathname === "/api/bi/kokpit-duzeltme") {
    try {
      const session = await requireModuleAccess(request, "intelligence");
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const U = String(session.userId || session.kullaniciId || session.kullanici || session.email || session.eposta || "ortak");
      await query(`CREATE TABLE IF NOT EXISTS bi_kokpit_duzeltme (
        id bigserial PRIMARY KEY, tenant_id text NOT NULL, kullanici text,
        anahtar text NOT NULL, gerekce text NOT NULL,
        durum text NOT NULL DEFAULT 'beklemede', organizma_notu text,
        ts timestamptz NOT NULL DEFAULT now(), karar_ts timestamptz)`);
      await query(`CREATE INDEX IF NOT EXISTS ix_kokpit_duz_tenant ON bi_kokpit_duzeltme(tenant_id, anahtar)`);
      if (request.method === "POST") {
        let _b = ""; await new Promise(r => { request.on("data", c => _b += c); request.on("end", r); });
        let _j = {}; try { _j = JSON.parse(_b || "{}"); } catch (e) {}
        const anahtar = String(_j.anahtar || "").slice(0, 200);
        const gerekce = String(_j.gerekce || "").slice(0, 4000);
        if (!anahtar || !gerekce) { sendJson(response, 400, { error: "anahtar+gerekce gerekli" }); return; }
        const r = await query(`INSERT INTO bi_kokpit_duzeltme(tenant_id,kullanici,anahtar,gerekce,durum)
          VALUES($1,$2,$3,$4,'beklemede')
          RETURNING anahtar, gerekce, kullanici, durum, organizma_notu, to_char(ts,'YYYY-MM-DD"T"HH24:MI') ts`,
          [String(T), U, anahtar, gerekce]);
        sendJson(response, 200, { duzeltme: r.rows[0] });
        return;
      }
      const r = await query(`SELECT anahtar, gerekce, kullanici, durum, organizma_notu,
          to_char(ts,'YYYY-MM-DD"T"HH24:MI') ts
        FROM bi_kokpit_duzeltme WHERE tenant_id::text=$1 ORDER BY ts DESC LIMIT 500`, [String(T)]);
      sendJson(response, 200, { duzeltmeler: r.rows });
    } catch (e) { console.error("[kokpit-duzeltme]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
'''

srv2 = srv[:b] + ROUTES + srv[b:]
shutil.copy2(S, S + ".k5.bak")
open(S, "w", encoding="utf-8").write(srv2)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".k5.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: host'ta node yok, --check atlandi (yedek .k5.bak)")
print("OK: kokpit-layout + kokpit-duzeltme route eklendi. Tablolar ilk cagrida olusur.")
print("Sonraki: yeni kokpit.html -> shells/kokpit.html, sonra docker build + compose up --force-recreate.")
