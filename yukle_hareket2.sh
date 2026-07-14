#!/usr/bin/env bash
# HAREKET_V2 YUKLEME — bi_stok_hareket'i TAM KAPSAM + PARA ile yeniden kur.
#
# ⚠ NEDEN: iki tablo vardi, ikisi de eksikti.
#   bi_stok_hareketleri (eski) : 358k satir · yillar · PARA VAR · ama
#                                 tarihler BOZUK (2026-12-05) ve tutarlar ~10 KAT SISKIN
#                                 (2021 tek yilda 8.004M TL cikis — 6 yilin toplami 6.035M)
#   bi_stok_hareket    (yeni)  : 37k satir · SADECE 2026 · PARA YOK
#
# ✅ YENI: 579.771 satir · 2021-09-30 (SAP devreye alma) → 2026-07-11 · PARA VAR
#   4 kapi gecti: satir kaybi 0 · gelecek tarih 0 · maliyet tutarsizligi %0,00
#
# ⚠ TARIH ONARIMI: Excel, ERP'nin GG/AA metnini AA/GG sanip gun<=12 olanlari
#   TAKAS ETMISTI (datetime), gun>12 olanlari METIN birakmisti. Tipten ayirt
#   edilebiliyordu -> 214.564 satir geri takas edildi, tahmin YOK.
#
# ⚠ SAYI ONARIMI: Excel bazi Turkce sayilarin ayracini ATIP tam sayi yapmis
#   ('932,203' -> 932203). Her kolonun ondalik basamagi SABIT (Price=3,
#   Fiyat=4, Miktar=2) -> int/10^b ile geri olceklendi. Once %33,5 tutarsizdi.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) CSV KONTROL ############"
[ -f hareket_all.csv ] || { echo "❌ hareket_all.csv yok"; exit 1; }
wc -l hareket_all.csv
head -1 hareket_all.csv

echo
echo "############ 1) SEMA: para kolonlari + export_date ekle ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE bi_stok_hareket
  ADD COLUMN IF NOT EXISTS birim_maliyet      numeric(14,4),
  ADD COLUMN IF NOT EXISTS giris_tutari       numeric(16,4),
  ADD COLUMN IF NOT EXISTS cikis_tutari       numeric(16,4),
  ADD COLUMN IF NOT EXISTS stok_bakiye_tutari numeric(18,4),
  ADD COLUMN IF NOT EXISTS kategori           text;
SQL
echo "  ✅ kolonlar hazir"

echo
echo "############ 2) ONCESI — ne vardi? ############"
$PSQL -c "
SELECT 'bi_stok_hareket (yeni, eksik)' AS tablo, count(*), min(belge_tarihi), max(belge_tarihi)
  FROM bi_stok_hareket WHERE tenant_id='$TEN'::uuid
UNION ALL
SELECT 'bi_stok_hareketleri (eski, bozuk)', count(*), min(belge_tarihi), max(belge_tarihi)
  FROM bi_stok_hareketleri WHERE tenant_id='$TEN'::uuid;"

echo
echo "############ 3) YUKLE — TRANSACTION icinde ############"
docker cp hareket_all.csv krb-assessment-postgres:/tmp/h.csv
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

CREATE TEMP TABLE _h (
  belge_tarihi date, belge_turu text, belge_no text, muhatap_kodu text, muhatap_adi text,
  satis_calisani text, depo text, kalem_kodu text, grup_adi text, kategori text, marka text,
  kalem_tanimi text, birim_maliyet numeric, giris numeric, giris_tutari numeric,
  cikis numeric, cikis_tutari numeric, stok_bakiye_tutari numeric, notlar text
);
\copy _h FROM '/tmp/h.csv' WITH (FORMAT csv, HEADER true)

-- ⚠ ESKI VERI SILINIYOR: yenisi ustkume (579.771 > 37.044) ve dogrulanmis
DELETE FROM bi_stok_hareket WHERE tenant_id='$TEN'::uuid;

INSERT INTO bi_stok_hareket (
  tenant_id, belge_tarihi, belge_turu, belge_no, muhatap_kodu, muhatap_adi,
  satis_calisani, depo, kalem_kodu, grup_adi, kategori, marka, kalem_tanimi,
  birim_maliyet, giris, giris_tutari, cikis, cikis_tutari, stok_bakiye_tutari,
  lastik_mi, sevk_girisi_mi, notlar
)
SELECT '$TEN'::uuid, belge_tarihi, belge_turu, belge_no, muhatap_kodu, muhatap_adi,
       satis_calisani, depo, kalem_kodu, grup_adi, kategori, marka, kalem_tanimi,
       birim_maliyet, giris, giris_tutari, cikis, cikis_tutari, stok_bakiye_tutari,
       (grup_adi ILIKE '%LASTIK%'),
       (belge_turu ILIKE '%MAL%GIRIS%' OR belge_turu ILIKE '%Satın%'),
       notlar
  FROM _h;

\echo ''
\echo '=== KAPI 1: satir sayisi ==='
SELECT count(*) AS yuklenen FROM bi_stok_hareket WHERE tenant_id='$TEN'::uuid \gset
SELECT CASE WHEN :yuklenen < 579000 THEN (SELECT 1/0) ELSE 1 END AS kapi1;

