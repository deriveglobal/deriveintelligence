#!/usr/bin/env bash
# MARJ_KUP_V2 — SKU anahtarli marj kubu.
#
# ⚠ V1 UC YERDEN PATLADI, HEPSI SESSIZ HATA CIKARDI:
#   #12 bayi_fiyati/net_fiyati 19 listenin HEPSINDE BOS -> maliyet liste_fiyati'ndan
#       turetilecek: liste x (1 - tesvik).
#   #13 tesvik tablosunda marka 'Bridgestone', listede 'BRIDGESTONE' -> join SIFIR
#       donuyordu -> tesvik %0 uygulanacak, butun bayilik marjlari DEVASA NEGATIF.
#   #14 ebat formati uyusmuyor ('205/65 R 15 XL' vs '215/55R18') -> 1210 liste
#       ciftinin sadece 278'i (%23) eslesiyordu. CANLIDAKI FIYAT MODULU DE BOYLE.
#
# ⚠ ASIL ANAHTAR SKU (Fatih hakliydi). Ayni kod, farkli format:
#     liste  '03 55 699'      -> bosluk sil, bastaki sifiri kirp -> 355699
#     satis  'CNT-355699'     -> harf onekini soy               -> 355699
#     satis  'MTD-1581262-26' -> onek + YIL soneki soy          -> 1581262
#   ⚠ -25/-26 URETIM YILI. Soyulmali: ayni urunun iki yili ayni fiyat satirina bakar.
#   ⚠ SIRA ONEMLI: once sonek, sonra rakam. Yoksa '158126226' cikar, hicbir seye uymaz.
#
# ⚠ TESVIK TAVANI: BARUM/MATADOR'da 28+13+2=43 ama max_toplam_pct=41,10.
#   LEAST(toplam, tavan) uygulanmazsa maliyet 1,9 puan DUSUK yazilir.
#
# ⚠ KOSULLU PRIM: donem_primi + sellout_primi HEDEFE BAGLI (donem_hedef_min_pct var).
#   Kosulsuz uygulamak "hedefler tuttu" varsaymaktir. GIZLENEMEZ.
#   -> IKI MALIYET: garantili (sadece fatura alti) + hedefli (tum primler).
#      Aradaki marj BANDI, gercek belirsizliktir.
#
# ⚠ TBR: 132M ciro, PSR fiyat listesi YOK (19 listenin hepsi PASSENGER).
#   Tesvik oranini biliyoruz (HRD %39) ama LISTE FIYATINI bilmiyoruz.
#   -> son_alis'a duser = PRIM ONCESI BRUT. TBR marji OLDUGUNDAN DUSUK gorunur.
#      Bu ekranda YAZACAK. Gizlenmeyecek.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SKU NORMALIZER ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE OR REPLACE FUNCTION bi_sku_norm(p text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT NULLIF(
    ltrim(
      regexp_replace(                                  -- 3) rakam disi her seyi sil (bosluk)
        regexp_replace(
          regexp_replace(upper(COALESCE(p,'')),
            '^[A-Z]+[-_ ]', '', ''),                   -- 1) harf oneki: CNT- MTD-
          '[-_ ]?[0-9]{2}$', '', ''),                  -- 2) ⚠ YIL soneki: -25 -26 (ONCE!)
        '[^0-9]', '', 'g'),
      '0'),                                            -- 4) bastaki sifir: 0355699 -> 355699
    '');
$$;
SQL
echo "  ✅ bi_sku_norm()"

echo
echo "############ 2) ⚠ ANAHTAR TESTI — kac SKU eslesiyor? ############"
$PSQL <<SQL
SET app.current_tenant_id = '$TEN';
\echo '--- ornekler: liste vs satis, normalize sonrasi ---'
SELECT k.urun_kodu AS liste_ham, bi_sku_norm(k.urun_kodu) AS liste_norm
  FROM bi_fiyat_listesi_kalemler k JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
 WHERE u.tenant_id='$TEN'::uuid GROUP BY 1,2 ORDER BY random() LIMIT 5;
