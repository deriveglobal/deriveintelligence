#!/usr/bin/env bash
# PROFIL_HAFIZASI_1 — sema + gecmisi geri kazan. (UI ayri adimda.)
#
# ⚠ TESHIS: eksik olan bir ARAYUZ degil, VERI MODELI.
#   saha_musteri'de sadece sektorler ve tedarikci_markalar var.
#   Ziyaret formu ayrica sunlari topluyor ama HICBIRININ KARSILIGI YOK:
#     TICARI  : arac_parki · kullanilan_markalar · yillik_potansiyel
#     TUKETICI: raf markalar · bayilikler · rakip toptancilar · kis/yaz stok
#   Hepsi ziyaretin detay (jsonb) alanina gomuluyor.
#   Yani form bir MUSTERI PROFILI topluyor, sistem onu ZIYARET FOTOGRAFI olarak sakliyor.
#   Ertesi ziyarette musteri BOMBOS aciliyor — cunku profil HIC OLUSMADI.
#
# ⚠ OLCUM: 1.033 musterinin 10'unda sektor, 146'sinda marka, 11'inde vergi no var.
#
# ✅ IYI HABER: VERI KAYIP DEGIL. 2.420 ziyaretin detay alaninda duruyor.
#   Ornek: "20 cekici, 20 dorse, 30 kamyon, 5 is makinesi · potansiyel 200 ·
#           Lassa, Bridgestone, Petlas, Starmaxx"
#   Sahanin topladigi gercek istihbarat — hicbir yerde KULLANILMIYOR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ ONCE: detay'da ne kadar veri var? ############"
$PSQL -c "
SELECT count(*)                                                                  AS ziyaret,
       count(*) FILTER (WHERE detay ? 'arac_parki')                              AS arac_parki_var,
       count(*) FILTER (WHERE detay->'kullanilan_markalar' <> '[]'::jsonb)       AS marka_var,
       count(*) FILTER (WHERE detay->>'yillik_potansiyel' IS NOT NULL)           AS potansiyel_var,
       count(*) FILTER (WHERE detay->'sektorler' <> '[]'::jsonb)                 AS sektor_var,
       count(DISTINCT musteri_id) FILTER (WHERE detay IS NOT NULL AND detay::text <> '{}') AS musteri_sayisi
  FROM saha_ziyaret;"
echo "  ⚠ 'musteri_sayisi' = kac musterinin profili GERI KAZANILABILIR."

echo
echo "############ 2) SEMA — eksik kolonlar ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- ⚠ TICARI profil
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS arac_parki          jsonb;
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS kullanilan_markalar text[];
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS yillik_potansiyel   integer;
-- ⚠ TUKETICI profil
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS raf_markalar        text[];
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS bayilikler          text[];
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS rakip_toptancilar   text[];
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS kis_stok            integer;
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS yaz_stok            integer;
-- ⚠ Profilin NE ZAMAN guncellendigi. "Bu bilgi 8 ay onceki ziyaretten" demek onemli.
ALTER TABLE saha_musteri ADD COLUMN IF NOT EXISTS profil_guncel_at    timestamptz;
SQL
echo "  ✅ 9 kolon"

