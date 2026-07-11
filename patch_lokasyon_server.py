# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# LOKASYON_SERVER — new karar 'LOKASYON' on /api/saha/kontrol-musteri-karar:
# attach a waiting record as a branch/location under a chosen parent customer.
# Creates saha_musteri_lokasyon, re-points the flagged row's visits to the parent
# TAGGED with the new location, re-parents quotes/discounts, retires the flagged row.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''      sendJson(response, 400, { error: "karar YENI, BIRLESTIR veya ERP_ESLE olmalı." });
      return;
    }''',
'''      if (p.karar === "LOKASYON") {
        const hedef = p.hedef_id;
        if (!uuidOk.test(hedef || "") || hedef === id) { sendJson(response, 400, { error: "Geçerli hedef_id gerekli." }); return; }
        const src = await pool.query("SELECT firma, il, ilce, lat, lng FROM saha_musteri WHERE tenant_id=$1 AND id=$2 AND aktif=true", [session.tenantId, id]);
        if (!src.rowCount) { sendJson(response, 404, { error: "Kayit bulunamadi." }); return; }
        const s0 = src.rows[0];
        const client = await requireDatabase().connect();
        try {
          await client.query("BEGIN");
          const chk = await client.query("SELECT count(*) n FROM saha_musteri WHERE tenant_id=$1 AND id=ANY($2::uuid[]) AND aktif=true", [session.tenantId, [hedef, id]]);
          if (Number(chk.rows[0].n) !== 2) throw Object.assign(new Error("Kart bulunamadi."), { statusCode: 404 });
          const loc = await client.query(
            "INSERT INTO saha_musteri_lokasyon (tenant_id, musteri_id, ad, il, ilce, lat, lng, created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8) RETURNING id",
            [session.tenantId, hedef, s0.firma, s0.il || null, s0.ilce || null, s0.lat ?? null, s0.lng ?? null, session.userId]);
          const locId = loc.rows[0].id;
          await client.query("UPDATE saha_ziyaret SET musteri_id=$2, lokasyon_id=$3 WHERE tenant_id=$1 AND musteri_id=$4", [session.tenantId, hedef, locId, id]);
          await client.query("UPDATE saha_iskonto_talep SET musteri_id=$2 WHERE tenant_id=$1 AND musteri_id=$3", [session.tenantId, hedef, id]);
          await client.query("UPDATE saha_teklif SET musteri_id=$2 WHERE tenant_id=$1 AND musteri_id=$3", [session.tenantId, hedef, id]);
          await client.query("UPDATE saha_musteri_lokasyon SET musteri_id=$2 WHERE tenant_id=$1 AND musteri_id=$3", [session.tenantId, hedef, id]);
          await client.query("UPDATE saha_musteri SET aktif=false, updated_at=now(), notlar=COALESCE(notlar||' | ','')||'SUBE OLARAK BAGLANDI -> '||$2::text WHERE tenant_id=$1 AND id=$3", [session.tenantId, hedef, id]);
          await client.query("COMMIT");
          sendJson(response, 200, { ok: true, karar: "LOKASYON", lokasyon_id: locId });
        } catch (e) { await client.query("ROLLBACK").catch(() => {}); throw e; } finally { client.release(); }
        return;
      }
      sendJson(response, 400, { error: "karar YENI, BIRLESTIR, ERP_ESLE veya LOKASYON olmali." });
      return;
    }''',
    "lokasyon-karar")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