SELECT kalem_kodu AS satis_ham, bi_sku_norm(kalem_kodu) AS satis_norm
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND ebat IS NOT NULL
   AND upper(marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR')
 GROUP BY 1,2 ORDER BY random() LIMIT 5;

\echo ''
\echo '--- ⚠⚠ KAPSAM: bayilik markalarinin cirosunun yuzde kaci SKU ile fiyatlaniyor? ---'
WITH l AS (SELECT DISTINCT bi_sku_norm(k.urun_kodu) AS sku
             FROM bi_fiyat_listesi_kalemler k
             JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
            WHERE u.tenant_id='$TEN'::uuid AND bi_sku_norm(k.urun_kodu) IS NOT NULL)
SELECT COALESCE(f.satis_kanali,'(bos)') AS kanal,
       round(sum(f.satir_tutar)/1e6,1) AS ciro_M,
       round(100.0*sum(f.satir_tutar) FILTER (WHERE l.sku IS NOT NULL)/sum(f.satir_tutar)) AS sku_kapsam_pct
  FROM bi_satis_faturalari f
  LEFT JOIN l ON l.sku = bi_sku_norm(f.kalem_kodu)
 WHERE f.tenant_id='$TEN' AND f.miktar>0 AND f.ebat IS NOT NULL
   AND upper(f.marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR','BARUM','DAYTON')
   AND f.fatura_tarihi >= CURRENT_DATE-365
 GROUP BY 1 ORDER BY 2 DESC LIMIT 8;
SQL

echo
echo "############ 3) KUP ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

CREATE OR REPLACE VIEW bi_satis_gercek AS
SELECT * FROM bi_satis_faturalari f
 WHERE f.miktar > 0
   AND f.ebat IS NOT NULL
   AND COALESCE(f.kategori,'') NOT IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')   -- ⚠ prim, satis degil (33,4M)
   AND COALESCE(f.satis_kanali,'') NOT ILIKE '%YANSIT%'                    -- ⚠ grup ici (46,4M)
   AND COALESCE(f.satis_kanali,'') <> 'DEPO';

-- ── ikame maliyet: liste x (1 - tesvik). IKI SENARYO. ──
DROP TABLE IF EXISTS _ikame;
CREATE TEMP TABLE _ikame AS
WITH t AS (   -- ⚠ upper() JOIN. 'Bridgestone' vs 'BRIDGESTONE' -> V1'de SIFIR donuyordu.
  SELECT upper(marka) AS marka, segment, kanal,
         COALESCE(fatura_alti_pct,0) AS garanti_pct,
         LEAST(  -- ⚠ TAVAN. Barum/Matador: 28+13+2=43 ama tavan 41,10.
           COALESCE(fatura_alti_pct,0)+COALESCE(donem_primi_pct,0)
          +COALESCE(sellout_primi_pct,0)+COALESCE(kanal_operasyon_pct,0)
          +COALESCE(kesin_siparis_pct,0),
           COALESCE(max_toplam_pct, 100)
         ) AS hedefli_pct,
         row_number() OVER (PARTITION BY upper(marka) ORDER BY yil DESC) AS rn
    FROM bi_tedarikci_tesvik WHERE tenant_id='$TEN'::uuid AND segment='PSR' AND kanal='perakende')
SELECT bi_sku_norm(k.urun_kodu) AS sku,
       upper(u.marka) AS marka,
       bi_ebat_norm(k.ebat) AS ebat_norm,
       -- ⚠ kdv_haric OKUNUYOR. Okumadigimiz icin Brisa maliyeti %20 sisikti (KDV_V1).
       (CASE WHEN u.kdv_haric THEN k.liste_fiyati ELSE k.liste_fiyati/1.20 END) AS liste_net,
       (CASE WHEN u.kdv_haric THEN k.liste_fiyati ELSE k.liste_fiyati/1.20 END)
         * (1 - COALESCE(t.garanti_pct,0)/100.0) AS maliyet_garantili,
       (CASE WHEN u.kdv_haric THEN k.liste_fiyati ELSE k.liste_fiyati/1.20 END)
         * (1 - COALESCE(t.hedefli_pct,0)/100.0) AS maliyet_hedefli,
       COALESCE(t.garanti_pct,0) AS garanti_pct,
       COALESCE(t.hedefli_pct,0) AS hedefli_pct,
       k.desen,
       row_number() OVER (PARTITION BY bi_sku_norm(k.urun_kodu) ORDER BY u.liste_tarihi DESC) AS rn
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
  LEFT JOIN t ON t.marka=upper(u.marka) AND t.rn=1
 WHERE u.tenant_id='$TEN'::uuid AND k.liste_fiyati > 0
   AND bi_sku_norm(k.urun_kodu) IS NOT NULL;
DELETE FROM _ikame WHERE rn > 1;   -- en guncel liste
CREATE INDEX ON _ikame(sku);
CREATE INDEX ON _ikame(marka, ebat_norm);

DROP TABLE IF EXISTS _son_alis;
CREATE TEMP TABLE _son_alis AS
SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
       bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS fiyat, fatura_tarihi
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   AND bi_sku_norm(kalem_kodu) IS NOT NULL
 ORDER BY 1, fatura_tarihi DESC;
CREATE INDEX ON _son_alis(sku);

DROP TABLE IF EXISTS _piyasa;
CREATE TEMP TABLE _piyasa AS
SELECT upper(marka) AS marka, bi_ebat_norm(ebat) AS ebat_norm,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY fiyat) AS med, min(fiyat) AS enaz
  FROM bi_rakip_fiyat_son
 WHERE lastik_mi AND fiyat>0 AND bi_ebat_norm(ebat) IS NOT NULL
 GROUP BY 1,2;

DROP TABLE IF EXISTS bi_marj_fact;
CREATE TABLE bi_marj_fact AS
SELECT '$TEN'::text AS tenant_id,
       date_trunc('month', f.fatura_tarihi)::date AS ay,
       f.sube, f.satis_kanali, f.sehir, f.satis_temsilcisi,
       upper(f.marka) AS marka, f.ebat, bi_ebat_norm(f.ebat) AS ebat_norm,
       f.kategori, f.jant_capi, f.musteri_kodu,
       COALESCE(max(i.desen), max(ip.desen)) AS desen,    -- ⚠ SKU eslesmesi DESEN'i getirir
       sum(f.miktar) AS adet,
       sum(f.satir_tutar) AS ciro,
       sum(f.satir_tutar)/NULLIF(sum(f.miktar),0) AS ort_satis_fiyati,
       -- ⚠ KASKAD: SKU > ebat_norm > son_alis. Kaynak ACIKCA yaziliyor.
       CASE WHEN max(i.sku)  IS NOT NULL THEN 'sku_liste'
            WHEN max(ip.marka) IS NOT NULL THEN 'ebat_liste'
            WHEN max(sa.sku) IS NOT NULL THEN 'son_alis'
            ELSE 'yok' END AS maliyet_kaynak,
       COALESCE(max(i.maliyet_garantili), max(ip.maliyet_garantili), max(sa.fiyat)) AS maliyet_garantili,
       COALESCE(max(i.maliyet_hedefli),   max(ip.maliyet_hedefli),   max(sa.fiyat)) AS maliyet_hedefli,
       COALESCE(max(i.garanti_pct), max(ip.garanti_pct)) AS garanti_pct,
       COALESCE(max(i.hedefli_pct), max(ip.hedefli_pct)) AS hedefli_pct,
       -- MARJ BANDI
       sum(f.satir_tutar) - COALESCE(max(i.maliyet_garantili),max(ip.maliyet_garantili),max(sa.fiyat))*sum(f.miktar) AS marj_alt_tl,
       sum(f.satir_tutar) - COALESCE(max(i.maliyet_hedefli),  max(ip.maliyet_hedefli),  max(sa.fiyat))*sum(f.miktar) AS marj_ust_tl,
       100.0*(sum(f.satir_tutar) - COALESCE(max(i.maliyet_garantili),max(ip.maliyet_garantili),max(sa.fiyat))*sum(f.miktar))/NULLIF(sum(f.satir_tutar),0) AS marj_alt_pct,
       100.0*(sum(f.satir_tutar) - COALESCE(max(i.maliyet_hedefli),  max(ip.maliyet_hedefli),  max(sa.fiyat))*sum(f.miktar))/NULLIF(sum(f.satir_tutar),0) AS marj_ust_pct,
       max(p.med) AS piyasa_medyan, max(p.enaz) AS piyasa_min,
       100.0*(sum(f.satir_tutar)/NULLIF(sum(f.miktar),0))/NULLIF(max(p.med),0) AS piyasa_konum_pct,
       NULL::numeric AS piyasa_trend_30g,   -- ⚠ rakip gecmisi 5 GUNLUK. UYDURMUYORUZ.
       -- ⚠ TBR/OTR: liste yok -> son_alis = PRIM ONCESI BRUT -> marj DUSUK gorunur.
       (max(i.sku) IS NULL AND max(ip.marka) IS NULL
        AND upper(f.marka) IN ('BRIDGESTONE','CONTINENTAL','LASSA','MATADOR','BARUM','DAYTON')) AS bayilik_ama_listesiz
  FROM bi_satis_gercek f
  LEFT JOIN _ikame   i  ON i.sku  = bi_sku_norm(f.kalem_kodu)
  LEFT JOIN _ikame   ip ON ip.marka = upper(f.marka) AND ip.ebat_norm = bi_ebat_norm(f.ebat)
                        AND i.sku IS NULL                       -- ⚠ SADECE SKU tutmadiysa
  LEFT JOIN _son_alis sa ON sa.sku = bi_sku_norm(f.kalem_kodu)
  LEFT JOIN _piyasa   p  ON p.marka = upper(f.marka) AND p.ebat_norm = bi_ebat_norm(f.ebat)
 WHERE f.tenant_id='$TEN' AND f.fatura_tarihi >= CURRENT_DATE - 730
 GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12;

CREATE INDEX idx_marj_ay   ON bi_marj_fact(tenant_id, ay DESC);
CREATE INDEX idx_marj_ebat ON bi_marj_fact(tenant_id, ebat_norm, marka);
CREATE INDEX idx_marj_sube ON bi_marj_fact(tenant_id, sube, satis_kanali);

\echo ''
\echo '=== GATE 1: maliyet kaynagi dagilimi ==='
SELECT maliyet_kaynak, count(*) AS satir, round(sum(ciro)/1e6,1) AS ciro_M,
       round(100.0*sum(ciro)/sum(sum(ciro)) OVER ()) AS pay_pct
  FROM bi_marj_fact GROUP BY 1 ORDER BY 3 DESC;

\echo '=== GATE 2: maliyetsiz ciro (<=10% olmali) ==='
SELECT round(100.0*sum(ciro) FILTER (WHERE maliyet_kaynak='yok')/sum(ciro)) AS maliyetsiz_pct
  FROM bi_marj_fact \gset
SELECT CASE WHEN :maliyetsiz_pct > 10 THEN (SELECT 1/0) ELSE 1 END AS gate2_ok;

\echo '=== GATE 3: prim/yansitma sizintisi (0 olmali) ==='
SELECT count(*) AS sizinti FROM bi_marj_fact
 WHERE kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM') OR satis_kanali ILIKE '%YANSIT%' \gset
SELECT CASE WHEN :sizinti > 0 THEN (SELECT 1/0) ELSE 1 END AS gate3_ok;

\echo '=== GATE 4: ⚠ TESVIK GERCEKTEN UYGULANDI MI? (0 ise #13 hala var) ==='
SELECT count(*) FILTER (WHERE hedefli_pct > 0) AS tesvikli_satir,
       round(max(hedefli_pct),1) AS max_tesvik_pct
  FROM bi_marj_fact \gset
SELECT CASE WHEN :tesvikli_satir = 0 THEN (SELECT 1/0) ELSE 1 END AS gate4_ok;

COMMIT;
SQL
[ $? -ne 0 ] && { echo "❌ GATE PATLADI — kup KURULMADI."; exit 1; }
echo "  ✅ kup kuruldu"

echo
echo "############ 4) ⚠ NE GOREMIYORUZ — durustce ############"
$PSQL -c "
SET app.current_tenant_id = '$TEN';
SELECT 'TBR/OTR — bayilik markasi ama LISTE YOK (prim oncesi brut)' AS kor_nokta,
       round(sum(ciro)/1e6,1) AS ciro_M
  FROM bi_marj_fact WHERE bayilik_ama_listesiz AND ay >= CURRENT_DATE-365
UNION ALL
SELECT 'Piyasa fiyati YOK (e-ticarette yok)', round(sum(ciro)/1e6,1)
  FROM bi_marj_fact WHERE piyasa_medyan IS NULL AND ay >= CURRENT_DATE-365;"

echo
echo "############ 5) ⚠⚠ ILK TARAMA ############"
$PSQL <<SQL
SET app.current_tenant_id = '$TEN';
\echo '--- A) AYNI URUN, SUBEDEN SUBEYE MARJ FARKI (yillik TL etkisine gore) ---'
WITH e AS (SELECT marka, ebat_norm, COALESCE(desen,'-') AS desen, sube,
                  sum(ciro) ciro, 100.0*sum(marj_alt_tl)/NULLIF(sum(ciro),0) AS marj
             FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
            GROUP BY 1,2,3,4 HAVING sum(ciro)>150000),
k AS (SELECT marka, ebat_norm, desen, max(marj)-min(marj) AS fark, sum(ciro) AS ciro,
             (array_agg(sube ORDER BY marj DESC))[1] AS iyi_sube, round(max(marj)::numeric,1) AS iyi_pct,
             (array_agg(sube ORDER BY marj))[1]      AS kotu_sube, round(min(marj)::numeric,1) AS kotu_pct
        FROM e GROUP BY 1,2,3 HAVING count(*)>=2)
SELECT marka, ebat_norm, left(desen,18) AS desen, iyi_sube, iyi_pct, kotu_sube, kotu_pct,
       round((ciro*fark/100.0)/1000.0) AS yillik_etki_binTL
  FROM k WHERE fark>5 ORDER BY ciro*fark DESC LIMIT 12;

\echo ''
\echo '--- B) MARKA MARJ BANDI (alt = garantili, ust = hedefler tutarsa) ---'
SELECT marka, round(sum(ciro)/1e6,1) AS ciro_M,
       round(100.0*sum(marj_alt_tl)/NULLIF(sum(ciro),0)::numeric,1) AS marj_alt,
       round(100.0*sum(marj_ust_tl)/NULLIF(sum(ciro),0)::numeric,1) AS marj_ust,
       max(maliyet_kaynak) AS kaynak
  FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
 GROUP BY 1 HAVING sum(ciro)>3e6 ORDER BY 3 DESC LIMIT 14;

\echo ''
\echo '--- C) ⚠ DEGER YOK EDEN URUNLER: piyasa medyani < garantili maliyet ---'
SELECT marka, ebat_norm, left(COALESCE(desen,'-'),18) AS desen, round(sum(adet)) AS adet,
       round(avg(ort_satis_fiyati)) AS krb, round(avg(maliyet_garantili)) AS maliyet,
       round(avg(piyasa_medyan)) AS piyasa, round(sum(marj_alt_tl)/1000.0) AS marj_binTL
  FROM bi_marj_fact
 WHERE ay>=CURRENT_DATE-365 AND piyasa_medyan IS NOT NULL AND maliyet_kaynak<>'yok'
 GROUP BY 1,2,3 HAVING avg(piyasa_medyan) < avg(maliyet_garantili) AND sum(adet)>20
 ORDER BY sum(adet) DESC LIMIT 10;

\echo ''
\echo '--- D) TEMSILCI MARJ SAPMASI ---'
WITH t AS (SELECT satis_temsilcisi, sum(ciro) ciro,
                  100.0*sum(marj_alt_tl)/NULLIF(sum(ciro),0) AS marj
             FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
            GROUP BY 1 HAVING sum(ciro)>5e6)
SELECT satis_temsilcisi, round(ciro/1e6,1) AS ciro_M, round(marj::numeric,1) AS marj_pct,
       round((ciro*((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY marj) FROM t)-marj)/100.0)/1000.0) AS medyandan_kayip_binTL
  FROM t ORDER BY marj LIMIT 10;
