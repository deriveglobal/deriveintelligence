# -*- coding: utf-8 -*-
# RAPOR_R2B_PORTFOY (server) — Portfoy raporunu saha_musteri_kanon view'ine tasir (ilk migrasyon; pattern).
#   ciro/son CTE + saha_musteri_saglik join -> tek view (alias m; repF/tipF/scope aynen calisir). Sayi DEGISMEZ (view=ayni hesap).
#   On kosul: saha_musteri_kanon v2 (ritim + recency_ay kolonlariyla) — deploy DDL'i once calistirir.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "RAPOR_R2B_PORTFOY" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '''      const r = await query(`
        WITH ciro AS (SELECT musteri_kodu, SUM(satir_tutar)::numeric yil FROM bi_satis_faturalari
                       WHERE tenant_id::text=$1::text AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '365 days') GROUP BY musteri_kodu),
             son AS (SELECT musteri_id, MAX(ziyaret_tarihi) mx FROM saha_ziyaret
                       WHERE tenant_id::text=$1::text AND durum='TAMAMLANDI' GROUP BY musteri_id)
        SELECT m.id::text id, m.firma, m.il, m.ilce, m.tip, to_jsonb(m)->>'segment' segment,
               m.musteri_kodu, m.sorumlu_rep::text rid,
               COALESCE(c.yil,0)::numeric ciro, s.mx son,
               sg.durum, sg.guven, sg.ritim, sg.recency_ay
          FROM saha_musteri m
          LEFT JOIN ciro c ON c.musteri_kodu=m.musteri_kodu
          LEFT JOIN son s ON s.musteri_id=m.id
          LEFT JOIN saha_musteri_saglik sg ON sg.tenant_id=$1::text AND sg.musteri_kodu=m.musteri_kodu
         WHERE m.tenant_id::text=$1::text AND m.aktif=true${repF}${tipF}`, p);'''
assert s.count(OLD) == 1, "portfoy query anchor=%d" % s.count(OLD)
NEW = '''      /* RAPOR_R2B_PORTFOY — kanon view (saha_musteri_kanon); ciro_12ay/son_ziyaret/saglik/ritim/recency tek tanim. Sayi ayni. */
      const r = await query(`
        SELECT m.musteri_id::text id, m.firma, m.il, m.ilce, m.tip, m.segment,
               m.musteri_kodu, m.sorumlu_rep::text rid,
               m.ciro_12ay ciro, m.son_ziyaret son,
               m.saglik durum, m.saglik_guven guven, m.ritim, m.recency_ay
          FROM saha_musteri_kanon m
         WHERE m.tenant_id::text=$1::text${repF}${tipF}`, p);'''
s = s.replace(OLD, NEW, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_R2B_PORTFOY (server) — portfoy -> saha_musteri_kanon view")
