#!/usr/bin/env bash
# MARJ_KUP_V1 — kilcal damar taramasi icin marj kubu.
#
# ⚠ KESIFTE OGRENDIKLERIMIZ (bunlar kodun icine gomulu, ezberden degil):
#   1. ebat, GERCEK lastik kategorilerinde %100 dolu. Bos olanlar lastik DEGIL
#      (silecek/ampul/jant/kaucuk/hizmet). -> ebat IS NOT NULL filtresi
#      dogal bir "lastik mi?" suzgeci gorevi goruyor.
#   2. ⚠⚠ 'DESTEK BEDELI' (25,4M) + 'TUKETICI PRIM' (8,0M) = 33,4M
#      CIRO OLARAK FATURALANMIS PRIM HAKEDISI. Bu SATIS DEGIL.
#      Kupe girerse marji SISIRIR. Ayri olculur.
#   3. ⚠ 'MERKEZ YONETIM GRP.DISI.YANSIT' (46,4M) = grup ici yansitma. SATIS DEGIL.
#   4. Liste fiyati cironun %18'ini kapsiyor (sadece bayilik: Brisa/Conti).
#      Son alis %100 kapsiyor. Bunlar FARKLI seyler:
#        - bayilik marka  -> ikame maliyet = liste - tesvik   (prim DAHIL, gercek)
#        - net-fiyat marka-> ikame maliyet = son alis         (tesvik YOK, gercek)
#      Kaskad yanlis kurulursa net-fiyat markalarina hayali tesvik yazariz.
#   5. ⚠ Rakip gecmisi sadece 5 GUN (08-13 Tem). Trend kolonu kuruluyor ama
#      NULL birakiliyor. UYDURMUYORUZ. Kendi kendine dolacak.
#   6. Tedarikci faturalarinda EBAT KOLONU YOK -> join kalem_kodu uzerinden.
#      Kapsami GATE ile olculuyor; dusukse ISLEM GERI ALINIYOR.
#
# ⚠ KDV: satis birim_fiyat'inin KDV dahil mi haric mi oldugu KESIN DEGIL.
#   Alis tarafinda birim_fiyat_kdv_haric acikca var. Yanlissa marj +%20 sisik cikar.
#   Kupte kdv_supheli bayragi + teshis ciktisi var. Fatih Bilen'e SORULACAK.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) ON GATE — kalem_kodu satis<->alis eslesmesi ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
SET app.current_tenant_id = '$TEN';
WITH s AS (
  SELECT kalem_kodu, sum(satir_tutar) ciro
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND miktar>0 AND ebat IS NOT NULL
     AND fatura_tarihi >= CURRENT_DATE - 365
   GROUP BY 1),
a AS (SELECT DISTINCT kalem_kodu FROM bi_tedarikci_faturalari
       WHERE tenant_id='$TEN'::uuid AND kalem_kodu IS NOT NULL)
SELECT round(sum(s.ciro)/1e6,1) AS lastik_ciro_M,
       round(100.0*sum(s.ciro) FILTER (WHERE a.kalem_kodu IS NOT NULL)/sum(s.ciro)) AS kalem_eslesme_pct
  FROM s LEFT JOIN a USING (kalem_kodu);
SQL
echo "  ^ kalem_eslesme_pct < 80 ise KUP KURULMAZ (asagida gate var)."

echo
echo "############ 1) KUP ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

-- ⚠ NE SATIS DEGILDIR? Tek yerde tanimli, her yerden cagriliyor.
CREATE OR REPLACE VIEW bi_satis_gercek AS
SELECT * FROM bi_satis_faturalari f
 WHERE f.miktar > 0                      -- ⚠ iade satirlari ortalamalari bozuyordu
   AND f.ebat IS NOT NULL                -- lastik degilse (silecek/jant/hizmet) disarida
   AND COALESCE(f.kategori,'') NOT IN ('DESTEK BEDELİ','TÜKETİCİ PRİM')  -- ⚠ prim, satis degil
   AND COALESCE(f.satis_kanali,'') NOT ILIKE '%YANSIT%'                  -- ⚠ grup ici
   AND COALESCE(f.satis_kanali,'') NOT IN ('DEPO');