SQL

git add -A && git commit -q -m "feat(marj): MARJ_KUP_V2 — SKU anahtarli marj kubu. Fatih hakliydi: urun_kodu satista VAR, format farkli (liste '03 55 699' / satis 'CNT-355699' / 'MTD-1581262-26'). bi_sku_norm(): harf oneki + YIL soneki (-25/-26, uretim yili) soy, sonra rakam, sonra bastaki sifir. Sira kritik. Kaskad: SKU > ebat_norm > son_alis. SKU eslesmesi DESEN duzeyine iniyor (BLIZZAK 6 vs TURANZA 6 ayni ebatta farkli marj). Duzeltilen 3 sessiz hata: #12 bayi_fiyati 19 listede de BOS (maliyet liste x (1-tesvik)), #13 tesvik marka case mismatch -> join SIFIR donuyordu -> tesvik hic uygulanmiyordu, #14 ebat format uyumsuzlugu (%23 eslesme). Tesvik tavani LEAST(toplam,max_toplam) — Barum/Matador'da 43 > 41,10. IKI MALIYET: garantili (fatura alti) vs hedefli (kosullu primler dahil) -> marj BANDI. TBR (132M) listesiz: son_alis = prim oncesi brut, marj dusuk gorunur, ETIKETLENDI." && echo "  COMMITTED"
