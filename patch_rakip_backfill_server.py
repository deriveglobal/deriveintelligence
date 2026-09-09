# -*- coding: utf-8 -*-
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAKIP_OCR_BACKFILL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCHOR = '    // ── Tekil foto sil (duzenleme) — ZIYARET_FOTO_SIL_V1 ──'
ENDPOINT = '''    // ── Fotoğraftan rakip fiyat oku (mevcut fotoları yeniden tara) — RAKIP_OCR_BACKFILL_V1 ──
    if (method === "POST" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/foto-oku$`)))) {
      const session = await requireSahaAccess(request, ["manager", "admin"]);
      const fr = await pool.query("SELECT id, mime, veri FROM saha_ziyaret_foto WHERE tenant_id=$1 AND ziyaret_id=$2 ORDER BY created_at", [session.tenantId, m[1]]);
      if (!fr.rowCount) { sendJson(response, 200, { islenen_foto: 0, cikarilan_kalem: 0 }); return; }
      await pool.query("DELETE FROM saha_rakip_teklif WHERE tenant_id=$1 AND ziyaret_id=$2 AND kaynak='FOTO'", [session.tenantId, m[1]]);
      for (const f of fr.rows) { try { await _rakipFotoCoz(session.tenantId, f.id, m[1], session.userId, f.mime, f.veri); } catch (e) {} }
      const cc = await pool.query("SELECT count(*)::int c FROM saha_rakip_teklif WHERE tenant_id=$1 AND ziyaret_id=$2 AND kaynak='FOTO'", [session.tenantId, m[1]]);
      sendJson(response, 200, { islenen_foto: fr.rowCount, cikarilan_kalem: cc.rows[0].c });
      return;
    }

''' + ANCHOR
assert s.count(ANCHOR) == 1, "anchor count=%d" % s.count(ANCHOR)
s = s.replace(ANCHOR, ENDPOINT, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] RAKIP_OCR_BACKFILL_V1 (server)")
