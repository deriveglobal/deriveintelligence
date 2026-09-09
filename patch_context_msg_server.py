# -*- coding: utf-8 -*-
# CONTEXT_MSG_V1 (server) — baglamsal mesaj:
#   - POST /api/saha/musteri/:id/mesaj — musterinin sorumlu_rep'ine, baglam iliştirilmiş mesaj.
#   - thread SELECT'leri baglam_tip/id/etiket doner (istemci 🔗 rozeti gosterir).
#   (baglam kolonlari deploy'da ALTER ile eklenir.)
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "CONTEXT_MSG_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) thread SELECT'lerine baglam ekle (2 yer: rep branch + :repId)
OLD1 = """SELECT id, gonderen_id, gonderen_adi, gonderen_rol, icerik, created_at
             FROM saha_konusma_mesaj WHERE konusma_id=$1 AND tenant_id=$2"""
NEW1 = """SELECT id, gonderen_id, gonderen_adi, gonderen_rol, icerik, created_at, baglam_tip, baglam_id, baglam_etiket
             FROM saha_konusma_mesaj WHERE konusma_id=$1 AND tenant_id=$2"""
assert s.count(OLD1) == 2, "thread-select anchor=%d (2 bekleniyor)" % s.count(OLD1)
s = s.replace(OLD1, NEW1)  # ikisini de

# E2) yeni endpoint — send endpoint yorumundan once ekle
ANCH = "    // POST /api/saha/konusmalar/:konusmaId — mesaj gönder"
ENDPOINT = """    // ══ MUSTERI BAGLAMLI MESAJ (contextual) — CONTEXT_MSG_V1 ══
    if (method === "POST" && (m = path.match(/^\\/api\\/saha\\/musteri\\/([^/]+)\\/mesaj$/))) {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const musteriId = m[1];
      const body = await readJson(request);
      const icerik = body && body.icerik;
      if (!icerik) { sendJson(response, 400, { error: "icerik zorunlu" }); return; }
      const mus = await pool.query(`SELECT id, firma, sorumlu_rep FROM saha_musteri WHERE tenant_id=$1 AND id=$2`, [session.tenantId, musteriId]);
      if (!mus.rowCount) { sendJson(response, 404, { error: "Müşteri bulunamadı." }); return; }
      const repId = mus.rows[0].sorumlu_rep;
      const firma = mus.rows[0].firma || "";
      if (!repId) { sendJson(response, 400, { error: "Müşterinin sorumlu temsilcisi yok." }); return; }
      let kRes = await pool.query(`SELECT id FROM saha_konusma WHERE tenant_id=$1 AND rep_id=$2 AND tip='BIREYSEL' LIMIT 1`, [session.tenantId, repId]);
      let kid;
      if (kRes.rows.length) { kid = kRes.rows[0].id; }
      else { const ins = await pool.query(`INSERT INTO saha_konusma (id,tenant_id,tip,rep_id) VALUES (gen_random_uuid(),$1,'BIREYSEL',$2) RETURNING id`, [session.tenantId, repId]); kid = ins.rows[0].id; }
      await pool.query(`INSERT INTO saha_konusma_mesaj (id,tenant_id,konusma_id,gonderen_id,gonderen_adi,gonderen_rol,icerik,baglam_tip,baglam_id,baglam_etiket) VALUES (gen_random_uuid(),$1,$2,$3,$4,$5,$6,'musteri',$7,$8)`, [session.tenantId, kid, session.userId, session.name || "Yönetici", session.sahaRole || "manager", icerik, musteriId, firma]);
      try { if (repId !== session.userId) pushToUsers(session.tenantId, [repId], "💬 Yeni mesaj", (session.name || "Yönetici") + " · " + firma + ": " + String(icerik).slice(0, 80), { room: "saha", type: "mesaj", konusma_id: kid }); } catch (e) {}
      sendJson(response, 201, { ok: true, konusma_id: kid });
      return;
    }

"""
assert s.count(ANCH) == 1, "endpoint anchor=%d" % s.count(ANCH)
s = s.replace(ANCH, ENDPOINT + ANCH, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CONTEXT_MSG_V1")
