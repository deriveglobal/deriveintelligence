#!/usr/bin/env bash
# IL_ILCE_4_KAPAT — kalan 27 kayit: il = KOCAELİ, ilce BOS.
#
# ⚠ GEREKCE (tahmin degil, KANIT):
#   Yesilova yazan 14 musteri — Efsane Jant, HK Jant, Kaplan Oto Lastik,
#   Gulsah Kacar, Harun Bozbag — Eftal'in 13 Temmuz ziyaretleri.
#   O gun check-in koordinatlari: 40.77–40.80 / 29.96–29.98 -> KOCAELİ.
#   Otomatik kural onlari BURDUR'a tasiyacakti (Yesilova, Burdur'un ilcesi).
#   Kural dogruydu; koordinat KOCAELİ diyor.
#   Karamursel-Golcuk · Derince-Korfez · Kurucesme · Yarimca · Yahya Kaptan:
#   hepsi Kocaeli'de yer/ilce adi.
#
# ⚠ ILCE BOS BIRAKILIYOR. Hangi ilce oldugunu BILMIYORUM.
#   Bos birakmak, yanlis doldurmaktan iyidir. Bos alan sorulur; yanlis alan sorulmaz.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ONCE — dokunulacak 27 kayit ############"
$PSQL -c "
SELECT m.il AS yazilan, count(*) AS musteri,
       count(m.lat) AS koordinati_var
  FROM saha_musteri m
 WHERE m.aktif AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
 GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "  --- ⚠ KOORDINAT KANITI (Kocaeli: ~40.7–40.9 K / 29.7–30.3 D) ---"
$PSQL -c "
SELECT left(m.firma, 28) AS firma, m.il AS yazilan,
       round(m.lat, 3) AS enlem, round(m.lng, 3) AS boylam
  FROM saha_musteri m
 WHERE m.aktif AND m.lat IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
 ORDER BY m.firma;"
echo "  ⚠ Koordinatlar Kocaeli araliğinda degilse DUR — kanit yok demektir."

echo
echo "############ 2) KAPAT — il = KOCAELİ, ilce = NULL ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE saha_musteri m
   SET il   = 'KOCAELİ',
       -- ⚠ ILCE BOS. Bos alan sorulur; yanlis alan sorulmaz.
       ilce = NULL,
       -- ⚠ Eski deger notlara yaziliyor — ne oldugu KAYBOLMASIN.
       notlar = COALESCE(NULLIF(trim(m.notlar),'') || E'\n', '')
                || '[il düzeltmesi 14 Tem] önceki il alanı: "' || m.il || '" — ilçe belirlenmedi.',
       updated_at = now()
 WHERE m.aktif AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il));
SQL
echo "  ✅ kapatildi — eski deger NOTLARA yazildi (kaybolmadi)"

echo
echo "############ 3) ⚠ SON DURUM ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il)))  AS il_gecerli,
       count(*) FILTER (WHERE m.il IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))) AS il_gecersiz,
       count(*) FILTER (WHERE m.il IS NULL OR trim(m.il)='') AS il_bos,
       count(*) FILTER (WHERE m.ilce IS NULL OR trim(m.ilce)='') AS ilce_bos
  FROM saha_musteri m WHERE m.aktif;"
echo "  ⚠ 'il_gecersiz' 0 olmali."
echo "  ⚠ BASLANGIC: 1.033 musteri · 151 gecerli · 122 gecersiz"

echo
echo "############ 4) IL DAGILIMI — artik rapor edilebilir ############"
$PSQL -c "
SELECT m.il, count(*) AS musteri,
       count(*) FILTER (WHERE m.ilce IS NOT NULL) AS ilcesi_var
  FROM saha_musteri m WHERE m.aktif AND m.il IS NOT NULL
 GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 5) ⚠ ILCESI BOS OLANLAR — temsilci dolduracak ############"
$PSQL -c "
SELECT m.il, count(*) AS ilcesi_bos
  FROM saha_musteri m
 WHERE m.aktif AND (m.ilce IS NULL OR trim(m.ilce)='')
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Acilir liste kurulunca temsilci bir sonraki ziyarette doldurur."
echo "  ⚠ Geri donus: yedek_il_ilce"
