# -*- coding: utf-8 -*-
# MESAJ_OKUNDU_V1 — Mesajlasma icin okundu/okunmadi (seen/unseen) + bildirim.
#   Sorunlar:
#     (a) Mesaj gonderilince alici BILDIRIM ALMIYORDU (pushToUsers cagrilmiyordu).
#     (b) Yonetici konusma listesinde okunmamis HEP 0 idi (0::int AS okunmamis).
#     (c) Bugun "Mesaj" sayaci HARDCODE 0 idi.
#     (d) saha_konusma_okundu tablosu vardi ama HIC yazilmiyor/okunmuyordu.
#   Cozum: gonderimde pushToUsers ile bildir; konusma acilinca okundu yaz + mesaj
#   bildirimini okundu yap; okunmamis gercek hesaplansin (liste + Bugun).
#   NOT: her iki shell zaten k.okunmamis'e gore seen/unseen (mavi cizgi + "N yeni")
#   ciziyor; sadece server gercek sayiyi dondurunce calisiyor. Shell degisikligi yok.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MESAJ_OKUNDU_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# ── 1) Gonderimde bildirim (pushToUsers) ────────────────────────────────────
OLD1 = '''        [session.tenantId, konusmaId, session.userId, session.name || "Kullanıcı", session.sahaRole || "rep", icerik]
      );
      sendJson(response, 201, { ok: true });'''
NEW1 = '''        [session.tenantId, konusmaId, session.userId, session.name || "Kullanıcı", session.sahaRole || "rep", icerik]
      );
      try {  /* MESAJ_OKUNDU_V1: aliciyi bildir (bell + push) */
        const _mtitle = "💬 Yeni mesaj";
        const _mbody = (session.name || "Kullanıcı") + ": " + String(icerik).slice(0, 90);
        const _mdata = { room: "saha", type: "mesaj", konusma_id: konusmaId };
        if (session.sahaRole === "rep") {
          sahaManagerIds(session.tenantId, session.userId).then(function (ids) { if (ids && ids.length) pushToUsers(session.tenantId, ids, _mtitle, _mbody, _mdata); }).catch(function () {});
        } else {
          const _rid = _kown.rows[0].rep_id;
          if (_rid && _rid !== session.userId) pushToUsers(session.tenantId, [_rid], _mtitle, _mbody, _mdata).catch(function () {});
        }
      } catch (e) {}
      sendJson(response, 201, { ok: true });'''
assert s.count(OLD1) == 1, "send anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# ── 2) Rep konusmasini acinca okundu yaz + mesaj bildirimini okundu yap ──────
OLD2 = '        sendJson(response, 200, { konusma_id, mesajlar: mRes.rows, yayimlar });'
NEW2 = '''        try {  /* MESAJ_OKUNDU_V1 */
          await pool.query(`INSERT INTO saha_konusma_okundu (konusma_id,user_id,son_okunan_at) VALUES ($1,$2,now()) ON CONFLICT (konusma_id,user_id) DO UPDATE SET son_okunan_at=now()`, [konusma_id, session.userId]);
          await pool.query(`UPDATE bi_bildirim SET okundu=true WHERE tenant_id=$1 AND user_id=$2 AND okundu=false AND tip='mesaj' AND data->>'konusma_id'=$3`, [tid, session.userId, konusma_id]);
        } catch (_) {}
        sendJson(response, 200, { konusma_id, mesajlar: mRes.rows, yayimlar });'''
assert s.count(OLD2) == 1, "rep-open anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# ── 3) Yonetici bir rep thread'ini acinca okundu yaz + bildirim okundu ───────
OLD3 = '      sendJson(response, 200, { konusma_id, mesajlar });'
NEW3 = '''      if (konusma_id) {  /* MESAJ_OKUNDU_V1 */
        try {
          await pool.query(`INSERT INTO saha_konusma_okundu (konusma_id,user_id,son_okunan_at) VALUES ($1,$2,now()) ON CONFLICT (konusma_id,user_id) DO UPDATE SET son_okunan_at=now()`, [konusma_id, session.userId]);
          await pool.query(`UPDATE bi_bildirim SET okundu=true WHERE tenant_id=$1 AND user_id=$2 AND okundu=false AND tip='mesaj' AND data->>'konusma_id'=$3`, [tid, session.userId, konusma_id]);
        } catch (_) {}
      }
      sendJson(response, 200, { konusma_id, mesajlar });'''