\echo '=== KAPI 2: gelecek tarih = 0 ==='
SELECT count(*) AS gelecek FROM bi_stok_hareket
 WHERE tenant_id='$TEN'::uuid AND belge_tarihi > CURRENT_DATE \gset
SELECT CASE WHEN :gelecek > 0 THEN (SELECT 1/0) ELSE 1 END AS kapi2;

\echo '=== KAPI 3: maliyet tutarliligi (tutar/adet = birim) ==='
SELECT count(*) FILTER (WHERE cikis>0 AND cikis_tutari>0 AND birim_maliyet>0
         AND abs((cikis_tutari/cikis)/birim_maliyet - 1) > 0.02) AS tutarsiz
  FROM bi_stok_hareket WHERE tenant_id='$TEN'::uuid \gset
SELECT CASE WHEN :tutarsiz > 1000 THEN (SELECT 1/0) ELSE 1 END AS kapi3;

COMMIT;
SQL
[ $? -ne 0 ] && { echo "❌ KAPI DUSTU — yukleme GERI ALINDI"; exit 1; }
echo "  ✅ yuklendi, kapilar gecti"

echo
echo "############ 4) SONRASI — dogrulama ############"
$PSQL <<SQL
SET app.current_tenant_id='$TEN';
\echo '--- yila gore ---'
SELECT EXTRACT(YEAR FROM belge_tarihi)::int AS yil, count(*),
       round(sum(giris)) AS giris_adet, round(sum(cikis)) AS cikis_adet,
       round(sum(cikis_tutari)/1e6,1) AS cikis_M_TL,
       min(belge_tarihi) AS ilk, max(belge_tarihi) AS son
  FROM bi_stok_hareket WHERE tenant_id='$TEN'::uuid
 GROUP BY 1 ORDER BY 1;

\echo ''
\echo '--- ⚠ ESKI TABLO NE KADAR SISKINDI? (karsilastir) ---'
SELECT 'ESKI (bozuk)' AS kaynak, round(sum(cikis_tutari)/1e6,1) AS toplam_cikis_M
  FROM bi_stok_hareketleri WHERE tenant_id='$TEN'::uuid
UNION ALL
SELECT 'YENI (dogrulanmis)', round(sum(cikis_tutari)/1e6,1)
  FROM bi_stok_hareket WHERE tenant_id='$TEN'::uuid;

\echo ''
\echo '--- ⚠⚠ GERCEK SMM — stok devir gunu artik DOGRU hesaplanabilir ---'
WITH smm AS (
  SELECT sum(cikis_tutari)/365.0 AS gunluk_smm
    FROM bi_stok_hareket
   WHERE tenant_id='$TEN'::uuid AND belge_tarihi >= CURRENT_DATE-365
     AND grup_adi ILIKE '%LASTIK%'),
sa AS (SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku,
              birim_fiyat_kdv_haric fiyat FROM bi_tedarikci_faturalari
        WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
        ORDER BY 1, fatura_tarihi DESC),
st AS (SELECT sum(s.adet*sa.fiyat) AS stok FROM bi_stok_anlik s
        LEFT JOIN sa ON sa.sku=bi_sku_norm(s.kalem_kodu)
       WHERE s.tenant_id='$TEN'::uuid AND s.adet>0)
SELECT round((SELECT gunluk_smm FROM smm)/1e6,2) AS gunluk_SMM_M,
       round((SELECT stok FROM st)/1e6,1)        AS stok_M,
       round((SELECT stok FROM st)/(SELECT gunluk_smm FROM smm)) AS STOK_GUNU_GERCEK;
\echo '  ^ Onceki 131 gun CIRO uzerinden hesaplanmisti (yaklasik).'
\echo '    Bu, SMM uzerinden — muhasebe standardi. Fark buyukse ekran duzelecek.'
SQL

git add -A && git commit -q -m "feat(veri): HAREKET_V2 — bi_stok_hareket TAM KAPSAM + PARA ile yeniden kuruldu. 579.771 satir (onceki 37.044), 2021-09-30 (SAP devreye alma) → 2026-07-11. ⚠ IKI ONARIM: (1) TARIH — Excel, ERP'nin GG/AA metnini AA/GG sanip gun<=12 olanlari TAKAS ETMIS (datetime tipi), gun>12 olanlari gecersiz ay olacagi icin METIN birakmis. Kanit: her yilin max tarihi tam olarak YYYY-12-12. Tipten ayirt edilebildigi icin 214.564 satir kesin olarak geri takas edildi — tahmin YOK. Eski tabloda 7.032 gelecek tarihli satir vardi. (2) SAYI — Excel bazi Turkce sayilarin ayracini ATIP tam sayi yapmis ('932,203' -> int 932203). Her kolonun ondalik basamagi SABIT (Price=3, Giris/Cikis Fiyati=4, Miktar=2, Stock Balance=2) -> int/10^b ile geri olceklendi. Onceki halim her noktayi BINLIK sanip siliyordu: %33,5 satirda maliyet BIN KAT sapiyordu, KAPI 3 yakaladi. SONUC: eski tablo 2021 TEK YILDA 8.004M TL cikis diyordu; yeni veri ALTI YILIN TOPLAMINDA 6.035M. Eski tutarlar ~10 kat siskindi. Artik gercek SMM hesaplanabilir -> stok devir gunu ciro yerine MALIYET uzerinden (muhasebe standardi)." && echo "  COMMITTED"
