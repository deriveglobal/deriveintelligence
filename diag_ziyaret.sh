#!/usr/bin/env bash
# Ziyaret siralama teshisi — mobilin aldigi sirayi ve ham tarih degerlerini goster.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_ziyaret.sh'
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'

echo "=== (1) TAMAMLANDI ziyaret: tip + null sayilari ==="
$PSQL -c "SELECT pg_typeof(ziyaret_tarihi) AS typ, count(*) AS toplam, count(*) FILTER (WHERE ziyaret_tarihi IS NULL) AS zt_null, count(*) FILTER (WHERE planlanan_tarih IS NULL) AS pt_null FROM saha_ziyaret WHERE durum='TAMAMLANDI'"

echo ""
echo "=== (2) SERVER sirasindaki ilk 12 (mobilin gordugu sira) ==="
$PSQL -c "SELECT left(m.firma,22) AS firma, z.ziyaret_tarihi::text AS zt, z.planlanan_tarih::text AS pt, z.created_at::text AS created FROM saha_ziyaret z JOIN saha_musteri m ON m.id=z.musteri_id WHERE z.durum='TAMAMLANDI' ORDER BY COALESCE(z.ziyaret_tarihi,z.planlanan_tarih) DESC NULLS LAST, z.created_at DESC LIMIT 12"

echo ""
echo "=== (3) ham JSON gibi: bir kaydin ziyaret_tarihi TAM degeri (format) ==="
$PSQL -t -c "SELECT json_build_object('ziyaret_tarihi', ziyaret_tarihi, 'planlanan_tarih', planlanan_tarih, 'created_at', created_at) FROM saha_ziyaret WHERE durum='TAMAMLANDI' AND ziyaret_tarihi IS NOT NULL ORDER BY created_at DESC LIMIT 1"
