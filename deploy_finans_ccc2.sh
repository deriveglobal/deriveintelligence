#!/usr/bin/env bash
# FINANS_CCC_V2 — donmus maliyet + eksik yanit govdesi.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

grep -q "FINANS_CCC_V1" server_container.mjs || { echo "❌ DUR: V1 yok"; exit 1; }
echo "✅ V1 yerinde"

echo
echo "############ 1) YAMA ############"
if grep -q "FINANS_CCC_V2" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_ccc2
  python3 patch_finans_ccc2.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_ccc2 server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_ccc2 server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 2) SQL DOGRULAMA — agirlikli birim maliyet ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS maliyet
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT COALESCE(SUM(s.adet*son.maliyet)/NULLIF(SUM(s.adet),0),0) AS avg_cost
  FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0
   AND s.export_date=(SELECT MAX(export_date) FROM bi_stok_anlik WHERE tenant_id='$TEN'::uuid);" >/dev/null \
  && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_ccc2 server_container.mjs; exit 1; }

echo
echo "  -- ESKI (donmus) vs YENI (agirlikli) birim maliyet --"
$PSQL -c "
SELECT round(AVG(birim_maliyet)) AS eski_donmus_ortalama
  FROM bi_stok_hareketleri
 WHERE tenant_id='$TEN' AND belge_tarihi >= now()-interval '30 days' AND birim_maliyet>1;" 2>&1 | head -4
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC)
SELECT round(SUM(s.adet*son.m)/NULLIF(SUM(s.adet),0)) AS yeni_agirlikli_TL,
       round(AVG(son.m))                              AS duz_ortalama_TL_YANLIS
  FROM bi_stok_anlik s JOIN son ON son.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$TEN'::uuid AND s.adet>0;"
echo "  ^ Duz ortalama, 1 adet is makinesi lastigini (137.000 TL) 500 adet"
echo "    binek lastigiyle (4.000 TL) esit agirlikta sayar. ADET AGIRLIKLI dogrusu."

echo
echo "############ 3) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 4) ⚠ SON TABLO — Fatih Bilen'e gidecek rakamlar ############"
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
          AND fatura_tarihi >= date_trunc('year',CURRENT_DATE)),
r AS (SELECT SUM(toplam_risk) acik, SUM(vadesi_gecmis) gec FROM bi_musteri_risk
       WHERE tenant_id='$TEN'::uuid AND musteri_mi),
dpo AS (SELECT SUM(satir_kdv_haric*vade_gun)/NULLIF(SUM(satir_kdv_haric),0) g
          FROM bi_tedarikci_faturalari WHERE tenant_id='$TEN'::uuid
            AND fatura_tarihi >= date_trunc('year',CURRENT_DATE)
            AND vade_gun>0 AND miktar>0 AND satir_kdv_haric>0)
SELECT round(stok.d/NULLIF(smm.g,0),1) AS stok_gunu,
       round(t.agir/NULLIF(t.tut,0),1) AS DSO,
       round((t.agir+r.acik*90)/NULLIF(t.tut+r.acik,0),1) AS DSO_gercekci,
       round(dpo.g,1) AS DPO,
       round(stok.d/NULLIF(smm.g,0) + t.agir/NULLIF(t.tut,0) - dpo.g,1) AS DONGU,
       round(stok.d/NULLIF(smm.g,0) + (t.agir+r.acik*90)/NULLIF(t.tut+r.acik,0) - dpo.g,1) AS DONGU_gercekci,
       round(smm.g*(stok.d/NULLIF(smm.g,0) + t.agir/NULLIF(t.tut,0) - dpo.g)/1e6,0) AS BAGLI_SERMAYE_MTL,
       round(smm.g*(stok.d/NULLIF(smm.g,0) + t.agir/NULLIF(t.tut,0) - dpo.g)*0.40/1e6,1) AS YILLIK_FINANSMAN_MTL
  FROM stok, smm, t, r, dpo;"
echo
echo "  ^ YILLIK_FINANSMAN = bagli sermaye x %40 sermaye maliyeti."
echo "    Bu para, hicbir sey satmadan, SADECE dongunun uzunlugu yuzunden gidiyor."
echo "    Stok gunu 146 -> lastikte tipik 60-90. Fazlasi dogrudan nakit."

git add -A && git commit -q -m "fix(finans): FINANS_CCC_V2 — avgCost donmus bi_stok_hareketleri yerine anlik stok x son alis (ADET AGIRLIKLI). Yanit govdesi acildi: dso_gercekci, ccc_gercekci, acik_alacak, stok_degeri, bagli_sermaye, yillik_finansman_maliyeti + 'varsayim' alani ile 90-gun tahsilat tahmininin VERI OLMADIGI acikca yaziliyor + 'kaynaklar' alani ile hangi tablodan geldigi." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_ccc2 server_container.mjs && docker cp server_container.mjs krb-assessment:/app/server.mjs && docker restart krb-assessment"
