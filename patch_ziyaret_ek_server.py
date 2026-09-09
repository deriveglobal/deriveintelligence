#!/usr/bin/env python3
# ZIYARET_EK_V1 (server) — Ziyarete DOSYA eki (Yildiray Bilen, 25 Agu; Fatih onayli).
#   DUYURU_EK_V1 desenini birebir yansitir: her tip dosya, 8MB, DB bytea, indir/sil uclari.
#   Foto ile ayni sahiplik: rep yalniz kendi ziyareti; manager/admin hepsi.
#   Uclar: POST .../ek · GET .../ekler · GET .../ek/:id (indir) · DELETE .../ek/:id
#   Idempotent (marker: ZIYARET_EK_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "ZIYARET_EK_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

# ── 1) 4 uc — foto binary serve blogundan sonra, iskonto listesinden once ──
anchor_uc = '''    // ── İskonto talepleri listesi ──'''
uclar = '''    /* ''' + MARK + ''' — ziyarete dosya eki (her tip, 8MB). Sahiplik foto ile ayni: rep kendi ziyareti, manager/admin hepsi. */
    if (method === "POST" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/ek$`)))) {
      const session = await requireSahaAccess(request);
      const own = await query(`SELECT rep_id FROM saha_ziyaret WHERE tenant_id = $1 AND id = $2`, [session.tenantId, m[1]]);
      if (!own.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      if (session.sahaRole === "rep" && own.rows[0].rep_id !== session.userId) { sendJson(response, 403, { error: "Sadece kendi ziyaretinize dosya ekleyebilirsiniz." }); return; }
      await ensureZiyaretEk();
      const body = await readJson(request, 12 * 1024 * 1024);
      const _ad = String((body && body.dosya_adi) || "dosya").slice(0, 200);
      const _mime = String((body && body.mime) || "application/octet-stream").slice(0, 120);
      let _buf = null; try { _buf = Buffer.from(String((body && body.veri) || "").replace(/^data:[^;]+;base64,/, ""), "base64"); } catch (e) {}
      if (!_buf || !_buf.length) { sendJson(response, 400, { error: "Dosya boş." }); return; }
      if (_buf.length > 8 * 1024 * 1024) { sendJson(response, 413, { error: "Dosya 8MB sınırını aşıyor." }); return; }
      const er = await query("INSERT INTO saha_ziyaret_ek (id,tenant_id,ziyaret_id,dosya_adi,mime,boyut,veri,yukleyen_id) VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7) RETURNING id, dosya_adi, mime, boyut, created_at", [session.tenantId, m[1], _ad, _mime, _buf.length, _buf, session.userId]);
      sendJson(response, 201, { ek: er.rows[0] });
      return;
    }
    /* ''' + MARK + ''' — ek listesi (veri HARIC) */
    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/ekler$`)))) {
      const session = await requireSahaAccess(request);
      await ensureZiyaretEk();
      const er = await query("SELECT id, dosya_adi, mime, boyut, created_at FROM saha_ziyaret_ek WHERE tenant_id=$1 AND ziyaret_id=$2 ORDER BY created_at ASC", [session.tenantId, m[1]]);
      sendJson(response, 200, { ekler: er.rows });
      return;
    }
    /* ''' + MARK + ''' — ek indir/goruntule */
    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/ek/(${SAHA_UUID_RE})$`)))) {
      const session = await requireSahaAccess(request);
      await ensureZiyaretEk();
      const er = await query("SELECT dosya_adi, mime, veri FROM saha_ziyaret_ek WHERE tenant_id=$1 AND ziyaret_id=$2 AND id=$3", [session.tenantId, m[1], m[2]]);
      if (!er.rowCount) { sendJson(response, 404, { error: "Ek bulunamadı." }); return; }
      const _e = er.rows[0];
      response.writeHead(200, { "Content-Type": _e.mime || "application/octet-stream", "Content-Disposition": 'inline; filename="' + encodeURIComponent(_e.dosya_adi || "dosya") + '"', "Cache-Control": "private, max-age=300", "X-Content-Type-Options": "nosniff" });
      response.end(_e.veri);
      return;
    }
    /* ''' + MARK + ''' — ek sil (rep kendi ziyareti, manager/admin hepsi) */
    if (method === "DELETE" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/ek/(${SAHA_UUID_RE})$`)))) {
      const session = await requireSahaAccess(request);
      const own = await query(`SELECT rep_id FROM saha_ziyaret WHERE tenant_id = $1 AND id = $2`, [session.tenantId, m[1]]);
      if (!own.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      if (session.sahaRole === "rep" && own.rows[0].rep_id !== session.userId) { sendJson(response, 403, { error: "Sadece kendi ziyaretinizin ekini silebilirsiniz." }); return; }
      await ensureZiyaretEk();
      const del = await query("DELETE FROM saha_ziyaret_ek WHERE tenant_id=$1 AND ziyaret_id=$2 AND id=$3 RETURNING id", [session.tenantId, m[1], m[2]]);
      if (!del.rowCount) { sendJson(response, 404, { error: "Ek bulunamadı." }); return; }
      sendJson(response, 200, { ok: true, silinen: m[2] });
      return;
    }

    // ── İskonto talepleri listesi ──'''
if anchor_uc not in src:
    print("HATA: iskonto anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor_uc, uclar, 1)
print("[+] 4 uc eklendi (POST/GET ekler/GET indir/DELETE)")

# ── 2) ensureZiyaretEk() — ensureDuyuruEk'ten once ──
anchor_fn = '''async function ensureDuyuruEk() {  /* DUYURU_EK_V1 */'''
fn = '''async function ensureZiyaretEk() {  /* ''' + MARK + ''' */
  await pool.query(`CREATE TABLE IF NOT EXISTS saha_ziyaret_ek (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id uuid NOT NULL,
    ziyaret_id uuid NOT NULL REFERENCES saha_ziyaret(id) ON DELETE CASCADE,
    dosya_adi text NOT NULL, mime text NOT NULL, boyut integer NOT NULL,
    veri bytea NOT NULL, yukleyen_id uuid,
    created_at timestamptz NOT NULL DEFAULT now())`);
  await pool.query("CREATE INDEX IF NOT EXISTS idx_saha_ziyaret_ek ON saha_ziyaret_ek (ziyaret_id)");
}
''' + anchor_fn
if anchor_fn not in src:
    print("HATA: ensureDuyuruEk anchor bulunamadi"); sys.exit(1)
src = src.replace(anchor_fn, fn, 1)
print("[+] ensureZiyaretEk() eklendi")

if src == orig:
    print("[=] Degisiklik yok"); sys.exit(1)
with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path)