assert s.count(OLD3) == 1, "mgr-open anchor count=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# ── 4a) Yonetici liste: gercek okunmamis ────────────────────────────────────
OLD4 = '              0::int AS okunmamis'
NEW4 = "              (SELECT count(*) FROM saha_konusma_mesaj mm WHERE mm.konusma_id=k.id AND mm.gonderen_rol='rep' AND mm.created_at > COALESCE((SELECT son_okunan_at FROM saha_konusma_okundu o WHERE o.konusma_id=k.id AND o.user_id=$2),'epoch'::timestamptz))::int AS okunmamis  /* MESAJ_OKUNDU_V1 */"
assert s.count(OLD4) == 1, "mgr-list-okunmamis anchor count=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

# ── 4b) Yonetici liste: param $2 ekle ───────────────────────────────────────
OLD4b = '''            ORDER BY (SELECT MAX(m3.created_at) FROM saha_konusma_mesaj m3 WHERE m3.konusma_id=k.id) DESC NULLS LAST
            LIMIT 100`,
          [tid]
        );'''
NEW4b = '''            ORDER BY (SELECT MAX(m3.created_at) FROM saha_konusma_mesaj m3 WHERE m3.konusma_id=k.id) DESC NULLS LAST
            LIMIT 100`,
          [tid, session.userId]  /* MESAJ_OKUNDU_V1 */
        );'''
assert s.count(OLD4b) == 1, "mgr-list-param anchor count=%d" % s.count(OLD4b)
s = s.replace(OLD4b, NEW4b, 1)

# ── 5) Bugun mesaj_okunmamis gercek hesap ───────────────────────────────────
OLD5 = '''      sendJson(response, 200, {
        bugun: today,'''
NEW5 = '''      let mesaj_okunmamis = 0;  /* MESAJ_OKUNDU_V1 */
      try {
        const _mrole = session.sahaRole === "rep";
        const _msql = _mrole
          ? `SELECT count(*)::int AS n FROM saha_konusma k JOIN saha_konusma_mesaj m ON m.konusma_id=k.id LEFT JOIN saha_konusma_okundu o ON o.konusma_id=k.id AND o.user_id=$2 WHERE k.tenant_id=$1 AND k.rep_id=$2 AND k.tip='BIREYSEL' AND m.gonderen_rol<>'rep' AND m.created_at > COALESCE(o.son_okunan_at,'epoch'::timestamptz)`
          : `SELECT count(*)::int AS n FROM saha_konusma k JOIN saha_konusma_mesaj m ON m.konusma_id=k.id LEFT JOIN saha_konusma_okundu o ON o.konusma_id=k.id AND o.user_id=$2 WHERE k.tenant_id=$1 AND k.tip='BIREYSEL' AND m.gonderen_rol='rep' AND m.created_at > COALESCE(o.son_okunan_at,'epoch'::timestamptz)`;
        mesaj_okunmamis = (await pool.query(_msql, [tid, session.userId])).rows[0].n;
      } catch (e) {}
      sendJson(response, 200, {
        bugun: today,'''
assert s.count(OLD5) == 1, "bugun-compute anchor count=%d" % s.count(OLD5)
s = s.replace(OLD5, NEW5, 1)

OLD5b = '        mesaj_okunmamis: 0,'
NEW5b = '        mesaj_okunmamis,  /* MESAJ_OKUNDU_V1 */'
assert s.count(OLD5b) == 1, "bugun-field anchor count=%d" % s.count(OLD5b)
s = s.replace(OLD5b, NEW5b, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MESAJ_OKUNDU_V1")
