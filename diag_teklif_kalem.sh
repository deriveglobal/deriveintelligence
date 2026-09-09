#!/usr/bin/env bash
# Test teklifinin (DOGAN YILDIZ) gercek kalem_kodu'lari + son_alis vs agirlikli kiyas.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_teklif_kalem.sh'
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'

echo "=== (A) teklif tablolari ==="
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_name ~ 'teklif' ORDER BY 1"

echo ""
echo "=== (B) saha_teklif_kalem kolonlari (varsa) ==="
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='saha_teklif_kalem' ORDER BY ordinal_position"

echo ""
echo "=== (C) DOGAN YILDIZ teklif kalemleri (kalem_kodu) — dene ==="
$PSQL -c "SELECT tk.kalem_kodu, tk.marka, tk.ebat, tk.birim_fiyat
  FROM saha_teklif_kalem tk
  JOIN saha_teklif te ON te.id=tk.teklif_id
  JOIN saha_musteri m ON m.id=te.musteri_id
  WHERE m.firma ILIKE '%DOGAN YILDIZ%' OR m.firma ILIKE '%DOĞAN YILDIZ%'
  ORDER BY te.created_at DESC, tk.kalem_sira LIMIT 10"

echo ""
echo "=== (D) son_alis (filtresiz) vs agirlikli (YTD+vade_gun) — nerede AYRISIYOR? ==="
$PSQL -c "WITH t AS (SELECT id FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1),
ks(kalem_kodu) AS (VALUES ('656740'),('656779'),('656723'),('656743'),('656748'),('256078'),('256803'),('256805'))
SELECT ks.kalem_kodu,
  (SELECT count(*) FROM bi_tedarikci_faturalari tf,t WHERE tf.tenant_id=t.id AND tf.kalem_kodu=ks.kalem_kodu AND birim_fiyat_kdv_haric>0 AND miktar>0) alis_kayit,
  (SELECT round(birim_fiyat_kdv_haric) FROM bi_tedarikci_faturalari tf,t WHERE tf.tenant_id=t.id AND tf.kalem_kodu=ks.kalem_kodu AND birim_fiyat_kdv_haric>0 AND miktar>0 ORDER BY fatura_tarihi DESC LIMIT 1) son_alis,
  (SELECT count(*) FROM bi_tedarikci_faturalari tf,t WHERE tf.tenant_id=t.id AND tf.kalem_kodu=ks.kalem_kodu AND birim_fiyat_kdv_haric>0 AND miktar>0 AND vade_gun IS NOT NULL AND fatura_tarihi>=date_trunc('year',CURRENT_DATE)) agir_kayit,
  (SELECT round(SUM(miktar*birim_fiyat_kdv_haric)/NULLIF(SUM(miktar),0)) FROM bi_tedarikci_faturalari tf,t WHERE tf.tenant_id=t.id AND tf.kalem_kodu=ks.kalem_kodu AND birim_fiyat_kdv_haric>0 AND miktar>0 AND vade_gun IS NOT NULL AND fatura_tarihi>=date_trunc('year',CURRENT_DATE)) agir_alis
FROM ks"
