# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ONERI_THREAD_SERVER — turn one-shot feedback into a real ticket system:
#   GET  /api/saha/oneriler            list (rep=own, staff=all) + unread + msg count
#   GET  /api/saha/oneriler/:id        full thread (marks read for caller)
#   POST /api/saha/oneri               open ticket  -> first thread msg + EMAIL
#   POST /api/saha/oneriler/:id/mesaj  reply        -> EMAIL the other side
#   PUT  /api/saha/oneriler/:id        status/note  -> written INTO thread + EMAIL rep
# Email recipients come from saha_oneri_ayar.bildirim_eposta (explicit list), so
# in-app access (role-based) and email (opt-in) are deliberately decoupled.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# ── 1) notification helper (module scope, next to sendGraphMail) ──────────────
rep(
'async function sendGraphMail({ to, subject, body }) {',
'''// ── Öneri/Destek bildirimi ────────────────────────────────────────────────
// Never throws into the request path: notification failure must not fail the write.
async function oneriBildirim(tenantId, oneriId, olay, aktorUserId) {
  try {
    const eh = (x) => String(x ?? "").replace(/[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
    const t = await pool.query(
      `SELECT o.id, o.baslik, o.kategori, o.durum, o.user_id,
              u.email AS sahip_email, COALESCE(u.full_name, u.email) AS sahip_ad
         FROM saha_oneri o LEFT JOIN users u ON u.id = o.user_id
        WHERE o.id = $1 AND o.tenant_id = $2`, [oneriId, tenantId]);
    if (!t.rowCount) return;
    const t0 = t.rows[0];
    const sn = await pool.query(
      `SELECT m.mesaj, COALESCE(u.full_name, u.email, 'Sistem') AS yazar
         FROM saha_oneri_mesaj m LEFT JOIN users u ON u.id = m.user_id
        WHERE m.oneri_id = $1 ORDER BY m.ts DESC LIMIT 1`, [oneriId]);
    const sonMesaj = sn.rowCount ? sn.rows[0].mesaj : "";
    const sonYazar = sn.rowCount ? sn.rows[0].yazar : "";

    let alicilar = [];
    if (olay === "YANIT_SAHIBE" || olay === "DURUM") {
      if (t0.sahip_email && t0.user_id !== aktorUserId) alicilar = [t0.sahip_email];
    } else {
      const a = await pool.query("SELECT bildirim_eposta FROM saha_oneri_ayar WHERE tenant_id = $1", [tenantId]);
      alicilar = (a.rows[0] && a.rows[0].bildirim_eposta) || [];
    }
    alicilar = [...new Set(alicilar.filter(Boolean))];
    if (!alicilar.length) return;

    const KAT = { HATA: "Hata Bildirimi", OZELLIK: "Özellik İsteği", UI: "Arayüz", DIGER: "Diğer" };
    const DUR = { YENI: "Yeni", INCELENIYOR: "İnceleniyor", TAMAMLANDI: "Tamamlandı", REDDEDILDI: "Reddedildi" };
    const ust = olay === "YENI" ? "Yeni destek kaydı"
              : olay === "DURUM" ? "Destek kaydınız güncellendi"
              : "Destek kaydına yanıt";
    const html = `
      <div style="font-family:Segoe UI,Arial,sans-serif;font-size:14px;color:#0f172a">
        <h3 style="margin:0 0 12px">${eh(ust)}</h3>
        <table cellpadding="6" style="border-collapse:collapse;font-size:13px">
          <tr><td style="color:#64748b">Başlık</td><td><b>${eh(t0.baslik)}</b></td></tr>
          <tr><td style="color:#64748b">Kategori</td><td>${eh(KAT[t0.kategori] || t0.kategori)}</td></tr>
          <tr><td style="color:#64748b">Durum</td><td>${eh(DUR[t0.durum] || t0.durum)}</td></tr>
          <tr><td style="color:#64748b">Açan</td><td>${eh(t0.sahip_ad || "-")}</td></tr>
          ${sonYazar ? `<tr><td style="color:#64748b">Son yazan</td><td>${eh(sonYazar)}</td></tr>` : ""}
        </table>
        ${sonMesaj ? `<div style="margin-top:12px;padding:10px 12px;background:#f1f5f9;border-radius:8px;white-space:pre-wrap">${eh(sonMesaj)}</div>` : ""}
        <p style="margin-top:14px;color:#64748b;font-size:12px">Saha &rsaquo; Öneriler sekmesinden görüntüleyip yanıtlayabilirsiniz.</p>
      </div>`;
    for (const adr of alicilar) {
      await sendGraphMail({ to: adr, subject: `[Derive Saha] ${ust}: ${t0.baslik}`, body: html });
    }
  } catch (e) {
    console.error("[oneriBildirim]", e && e.message);
  }
}

async function sendGraphMail({ to, subject, body }) {''',
    "oneri-bildirim-helper")

