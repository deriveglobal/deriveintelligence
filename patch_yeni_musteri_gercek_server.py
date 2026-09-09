# -*- coding: utf-8 -*-
# YENI_MUSTERI_GERCEK_V1 (server) — /api/saha/admin/yeni-musteriler artik GERÇEK saha edinimini sayar:
#   ilk ziyareti UYGULAMADAN (saha_ziyaret.kaynak='APP') girilen VE Excel master listesinde OLMAYAN
#   (kayit_kaynagi <> 'EXCEL_IMPORT_KONTROL') müşteri. Dönem filtresi ilk-app-ziyaret tarihine göre.
#   Toplu yüklenen (EXCEL_IMPORT_KONTROL + EXCEL_MIGRASYON) müşteriler sayılmaz.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "YENI_MUSTERI_GERCEK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = """      const _p = [session.tenantId];
      let _w = "m.tenant_id=$1";
      if (_from) { _p.push(_from); _w += " AND m.created_at >= $" + _p.length + "::date"; }
      if (_to) { _p.push(_to); _w += " AND m.created_at < ($" + _p.length + "::date + INTERVAL '1 day')"; }
      if (_tip && ["TUKETICI","TICARI"].includes(_tip)) { _p.push(_tip); _w += " AND m.tip=$" + _p.length; }
      const _oz = await query("SELECT COUNT(*)::int AS toplam, COUNT(*) FILTER (WHERE m.lat IS NOT NULL)::int AS konumlu, COUNT(*) FILTER (WHERE m.vergi_no IS NOT NULL AND m.vergi_no <> '')::int AS vkn_var FROM saha_musteri m WHERE " + _w, _p);
      const _ls = await query("SELECT m.id, m.firma, m.tip, m.il, m.ilce, m.durum, m.lat, m.vergi_no, m.created_at, COALESCE(u.full_name,u.email) AS rep FROM saha_musteri m LEFT JOIN users u ON u.id=m.sorumlu_rep WHERE " + _w + " ORDER BY m.created_at DESC LIMIT 200", _p);"""

NEW = """      const _p = [session.tenantId];
      let _flt = "";  /* YENI_MUSTERI_GERCEK_V1 */
      if (_tip && ["TUKETICI","TICARI"].includes(_tip)) { _p.push(_tip); _flt += " AND m.tip=$" + _p.length; }
      if (_from) { _p.push(_from); _flt += " AND i.ilk_tarih >= $" + _p.length + "::date"; }
      if (_to) { _p.push(_to); _flt += " AND i.ilk_tarih < ($" + _p.length + "::date + INTERVAL '1 day')"; }
      const _base = `FROM saha_musteri m
        JOIN (SELECT z.musteri_id,
                     MIN(COALESCE(z.ziyaret_tarihi, z.created_at::date)) AS ilk_tarih,
                     (array_agg(z.kaynak ORDER BY COALESCE(z.ziyaret_tarihi, z.created_at::date) ASC, z.created_at ASC))[1] AS ilk_kaynak
                FROM saha_ziyaret z WHERE z.tenant_id=$1 GROUP BY z.musteri_id) i ON i.musteri_id = m.id
        LEFT JOIN users u ON u.id = m.sorumlu_rep
        WHERE m.tenant_id=$1 AND i.ilk_kaynak='APP' AND COALESCE(m.kayit_kaynagi,'') <> 'EXCEL_IMPORT_KONTROL'` + _flt;
      const _oz = await query("SELECT COUNT(*)::int AS toplam, COUNT(*) FILTER (WHERE m.lat IS NOT NULL)::int AS konumlu, COUNT(*) FILTER (WHERE m.vergi_no IS NOT NULL AND m.vergi_no <> '')::int AS vkn_var " + _base, _p);
      const _ls = await query("SELECT m.id, m.firma, m.tip, m.il, m.ilce, m.durum, m.lat, m.vergi_no, i.ilk_tarih AS created_at, COALESCE(u.full_name,u.email) AS rep " + _base + " ORDER BY i.ilk_tarih DESC LIMIT 200", _p);"""

assert s.count(OLD) == 1, "server anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] YENI_MUSTERI_GERCEK_V1 (server)")
