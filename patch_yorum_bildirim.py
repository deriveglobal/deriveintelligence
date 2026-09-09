# -*- coding: utf-8 -*-
# YORUM_BILDIRIM_V1 — ziyaret yorumu yazilinca: ziyaret sahibi (rep) + o ziyarete daha once
#   yorum yapan herkes (yazan HARIC) push + 🔔 inbox alir. Deep-link: type=ziyaret,id=zid.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YORUM_BILDIRIM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = """          [session.tenantId, zid, session.userId, adi, session.sahaRole || "rep", icerik]
        );
        sendJson(response, 201, { yorum: r.rows[0] });"""

NEW = """          [session.tenantId, zid, session.userId, adi, session.sahaRole || "rep", icerik]
        );
        try { /* YORUM_BILDIRIM_V1 — ziyaret sahibi + onceki yorumcular (yazan haric) push+inbox */
          const _zr = await pool.query("SELECT z.rep_id, m.firma FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id=z.musteri_id WHERE z.id=$1 AND z.tenant_id=$2", [zid, session.tenantId]);
          const _sahip = _zr.rows[0] && _zr.rows[0].rep_id;
          const _firma = (_zr.rows[0] && _zr.rows[0].firma) || "Ziyaret";
          const _kr = await pool.query("SELECT DISTINCT user_id FROM saha_ziyaret_yorum WHERE tenant_id=$1 AND ziyaret_id=$2", [session.tenantId, zid]);
          const _hedef = new Set();
          if (_sahip) _hedef.add(_sahip);
          for (const _x of _kr.rows) { if (_x.user_id) _hedef.add(_x.user_id); }
          _hedef.delete(session.userId);
          const _ids = Array.from(_hedef);
          if (_ids.length) {
            const _snip = icerik.length > 90 ? icerik.slice(0, 90) + "…" : icerik;
            pushToUsers(session.tenantId, _ids, "💬 Ziyaret yorumu", adi + " · " + _firma + ": " + _snip, { room: "saha", type: "ziyaret", id: zid }).catch(function () {});
          }
        } catch (e) { try { console.warn("yorum bildirim:", e.message); } catch (er) {} }
        sendJson(response, 201, { yorum: r.rows[0] });"""

assert s.count(OLD) == 1, "anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YORUM_BILDIRIM_V1 (server)")
