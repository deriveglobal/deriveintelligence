#!/usr/bin/env bash
# SINYAL_V2 — PUANLAMA DUZELTMESI. Kendi formulum kendi tuzagima dustu.
#
# ⚠ V1'IN CIKTISI YANLISLIGI ELE VERDI:
#     Olu stok (24,9M, tarihsiz)          -> 66,6  ❌ BIRINCI
#     Mutaflar (90,4M, limitin 138 kati)  -> 59,2  ❌ IKINCI
#   90 milyonluk kredi riski, rafta bekleyen 25 milyondan SONRA geliyordu.
#
# HATA 1 — ACILIYET SERT KESIM:
#   1 - gun/90  yazmisim. Mutaflar'in son tarihi 128 gun uzakta -> NEGATIF -> SIFIR.
#   Tarihsiz olan ise 0,30 taban aliyor.
#   Yani UZAK BIR SON TARIH, HIC SON TARIH OLMAMASINDAN KOTU puan aliyordu. ABSURD.
#   ✅ SONUM EGRISI: 1/(1 + gun/30)
#      bugun 1,00 · 30 gun 0,50 · 90 gun 0,25 · 180 gun 0,14 · tarih gecti 0
#
# HATA 2 — LOG OLCEGI PARAYI EZIYOR:
#   log(90,4M)/log(1e9) = 0,884 · log(24,9M)/log(1e9) = 0,822
#   Aralarinda sadece %6 fark — oysa biri digerinin 3,6 KATI.
#   Log, 1M-200M araliginda cok DUZ.
#   ✅ DOGRUSAL, 100M'de TAVAN: 90,4M -> 0,90 · 24,9M -> 0,25
#
# ⚠ VE BU FORMUL DE BIR VARSAYIMDIR. Ekranda puanin NASIL hesaplandigi
#   gorunecek — Fatih Bilen siralamaya ITIRAZ EDEBILMELI.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ESKI PUANLAMA — yanlisligi goster ############"
$PSQL -c "
SELECT left(baslik,44) AS baslik,
       round(tutar_tl/1e6,1) AS tutar_M,
       CASE WHEN son_tarih IS NULL THEN NULL ELSE (son_tarih-CURRENT_DATE) END AS gun,
       bi_sinyal_puan(tutar_tl, son_tarih, eylem_var) AS ESKI_PUAN
  FROM bi_sinyal WHERE tenant_id='$TEN' AND durum='acik'
 ORDER BY 4 DESC LIMIT 5;"
echo "  ^ Olu stok (tarihsiz) MUTAFLAR'IN (90,4M) ONUNDE. YANLIS."

echo
echo "############ 2) YENI PUANLAMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE OR REPLACE FUNCTION bi_sinyal_puan(
  p_tutar numeric, p_son_tarih date, p_eylem boolean
) RETURNS numeric LANGUAGE sql IMMUTABLE AS $$
  SELECT ROUND((
      -- ⚠ PARA: DOGRUSAL, 100M'de tavan. Log olcegi 1M-200M araliginda
      --   cok duz -> 90M ile 25M arasinda %6 fark gosteriyordu. YANLIS.
      0.50 * LEAST(1.0, COALESCE(p_tutar,0) / 100e6)

      -- ⚠ ACILIYET: SONUM EGRISI. Sert kesim (1-gun/90) uzak tarihleri
      --   SIFIRLIYORDU -> tarihsiz olandan bile kotu puan aliyorlardi.
      --   1/(1+gun/30): bugun 1,00 · 30g 0,50 · 90g 0,25 · 180g 0,14
    + 0.35 * CASE
        WHEN p_son_tarih IS NULL          THEN 0.20   -- surekli sorun, acil degil
        WHEN p_son_tarih < CURRENT_DATE   THEN 0.0    -- gecti -> DUSER
        ELSE 1.0 / (1.0 + (p_son_tarih - CURRENT_DATE)::numeric / 30.0)
      END

      -- EYLEM: bugun bir sey yapilabiliyor mu?
    + 0.15 * CASE WHEN p_eylem THEN 1.0 ELSE 0.4 END
  ) * 100, 1)