DROP TABLE IF EXISTS bi_marj_fact;
CREATE TABLE bi_marj_fact (
  tenant_id        text NOT NULL,
  ay               date NOT NULL,
  sube             text, satis_kanali text, sehir text, satis_temsilcisi text,
  marka            text, ebat text, kategori text, jant_capi text,
  musteri_kodu     text,
  adet             numeric,
  ciro             numeric,
  ort_satis_fiyati numeric,
  -- maliyet: kaskad. hangi yoldan geldigi ACIKCA yaziyor.
  maliyet_birim    numeric,
  maliyet_kaynak   text,      -- 'liste_tesvik' (bayilik) | 'son_alis' | 'yok'
  bayilik_mi       boolean,
  maliyet_toplam   numeric,
  marj_tl          numeric,
  marj_pct         numeric,
  -- piyasa
  piyasa_medyan    numeric,
  piyasa_min       numeric,
  piyasa_konum_pct numeric,   -- KRB fiyati / piyasa medyani
  piyasa_trend_30g numeric,   -- ⚠ NULL. Rakip gecmisi 5 gunluk. Zamanla dolacak.
  kdv_supheli      boolean,
  PRIMARY KEY (tenant_id, ay, sube, satis_kanali, satis_temsilcisi, marka, ebat, musteri_kodu)
);

-- son alis fiyati: kalem_kodu bazinda EN SON fatura
CREATE TEMP TABLE _son_alis AS
SELECT DISTINCT ON (kalem_kodu)
       kalem_kodu, marka,
       birim_fiyat_kdv_haric AS fiyat,
       fatura_tarihi
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
 ORDER BY kalem_kodu, fatura_tarihi DESC;

