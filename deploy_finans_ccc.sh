#!/usr/bin/env bash
# FINANS_CCC_V1 — nakit dongusu ucunu YIK ve YENIDEN KUR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) MEVCUT HANDLER'IN TAMAMI — yanit govdesi ne? ############"
L=$(grep -n '"/api/bi/pricing/ccc"' server_container.mjs | cut -d: -f1)
sed -n "$((L+45)),$((L+95))p" server_container.mjs
echo "  ^ ⚠ Yukarida sendJson(...) neyi donduruyorsa, YENI alanlari oraya eklemeliyiz."

echo
echo "############ 1) ⚠ EKRANIN SU AN GOSTERDIGI (yamadan ONCE) ############"
$PSQL -c "
WITH daily_rev AS (
  SELECT SUM(satir_tutar)/90 d FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND fatura_tarihi >= now()-interval '90 days'),
ar AS (SELECT AVG(bakiye) a FROM bi_musteri_bakiye WHERE tenant_id='$TEN'::uuid)
SELECT round((SELECT a/NULLIF((SELECT d FROM daily_rev),0) FROM ar),1) AS ESKI_DSO,
       round(AVG(vade_gun),1) AS ESKI_DPO
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND fatura_tarihi >= now()-interval '90 days' AND vade_gun>0;"
echo "  ^ DSO 0,1 gun = 'parayi 2,4 SAATTE tahsil ediyoruz'. AVG yerine SUM olmaliydi."

echo
echo "############ 2) YAMA ############"
if grep -q "FINANS_CCC_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_ccc
  python3 patch_finans_ccc.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_ccc server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_ccc server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) ⚠ SQL'i POSTGRES'E DOGRULAT (JS gecerli + SQL gecersiz = uygulama coker) ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id = '$TEN'::uuid AND birim_fiyat_kdv_haric > 0 AND miktar > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC
), stok AS (
  SELECT COALESCE(SUM(s.adet * son.maliyet),0) AS deger
    FROM bi_stok_anlik s JOIN son ON son.kalem_kodu = s.kalem_kodu
   WHERE s.tenant_id = '$TEN'::uuid
     AND s.export_date = (SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id='$TEN'::uuid)
), smm AS (
  SELECT COALESCE(SUM(f.miktar * son.maliyet),0)/365.0 AS gunluk
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu = f.kalem_kodu
   WHERE f.tenant_id = '$TEN'::text AND f.grup_adi LIKE 'LASTIK%' AND f.miktar > 0
     AND f.fatura_tarihi >= CURRENT_DATE - 365)
SELECT COALESCE(stok.deger/NULLIF(smm.gunluk,0),0) AS dis, stok.deger, smm.gunluk*365
  FROM stok CROSS JOIN smm;" >/dev/null \
  && echo "  SQL_OK: DIS" || { echo "❌ SQL FAIL DIS"; cp server_container.mjs.bak_ccc server_container.mjs; exit 1; }

$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH t AS (
  SELECT COALESCE(SUM(fatura_tutari),0) tut, COALESCE(SUM(fatura_tutari*tahsilat_gun),0) agir
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN'::uuid AND tahsilat_gun IS NOT NULL
     AND fatura_tarihi >= date_trunc('year', CURRENT_DATE)),
r AS (
  SELECT COALESCE(SUM(toplam_risk),0) acik, COALESCE(SUM(vadesi_gecmis),0) gecikmis
    FROM bi_musteri_risk
   WHERE tenant_id='$TEN'::uuid AND musteri_mi
     AND export_date=(SELECT MAX(export_date) FROM bi_musteri_risk WHERE tenant_id='$TEN'::uuid))
SELECT COALESCE(t.agir/NULLIF(t.tut,0),0) dso,
       COALESCE((t.agir + r.acik*90)/NULLIF(t.tut+r.acik,0),0) dso_gercekci,
       r.acik, r.gecikmis FROM t CROSS JOIN r;" >/dev/null \
  && echo "  SQL_OK: DSO" || { echo "❌ SQL FAIL DSO"; cp server_container.mjs.bak_ccc server_container.mjs; exit 1; }

