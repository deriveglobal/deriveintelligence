# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ERP_MATCH_SERVER — let reps match a flagged customer to the FULL ERP master
# (master_musteri, ~26k), not just the fuzzy saha_musteri suggestion.
#   GET  /api/saha/erp-ara?q=...          -> search master_musteri by name
#   karar='ERP_ESLE' {erp_kod}            -> merge into existing ERP-linked card,
#                                            or adopt the ERP code onto the flagged card
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) ERP search endpoint (before kontrol-musteriler)
rep(
'    if (method === "GET" && path === "/api/saha/kontrol-musteriler") {',
'''    if (method === "GET" && path === "/api/saha/erp-ara") {
      const session = await requireSahaAccess(request);
      const qy = (url.searchParams.get("q") || "").trim();
      if (qy.length < 2) { sendJson(response, 200, { sonuclar: [] }); return; }
      const r = await pool.query(
        "SELECT musteri_kodu AS kod, musteri_adi, COALESCE(sehir,'') AS sehir, COALESCE(vergi_no,'') AS vergi_no FROM master_musteri WHERE tenant_id=$1 AND musteri_adi ILIKE $2 ORDER BY musteri_adi LIMIT 20",
        [session.tenantId, "%" + qy + "%"]);
      sendJson(response, 200, { sonuclar: r.rows });
      return;
    }
    if (method === "GET" && path === "/api/saha/kontrol-musteriler") {''',
    "erp-ara-endpoint")

# 2) ERP_ESLE decision handling
rep(
'''      sendJson(response, 400, { error: "karar YENI veya BIRLESTIR olmalı." });
      return;
    }''',
'''      if (p.karar === "ERP_ESLE") {
        const kod = String(p.erp_kod || "").trim();
        if (!kod) { sendJson(response, 400, { error: "erp_kod gerekli." }); return; }
        const erp = await pool.query("SELECT musteri_kodu, musteri_adi, COALESCE(vergi_no,'') vergi_no FROM master_musteri WHERE tenant_id=$1 AND musteri_kodu=$2 LIMIT 1", [session.tenantId, kod]);
        if (!erp.rowCount) { sendJson(response, 404, { error: "ERP müşterisi bulunamadı." }); return; }
        const mev = await pool.query("SELECT id FROM saha_musteri WHERE tenant_id=$1 AND musteri_kodu=$2 AND aktif=true AND id<>$3 LIMIT 1", [session.tenantId, kod, id]);
        if (mev.rowCount) {
          const hedef = mev.rows[0].id;
          const client = await requireDatabase().connect();
          try {
            await client.query("BEGIN");
            for (const t of ["saha_ziyaret", "saha_iskonto_talep", "saha_teklif", "saha_musteri_lokasyon"]) {
              await client.query(`UPDATE ${t} SET musteri_id=$2 WHERE tenant_id=$1 AND musteri_id=$3`, [session.tenantId, hedef, id]);
            }
            await client.query("UPDATE saha_musteri SET aktif=false, updated_at=now(), notlar=COALESCE(notlar||' | ','')||'BİRLEŞTİRİLDİ (ERP) → '||$2::text WHERE tenant_id=$1 AND id=$3", [session.tenantId, hedef, id]);
            await client.query("COMMIT");
            sendJson(response, 200, { ok: true, karar: "ERP_ESLE", birlestirildi: true });
          } catch (e) { await client.query("ROLLBACK").catch(() => {}); throw e; } finally { client.release(); }
          return;
        }
        await pool.query("UPDATE saha_musteri SET musteri_kodu=$2, vergi_no=COALESCE(NULLIF($3,''), vergi_no), kayit_kaynagi='SAHA_ZIYARETI', notlar=NULL, updated_at=now() WHERE id=$1 AND tenant_id=$4", [id, kod, erp.rows[0].vergi_no, session.tenantId]);
        sendJson(response, 200, { ok: true, karar: "ERP_ESLE", birlestirildi: false });
        return;
      }
      sendJson(response, 400, { error: "karar YENI, BIRLESTIR veya ERP_ESLE olmalı." });
      return;
    }''',
    "erp-esle-karar")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