$$;

-- ⚠ SEFFAFLIK: puanin BILESENLERI de donsun — ekranda gorunecek.
CREATE OR REPLACE FUNCTION bi_sinyal_puan_detay(
  p_tutar numeric, p_son_tarih date, p_eylem boolean
) RETURNS jsonb LANGUAGE sql IMMUTABLE AS $$
  SELECT jsonb_build_object(
    'para',     round(LEAST(1.0, COALESCE(p_tutar,0)/100e6)::numeric, 2),
    'aciliyet', round((CASE
        WHEN p_son_tarih IS NULL        THEN 0.20
        WHEN p_son_tarih < CURRENT_DATE THEN 0.0
        ELSE 1.0/(1.0+(p_son_tarih-CURRENT_DATE)::numeric/30.0) END)::numeric, 2),
    'eylem',    CASE WHEN p_eylem THEN 1.0 ELSE 0.4 END,
    'gun_kaldi', CASE WHEN p_son_tarih IS NULL THEN NULL
                      ELSE (p_son_tarih - CURRENT_DATE) END,
    'formul',   'puan = 0,50×para + 0,35×aciliyet + 0,15×eylem'
  )
$$;
SQL
echo "  ✅ puanlama + seffaflik fonksiyonu"

echo
echo "############ 3) ⚠⚠ YENI SIRALAMA — ana sayfada ne gorunecek? ############"
$PSQL -c "
SELECT bi_sinyal_puan(tutar_tl, son_tarih, eylem_var) AS puan,
       left(baslik, 46) AS baslik,
       round(tutar_tl/1e6,1) AS tutar_M,
       CASE WHEN son_tarih IS NULL THEN '—'
            ELSE (son_tarih-CURRENT_DATE)||'g' END AS kalan,
       (bi_sinyal_puan_detay(tutar_tl,son_tarih,eylem_var)->>'para')   AS p_para,
       (bi_sinyal_puan_detay(tutar_tl,son_tarih,eylem_var)->>'aciliyet') AS p_acil,
       oda
  FROM bi_sinyal WHERE tenant_id='$TEN' AND durum='acik'
 ORDER BY 1 DESC LIMIT 10;"
echo
echo "  >>> ILK 3 ANA SAYFADA. Puanin BILESENLERI de gorunuyor —"
echo "      Fatih Bilen siralamaya ITIRAZ EDEBILIR. Formul saklanmiyor."

echo
echo "############ 4) ⚠ SEVK SINYALLERI COK — grupla ############"
echo "   20 ayri 'sevk_gecikme' sinyali var. Ana sayfada 1 satir olmali."
$PSQL -c "
SELECT count(*) AS sinyal,
       round(sum(tutar_tl)/1e6,1) AS toplam_MTL,
       count(*) FILTER (WHERE detay->>'gelen' = '0') AS hic_gelmeyen,
       min(son_tarih) AS en_yakin_tarih
  FROM bi_sinyal
 WHERE tenant_id='$TEN' AND durum='acik' AND tur='sevk_gecikme';"
echo "  ^ Ana sayfada: 'Sevkiyat 20 ebatta geride — 66,3M bekliyor · 4'u hic gelmedi'"
echo "    Detay Sezon odasinda. Ana sayfa OZET, oda DETAY."

git add -A && git commit -q -m "fix(sinyal): SINYAL_V2 — puanlama duzeltildi. V1'de olu stok (24,9M, tarihsiz) Mutaflar'in (90,4M, limitin 138 kati) ONUNDEYDI. Iki hata: (1) aciliyet sert kesim (1-gun/90) uzak tarihleri SIFIRLIYORDU -> tarihsizden bile kotu puan; sonum egrisi 1/(1+gun/30) ile degistirildi. (2) log olcegi 1M-200M araliginda cok duz (90M ile 25M arasi %6 fark); dogrusal 100M-tavanli oldu. Ayrica puan bilesenleri jsonb ile dondurulüyor — ekranda gorunecek, kullanici itiraz edebilecek." && echo "  COMMITTED"
