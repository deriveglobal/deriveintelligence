#!/usr/bin/env bash
# IL_ILCE_2_TESHIS — ⚠ KENDI SORGUM BOZUKTU. Once ONU duzeltiyorum.
#
# ⚠ POSTGRES upper('Kocaeli') = 'KOCAELI'  (NOKTASIZ I)
#   Resmi ad                  = 'KOCAELİ'  (NOKTALI  İ)
#   Ikisi ESLESMIYOR. "Kocaeli" yazan 16 musteri "gecersiz il" listelendi —
#   OYSA DOGRU YAZILMIS. Ayni tuzak: İzmir · Niğde · DIYARBAKIR · Yenimahalle · Etimesgut.
#   ⚠ Olcum aracim, olctugu seyi BOZUYORDU. 174 "gecersiz" ABARTILI.
#
# ✅ COZUM: Turkce-duyarli normalize. Tum i/I/ı/İ -> 'i', s/S/ş/Ş -> 's', vb.
#   Boylece "KOCAELİ" = "Kocaeli" = "KOCAELI" = "kocaeli".
# Sadece OKUR (fonksiyon disinda yazma yok).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) TURKCE NORMALIZE FONKSIYONU ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- ⚠ Turkce i/I sorunu: upper('i')='I' ama Turkcede 'İ' olmali.
--   Karsilastirma icin HER SEYI ayni havuza indiriyoruz.
CREATE OR REPLACE FUNCTION tr_norm(t text) RETURNS text AS $$
  SELECT translate(
           lower(trim(coalesce(t,''))),
           'İIıîÎşŞğĞüÜöÖçÇâÂ',
           'iiiiissggu' || 'uoocca' || 'a')
$$ LANGUAGE sql IMMUTABLE;
SQL
$PSQL -c "SELECT tr_norm('KOCAELİ') AS a, tr_norm('Kocaeli') AS b, tr_norm('KOCAELI') AS c,
                 tr_norm('KOCAELİ')=tr_norm('Kocaeli') AS esit;"
echo "  ⚠ 'esit' true olmali."

echo
echo "############ 2) ⚠ DUZELTILMIS OLCUM — il gercekten kac tane gecersiz? ############"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il)))         AS il_GECERLI,
       count(*) FILTER (WHERE m.il IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))) AS il_gecersiz,
       count(*) FILTER (WHERE m.il IS NULL OR trim(m.il)='') AS il_bos
  FROM saha_musteri m WHERE m.aktif;"
echo "  ⚠ ONCEKI (bozuk) olcum: 850 gecerli / 174 gecersiz. GERCEK bu."

echo
echo "############ 3) KATEGORI A — il alanina ILCE yazilmis (OTOMATIK DUZELTILEBILIR) ############"
$PSQL -c "
SELECT m.il AS yazilan, count(*) AS musteri,
       (SELECT string_agg(DISTINCT r.il, ', ') FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il)) AS dogru_il,
       (SELECT count(DISTINCT r.il) FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il)) AS kac_ilde_var
  FROM saha_musteri m
 WHERE m.aktif AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
   AND EXISTS     (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il))
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ 'kac_ilde_var' = 1 ise TEK ADAY -> guvenle duzeltilir."
echo "     > 1 ise BELIRSIZ -> dokunmam."

echo
echo "############ 4) KATEGORI B — BIRLESIK yazim ('Il-Ilce') ############"
$PSQL -c "
SELECT m.il AS yazilan, count(*) AS musteri,
       split_part(m.il, '-', 1) AS parca1,
       split_part(m.il, '-', 2) AS parca2,
       (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(split_part(m.il,'-',1)) LIMIT 1) AS p1_il_mi,
       (SELECT r.il FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(split_part(m.il,'-',2)) LIMIT 1) AS p2_il_mi
  FROM saha_musteri m
 WHERE m.aktif AND m.il LIKE '%-%'
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Hangi parca IL, hangisi ILCE — sorgu soyluyor."

echo
echo "############ 5) KATEGORI C — IL DEGIL (firma adi, kanal, ulke) ############"
$PSQL -c "
SELECT m.il AS yazilan, count(*) AS musteri
  FROM saha_musteri m
 WHERE m.aktif AND m.il IS NOT NULL AND m.il NOT LIKE '%-%'
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.il)=tr_norm(m.il))
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.il))
 GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ Bunlar il DEGIL. Mahalle · firma adi · kanal · ulke."
echo "     ⚠ UYDURMAM. Ne olduklarini SEN bilirsin ya da Eftal bilir."

echo
echo "############ 6) ILCE alani — o ilde OLMAYANLAR (duzeltilmis olcumle) ############"
$PSQL -c "
SELECT m.il, m.ilce, count(*) AS musteri,
       (SELECT string_agg(DISTINCT r.il, ', ') FROM tr_ilce_ref r WHERE tr_norm(r.ilce)=tr_norm(m.ilce)) AS bu_ilce_su_ilde_var
  FROM saha_musteri m
 WHERE m.aktif AND m.ilce IS NOT NULL AND m.il IS NOT NULL
   AND NOT EXISTS (SELECT 1 FROM tr_ilce_ref r
                    WHERE tr_norm(r.il)=tr_norm(m.il) AND tr_norm(r.ilce)=tr_norm(m.ilce))
 GROUP BY 1,2 ORDER BY 3 DESC LIMIT 25;"
echo "  ⚠ 'bu_ilce_su_ilde_var' doluysa: IL yanlis, ilce dogru."
echo "     Bos ise: MAHALLE adi ya da yazim hatasi."
