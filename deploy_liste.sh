#!/usr/bin/env bash
# LISTE_V1 — Brisa YAZ + 4 MEVSIM + KIS liste fiyatlari.
#   ./deploy_liste.sh        # KURU
#   ./deploy_liste.sh --yaz  # YUKLE
#
# ⚠ KAYNAK: Brisa'nin "Tavsiye Edilen Perakende Satis Fiyat Listesi (KDV DAHIL TL)"
#   -> kdv_haric = FALSE olarak basiliyor. Kod (KDV_V1) bayragi okuyup /1,20 uyguluyor.
#   -> Mevcut Brisa satirlari (2026-06-05) da ayni konvansiyonda. TUTARLI.
#
# ⚠ NEDEN ONEMLI: bugune kadar bayilik markalarinda SADECE KIS listesi vardi.
#   YAZ ve 4 MEVSIM'de liste YOKTU -> ikame maliyeti hesaplanamiyordu
#   -> BAYILIK_V2 son alis faturasina dusuyordu (brut, prim haric).
#   Bu yukleme cironun buyuk bir kismini NET maliyet temeline tasiyor.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
TARIH="2026-07-13"

[ -f brisa_liste_YUKLE.csv ] || { echo "❌ brisa_liste_YUKLE.csv YOK"; exit 1; }
N=$(($(wc -l < brisa_liste_YUKLE.csv)-1))
echo "✅ CSV: $N satir"

echo
echo "############ 1) MEVCUT DURUM — bayilik markalarinda hangi sezon var? ############"
$PSQL -c "
SELECT u.marka, u.kategori, u.kdv_haric, u.liste_tarihi, count(k.id) AS kalem
  FROM bi_fiyat_listesi_uploads u
  LEFT JOIN bi_fiyat_listesi_kalemler k ON k.upload_id=u.id
 WHERE u.tenant_id='$TEN'::uuid AND u.aktif
 GROUP BY 1,2,3,4 ORDER BY 1,2;"
echo "  ^ BRISA (BRIDGESTONE/LASSA/DAYTON): sadece KIS var. YAZ ve 4 MEVSIM YOK."

echo
echo "############ 2) ⚠ BOSLUGUN BEDELI — kac satis NET maliyet gormuyor? ############"
$PSQL -c "
WITH liste AS (
  SELECT DISTINCT upper(u.marka) AS marka, u.kategori
    FROM bi_fiyat_listesi_uploads u WHERE u.tenant_id='$TEN'::uuid AND u.aktif)
SELECT CASE WHEN f.kategori ILIKE '%4 MEVSIM%' THEN '4 MEVSIM'
            WHEN f.kategori ILIKE '%KIS%' THEN 'KIS'
            WHEN f.kategori ILIKE '%YAZ%' THEN 'YAZ' ELSE 'DIGER' END AS kategori,
       count(*) AS satir,
       round(sum(f.satir_tutar)/1e6,1) AS ciro_MTL,
       CASE WHEN bool_or(l.marka IS NOT NULL) THEN '✅ liste VAR' ELSE '❌ liste YOK' END AS durum
  FROM bi_satis_faturalari f
  LEFT JOIN liste l ON l.marka=upper(f.marka)
                   AND l.kategori = CASE WHEN f.kategori ILIKE '%4 MEVSIM%' THEN '4 MEVSIM'
                                         WHEN f.kategori ILIKE '%KIS%' THEN 'KIS'
                                         WHEN f.kategori ILIKE '%YAZ%' THEN 'YAZ' END
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0
   AND upper(f.marka) IN ('LASSA','BRIDGESTONE','DAYTON')
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 GROUP BY 1,4 ORDER BY 3 DESC;"
echo "  ^ '❌ liste YOK' olan ciro, ikame maliyetini NET degil BRUT goruyordu."

if [ "${1:-}" != "--yaz" ]; then
  echo
  echo "  KURU CALISMA. Yaz: ./deploy_liste.sh --yaz"
  exit 0
fi

echo
echo "############ 3) YUKLE ############"
tr -d '\r' < brisa_liste_YUKLE.csv > /tmp/_l.csv
docker cp /tmp/_l.csv krb-assessment-postgres:/tmp/_l.csv >/dev/null
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
CREATE TEMP TABLE _l (marka text, kategori text, ebat text, urun_kodu text,
                      desen text, liste_fiyati numeric, perakende_fiyati numeric) ON COMMIT DROP;
\copy _l FROM '/tmp/_l.csv' WITH (FORMAT csv, HEADER true)

-- ⚠ Eski BRISA listelerini PASIFE al (silme — gecmis kalsin)
UPDATE bi_fiyat_listesi_uploads SET aktif = false
 WHERE tenant_id='$TEN'::uuid AND aktif
   AND upper(marka) IN ('LASSA','BRIDGESTONE','DAYTON');

-- Yeni upload kayitlari (marka x kategori)
INSERT INTO bi_fiyat_listesi_uploads
  (tenant_id, marka, kategori, liste_tarihi, dosya_adi, kayit_sayisi, aktif, kdv_haric, segment)
SELECT '$TEN'::uuid, marka, kategori, DATE '$TARIH',
       'Brisa Tavsiye Edilen Perakende Fiyat Listesi (KDV DAHIL)',
       count(*), true,
       false,          -- ⚠ KDV DAHIL. Kod /1,20 uyguluyor.
       'PASSENGER'
  FROM _l GROUP BY marka, kategori;

-- Kalemler
INSERT INTO bi_fiyat_listesi_kalemler
  (upload_id, tenant_id, ebat, urun_kodu, desen, liste_fiyati, perakende_fiyati, para_birimi, segment)