echo
echo "############ 3) ⚠ GECMISI GERI KAZAN — her musterinin SON ziyaretinden ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
WITH son AS (
  SELECT DISTINCT ON (musteri_id)
         musteri_id, detay, ziyaret_tarihi, created_at
    FROM saha_ziyaret
   WHERE detay IS NOT NULL AND detay::text <> '{}'
   ORDER BY musteri_id, COALESCE(ziyaret_tarihi, created_at::date) DESC, created_at DESC
)
UPDATE saha_musteri m
   SET arac_parki = COALESCE(m.arac_parki,
         CASE WHEN s.detay ? 'arac_parki' THEN s.detay->'arac_parki' END),
       kullanilan_markalar = COALESCE(m.kullanilan_markalar,
         CASE WHEN jsonb_typeof(s.detay->'kullanilan_markalar')='array'
                   AND s.detay->'kullanilan_markalar' <> '[]'::jsonb
              THEN ARRAY(SELECT jsonb_array_elements_text(s.detay->'kullanilan_markalar')) END),
       yillik_potansiyel = COALESCE(m.yillik_potansiyel,
         NULLIF(s.detay->>'yillik_potansiyel','')::integer),
       sektorler = CASE
         WHEN m.sektorler IS NULL OR array_length(m.sektorler,1) IS NULL THEN
           CASE WHEN jsonb_typeof(s.detay->'sektorler')='array' AND s.detay->'sektorler' <> '[]'::jsonb
                THEN ARRAY(SELECT jsonb_array_elements_text(s.detay->'sektorler')) END
         ELSE m.sektorler END,
       tedarikci_markalar = CASE
         WHEN m.tedarikci_markalar IS NULL OR array_length(m.tedarikci_markalar,1) IS NULL THEN
           CASE WHEN jsonb_typeof(s.detay->'tedarikci_markalar')='array' AND s.detay->'tedarikci_markalar' <> '[]'::jsonb
                THEN ARRAY(SELECT jsonb_array_elements_text(s.detay->'tedarikci_markalar')) END
         ELSE m.tedarikci_markalar END,
       -- TUKETICI alanlari (form: zf-raf, zf-bayilik, zf-rakip, zf-kis, zf-yaz)
       raf_markalar = COALESCE(m.raf_markalar,
         CASE WHEN jsonb_typeof(s.detay->'raf_markalar')='array' AND s.detay->'raf_markalar' <> '[]'::jsonb
              THEN ARRAY(SELECT jsonb_array_elements_text(s.detay->'raf_markalar')) END),
       bayilikler = COALESCE(m.bayilikler,
         CASE WHEN jsonb_typeof(s.detay->'bayilikler')='array' AND s.detay->'bayilikler' <> '[]'::jsonb
              THEN ARRAY(SELECT jsonb_array_elements_text(s.detay->'bayilikler')) END),
       rakip_toptancilar = COALESCE(m.rakip_toptancilar,
         CASE WHEN jsonb_typeof(s.detay->'rakip_toptancilar')='array' AND s.detay->'rakip_toptancilar' <> '[]'::jsonb
              THEN ARRAY(SELECT jsonb_array_elements_text(s.detay->'rakip_toptancilar')) END),
       kis_stok = COALESCE(m.kis_stok, NULLIF(s.detay->>'kis_stok','')::integer),
       yaz_stok = COALESCE(m.yaz_stok, NULLIF(s.detay->>'yaz_stok','')::integer),
       profil_guncel_at = COALESCE(s.ziyaret_tarihi::timestamptz, s.created_at),
       updated_at = now()
  FROM son s
 WHERE m.id = s.musteri_id;
SQL

echo
echo "############ 4) ⚠ SONUC — profil ne kadar doldu? ############"
$PSQL -c "
SELECT count(*)                                                                       AS musteri,
       count(*) FILTER (WHERE sektorler IS NOT NULL AND array_length(sektorler,1)>0)  AS sektor,
       count(*) FILTER (WHERE kullanilan_markalar IS NOT NULL)                        AS kullanilan_marka,
       count(*) FILTER (WHERE tedarikci_markalar IS NOT NULL AND array_length(tedarikci_markalar,1)>0) AS tedarikci_marka,
       count(arac_parki)                                                              AS arac_parki,
       count(yillik_potansiyel)                                                       AS potansiyel,
       count(profil_guncel_at)                                                        AS profil_tarihli
  FROM saha_musteri WHERE aktif;"
echo "  ⚠ ONCEDEN: sektor 10 · marka 146 · arac_parki 0 · potansiyel 0"

echo
echo "############ 5) ORNEK — geri kazanilan profil ############"
$PSQL -x -c "
SELECT firma, sektorler, kullanilan_markalar, tedarikci_markalar,
       arac_parki, yillik_potansiyel, profil_guncel_at::date AS profil_tarihi
  FROM saha_musteri
 WHERE arac_parki IS NOT NULL AND yillik_potansiyel IS NOT NULL
 ORDER BY yillik_potansiyel DESC NULLS LAST LIMIT 3;"

echo
echo "############ 6) ⚠ EN DEGERLI — sahanin topladigi ama KULLANILMAYAN istihbarat ############"
$PSQL -c "
SELECT count(*) AS musteri,
       sum(yillik_potansiyel) AS toplam_yillik_potansiyel_adet,
       sum((arac_parki->>'cekici')::int + (arac_parki->>'dorse')::int
         + (arac_parki->>'kamyon')::int + (arac_parki->>'is_makinesi')::int) AS toplam_arac
  FROM saha_musteri
 WHERE arac_parki IS NOT NULL;"
echo "  ⚠ Bu, sahanin AYLARDIR topladigi ve hicbir ekranda GORUNMEYEN veri."
