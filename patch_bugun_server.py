# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# BUGUN_V1 (server) — /api/saha/bugun: compute real unread announcements +
# reader counts (rep_sayisi), and wire hatirlatmalar (reminders) from saha_rep_not.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = '''      sendJson(response, 200, {
        bugun: today,
        ziyaretler,
        duyurular_okunmamis: [],
        mesaj_okunmamis: 0,
        teklifler,
        hatirlatmalar: []
      });'''

NEW = '''      // Duyurular (reader counts) + hatirlatmalar
      let duyurular_okunmamis = [], duyurular_yeni_sayisi = 0, rep_sayisi = 0, hatirlatmalar = [];
      try {
        const _isRep = session.sahaRole === "rep";
        const _base = "SELECT d.id, d.baslik, d.yazan_adi, d.onem, COALESCE(d.tip,'DUYURU') AS tip, d.created_at, (SELECT count(*) FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id) AS okuyan_sayisi, EXISTS(SELECT 1 FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2) AS okundu FROM saha_duyuru d WHERE d.tenant_id=$1";
        const _dq = _isRep ? (_base + " AND NOT EXISTS(SELECT 1 FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2) ORDER BY d.created_at DESC LIMIT 10") : (_base + " ORDER BY d.created_at DESC LIMIT 6");
        duyurular_okunmamis = (await pool.query(_dq, [tid, session.userId])).rows;
        const _yq = await pool.query("SELECT count(*)::int AS n FROM saha_duyuru d WHERE d.tenant_id=$1 AND NOT EXISTS(SELECT 1 FROM saha_duyuru_okundu o WHERE o.duyuru_id=d.id AND o.user_id=$2)", [tid, session.userId]);
        duyurular_yeni_sayisi = _yq.rows[0].n;
        const _rq = await pool.query("SELECT count(*)::int AS n FROM users u JOIN tenant_user_modules tum ON tum.user_id=u.id AND tum.module_id='saha' AND tum.tenant_id=$1 AND tum.active=true WHERE u.status != 'disabled'", [tid]);
        rep_sayisi = _rq.rows[0].n;
      } catch (e) {}
      try {
        hatirlatmalar = (await pool.query("SELECT id, icerik, hatirlatma_tarihi FROM saha_rep_not WHERE tenant_id=$1 AND rep_id=$2 AND tamamlandi=false AND hatirlatma_tarihi IS NOT NULL AND hatirlatma_tarihi <= (CURRENT_DATE + INTERVAL '1 day') ORDER BY hatirlatma_tarihi ASC LIMIT 10", [tid, session.userId])).rows;
      } catch (e) {}

      sendJson(response, 200, {
        bugun: today,
        ziyaretler,
        duyurular_okunmamis,
        duyurular_yeni_sayisi,
        rep_sayisi,
        mesaj_okunmamis: 0,
        teklifler,
        hatirlatmalar
      });'''

c = s.count(OLD)
assert c == 1, "ABORT: bugun return block found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: bugun-compute")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
