# -*- coding: utf-8 -*-
# YAYIM_OKUNDU_V1 (server) — Yayim (broadcast) hesap verebilirlik:
#   - rep Mesajlar'i acinca YAYIM konusmalarini da okundu isaretle (son_okunan_at).
#   - yonetici yayim listesi her yayim icin kac rep okudu (okuyan) + toplam rep (rep_toplam) doner.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YAYIM_OKUNDU_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) rep thread acinca YAYIM okundu (karsi_okundu_at satirindan once)
OLD1 = "        let karsi_okundu_at = null;  /* MESAJ_TIK_V1: yoneticilerin en yeni okuma zamani */"
NEW1 = """        try {  /* YAYIM_OKUNDU_V1: rep thread acinca YAYIM konusmalarini okundu yap */
          await pool.query(`INSERT INTO saha_konusma_okundu (konusma_id,user_id,son_okunan_at) SELECT k.id,$2,now() FROM saha_konusma k WHERE k.tenant_id=$1 AND k.rep_id=$2 AND k.tip='YAYIM' ON CONFLICT (konusma_id,user_id) DO UPDATE SET son_okunan_at=now()`, [tid, session.userId]);
        } catch (_) {}
        let karsi_okundu_at = null;  /* MESAJ_TIK_V1: yoneticilerin en yeni okuma zamani */"""
assert s.count(OLD1) == 1, "rep-karsi anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# E2) yonetici yayim sorgusu -> okuyan sayaci
OLD2 = """          const yRes = await pool.query(
            `SELECT DISTINCT ON (m.icerik) m.icerik, m.created_at, m.gonderen_adi
               FROM saha_konusma k
               JOIN saha_konusma_mesaj m ON m.konusma_id=k.id
              WHERE k.tenant_id=$1 AND k.tip='YAYIM'
              ORDER BY m.icerik, m.created_at DESC
              LIMIT 5`,
            [tid]
          );"""
NEW2 = """          const yRes = await pool.query(  /* YAYIM_OKUNDU_V1: okuyan sayaci */
            `SELECT x.icerik, x.created_at, x.gonderen_adi,
                (SELECT count(DISTINCT k2.rep_id) FROM saha_konusma k2
                   JOIN saha_konusma_mesaj m2 ON m2.konusma_id=k2.id
                   JOIN saha_konusma_okundu o2 ON o2.konusma_id=k2.id AND o2.user_id=k2.rep_id
                  WHERE k2.tenant_id=$1 AND k2.tip='YAYIM' AND m2.icerik=x.icerik AND o2.son_okunan_at >= m2.created_at)::int AS okuyan
             FROM (
               SELECT DISTINCT ON (m.icerik) m.icerik, m.created_at, m.gonderen_adi
                 FROM saha_konusma k JOIN saha_konusma_mesaj m ON m.konusma_id=k.id
                WHERE k.tenant_id=$1 AND k.tip='YAYIM'
                ORDER BY m.icerik, m.created_at DESC LIMIT 5
             ) x
             ORDER BY x.created_at DESC`,
            [tid]
          );"""
assert s.count(OLD2) == 1, "yayim-query anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# E3) manager sendJson -> rep_toplam
OLD3 = "        sendJson(response, 200, { konusmalar: rows.rows, yayimlar });"
NEW3 = """        let rep_toplam = 0;  /* YAYIM_OKUNDU_V1 */
        try { const _rt = await pool.query(`SELECT count(*)::int AS n FROM users u JOIN tenant_user_modules um ON um.user_id=u.id AND um.module_id='saha' AND um.tenant_id=$1 AND um.active=true AND um.module_role='rep' WHERE u.status <> 'disabled'`, [tid]); rep_toplam = _rt.rows[0].n; } catch (_) {}
        sendJson(response, 200, { konusmalar: rows.rows, yayimlar, rep_toplam });"""
assert s.count(OLD3) == 1, "mgr-sendjson anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] YAYIM_OKUNDU_V1")