-- liste + tesvik: SADECE bayilik markalar. ⚠ marka uploads'ta, kalemlerde DEGIL.
-- ⚠ kdv_haric bayragi OKUNUYOR (KDV_V1'de bunu okumadigimiz icin maliyet %20 sisikti)
CREATE TEMP TABLE _ikame AS
SELECT u.marka, k.ebat,
       CASE WHEN u.kdv_haric THEN k.bayi_fiyati ELSE k.bayi_fiyati/1.20 END
         * (1 - COALESCE(t.toplam_pct,0)/100.0) AS fiyat
  FROM bi_fiyat_listesi_kalemler k
  JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id AND u.aktif
  LEFT JOIN LATERAL (
     SELECT COALESCE(fatura_alti_pct,0)+COALESCE(donem_primi_pct,0)
           +COALESCE(sellout_primi_pct,0)+COALESCE(kanal_operasyon_pct,0)
           +COALESCE(kesin_siparis_pct,0) AS toplam_pct
       FROM bi_tedarikci_tesvik tt
      WHERE tt.tenant_id=u.tenant_id AND tt.marka=u.marka
      ORDER BY tt.yil DESC LIMIT 1) t ON true
 WHERE u.tenant_id='$TEN'::uuid AND k.bayi_fiyati > 0;

-- piyasa (e-ticaret) medyani — ebat+marka
CREATE TEMP TABLE _piyasa AS
SELECT marka, ebat,
       percentile_cont(0.5) WITHIN GROUP (ORDER BY fiyat) AS med,
       min(fiyat) AS enaz
  FROM bi_rakip_fiyat_son
 WHERE lastik_mi AND fiyat > 0
 GROUP BY 1,2;

INSERT INTO bi_marj_fact
SELECT '$TEN',
       date_trunc('month', f.fatura_tarihi)::date,
       f.sube, f.satis_kanali, f.sehir, f.satis_temsilcisi,
       f.marka, f.ebat, f.kategori, f.jant_capi, f.musteri_kodu,
       sum(f.miktar), sum(f.satir_tutar),
       sum(f.satir_tutar)/NULLIF(sum(f.miktar),0),
       -- ⚠ KASKAD: bayilikse liste-tesvik, degilse son alis. ASLA karistirma.
       COALESCE(max(i.fiyat), max(sa.fiyat)),
       CASE WHEN max(i.fiyat) IS NOT NULL THEN 'liste_tesvik'
            WHEN max(sa.fiyat) IS NOT NULL THEN 'son_alis' ELSE 'yok' END,
       max(i.fiyat) IS NOT NULL,
       COALESCE(max(i.fiyat), max(sa.fiyat)) * sum(f.miktar),
       sum(f.satir_tutar) - COALESCE(max(i.fiyat), max(sa.fiyat))*sum(f.miktar),
       100.0*(sum(f.satir_tutar) - COALESCE(max(i.fiyat), max(sa.fiyat))*sum(f.miktar))
            / NULLIF(sum(f.satir_tutar),0),
       max(p.med), max(p.enaz),
       100.0*(sum(f.satir_tutar)/NULLIF(sum(f.miktar),0)) / NULLIF(max(p.med),0),
       NULL,   -- ⚠ piyasa_trend_30g: rakip gecmisi 5 gunluk. UYDURMUYORUZ.
       false
  FROM bi_satis_gercek f
  LEFT JOIN _son_alis sa ON sa.kalem_kodu = f.kalem_kodu
  LEFT JOIN _ikame  i    ON i.marka = f.marka AND i.ebat = f.ebat
  LEFT JOIN _piyasa p    ON p.marka = f.marka AND p.ebat = f.ebat
 WHERE f.tenant_id='$TEN' AND f.fatura_tarihi >= CURRENT_DATE - 730
 GROUP BY 1,2,3,4,5,6,7,8,9,10,11;

CREATE INDEX idx_marj_ay    ON bi_marj_fact(tenant_id, ay DESC);
CREATE INDEX idx_marj_ebat  ON bi_marj_fact(tenant_id, ebat, marka);
CREATE INDEX idx_marj_sube  ON bi_marj_fact(tenant_id, sube, satis_kanali);

\echo ''
\echo '=== GATE 1: maliyet kapsami (>=90% olmali) ==='
SELECT round(100.0*sum(ciro) FILTER (WHERE maliyet_kaynak<>'yok')/sum(ciro)) AS maliyet_pct,
       round(sum(ciro) FILTER (WHERE maliyet_kaynak='yok')/1e6,1) AS maliyetsiz_M
  FROM bi_marj_fact \gset
SELECT CASE WHEN :maliyet_pct < 90
       THEN (SELECT 1/0) ELSE 1 END AS gate1_ok;   -- ⚠ dusukse PATLAT -> ROLLBACK

\echo '=== GATE 2: prim/yansitma kupe SIZDI MI? (0 olmali) ==='
SELECT count(*) AS sizinti FROM bi_marj_fact
 WHERE kategori IN ('DESTEK BEDELİ','TÜKETİCİ PRİM') OR satis_kanali ILIKE '%YANSIT%' \gset
SELECT CASE WHEN :sizinti > 0 THEN (SELECT 1/0) ELSE 1 END AS gate2_ok;

\echo '=== GATE 3: bayilik markalara son_alis, net markalara liste yazilmis mi? ==='
SELECT count(*) FILTER (WHERE bayilik_mi AND maliyet_kaynak<>'liste_tesvik') AS yanlis_bayilik,
       count(*) FILTER (WHERE NOT bayilik_mi AND maliyet_kaynak='liste_tesvik') AS yanlis_net
  FROM bi_marj_fact;

COMMIT;
SQL
[ $? -ne 0 ] && { echo "❌ GATE PATLADI — kup KURULMADI, islem geri alindi."; exit 1; }
echo "  ✅ kup kuruldu, gateler gecti"

echo
echo "############ 2) ⚠ KDV TESHISI — marj sisik mi? ############"
$PSQL -c "
SET app.current_tenant_id = '$TEN';
SELECT maliyet_kaynak,
       round(sum(ciro)/1e6,1) AS ciro_M,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY marj_pct)::numeric,1) AS medyan_marj,
       round(percentile_cont(0.5) WITHIN GROUP (ORDER BY marj_pct)::numeric - 16.7,1) AS kdv_dahilse
  FROM bi_marj_fact WHERE ay >= date_trunc('year',CURRENT_DATE) GROUP BY 1;"
echo "  ⚠ Satis fiyati KDV DAHIL ise gercek marj 'kdv_dahilse' sutunudur."
echo "    Medyan marj %25+ cikiyorsa lastik toptaninda SUPHELI -> Fatih Bilen'e sorulacak."

echo
echo "############ 3) ⚠⚠ ILK TARAMA — KILCAL DAMARLAR ############"
$PSQL -c "
SET app.current_tenant_id = '$TEN';
\echo '--- A) AYNI EBAT, SUBEDEN SUBEYE MARJ FARKI (yillik >250k TL etki) ---'
WITH e AS (
  SELECT ebat, marka, sube,
         sum(ciro) ciro, sum(marj_tl) marj,
         100.0*sum(marj_tl)/NULLIF(sum(ciro),0) AS marj_pct
    FROM bi_marj_fact
   WHERE ay >= CURRENT_DATE - 365 AND maliyet_kaynak<>'yok'
   GROUP BY 1,2,3 HAVING sum(ciro) > 200000),