SELECT u.id, '$TEN'::uuid, l.ebat, l.urun_kodu, l.desen,
       l.liste_fiyati, l.perakende_fiyati, 'TL', 'PASSENGER'
  FROM _l l
  JOIN bi_fiyat_listesi_uploads u
    ON u.tenant_id='$TEN'::uuid AND u.aktif AND u.liste_tarihi = DATE '$TARIH'
   AND u.marka = l.marka AND u.kategori = l.kategori;

DO \$\$
DECLARE n int; y int; d int;
BEGIN
  SELECT count(*) INTO n FROM bi_fiyat_listesi_kalemler k
    JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id
   WHERE u.tenant_id='$TEN'::uuid AND u.liste_tarihi=DATE '$TARIH';
  IF n <> $N THEN RAISE EXCEPTION 'RED: % kalem yazildi, % bekleniyordu', n, $N; END IF;

  SELECT count(*) INTO y FROM bi_fiyat_listesi_uploads
   WHERE tenant_id='$TEN'::uuid AND aktif AND kategori='YAZ'
     AND upper(marka) IN ('LASSA','BRIDGESTONE','DAYTON');
  IF y = 0 THEN RAISE EXCEPTION 'RED: YAZ listesi olusmadi'; END IF;

  SELECT count(*) INTO d FROM bi_fiyat_listesi_uploads
   WHERE tenant_id='$TEN'::uuid AND aktif AND kdv_haric = true
     AND upper(marka) IN ('LASSA','BRIDGESTONE','DAYTON');
  IF d > 0 THEN RAISE EXCEPTION 'RED: BRISA satirinda kdv_haric=true — YANLIS BAYRAK'; END IF;

  RAISE NOTICE '✅ % kalem · YAZ listesi VAR · kdv_haric bayragi DOGRU', n;
END \$\$;
COMMIT;
SQL
docker exec krb-assessment-postgres rm -f /tmp/_l.csv 2>/dev/null

echo
echo "############ 4) SONRASI ############"
$PSQL -c "
SELECT u.marka, u.kategori, u.kdv_haric, count(k.id) AS kalem,
       round(min(k.liste_fiyati)) AS min_TL, round(max(k.liste_fiyati)) AS max_TL
  FROM bi_fiyat_listesi_uploads u
  JOIN bi_fiyat_listesi_kalemler k ON k.upload_id=u.id
 WHERE u.tenant_id='$TEN'::uuid AND u.aktif
 GROUP BY 1,2,3 ORDER BY 1,2;"

echo
echo "############ 5) ⚠⚠ ETKI — kac satis artik NET maliyet goruyor? ############"
$PSQL -c "
WITH liste AS (
  SELECT DISTINCT upper(u.marka) AS marka, u.kategori
    FROM bi_fiyat_listesi_uploads u WHERE u.tenant_id='$TEN'::uuid AND u.aktif),
tesvik AS (
  SELECT DISTINCT upper(marka) AS marka, sezon
    FROM bi_fiyat_iskonto WHERE tenant_id='$TEN'::uuid AND aktif)
SELECT CASE WHEN f.kategori ILIKE '%4 MEVSIM%' THEN '4 MEVSIM'
            WHEN f.kategori ILIKE '%KIS%' THEN 'KIS'
            WHEN f.kategori ILIKE '%YAZ%' THEN 'YAZ' ELSE 'DIGER' END AS kategori,
       round(sum(f.satir_tutar)/1e6,1) AS ciro_MTL,
       CASE WHEN bool_or(l.marka IS NOT NULL) AND bool_or(t.marka IS NOT NULL)
            THEN '✅ liste + tesvik -> NET maliyet'
            WHEN bool_or(l.marka IS NOT NULL)
            THEN '🟡 liste VAR, tesvik YOK -> hala son alis (BRUT)'
            ELSE '❌ liste YOK' END AS durum
  FROM bi_satis_faturalari f
  LEFT JOIN liste l ON l.marka=upper(f.marka)
                   AND l.kategori = CASE WHEN f.kategori ILIKE '%4 MEVSIM%' THEN '4 MEVSIM'
                                         WHEN f.kategori ILIKE '%KIS%' THEN 'KIS'
                                         WHEN f.kategori ILIKE '%YAZ%' THEN 'YAZ' END
  LEFT JOIN tesvik t ON t.marka=upper(f.marka)
                    AND t.sezon = CASE WHEN f.kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
                                       WHEN f.kategori ILIKE '%KIS%' THEN 'KIS'
                                       WHEN f.kategori ILIKE '%YAZ%' THEN 'YAZ' END
 WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0
   AND upper(f.marka) IN ('LASSA','BRIDGESTONE','DAYTON')
   AND f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
 GROUP BY 1,3 ORDER BY 2 DESC;"
echo
echo "  ⚠ '🟡 liste VAR, tesvik YOK' -> LISTE artik var ama TESVIK tablosunda"
echo "     YAZ/4MEVSIM satiri hala YOK. O yuzden ikame maliyeti henuz NET degil."
echo "     KRB'nin yapmasi gereken: bi_fiyat_iskonto'ya YAZ + 4 MEVSIM iskontolarini girmek."
echo "     Kod (SEZON_V1) girildigi AN kendiliginden devreye girer."

git add -A && git commit -q -m "feat(fiyat): LISTE_V1 — Brisa YAZ (671) + 4 MEVSIM (154) + KIS (449) liste fiyatlari yuklendi. Kaynak: Brisa Tavsiye Edilen Perakende Fiyat Listesi (KDV DAHIL) -> kdv_haric=false bayragiyla; KDV_V1 kodu /1,20 uyguluyor. Bugune kadar bayilik markalarinda SADECE KIS listesi vardi." && echo "  COMMITTED"
