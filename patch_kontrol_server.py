# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# KONTROL_SERVER — rep-facing review of EXCEL_IMPORT_KONTROL customers.
#   GET  /api/saha/kontrol-musteriler         -> this rep's flagged customers
#   POST /api/saha/kontrol-musteri-karar      -> {id, karar:'YENI'|'BIRLESTIR', hedef_id}
#     YENI: clear the flag (kayit_kaynagi=SAHA_ZIYARETI). BIRLESTIR: merge into hedef.
# Rep-scoped: only customers that have a visit by the requesting rep.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

ANCHOR = '    if (method === "POST" && path === "/api/saha/mukerrer-birlestir") {'
BLOCK = r'''    if (method === "GET" && path === "/api/saha/kontrol-musteriler") {
      const session = await requireSahaAccess(request);
      const r = await pool.query(
        `SELECT m.id, m.firma, m.il, m.ilce, m.notlar,
                (SELECT count(*) FROM saha_ziyaret z WHERE z.musteri_id=m.id) AS ziyaret_sayisi
           FROM saha_musteri m
          WHERE m.tenant_id=$1 AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL' AND m.aktif=true
            AND EXISTS (SELECT 1 FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.rep_id=$2)
          ORDER BY m.firma`,
        [session.tenantId, session.userId]);
      sendJson(response, 200, { musteriler: r.rows });
      return;
    }
    if (method === "POST" && path === "/api/saha/kontrol-musteri-karar") {
      const session = await requireSahaAccess(request);
      const p = await readJson(request);
      const uuidOk = new RegExp(`^${SAHA_UUID_RE}$`);
      const id = p.id;
      if (!uuidOk.test(id || "")) { sendJson(response, 400, { error: "id gerekli." }); return; }
      const own = await pool.query(
        "SELECT 1 FROM saha_musteri m WHERE m.id=$1 AND m.tenant_id=$2 AND m.kayit_kaynagi='EXCEL_IMPORT_KONTROL' AND m.aktif=true AND EXISTS(SELECT 1 FROM saha_ziyaret z WHERE z.musteri_id=m.id AND z.rep_id=$3)",
        [id, session.tenantId, session.userId]);
      if (!own.rowCount) { sendJson(response, 403, { error: "Bu müşteri için yetkiniz yok." }); return; }
      if (p.karar === "YENI") {
        await pool.query("UPDATE saha_musteri SET kayit_kaynagi='SAHA_ZIYARETI', notlar=NULL, updated_at=now() WHERE id=$1 AND tenant_id=$2", [id, session.tenantId]);
        sendJson(response, 200, { ok: true, karar: "YENI" });
        return;
      }
      if (p.karar === "BIRLESTIR") {
        const hedef = p.hedef_id;
        if (!uuidOk.test(hedef || "") || hedef === id) { sendJson(response, 400, { error: "Geçerli hedef_id gerekli." }); return; }
        const client = await requireDatabase().connect();
        try {
          await client.query("BEGIN");
          const chk = await client.query("SELECT count(*) n FROM saha_musteri WHERE tenant_id=$1 AND id=ANY($2::uuid[]) AND aktif=true", [session.tenantId, [hedef, id]]);
          if (Number(chk.rows[0].n) !== 2) throw Object.assign(new Error("Kart bulunamadı."), { statusCode: 404 });
          for (const t of ["saha_ziyaret", "saha_iskonto_talep", "saha_teklif", "saha_musteri_lokasyon"]) {
            await client.query(`UPDATE ${t} SET musteri_id=$2 WHERE tenant_id=$1 AND musteri_id=$3`, [session.tenantId, hedef, id]);
          }
          await client.query("UPDATE saha_musteri SET aktif=false, updated_at=now(), notlar=COALESCE(notlar||' | ','')||'BİRLEŞTİRİLDİ → '||$2::text WHERE tenant_id=$1 AND id=$3", [session.tenantId, hedef, id]);
          await client.query("COMMIT");
          sendJson(response, 200, { ok: true, karar: "BIRLESTIR" });
        } catch (e) { await client.query("ROLLBACK").catch(() => {}); throw e; }
        finally { client.release(); }
        return;
      }
      sendJson(response, 400, { error: "karar YENI veya BIRLESTIR olmalı." });
      return;
    }
'''
c = s.count(ANCHOR)
assert c == 1, "ABORT: mukerrer-birlestir anchor found %d" % c
s = s.replace(ANCHOR, BLOCK + ANCHOR)
print("OK: kontrol-endpoints")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
