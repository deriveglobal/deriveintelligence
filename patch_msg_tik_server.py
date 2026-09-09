# -*- coding: utf-8 -*-
# MESAJ_TIK_V1 (server) — thread uc noktalari karsi tarafin son okuma zamanini (karsi_okundu_at)
#   doner. Yonetici :repId -> rep'in okuma zamani; rep -> yoneticilerin en yeni okuma zamani.
#   Boylece istemci "✓✓ Görüldü / ✓ Gönderildi" tikini gosterebilir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MESAJ_TIK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) Yonetici :repId
OLD1 = "      sendJson(response, 200, { konusma_id, mesajlar });"
NEW1 = """      let karsi_okundu_at = null;  /* MESAJ_TIK_V1: karsi tarafin (rep) son okuma zamani */
      if (konusma_id) { try { const _kr = await pool.query(`SELECT son_okunan_at FROM saha_konusma_okundu WHERE konusma_id=$1 AND user_id=$2`, [konusma_id, repId]); karsi_okundu_at = _kr.rows[0] ? _kr.rows[0].son_okunan_at : null; } catch (_) {} }
      sendJson(response, 200, { konusma_id, mesajlar, karsi_okundu_at });"""
assert s.count(OLD1) == 1, "repId sendJson anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# E2) Rep branch
OLD2 = "        sendJson(response, 200, { konusma_id, mesajlar: mRes.rows, yayimlar });"
NEW2 = """        let karsi_okundu_at = null;  /* MESAJ_TIK_V1: yoneticilerin en yeni okuma zamani */
        try { const _kr = await pool.query(`SELECT MAX(son_okunan_at) AS t FROM saha_konusma_okundu WHERE konusma_id=$1 AND user_id<>$2`, [konusma_id, session.userId]); karsi_okundu_at = _kr.rows[0] ? _kr.rows[0].t : null; } catch (_) {}
        sendJson(response, 200, { konusma_id, mesajlar: mRes.rows, yayimlar, karsi_okundu_at });"""
assert s.count(OLD2) == 1, "rep sendJson anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MESAJ_TIK_V1")
