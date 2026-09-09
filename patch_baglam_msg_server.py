# -*- coding: utf-8 -*-
# BAGLAM_MSG_V1 (server) — genel baglamli mesaj endpoint'i:
#   POST /api/saha/baglamli-mesaj { rep_id, icerik, baglam_tip, baglam_id, baglam_etiket }
#   -> rep'in BIREYSEL konusmasina baglam iliştirilmiş mesaj + push. (teklif/ziyaret girisleri kullanir)
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BAGLAM_MSG_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

ANCH = "    // POST /api/saha/konusmalar/:konusmaId — mesaj gönder"
ENDPOINT = """    // ══ GENEL BAGLAMLI MESAJ — BAGLAM_MSG_V1 ══
    if (method === "POST" && path === "/api/saha/baglamli-mesaj") {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const body = await readJson(request);
      const rep_id = body && body.rep_id, icerik = body && body.icerik;
      const baglam_tip = (body && body.baglam_tip) || null, baglam_id = (body && body.baglam_id) || null, baglam_etiket = (body && body.baglam_etiket) || null;
      if (!rep_id || !icerik) { sendJson(response, 400, { error: "rep_id ve icerik zorunlu" }); return; }
      let kRes = await pool.query(`SELECT id FROM saha_konusma WHERE tenant_id=$1 AND rep_id=$2 AND tip='BIREYSEL' LIMIT 1`, [session.tenantId, rep_id]);
      let kid;
      if (kRes.rows.length) { kid = kRes.rows[0].id; }
      else { const ins = await pool.query(`INSERT INTO saha_konusma (id,tenant_id,tip,rep_id) VALUES (gen_random_uuid(),$1,'BIREYSEL',$2) RETURNING id`, [session.tenantId, rep_id]); kid = ins.rows[0].id; }
      await pool.query(`INSERT INTO saha_konusma_mesaj (id,tenant_id,konusma_id,gonderen_id,gonderen_adi,gonderen_rol,icerik,baglam_tip,baglam_id,baglam_etiket) VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,$7,$8,$9)`, [session.tenantId, kid, session.userId, session.name || "Yönetici", session.sahaRole || "manager", icerik, baglam_tip, baglam_id, baglam_etiket]);
      try { if (rep_id !== session.userId) pushToUsers(session.tenantId, [rep_id], "💬 Yeni mesaj", (session.name || "Yönetici") + (baglam_etiket ? " · " + baglam_etiket : "") + ": " + String(icerik).slice(0, 80), { room: "saha", type: "mesaj", konusma_id: kid }); } catch (e) {}
      sendJson(response, 201, { ok: true, konusma_id: kid });
      return;
    }

"""
assert s.count(ANCH) == 1, "anchor=%d" % s.count(ANCH)
s = s.replace(ANCH, ENDPOINT + ANCH, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] BAGLAM_MSG_V1")
