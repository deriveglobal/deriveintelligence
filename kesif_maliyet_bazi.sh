#!/usr/bin/env bash
# MALİYET BAZI ÇARPIKLIĞI — enflasyonda tüm-geçmiş-ort vs yenileme vs dönem maliyeti. Marj ne kadar sapıyor. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. MALİYET YAŞI — tüm-geçmiş ort maliyetin ağırlıklı ortalama alış TARİHİ ne kadar eski"
$PSQL -c "
SELECT round(avg(EXTRACT(day FROM (CURRENT_DATE - belge_tarihi))/30.0)) ort_alis_ay_once,
       min(belge_tarihi)::text en_eski, max(belge_tarihi)::text en_yeni
  FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0;" 2>&1 | sed 's/^/  /'

hr "2. CONTINENTAL — üç maliyet bazı yan yana (SKU başına), son 6 ay satılan"
$PSQL -c "
WITH m0 AS (SELECT date_trunc('month',CURRENT_DATE)::date d),
tumgecmis AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu),
son6 AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 AND belge_tarihi>=(SELECT d FROM m0)-interval '6 month' GROUP BY kalem_kodu),
sonalis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, (giris_tutari/NULLIF(giris,0)) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 ORDER BY kalem_kodu, belge_tarihi DESC),
sat AS (SELECT kalem_kodu, left(max(kalem_tanimi),18) tanim, sum(satir_tutar)/NULLIF(sum(miktar),0) satis_fiyat, sum(satir_tutar) ciro
        FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0
          AND fatura_tarihi>=(SELECT d FROM m0)-interval '6 month' AND fatura_tarihi<(SELECT d FROM m0) GROUP BY kalem_kodu)
SELECT sat.tanim, round(sat.satis_fiyat) satis, round(tg.c) tum_gecmis, round(s6.c) son6ay, round(sa.c) son_alis,
       round(100*(1-tg.c/NULLIF(sat.satis_fiyat,0))) marj_tumg, round(100*(1-sa.c/NULLIF(sat.satis_fiyat,0))) marj_yenileme
  FROM sat LEFT JOIN tumgecmis tg USING(kalem_kodu) LEFT JOIN son6 s6 USING(kalem_kodu) LEFT JOIN sonalis sa USING(kalem_kodu)
 WHERE sat.ciro>800000 ORDER BY sat.ciro DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "3. CONTINENTAL TOPLAM MARJ — üç bazla (son 6 ay) — çarpıklık ne kadar"
$PSQL -c "
WITH m0 AS (SELECT date_trunc('month',CURRENT_DATE)::date d),
tumgecmis AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu),
sonalis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, (giris_tutari/NULLIF(giris,0)) c FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 ORDER BY kalem_kodu, belge_tarihi DESC),
sat AS (SELECT kalem_kodu, sum(satir_tutar) ciro, sum(miktar) adet FROM bi_satis_faturalari WHERE tenant_id='$T' AND upper(marka)='CONTINENTAL' AND ebat IS NOT NULL AND miktar>0 AND fatura_tarihi>=(SELECT d FROM m0)-interval '6 month' AND fatura_tarihi<(SELECT d FROM m0) GROUP BY kalem_kodu)
SELECT round(sum(ciro)/1e6,1) ciro_m,
       round(100*(sum(ciro)-sum(adet*tg.c))/NULLIF(sum(ciro),0),1) marj_tum_gecmis_pct,
       round(100*(sum(ciro)-sum(adet*sa.c))/NULLIF(sum(ciro),0),1) marj_yenileme_pct
  FROM sat LEFT JOIN tumgecmis tg USING(kalem_kodu) LEFT JOIN sonalis sa USING(kalem_kodu);" 2>&1 | sed 's/^/  /'

hr "4. TEŞVİK verisi var mı — bi_fiyat_iskonto ne tutuyor (satış primi/iskonto tavanı)"
$PSQL -c "SELECT string_agg(column_name,', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_fiyat_iskonto';" 2>&1 | fold -s -w 140 | sed 's/^/  /'
$PSQL -c "SELECT count(*) FROM bi_fiyat_iskonto WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "BITTI — çarpıklık büyüklüğü + teşvik veri durumu net. Sonra doğru marj bazı kararı."
