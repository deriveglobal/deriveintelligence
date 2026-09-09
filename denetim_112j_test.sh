#!/usr/bin/env bash
# DENETIM_112J — trigger TEMIZ testi (url dahil, uc durum). ROLLBACK.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ TRIGGER TESTI — uc ebat, segment otomatik yazilmali ############"
$PSQL <<'SQL'
BEGIN;
INSERT INTO bi_rakip_fiyat (kaynak, marka, ebat, model, cap, fiyat, url) VALUES
  ('__TEST__','Michelin',   '205/55R16 91V',      'Michelin Primacy 205/55R16',      16,   1, 'http://t/1'),
  ('__TEST__','Petlas',     '225/65R16C 112/110R','Petlas FullGrip 225/65R16C',      16,   1, 'http://t/2'),
  ('__TEST__','Bridgestone','315/80R22.5',        'Bridgestone kamyon 315/80R22.5',  22.5, 1, 'http://t/3'),
  ('__TEST__','Lassa',      '195R14 C',           'Lassa 195R14 C Wintus',           14,   1, 'http://t/4');
SELECT ebat, segment,
       CASE ebat
         WHEN '205/55R16 91V'       THEN (segment='BINEK')
         WHEN '225/65R16C 112/110R' THEN (segment='HAFIF_TICARI')
         WHEN '315/80R22.5'         THEN (segment='KAMYON_OTOBUS')
         WHEN '195R14 C'            THEN (segment='HAFIF_TICARI')
       END AS dogru_mu
  FROM bi_rakip_fiyat WHERE kaynak='__TEST__' ORDER BY ebat;
ROLLBACK;
SQL
echo
echo "  ⚠ Beklenen: BINEK · HAFIF_TICARI · KAMYON_OTOBUS · HAFIF_TICARI (bosluklu C dahil)"
echo "  ⚠ dogru_mu sutunu hepsi 't' olmali. Satirlar ROLLBACK ile silindi."
