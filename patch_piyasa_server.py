# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# PIYASA_SERVER — file upload endpoints for the Market Intel module.
# saha_dosya (bytea) + POST upload / GET list / GET binary. Mirrors ziyaret_foto.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

ANCHOR = '    if (method === "POST" && path === "/api/saha/rakip-teklif") {'
ENDPOINTS = r'''    if (method === "POST" && path === "/api/saha/piyasa-dosya") {
      const session = await requireSahaAccess(request);
      const p = await readJson(request);
      if (!p.data) { sendJson(response, 400, { error: "data (base64) zorunlu." }); return; }
      const ALLOWED = ["image/jpeg","image/png","image/webp","image/gif","application/pdf"];
      const mime = String(p.mime || "").toLowerCase().split(";")[0].trim();
      if (!ALLOWED.includes(mime)) { sendJson(response, 400, { error: "Yalnizca resim (JPEG/PNG/WebP/GIF) veya PDF yuklenebilir." }); return; }
      const buf = Buffer.from(String(p.data).replace(/^data:[^;]+;base64,/, ""), "base64");
      if (!buf.length) { sendJson(response, 400, { error: "Gecersiz dosya." }); return; }
      if (buf.length > 8 * 1024 * 1024) { sendJson(response, 413, { error: "Dosya 8MB'i asamaz." }); return; }
      const tip = ["FIYAT_LISTESI","KAMPANYA","RAKIP_TEKLIF","DIGER"].includes(p.tip) ? p.tip : "DIGER";
      const r = await query(
        "INSERT INTO saha_dosya (tenant_id, rep_id, tip, baslik, rakip_marka, musteri_id, mime, boyut, veri, notlar) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id, tip, baslik, rakip_marka, mime, boyut, created_at",
        [session.tenantId, session.userId, tip, p.baslik || null, p.rakip_marka || null, p.musteri_id || null, mime, buf.length, buf, p.notlar || null]);
      sendJson(response, 200, { dosya: r.rows[0] });
      return;
    }
    if (method === "GET" && path === "/api/saha/piyasa-dosya") {
      const session = await requireSahaAccess(request);
      const r = await query(
        "SELECT d.id, d.tip, d.baslik, d.rakip_marka, d.mime, d.boyut, d.notlar, d.created_at, m.firma AS musteri, COALESCE(u.full_name,u.email) AS rep FROM saha_dosya d LEFT JOIN saha_musteri m ON m.id=d.musteri_id LEFT JOIN users u ON u.id=d.rep_id WHERE d.tenant_id=$1 ORDER BY d.created_at DESC LIMIT 100",
        [session.tenantId]);
      sendJson(response, 200, { dosyalar: r.rows });
      return;
    }
    if (method === "GET" && (m = path.match(new RegExp("^/api/saha/piyasa-dosya/(" + SAHA_UUID_RE + ")$")))) {
      const session = await requireSahaAccess(request);
      const r = await query("SELECT mime, veri FROM saha_dosya WHERE tenant_id=$1 AND id=$2", [session.tenantId, m[1]]);
      if (!r.rowCount) { sendJson(response, 404, { error: "Dosya bulunamadi." }); return; }
      response.writeHead(200, { "Content-Type": r.rows[0].mime || "application/octet-stream", "Cache-Control": "private, max-age=3600", "X-Content-Type-Options": "nosniff" });
      response.end(r.rows[0].veri);
      return;
    }
'''

c = s.count(ANCHOR)
assert c == 1, "ABORT: rakip-teklif anchor found %d" % c
s = s.replace(ANCHOR, ENDPOINTS + ANCHOR)
print("OK: piyasa-endpoints")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
