#!/usr/bin/env bash
# KUP_V1 + MONITOR_V2
#
# ══ A) MONITOR — KALICI COZUM ══
# ⚠ Log'a satir eklemek YAMAYDI: yarin yeni dosya yuklenince yukleyici yine loga
#   yazmaz, monitor yine sahte alarm verir, biri yine ELLE kayit acar.
# ✅ Monitor artik LOGU DEGIL, TABLOLARIN KENDISINI okuyor.
#   Log = yukleyicinin SOYLEDIGI.  Tablo = GERCEKTE OLAN.
#   Kimin log yazip yazmadigi ONEMSIZLESIYOR.
#
# ══ B) MARJ KUBU ══
# ⚠ Maliyet AY BAZLI. Ocak'ta satilana Aralik maliyeti uygulanirsa marj yanlis cikar.
# ⚠ Her satirda maliyetin NEREDEN geldigi yaziyor. Kaynagini soylemeyen maliyet,
#   uydurulmus maliyettir.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ A) MONITOR_V2 — tablolari oku, logu degil ############"
cp ops_monitor.py ops_monitor.py.bak_v2
python3 patch_monitor.py || { cp ops_monitor.py.bak_v2 ops_monitor.py; echo "❌ geri alindi"; exit 1; }
python3 -c "import ast,sys; ast.parse(open('ops_monitor.py').read())" \
  || { cp ops_monitor.py.bak_v2 ops_monitor.py; echo "❌ SOZDIZIMI HATASI — geri alindi"; exit 1; }
echo "  ✅ python sozdizimi"

echo
echo "  -- ⚠ CALISTIR: sahte alarm kalkti mi? --"
/opt/price_monitor/venv/bin/python3 ops_monitor.py 2>&1 | tail -3 || true
$PSQL -c "
SELECT check_key, status, value, left(detail,58) AS detay
  FROM ops_health
 WHERE checked_at = (SELECT max(checked_at) FROM ops_health)
   AND check_key LIKE 'pipeline.ingest%'
 ORDER BY check_key;"
echo "  ^ ⚠ Artik TABLONUN son veri tarihini gosteriyor. Yeni dosya yuklenince"
echo "    kendiliginden guncellenir — elle is YOK."

echo
echo "############ B) MARJ KUBU ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

-- ⚠ AY BAZLI maliyet: urunun maliyeti yil icinde degisiyor (enflasyon, kur).
DROP TABLE IF EXISTS bi_maliyet_ay;
CREATE TABLE bi_maliyet_ay AS
SELECT tenant_id, date_trunc('month', belge_tarihi)::date AS ay, kalem_kodu,
       sum(cikis_tutari)/NULLIF(sum(cikis),0) AS birim_maliyet, sum(cikis) AS adet
  FROM bi_stok_hareket
 WHERE tenant_id='$TEN'::uuid AND cikis>0 AND cikis_tutari>0
 GROUP BY 1,2,3;
CREATE INDEX ON bi_maliyet_ay(tenant_id, ay, kalem_kodu);

DROP TABLE IF EXISTS bi_maliyet_sku;
CREATE TABLE bi_maliyet_sku AS
SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
       bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS birim_maliyet
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
 ORDER BY 1, fatura_tarihi DESC;
CREATE INDEX ON bi_maliyet_sku(sku);

DROP TABLE IF EXISTS bi_marj_fact;
CREATE TABLE bi_marj_fact AS
SELECT f.tenant_id,
       date_trunc('month', f.fatura_tarihi)::date AS ay,
       f.sube, f.satis_kanali, f.sehir, f.satis_temsilcisi,
       upper(f.marka) AS marka, f.ebat, bi_ebat_norm(f.ebat) AS ebat_norm,
       f.kategori, f.jant_capi, f.musteri_kodu, f.musteri_adi, f.kalem_kodu,
       max(f.kalem_tanimi) AS kalem_tanimi,
       sum(f.miktar) AS adet, sum(f.satir_tutar) AS ciro,
       sum(f.satir_tutar)/NULLIF(sum(f.miktar),0) AS ort_fiyat,
       COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet)) AS birim_maliyet,
       -- ⚠ KAYNAGINI SOYLEMEYEN MALIYET, UYDURULMUS MALIYETTIR.
       CASE WHEN max(ma.birim_maliyet) IS NOT NULL THEN 'hareket_ay'
            WHEN max(ms.birim_maliyet) IS NOT NULL THEN 'son_alis'
            ELSE 'yok' END AS maliyet_kaynak,
       COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet))*sum(f.miktar) AS smm,
       sum(f.satir_tutar) - COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet))*sum(f.miktar) AS brut_kar,
       100.0*(sum(f.satir_tutar) - COALESCE(max(ma.birim_maliyet), max(ms.birim_maliyet))*sum(f.miktar))
            /NULLIF(sum(f.satir_tutar),0) AS marj_pct
  FROM bi_satis_faturalari f
  LEFT JOIN bi_maliyet_ay  ma ON ma.tenant_id = f.tenant_id::uuid
                             AND ma.ay = date_trunc('month', f.fatura_tarihi)::date
                             AND ma.kalem_kodu = f.kalem_kodu
  LEFT JOIN bi_maliyet_sku ms ON ms.sku = bi_sku_norm(f.kalem_kodu)
 WHERE f.tenant_id='$TEN' AND f.miktar>0
   AND f.grup_adi IN ('LASTIK TICARI','LASTIK TUKETICI')
   AND f.fatura_tarihi >= CURRENT_DATE-730
 GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14;

