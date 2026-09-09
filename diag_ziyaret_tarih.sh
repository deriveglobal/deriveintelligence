#!/usr/bin/env bash
# Ziyaret GELECEK-TARIH teshisi — 2027 gibi imkansiz tarihler nereden, kac tane, hangi desen.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_ziyaret_tarih.sh'
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'

echo "=== (1) TAMAMLANDI ziyaret_tarihi YIL dagilimi ==="
$PSQL -c "SELECT date_part('year',ziyaret_tarihi)::int AS yil, count(*) AS n, min(ziyaret_tarihi)::text AS mn, max(ziyaret_tarihi)::text AS mx FROM saha_ziyaret WHERE durum='TAMAMLANDI' AND ziyaret_tarihi IS NOT NULL GROUP BY 1 ORDER BY 1"

echo ""
echo "=== (2) GELECEK tarihli (bugunden sonra) — kac tane, hangi import gunu ==="
$PSQL -c "SELECT date_trunc('day',created_at)::text AS import_gun, count(*) AS n, min(ziyaret_tarihi)::text AS mn, max(ziyaret_tarihi)::text AS mx FROM saha_ziyaret WHERE ziyaret_tarihi > CURRENT_DATE GROUP BY 1 ORDER BY 1"

echo ""
echo "=== (3) ornek 10 gelecek-tarihli (firma, zt, created, rep) ==="
$PSQL -c "SELECT left(m.firma,20) AS firma, z.ziyaret_tarihi::text AS zt, z.created_at::text AS created, z.rep_adi FROM saha_ziyaret z JOIN saha_musteri m ON m.id=z.musteri_id WHERE z.ziyaret_tarihi > CURRENT_DATE ORDER BY z.ziyaret_tarihi DESC LIMIT 10"