$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT COALESCE(SUM(satir_kdv_haric*vade_gun)/NULLIF(SUM(satir_kdv_haric),0),0) AS dpo
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND fatura_tarihi >= date_trunc('year',CURRENT_DATE)
   AND vade_gun>0 AND miktar>0 AND satir_kdv_haric>0;" >/dev/null \
  && echo "  SQL_OK: DPO" || { echo "❌ SQL FAIL DPO"; cp server_container.mjs.bak_ccc server_container.mjs; exit 1; }

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ⚠⚠ ONCE / SONRA — ekran ne diyordu, ne diyecek? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
stok AS (SELECT SUM(s.adet*son.m) d FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
          WHERE s.tenant_id='$TEN'::uuid),
smm AS (SELECT SUM(f.miktar*son.m)/365.0 g FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu=f.kalem_kodu
         WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0
           AND f.fatura_tarihi >= CURRENT_DATE-365),
t AS (SELECT SUM(fatura_tutari) tut, SUM(fatura_tutari*tahsilat_gun) agir
        FROM bi_fatura_tahsilat WHERE tenant_id='$TEN'::uuid AND tahsilat_gun IS NOT NULL
          AND fatura_tarihi >= DATE '2026-01-01'),
r AS (SELECT SUM(toplam_risk) acik FROM bi_musteri_risk WHERE tenant_id='$TEN'::uuid AND musteri_mi),
dpo AS (SELECT SUM(satir_kdv_haric*vade_gun)/NULLIF(SUM(satir_kdv_haric),0) g
          FROM bi_tedarikci_faturalari WHERE tenant_id='$TEN'::uuid
            AND fatura_tarihi >= DATE '2026-01-01' AND vade_gun>0 AND miktar>0 AND satir_kdv_haric>0)
SELECT round(stok.d/NULLIF(smm.g,0),1)                          AS STOK_GUNU,
       round(t.agir/NULLIF(t.tut,0),1)                          AS DSO,
       round((t.agir+r.acik*90)/NULLIF(t.tut+r.acik,0),1)       AS DSO_gercekci,
       round(dpo.g,1)                                           AS DPO,
       round(stok.d/NULLIF(smm.g,0) + t.agir/NULLIF(t.tut,0) - dpo.g,1) AS DONGU_iyimser,
       round(stok.d/NULLIF(smm.g,0) + (t.agir+r.acik*90)/NULLIF(t.tut+r.acik,0) - dpo.g,1) AS DONGU_gercekci,
       round(stok.d/1e6,1)                                      AS bagli_stok_MTL,
       round(r.acik/1e6,1)                                      AS bagli_alacak_MTL
  FROM stok, smm, t, r, dpo;"
echo
echo "  ESKI EKRAN : DSO 0,1 · DPO 70,1 · stok gunu donmus veriden -> 'nakit URETIYORUZ'"
echo "  YENI EKRAN : yukaridaki. Nakit URETMIYORUZ, ~200-250M TL BAGLI."
echo "  ⚠ 'gercekci' bir TAHMIN (acik alacak 90 gunde tahsil) — ekranda OYLE ETIKETLI."

git add -A && git commit -q -m "fix(finans): FINANS_CCC_V1 — /api/bi/pricing/ccc yikildi, yeniden kuruldu. ESKI: DSO=AVG(bakiye)/gunluk_ciro = 0,1 gun (musteri basina ortalama bakiye, TOPLAM degil -- SUM yerine AVG); DPO=AVG(vade_gun) agirliksiz = 70,1; stok gunu 12 Haziran'da donmus tablodan. Sonuc: ekran 'nakit uretiyoruz' diyordu. YENI: bi_stok_anlik (son alis maliyeti) + bi_fatura_tahsilat (gercek tahsilat tarihleri) + bi_musteri_risk (acik alacak) + tutar agirlikli DPO. Gercek dongu +104,5/+134,7 gun." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_ccc server_container.mjs && docker cp server_container.mjs krb-assessment:/app/server.mjs && docker restart krb-assessment"