k AS (
  SELECT ebat, marka,
         max(marj_pct) - min(marj_pct) AS fark,
         (array_agg(sube ORDER BY marj_pct DESC))[1] AS en_iyi_sube,
         round(max(marj_pct)::numeric,1) AS en_iyi_pct,
         (array_agg(sube ORDER BY marj_pct))[1]      AS en_kotu_sube,
         round(min(marj_pct)::numeric,1) AS en_kotu_pct,
         sum(ciro) AS toplam_ciro,
         count(*) AS sube_sayisi
    FROM e GROUP BY 1,2 HAVING count(*) >= 2)
SELECT marka, ebat, en_iyi_sube, en_iyi_pct, en_kotu_sube, en_kotu_pct,
       round(fark::numeric,1) AS fark_puan,
       round((toplam_ciro * fark/100.0)/1000.0) AS yillik_etki_bin_TL
  FROM k WHERE fark > 5
 ORDER BY (toplam_ciro * fark) DESC LIMIT 12;"

$PSQL -c "
SET app.current_tenant_id = '$TEN';
\echo ''
\echo '--- B) ⚠ DEGER YOK EDEN EBATLAR: piyasa fiyati < ikame maliyeti ---'
SELECT marka, ebat,
       round(sum(adet)) AS adet,
       round(avg(ort_satis_fiyati)) AS krb_fiyat,
       round(avg(maliyet_birim))    AS maliyet,
       round(avg(piyasa_medyan))    AS piyasa_med,
       round(avg(piyasa_min))       AS piyasa_min,
       round(sum(marj_tl)/1000.0)   AS marj_bin_TL
  FROM bi_marj_fact
 WHERE ay >= CURRENT_DATE - 365 AND piyasa_medyan IS NOT NULL AND maliyet_kaynak<>'yok'
 GROUP BY 1,2
HAVING avg(piyasa_medyan) < avg(maliyet_birim) AND sum(adet) > 20
 ORDER BY sum(adet) DESC LIMIT 10;"

$PSQL -c "
SET app.current_tenant_id = '$TEN';
\echo ''
\echo '--- C) MARKA MARJLARI (Fatih Bilen bunu hic gormedi) ---'
SELECT marka, round(sum(ciro)/1e6,1) AS ciro_M,
       round(100.0*sum(marj_tl)/NULLIF(sum(ciro),0)::numeric,1) AS marj_pct,
       round(sum(marj_tl)/1e6,1) AS marj_M,
       max(maliyet_kaynak) AS kaynak
  FROM bi_marj_fact
 WHERE ay >= CURRENT_DATE - 365 AND maliyet_kaynak<>'yok'
 GROUP BY 1 HAVING sum(ciro) > 3e6
 ORDER BY 2 DESC LIMIT 14;"

$PSQL -c "
SET app.current_tenant_id = '$TEN';
\echo ''
\echo '--- D) TEMSILCI: ayni urunu kim ucuza satiyor? ---'
WITH t AS (
  SELECT satis_temsilcisi, sum(ciro) ciro,
         100.0*sum(marj_tl)/NULLIF(sum(ciro),0) AS marj_pct
    FROM bi_marj_fact
   WHERE ay >= CURRENT_DATE - 365 AND maliyet_kaynak<>'yok'
   GROUP BY 1 HAVING sum(ciro) > 5e6)
SELECT satis_temsilcisi, round(ciro/1e6,1) AS ciro_M, round(marj_pct::numeric,1) AS marj_pct,
       round(((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY marj_pct) FROM t) - marj_pct)::numeric,1) AS medyandan_fark,
       round((ciro * ((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY marj_pct) FROM t) - marj_pct)/100.0)/1000.0) AS kayip_bin_TL
  FROM t ORDER BY marj_pct LIMIT 10;"

git add -A && git commit -q -m "feat(marj): MARJ_KUP_V1 — kilcal damar taramasi icin marj kubu. Grain: ay×sube×kanal×sehir×temsilci×marka×ebat×musteri. KESIFTE BULUNAN 3 TUZAK KODA GOMULDU: (1) 'DESTEK BEDELI' 25,4M + 'TUKETICI PRIM' 8,0M CIRO OLARAK faturalanmis prim hakedisi — SATIS DEGIL, kupten cikarildi, yoksa marj sisiyordu. (2) 'GRP.DISI.YANSIT' 46,4M grup ici yansitma — cikarildi. (3) maliyet kaskadi: bayilik marka -> liste-tesvik (%18 kapsam), net-fiyat marka -> son alis (%100) — karistirilirsa net markalara hayali tesvik yazilir. Piyasa trend kolonu NULL: rakip gecmisi henuz 5 gunluk, uydurulmadi. 3 gate: maliyet kapsami>=90%, prim sizintisi=0, kaskad dogrulugu." && echo "  COMMITTED"