# ── 2) replace the three handlers with the full ticket system ─────────────────
rep(
'''    if (method === "GET" && path === "/api/saha/oneriler") {
      const session = await requireSahaAccess(request);
      let sql = `SELECT id, kategori, baslik, mesaj, durum, yonetici_notu, ts, guncellendi_at
                   FROM saha_oneri WHERE tenant_id=$1`;
      const p = [session.tenantId];
      if (session.sahaRole === 'rep') { sql += ' AND user_id=$2'; p.push(session.userId); }
      sql += ' ORDER BY ts DESC LIMIT 50';
      const rows = await pool.query(sql, p);
      sendJson(response, 200, { oneriler: rows.rows });
      return;
    }
    if (method === "POST" && path === "/api/saha/oneri") {
      const session = await requireSahaAccess(request);
      const body = await readJson(request);
      let { kategori='DIGER', baslik, mesaj } = body;
      if (!["HATA","OZELLIK","UI","DIGER"].includes(kategori)) kategori = "DIGER";
      if (!baslik || !mesaj) { sendJson(response, 400, { error: 'baslik ve mesaj zorunlu' }); return; }
      await pool.query(
        `INSERT INTO saha_oneri (id,tenant_id,user_id,kategori,baslik,mesaj,durum)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,'YENI')`,
        [session.tenantId, session.userId, kategori, baslik, mesaj]
      );
      sendJson(response, 201, { ok: true });
      return;
    }
    if (method === "PUT" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request, ['manager','admin']);
      const body = await readJson(request);
      const { durum, yonetici_notu } = body;
      await pool.query(
        `UPDATE saha_oneri SET durum=COALESCE($2,durum), yonetici_notu=COALESCE($3,yonetici_notu), guncellendi_at=now() WHERE id=$1`,
        [m[1], durum||null, yonetici_notu||null]
      );
      sendJson(response, 200, { ok: true });
      return;
    }''',
'''    if (method === "GET" && path === "/api/saha/oneriler") {
      const session = await requireSahaAccess(request);
      const staff = session.sahaRole !== "rep";
      const p = [session.tenantId, session.userId];
      let sql = `
        SELECT o.id, o.kategori, o.baslik, o.mesaj, o.durum, o.yonetici_notu, o.ts,
               o.guncellendi_at, o.son_mesaj_at,
               COALESCE(u.full_name, u.email) AS kullanici,
               (SELECT count(*) FROM saha_oneri_mesaj mm WHERE mm.oneri_id = o.id)::int AS mesaj_sayisi,
               (o.son_mesaj_at > COALESCE(
                  (SELECT r.okundu_at FROM saha_oneri_okuma r
                    WHERE r.oneri_id = o.id AND r.user_id = $2), 'epoch'::timestamptz)) AS okunmamis
          FROM saha_oneri o
          LEFT JOIN users u ON u.id = o.user_id
         WHERE o.tenant_id = $1`;
      if (!staff) sql += " AND o.user_id = $2";
      sql += " ORDER BY o.son_mesaj_at DESC NULLS LAST, o.ts DESC LIMIT 100";
      const rows = await pool.query(sql, p);
      sendJson(response, 200, { oneriler: rows.rows, staff });
      return;
    }
    if (method === "GET" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request);
      const staff = session.sahaRole !== "rep";
      const t = await pool.query(
        `SELECT o.*, COALESCE(u.full_name, u.email) AS kullanici
           FROM saha_oneri o LEFT JOIN users u ON u.id = o.user_id
          WHERE o.id = $1 AND o.tenant_id = $2`, [m[1], session.tenantId]);
      if (!t.rowCount) { sendJson(response, 404, { error: "Kayıt bulunamadı." }); return; }
      const tk = t.rows[0];
      if (!staff && tk.user_id !== session.userId) { sendJson(response, 403, { error: "Yetkiniz yok." }); return; }
      const msgs = await pool.query(
        `SELECT m2.id, m2.ts, m2.tip, m2.mesaj, m2.user_id,
                COALESCE(u.full_name, u.email, 'Sistem') AS yazar
           FROM saha_oneri_mesaj m2 LEFT JOIN users u ON u.id = m2.user_id
          WHERE m2.oneri_id = $1 AND m2.tenant_id = $2 ORDER BY m2.ts`, [m[1], session.tenantId]);
      await pool.query(
        `INSERT INTO saha_oneri_okuma (tenant_id, oneri_id, user_id, okundu_at) VALUES ($1,$2,$3,now())
         ON CONFLICT (oneri_id, user_id) DO UPDATE SET okundu_at = now()`,
        [session.tenantId, m[1], session.userId]);
      sendJson(response, 200, { oneri: tk, mesajlar: msgs.rows, staff, ben: session.userId });
      return;
    }
    if (method === "POST" && path === "/api/saha/oneri") {
      const session = await requireSahaAccess(request);
      const body = await readJson(request);
      let { kategori='DIGER', baslik, mesaj } = body;
      if (!["HATA","OZELLIK","UI","DIGER"].includes(kategori)) kategori = "DIGER";
      if (!baslik || !mesaj) { sendJson(response, 400, { error: 'baslik ve mesaj zorunlu' }); return; }
      const ins = await pool.query(
        `INSERT INTO saha_oneri (id,tenant_id,user_id,kategori,baslik,mesaj,durum,modul,son_mesaj_at)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,'YENI','saha',now()) RETURNING id`,
        [session.tenantId, session.userId, kategori, baslik, mesaj]
      );
      const oid = ins.rows[0].id;
      await pool.query(
        `INSERT INTO saha_oneri_mesaj (tenant_id, oneri_id, user_id, tip, mesaj) VALUES ($1,$2,$3,'MESAJ',$4)`,
        [session.tenantId, oid, session.userId, mesaj]);
      await pool.query(
        `INSERT INTO saha_oneri_okuma (tenant_id, oneri_id, user_id, okundu_at) VALUES ($1,$2,$3,now())
         ON CONFLICT (oneri_id, user_id) DO UPDATE SET okundu_at = now()`,
        [session.tenantId, oid, session.userId]);
      sendJson(response, 201, { ok: true, id: oid });
      oneriBildirim(session.tenantId, oid, "YENI", session.userId);
      return;
    }
    if (method === "POST" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})\\/mesaj$/))) {
      const session = await requireSahaAccess(request);
      const body = await readJson(request);
      const yeni = String(body.mesaj || "").trim();
      if (!yeni) { sendJson(response, 400, { error: "mesaj zorunlu" }); return; }
      const staff = session.sahaRole !== "rep";
      const t = await pool.query("SELECT id, user_id FROM saha_oneri WHERE id=$1 AND tenant_id=$2", [m[1], session.tenantId]);
      if (!t.rowCount) { sendJson(response, 404, { error: "Kayıt bulunamadı." }); return; }
      if (!staff && t.rows[0].user_id !== session.userId) { sendJson(response, 403, { error: "Yetkiniz yok." }); return; }
      await pool.query(
        `INSERT INTO saha_oneri_mesaj (tenant_id, oneri_id, user_id, tip, mesaj) VALUES ($1,$2,$3,'MESAJ',$4)`,
        [session.tenantId, m[1], session.userId, yeni]);
      await pool.query("UPDATE saha_oneri SET son_mesaj_at = now() WHERE id=$1 AND tenant_id=$2", [m[1], session.tenantId]);
      await pool.query(
        `INSERT INTO saha_oneri_okuma (tenant_id, oneri_id, user_id, okundu_at) VALUES ($1,$2,$3,now())
         ON CONFLICT (oneri_id, user_id) DO UPDATE SET okundu_at = now()`,
        [session.tenantId, m[1], session.userId]);
      sendJson(response, 200, { ok: true });
      oneriBildirim(session.tenantId, m[1], staff ? "YANIT_SAHIBE" : "YANIT_EKIBE", session.userId);
      return;
    }
    if (method === "PUT" && (m = path.match(/^\\/api\\/saha\\/oneriler\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request, ['manager','admin']);
      const body = await readJson(request);
      const { durum, yonetici_notu } = body;
      const GECERLI = ['YENI','INCELENIYOR','TAMAMLANDI','REDDEDILDI'];
      if (durum && !GECERLI.includes(durum)) { sendJson(response, 400, { error: "Geçersiz durum." }); return; }
      const onc = await pool.query("SELECT durum FROM saha_oneri WHERE id=$1 AND tenant_id=$2", [m[1], session.tenantId]);
      if (!onc.rowCount) { sendJson(response, 404, { error: "Kayıt bulunamadı." }); return; }
      const eski = onc.rows[0].durum;
      await pool.query(
        `UPDATE saha_oneri SET durum=COALESCE($2,durum), yonetici_notu=COALESCE($3,yonetici_notu),
                guncellendi_at=now(), son_mesaj_at=now()
          WHERE id=$1 AND tenant_id=$4`,
        [m[1], durum||null, yonetici_notu||null, session.tenantId]
      );
      const DUR = { YENI: "Yeni", INCELENIYOR: "İnceleniyor", TAMAMLANDI: "Tamamlandı", REDDEDILDI: "Reddedildi" };
      const degisti = durum && durum !== eski;
      if (degisti) {
        await pool.query(
          `INSERT INTO saha_oneri_mesaj (tenant_id, oneri_id, user_id, tip, mesaj) VALUES ($1,$2,$3,'DURUM',$4)`,
          [session.tenantId, m[1], session.userId, `Durum: ${DUR[eski] || eski} → ${DUR[durum] || durum}`]);
      }
      if (yonetici_notu && String(yonetici_notu).trim()) {
        await pool.query(
          `INSERT INTO saha_oneri_mesaj (tenant_id, oneri_id, user_id, tip, mesaj) VALUES ($1,$2,$3,'MESAJ',$4)`,
          [session.tenantId, m[1], session.userId, String(yonetici_notu).trim()]);
      }
      sendJson(response, 200, { ok: true });
      if (degisti || (yonetici_notu && String(yonetici_notu).trim())) {
        oneriBildirim(session.tenantId, m[1], "DURUM", session.userId);
      }
      return;
    }''',
    "oneri-ticket-endpoints")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