CREATE INDEX ON bi_marj_fact(tenant_id, ay DESC);
CREATE INDEX ON bi_marj_fact(tenant_id, ebat_norm, marka);
CREATE INDEX ON bi_marj_fact(tenant_id, sube, satis_kanali);
CREATE INDEX ON bi_marj_fact(tenant_id, satis_temsilcisi);

\echo '=== KAPI 1: maliyet kapsami >= %90 ==='
SELECT round(100.0*sum(ciro) FILTER (WHERE maliyet_kaynak<>'yok')/sum(ciro)) AS kapsam
  FROM bi_marj_fact WHERE ay >= CURRENT_DATE-365 \gset
SELECT CASE WHEN :kapsam < 90 THEN (SELECT 1/0) ELSE 1 END AS k1;

\echo '=== KAPI 2: ⚠ KUP KENDINI MUTABAKATA SOKUYOR — bagimsiz %8,3 ile tutmali ==='
SELECT round(100.0*sum(brut_kar)/sum(ciro),1) AS kup_marj
  FROM bi_marj_fact WHERE ay >= CURRENT_DATE-365 AND maliyet_kaynak<>'yok' \gset
SELECT CASE WHEN abs(:kup_marj - 8.3) > 3 THEN (SELECT 1/0) ELSE 1 END AS k2;

COMMIT;
SQL
[ $? -ne 0 ] && { echo "❌ KAPI DUSTU — kup KURULMADI"; exit 1; }
echo "  ✅ kup kuruldu"

echo
echo "############ C) ⚠⚠ KILCAL DAMARLAR ############"
$PSQL <<SQL
SET app.current_tenant_id='$TEN';
\echo '--- A) AYNI URUN, SUBEDEN SUBEYE MARJ FARKI ---'
WITH e AS (SELECT marka, ebat_norm, sube, sum(ciro) c, 100.0*sum(brut_kar)/NULLIF(sum(ciro),0) m
             FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
            GROUP BY 1,2,3 HAVING sum(ciro)>300000),
k AS (SELECT marka, ebat_norm, max(m)-min(m) fark, sum(c) ciro,
             (array_agg(sube ORDER BY m DESC))[1] iyi, round(max(m)::numeric,1) iyi_pct,
             (array_agg(sube ORDER BY m))[1] kotu, round(min(m)::numeric,1) kotu_pct
        FROM e GROUP BY 1,2 HAVING count(*)>=2)
SELECT marka, ebat_norm, iyi, iyi_pct, kotu, kotu_pct,
       round((ciro*fark/100.0)/1000.0) AS yillik_etki_binTL
  FROM k WHERE fark>4 ORDER BY ciro*fark DESC LIMIT 10;

\echo ''
\echo '--- B) ⚠ ZARARINA SATILAN URUNLER ---'
SELECT marka, ebat_norm, left(max(kalem_tanimi),24) AS urun,
       round(sum(adet)) AS adet, round(avg(ort_fiyat)) AS satis,
       round(avg(birim_maliyet)) AS maliyet,
       round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0),1) AS marj_pct,
       round(sum(brut_kar)/1000.0) AS zarar_binTL
  FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
 GROUP BY 1,2 HAVING sum(brut_kar)<0 AND sum(adet)>30
 ORDER BY sum(brut_kar) LIMIT 10;

\echo ''
\echo '--- C) MARKA MARJLARI ---'
SELECT marka, round(sum(ciro)/1e6,1) AS ciro_M,
       round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0),1) AS marj_pct,
       round(sum(brut_kar)/1e6,1) AS brut_kar_M
  FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
 GROUP BY 1 HAVING sum(ciro)>5e6 ORDER BY 3 DESC LIMIT 12;

\echo ''
\echo '--- D) KANAL MARJLARI ---'
SELECT satis_kanali, round(sum(ciro)/1e6,1) AS ciro_M,
       round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0),1) AS marj_pct
  FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
 GROUP BY 1 HAVING sum(ciro)>3e6 ORDER BY 2 DESC;

\echo ''
\echo '--- E) TEMSILCI SAPMASI ---'
WITH t AS (SELECT satis_temsilcisi, sum(ciro) c, 100.0*sum(brut_kar)/NULLIF(sum(ciro),0) m
             FROM bi_marj_fact WHERE ay>=CURRENT_DATE-365 AND maliyet_kaynak<>'yok'
            GROUP BY 1 HAVING sum(ciro)>10e6)
SELECT satis_temsilcisi, round(c/1e6,1) AS ciro_M, round(m::numeric,1) AS marj_pct,
       round((c*((SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY m) FROM t)-m)/100.0)/1000.0) AS medyandan_kayip_binTL
  FROM t ORDER BY m LIMIT 8;
SQL

git add -A && git commit -q -m "feat: KUP_V1 + MONITOR_V2. MONITOR: loga satir eklemek YAMAYDI — yarin yeni dosya yuklenince yukleyici yine loga yazmaz, monitor yine sahte alarm verir, biri yine ELLE kayit acar. KALICI COZUM: monitor artik LOGU DEGIL TABLOLARIN KENDISINI okuyor. Log = yukleyicinin SOYLEDIGI; tablo = GERCEKTE OLAN. Kimin log yazip yazmadigi onemsizlesti. Tazelik olcusu: export_date varsa O (verinin AIT OLDUGU tarih), yoksa ingested_at — dun yuklenmis ama 3 ay onceki veriyi tasiyan dosya TAZE DEGILDIR. KUP: bi_marj_fact, ay bazli GERCEK maliyetle (bi_stok_hareket.birim_maliyet). Kup KENDINI MUTABAKATA SOKUYOR: urettigi toplam marj, bagimsiz dogrulanmis %8,3'ten 3 puandan fazla saparsa KURULMAZ." && echo "  COMMITTED"
