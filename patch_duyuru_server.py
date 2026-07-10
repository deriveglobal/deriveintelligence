# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# DUYURU_BOARD_V1 (server) — open posting to all reps, add tip (DUYURU/PIYASA),
# list returns tip+counts+rep_sayisi, add GET detail / POST comment / DELETE.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) GET list — add tip, comment count, reader count, rep_sayisi
OLD_GET = '''    if (method === "GET" && path === "/api/saha/duyurular") {
      const session = await requireSahaAccess(request);
      const rows = await pool.query(
        `SELECT d.id, d.yazan_adi, d.baslik, d.icerik, d.onem, d.created_at,
                (SELECT count(*) FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2) > 0 AS okundu
           FROM saha_duyuru d
          WHERE d.tenant_id=$1 ORDER BY d.created_at DESC LIMIT 50`,
        [session.tenantId, session.userId]
      );
      const okunmamis = rows.rows.filter(d => !d.okundu);
      sendJson(response, 200, { duyurular: rows.rows, okunmamis_sayisi: okunmamis.length });
      return;
    }'''
NEW_GET = '''    if (method === "GET" && path === "/api/saha/duyurular") {
      const session = await requireSahaAccess(request);
      const rows = await pool.query(
        `SELECT d.id, d.yazan_adi, d.baslik, d.icerik, d.onem, COALESCE(d.tip,'DUYURU') AS tip, d.created_at,
                (SELECT count(*) FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2) > 0 AS okundu,
                (SELECT count(*) FROM saha_duyuru_yorum y WHERE y.duyuru_id=d.id) AS yorum_sayisi,
                (SELECT count(*) FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id) AS okuyan_sayisi
           FROM saha_duyuru d
          WHERE d.tenant_id=$1 ORDER BY d.created_at DESC LIMIT 50`,
        [session.tenantId, session.userId]
      );
      let repSayisi = 0;
      try { const rsq = await pool.query("SELECT count(*)::int AS n FROM users u JOIN tenant_user_modules tum ON tum.user_id=u.id AND tum.module_id='saha' AND tum.tenant_id=$1 AND tum.active=true WHERE u.status != 'disabled'", [session.tenantId]); repSayisi = rsq.rows[0].n; } catch (e) {}
      const okunmamis = rows.rows.filter(d => !d.okundu);
      sendJson(response, 200, { duyurular: rows.rows, okunmamis_sayisi: okunmamis.length, rep_sayisi: repSayisi });
      return;
    }'''
rep(OLD_GET, NEW_GET, "get-list")

# 2) POST — open to all + tip
OLD_POST = '''    if (method === "POST" && path === "/api/saha/duyurular") {
      const session = await requireSahaAccess(request, ['manager','admin']);
      const body = await readJson(request);
      const { baslik, icerik, onem='NORMAL' } = body;
      if (!baslik || !icerik) { sendJson(response, 400, { error: 'baslik ve icerik zorunlu' }); return; }
      const r = await pool.query(
        `INSERT INTO saha_duyuru (id,tenant_id,yazan_id,yazan_adi,baslik,icerik,onem)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6) RETURNING id`,
        [session.tenantId, session.userId, session.name||'Yönetici', baslik, icerik, onem]
      );
      sendJson(response, 201, { id: r.rows[0].id });
      return;
    }'''
NEW_POST = '''    if (method === "POST" && path === "/api/saha/duyurular") {
      const session = await requireSahaAccess(request);
      const body = await readJson(request);
      const { baslik, icerik, onem='NORMAL', tip='DUYURU' } = body;
      if (!baslik || !icerik) { sendJson(response, 400, { error: 'baslik ve icerik zorunlu' }); return; }
      const _tip = tip === 'PIYASA' ? 'PIYASA' : 'DUYURU';
      const _onem = ['NORMAL','YUKSEK','ACIL'].includes(onem) ? onem : 'NORMAL';
      const r = await pool.query(
        `INSERT INTO saha_duyuru (id,tenant_id,yazan_id,yazan_adi,baslik,icerik,onem,tip)
         VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7) RETURNING id`,
        [session.tenantId, session.userId, session.name||'Kullanıcı', baslik, icerik, _onem, _tip]
      );
      sendJson(response, 201, { id: r.rows[0].id });
      return;
    }'''
rep(OLD_POST, NEW_POST, "post-open")

# 3) new endpoints (GET detail / POST comment / DELETE), before KONUSMALAR
ANCHOR = '    // ══ KONUŞMALAR (mesajlar) ════════════════════════════'
NEWENDPOINTS = '''    if (method === "GET" && (m = path.match(/^\\/api\\/saha\\/duyurular\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request);
      const dr = await pool.query("SELECT id, yazan_id, yazan_adi, baslik, icerik, onem, COALESCE(tip,'DUYURU') AS tip, created_at FROM saha_duyuru WHERE tenant_id=$1 AND id=$2", [session.tenantId, m[1]]);
      if (!dr.rowCount) { sendJson(response, 404, { error: 'Duyuru bulunamadı.' }); return; }
      const yr = await pool.query("SELECT id, user_adi, rol, icerik, created_at FROM saha_duyuru_yorum WHERE tenant_id=$1 AND duyuru_id=$2 ORDER BY created_at ASC", [session.tenantId, m[1]]);
      let okuyanlar = [];
      try { const orr = await pool.query("SELECT u.full_name FROM saha_duyuru_okundu o JOIN users u ON u.id=o.user_id WHERE o.duyuru_id=$1", [m[1]]); okuyanlar = orr.rows; } catch (e) {}
      sendJson(response, 200, { duyuru: dr.rows[0], yorumlar: yr.rows, okuyanlar: okuyanlar });
      return;
    }
    if (method === "POST" && (m = path.match(/^\\/api\\/saha\\/duyurular\\/([0-9a-f-]{36})\\/yorum$/))) {
      const session = await requireSahaAccess(request);
      const body = await readJson(request);
      const icerik = String(body.icerik || '').trim();
      if (!icerik) { sendJson(response, 400, { error: 'icerik zorunlu' }); return; }
      await pool.query("INSERT INTO saha_duyuru_yorum (id,tenant_id,duyuru_id,user_id,user_adi,rol,icerik) VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6)", [session.tenantId, m[1], session.userId, session.name || 'Kullanıcı', session.sahaRole || 'rep', icerik]);
      const yr = await pool.query("SELECT id, user_adi, rol, icerik, created_at FROM saha_duyuru_yorum WHERE tenant_id=$1 AND duyuru_id=$2 ORDER BY created_at ASC", [session.tenantId, m[1]]);
      sendJson(response, 201, { yorumlar: yr.rows });
      return;
    }
    if (method === "DELETE" && (m = path.match(/^\\/api\\/saha\\/duyurular\\/([0-9a-f-]{36})$/))) {
      const session = await requireSahaAccess(request);
      const dr = await pool.query("SELECT yazan_id FROM saha_duyuru WHERE tenant_id=$1 AND id=$2", [session.tenantId, m[1]]);
      if (!dr.rowCount) { sendJson(response, 404, { error: 'Bulunamadı.' }); return; }
      if (session.sahaRole === 'rep' && dr.rows[0].yazan_id !== session.userId) { sendJson(response, 403, { error: 'Sadece kendi paylaşımınızı silebilirsiniz.' }); return; }
      await pool.query("DELETE FROM saha_duyuru WHERE tenant_id=$1 AND id=$2", [session.tenantId, m[1]]);
      sendJson(response, 200, { ok: true });
      return;
    }

'''
rep(ANCHOR, NEWENDPOINTS + ANCHOR, "new-endpoints")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
