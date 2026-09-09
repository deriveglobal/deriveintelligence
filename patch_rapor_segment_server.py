# -*- coding: utf-8 -*-
# RAPOR_SEGMENT_V1 (server) — rep-performans'a segment verisi:
#   rep_id, tuketici_z, ticari_z (m.tip ile ziyaret kirilimi) ve admin saha_tip.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAPOR_SEGMENT_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = """      const result = await query(`
        SELECT COALESCE(u.full_name, z.rep_adi, 'Bilinmiyor') AS rep,
               COUNT(*) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date) AS ziyaret,
               COUNT(DISTINCT z.musteri_id) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date) AS benzersiz_musteri
        FROM saha_ziyaret z LEFT JOIN users u ON u.id = z.rep_id
        WHERE z.tenant_id = $1
        GROUP BY z.tenant_id, z.rep_id, 1
        HAVING COUNT(*) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date) > 0
        ORDER BY 2 DESC
      `, [session.tenantId, from, to]);"""

NEW = """      const result = await query(`/* RAPOR_SEGMENT_V1 */
        SELECT z.rep_id,
               COALESCE(u.full_name, z.rep_adi, 'Bilinmiyor') AS rep,
               COUNT(*) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date) AS ziyaret,
               COUNT(DISTINCT z.musteri_id) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date) AS benzersiz_musteri,
               COUNT(*) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date AND m.tip = 'TUKETICI') AS tuketici_z,
               COUNT(*) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date AND m.tip = 'TICARI') AS ticari_z,
               (SELECT tum.permissions_json->>'saha_tip' FROM tenant_user_modules tum
                  WHERE tum.user_id = z.rep_id AND tum.tenant_id = z.tenant_id AND tum.module_id = 'saha' LIMIT 1) AS saha_tip
        FROM saha_ziyaret z
        LEFT JOIN users u ON u.id = z.rep_id
        LEFT JOIN saha_musteri m ON m.id = z.musteri_id
        WHERE z.tenant_id = $1
        GROUP BY z.tenant_id, z.rep_id, COALESCE(u.full_name, z.rep_adi, 'Bilinmiyor')
        HAVING COUNT(*) FILTER (WHERE z.durum = 'TAMAMLANDI'
                 AND z.ziyaret_tarihi >= $2::date AND z.ziyaret_tarihi <= $3::date) > 0
        ORDER BY ziyaret DESC
      `, [session.tenantId, from, to]);"""

assert s.count(OLD) == 1, "server anchor=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_SEGMENT_V1 (server)")
