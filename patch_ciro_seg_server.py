# -*- coding: utf-8 -*-
# CIRO_SEG_SRV_V1 (server) — ziyaret-ciro YÖNETİCİ payload'una rep saha alanı ekle:
#   saha_tip (Yönetim>İzinler matrisinin yazdığı permissions_json->>'saha_tip' — kanonik etiket),
#   tuketici_z / ticari_z (m.tip ile ziyaret kırılımı; etiket yoksa çoğunluktan türetme için).
#   Kırılım (Ticari/Tüketici saha) ve rep ₺/ziyaret'in saha ortalamasıyla karşılaştırması bununla beslenir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "CIRO_SEG_SRV_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "ZIYARET_CIRO_V1" in s, "HATA: once ZIYARET_CIRO_V1 (ciro endpoint) olmali"

# 1) enr CTE — m.tip kolonu ekle (ziyaret kırılımı için)
a1 = "          SELECT v.rep_id, v.ziyaret, m.musteri_kodu,"
n1 = "          SELECT v.rep_id, v.ziyaret, m.musteri_kodu, m.tip,  /* CIRO_SEG_SRV_V1 */"
assert s.count(a1) == 1, "anchor#1=%d" % s.count(a1)
s = s.replace(a1, n1, 1)

# 2) final SELECT — tuketici_z/ticari_z/saha_tip kolonları
a2 = ("               SUM(e.ciro)::numeric ciro, MAX(pt.portfoy)::int portfoy\n"
      "          FROM enr e LEFT JOIN users u ON u.id=e.rep_id LEFT JOIN port pt ON pt.rep_id=e.rep_id")
n2 = ("               SUM(e.ciro)::numeric ciro, MAX(pt.portfoy)::int portfoy,\n"
      "               SUM(e.ziyaret) FILTER (WHERE e.tip='TUKETICI')::int tuketici_z,  /* CIRO_SEG_SRV_V1 */\n"
      "               SUM(e.ziyaret) FILTER (WHERE e.tip='TICARI')::int ticari_z,\n"
      "               (SELECT tum.permissions_json->>'saha_tip' FROM tenant_user_modules tum\n"
      "                  WHERE tum.user_id=e.rep_id AND tum.tenant_id=$1 AND tum.module_id='saha' LIMIT 1) AS saha_tip\n"
      "          FROM enr e LEFT JOIN users u ON u.id=e.rep_id LEFT JOIN port pt ON pt.rep_id=e.rep_id")
assert s.count(a2) == 1, "anchor#2=%d" % s.count(a2)
s = s.replace(a2, n2, 1)

# 3) JS map — yeni alanları döndür
a3 = ("        return { rep: x.rep, rep_id: x.rep_id, ziyaret, benzersiz, eslesen, ciro,\n"
      "                 kapsam: portfoy ? Math.round(1000 * benzersiz / portfoy) / 10 : null,")
n3 = ("        return { rep: x.rep, rep_id: x.rep_id, ziyaret, benzersiz, eslesen, ciro,\n"
      "                 saha_tip: x.saha_tip, tuketici_z: Number(x.tuketici_z) || 0, ticari_z: Number(x.ticari_z) || 0,  /* CIRO_SEG_SRV_V1 */\n"
      "                 kapsam: portfoy ? Math.round(1000 * benzersiz / portfoy) / 10 : null,")
assert s.count(a3) == 1, "anchor#3=%d" % s.count(a3)
s = s.replace(a3, n3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_SEG_SRV_V1 (server) — saha_tip + ziyaret kırılımı eklendi")
