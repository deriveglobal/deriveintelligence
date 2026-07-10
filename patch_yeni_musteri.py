# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# YENI_MUSTERI — missing endpoint: Rapor > Özet (manager) calls
# /api/saha/admin/yeni-musteriler which didn't exist -> "Bilinmeyen saha endpoint".
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

ANCHOR = '    if (method === "POST" && path === "/api/saha/admin/users") {'
ENDPOINT = r'''    if (method === "GET" && path === "/api/saha/admin/yeni-musteriler") {
      const session = await requireSahaAccess(request, ["manager","admin"]);
      const _from = url.searchParams.get("from");
      const _to = url.searchParams.get("to");
      const _tip = url.searchParams.get("tip");
      const _p = [session.tenantId];
      let _w = "m.tenant_id=$1";
      if (_from) { _p.push(_from); _w += " AND m.created_at >= $" + _p.length + "::date"; }
      if (_to) { _p.push(_to); _w += " AND m.created_at < ($" + _p.length + "::date + INTERVAL '1 day')"; }
      if (_tip && ["TUKETICI","TICARI"].includes(_tip)) { _p.push(_tip); _w += " AND m.tip=$" + _p.length; }
      const _oz = await query("SELECT COUNT(*)::int AS toplam, COUNT(*) FILTER (WHERE m.lat IS NOT NULL)::int AS konumlu, COUNT(*) FILTER (WHERE m.vergi_no IS NOT NULL AND m.vergi_no <> '')::int AS vkn_var FROM saha_musteri m WHERE " + _w, _p);
      const _ls = await query("SELECT m.id, m.firma, m.tip, m.il, m.ilce, m.durum, m.lat, m.vergi_no, m.created_at, COALESCE(u.full_name,u.email) AS rep FROM saha_musteri m LEFT JOIN users u ON u.id=m.sorumlu_rep WHERE " + _w + " ORDER BY m.created_at DESC LIMIT 200", _p);
      sendJson(response, 200, { ozet: _oz.rows[0], liste: _ls.rows });
      return;
    }
'''

c = s.count(ANCHOR)
assert c == 1, "ABORT: admin/users anchor found %d" % c
s = s.replace(ANCHOR, ENDPOINT + ANCHOR)
print("OK: yeni-musteriler-endpoint")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
