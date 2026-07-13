#!/usr/bin/env bash
# Salt okuma. Onay ekranini cizen fonksiyonun TAM metni.
S=/opt/krb-assessment/shells/saha.js

echo "═════════ _teklifAnalizHTML (2384'ten itibaren) ═════════"
sed -n '2384,2450p' $S

echo
echo "═════════ cagrildigi yer (2305-2320) ═════════"
sed -n '2305,2320p' $S

echo
echo "═════════ API canli test — yeni alanlar geliyor mu? ═════════"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TID=$($PSQL -tAc "SELECT id FROM saha_teklif ORDER BY created_at DESC LIMIT 1")
echo "  son teklif: $TID"
echo "  (endpoint oturum ister; burada sadece SQL'in dondugu veriyi gosteriyorum)"
$PSQL -x -c "
SELECT t.marka, t.ebat, t.kalem_kodu, t.talep_fiyat, t.vade_gun,
       oz.oz_min, oz.oz_med, oz.oz_max, oz.oz_ucuz, oz.oz_pahali,
       al.ag_alis, al.ag_alis_vade, sv.ag_satis_vade
  FROM saha_teklif t
  LEFT JOIN LATERAL (
    SELECT ROUND(MIN(birim_fiyat)) oz_min,
           ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) oz_med,
           ROUND(MAX(birim_fiyat)) oz_max,
           (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1]  oz_ucuz,
           (array_agg(musteri_adi ORDER BY birim_fiyat DESC))[1] oz_pahali
      FROM bi_satis_faturalari sf
     WHERE sf.tenant_id=t.tenant_id::text AND sf.ebat=t.ebat
       AND upper(sf.marka)=upper(t.marka) AND sf.birim_fiyat>0
       AND sf.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) oz ON true
  LEFT JOIN LATERAL (
    SELECT ROUND(SUM(miktar*birim_fiyat_kdv_haric)/NULLIF(SUM(miktar),0)) ag_alis,
           ROUND(SUM(miktar*vade_gun)/NULLIF(SUM(miktar),0)) ag_alis_vade
      FROM bi_tedarikci_faturalari tf
     WHERE tf.tenant_id=t.tenant_id AND tf.kalem_kodu=t.kalem_kodu
       AND tf.vade_gun IS NOT NULL
       AND tf.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) al ON true
  LEFT JOIN LATERAL (
    SELECT ROUND(SUM(miktar*(vade_tarihi-fatura_tarihi))/NULLIF(SUM(miktar),0)) ag_satis_vade
      FROM bi_satis_faturalari sv
     WHERE sv.tenant_id=t.tenant_id::text AND sv.kalem_kodu=t.kalem_kodu
       AND sv.vade_tarihi IS NOT NULL
       AND sv.fatura_tarihi >= date_trunc('year', CURRENT_DATE)) sv ON true
 WHERE t.id='$TID';"
echo "  ^ onay ekraninda gorunecek veri BU."
