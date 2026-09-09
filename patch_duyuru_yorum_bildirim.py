# -*- coding: utf-8 -*-
# DUYURU_YORUM_BILDIRIM_V1 — duyuru yorumu yazilinca: duyuru sahibi (yazan) + o duyuruya daha once
#   yorum yapan herkes (yazan HARIC) push + 🔔 inbox alir. Deep-link: type=duyuru,id=duyuru.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "DUYURU_YORUM_BILDIRIM_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = """      await pool.query("INSERT INTO saha_duyuru_yorum (id,tenant_id,duyuru_id,user_id,user_adi,rol,icerik) VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6)", [session.tenantId, m[1], session.userId, session.name || 'Kullanıcı', session.sahaRole || 'rep', icerik]);"""

NEW = OLD + r"""
      try { /* DUYURU_YORUM_BILDIRIM_V1 — duyuru sahibi + onceki yorumcular (yazan haric) push+inbox */
        const _dr = await pool.query("SELECT yazan_id, baslik FROM saha_duyuru WHERE id=$1 AND tenant_id=$2", [m[1], session.tenantId]);
        const _yazan = _dr.rows[0] && _dr.rows[0].yazan_id;
        const _baslik = (_dr.rows[0] && _dr.rows[0].baslik) || "Duyuru";
        const _kr = await pool.query("SELECT DISTINCT user_id FROM saha_duyuru_yorum WHERE tenant_id=$1 AND duyuru_id=$2", [session.tenantId, m[1]]);
        const _hedef = new Set();
        if (_yazan) _hedef.add(_yazan);
        for (const _x of _kr.rows) { if (_x.user_id) _hedef.add(_x.user_id); }
        _hedef.delete(session.userId);
        const _ids = Array.from(_hedef);
        if (_ids.length) {
          const _snip = icerik.length > 90 ? icerik.slice(0, 90) + "…" : icerik;
          pushToUsers(session.tenantId, _ids, "💬 Duyuru yorumu", (session.name || "Kullanıcı") + " · " + _baslik + ": " + _snip, { room: "reception", type: "duyuru", id: m[1] }).catch(function () {});
        }
      } catch (e) { try { console.warn("duyuru yorum bildirim:", e.message); } catch (er) {} }"""

assert s.count(OLD) == 1, "anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] DUYURU_YORUM_BILDIRIM_V1 (server)")
