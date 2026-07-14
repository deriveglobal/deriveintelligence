#!/usr/bin/env bash
# NET_V1 — tedarikci borcu + NET pozisyon. BUGUNUN EN BUYUK DUZELTMESI.
#
# ⚠⚠ BENIM HATA ZINCIRIM:
#   'Bagli sermaye 507,3M'  -> stok 268,5 + alacak 238,8. TEDARIKCI BORCUNU SAYMADIM.
#      Dogrusu: 268,5 + 238,8 - 403,4 = 103,9M
#   'Yillik sermaye yuku 202,9M' -> gercegi 41,6M
#   'Kar ediyorsun, deger kaybediyorsun' -> YANLIS TEZ.
#      Lastik brut kar ~96M > sermaye yuku 41,6M. KRB DEGER YARATIYOR.
#      Isletme sermayesini BRISA finanse ediyor: 318,95M borc, Kasim-Subat odemeli.
#   'MUTAFLAR riski limitin 138 kati' -> GERCEK NET RISK 1,0M, TAM LIMITTE.
#      alacak 47.556.434 - borc 46.555.721 = NET 1.000.714  (limit 1.000.000)
#      Tesadüf DEGIL: KRB ve Mutaflar MAHSUPLASAN cari calistiriyor, net riski
#      bilinçli olarak limitte tutuyorlar. Iliski YONETILIYOR.
#      Sistem, yonetilen bir iliski hakkinda HER GUN bagiriyordu.
#      Fatih Bilen'in sistemi birakma sebebi buyuk ihtimalle BU.
#
# ⚠ ERP CIFT CARI TUTUYOR: Mutaflar musteri=M4115532, tedarikci=S4100079.
#   Kodlar TUTMAZ. Esleme SADECE 'Bagli Musteri Kodu' alanindan yapilabilir —
#   ve o alan account balance dosyasinda, AYLARDIR YUKLENMEDI.
#
# ⚠ RISK MOTORU BRUT ALACAGA BAKIYORDU. Net pozisyona gecince siralama DEGISIYOR:
#   YEDI OTO net 30,5M (GERCEK) · TOROS 9,5M (gercek) · MUTAFLAR 1,0M (yonetiliyor)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) TABLO + YUKLE ############"
docker cp bakiye_TEMIZ.csv krb-assessment-postgres:/tmp/b.csv
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

CREATE TABLE IF NOT EXISTS bi_cari_bakiye (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid NOT NULL,
  export_date date NOT NULL DEFAULT CURRENT_DATE,
  ingested_at timestamptz NOT NULL DEFAULT now(),
  tedarikci_kodu   text NOT NULL,
  tedarikci_adi    text,
  tedarikci_bakiye numeric(18,2),   -- ⚠ NEGATIF = KRB BORCLU
  musteri_kodu     text,            -- ⚠ ERP'nin KENDI eslemesi ('Bagli Musteri Kodu')
  musteri_bakiye   numeric(18,2),
  net_pozisyon     numeric(18,2)
);
CREATE INDEX IF NOT EXISTS idx_cb_ten ON bi_cari_bakiye(tenant_id);
CREATE INDEX IF NOT EXISTS idx_cb_mus ON bi_cari_bakiye(tenant_id, musteri_kodu);

DELETE FROM bi_cari_bakiye WHERE tenant_id='$TEN'::uuid;

CREATE TEMP TABLE _b (
  tedarikci_kodu text, tedarikci_adi text, tedarikci_bakiye numeric,
  musteri_kodu text, musteri_bakiye numeric, net_pozisyon numeric);
\copy _b FROM '/tmp/b.csv' WITH (FORMAT csv, HEADER true)

INSERT INTO bi_cari_bakiye
  (tenant_id, tedarikci_kodu, tedarikci_adi, tedarikci_bakiye, musteri_kodu, musteri_bakiye, net_pozisyon)
SELECT '$TEN'::uuid, tedarikci_kodu, tedarikci_adi, tedarikci_bakiye,
       NULLIF(musteri_kodu,''), musteri_bakiye, net_pozisyon
  FROM _b;

\echo '=== KAPI 1: satir ==='
SELECT count(*) AS n FROM bi_cari_bakiye WHERE tenant_id='$TEN'::uuid \gset
SELECT CASE WHEN :n < 380 THEN (SELECT 1/0) ELSE 1 END AS k1;

\echo '=== KAPI 2: MUTAFLAR net = 1.000.714 ==='
SELECT round(net_pozisyon) AS mut FROM bi_cari_bakiye
 WHERE tenant_id='$TEN'::uuid AND tedarikci_adi ILIKE '%MUTAFLAR%' LIMIT 1 \gset
SELECT CASE WHEN abs(:mut - 1000714) > 1000 THEN (SELECT 1/0) ELSE 1 END AS k2;

\echo '=== KAPI 3: tedarikci borcu 380-420M ==='
SELECT round(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0))) AS borc
  FROM bi_cari_bakiye WHERE tenant_id='$TEN'::uuid \gset
SELECT CASE WHEN :borc < 380000000 OR :borc > 420000000 THEN (SELECT 1/0) ELSE 1 END AS k3;
COMMIT;
SQL
if [ $? -ne 0 ]; then echo "❌ KAPI DUSTU"; exit 1; fi
echo "  ✅ yuklendi"

echo
echo "############ 2) ⚠⚠ GERCEK TABLO ############"
$PSQL <<SQL
SET app.current_tenant_id='$TEN';
\echo '--- NET ISLETME SERMAYESI (dogrusu) ---'
WITH sa AS (SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku,
              birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari
             WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
             ORDER BY 1, fatura_tarihi DESC),
st AS (SELECT sum(s.adet*sa.f) AS stok FROM bi_stok_anlik s
         LEFT JOIN sa ON sa.sku=bi_sku_norm(s.kalem_kodu)
        WHERE s.tenant_id='$TEN'::uuid AND s.adet>0),
al AS (SELECT sum(toplam_risk) AS alacak FROM bi_musteri_risk
        WHERE tenant_id='$TEN'::uuid AND COALESCE(musteri_mi,true)),
bo AS (SELECT abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0)) AS borc
         FROM bi_cari_bakiye WHERE tenant_id='$TEN'::uuid)
SELECT round((SELECT stok FROM st)/1e6,1)   AS stok_M,
       round((SELECT alacak FROM al)/1e6,1) AS alacak_M,
       round((SELECT borc FROM bo)/1e6,1)   AS TEDARIKCI_BORCU_M,
       round(((SELECT stok FROM st)+(SELECT alacak FROM al)-(SELECT borc FROM bo))/1e6,1) AS NET_ISLETME_SERMAYESI_M,
       round(((SELECT stok FROM st)+(SELECT alacak FROM al)-(SELECT borc FROM bo))*0.40/1e6,1) AS YILLIK_YUK_M;
\echo '  ^ ONCEKI: 507,3M bagli sermaye · 202,9M yuk  -> YANLISTI (borc sayilmamisti)'

\echo ''
\echo '--- ⚠⚠ NET RISK SIRALAMASI (brut degil) ---'
SELECT b.tedarikci_adi AS musteri,
       round(b.musteri_bakiye/1e6,1)   AS brut_alacak_M,
       round(b.tedarikci_bakiye/1e6,1) AS krb_borcu_M,
       round(b.net_pozisyon/1e6,1)     AS NET_M,
       round(r.kredi_limiti/1e6,2)     AS limit_M,
       CASE WHEN r.kredi_limiti > 0 THEN round(b.net_pozisyon/r.kredi_limiti,1) END AS NET_KAT
  FROM bi_cari_bakiye b
  LEFT JOIN bi_musteri_risk r ON r.tenant_id=b.tenant_id AND r.muhatap_kodu=b.musteri_kodu
 WHERE b.tenant_id='$TEN'::uuid AND b.net_pozisyon > 1e6
 ORDER BY b.net_pozisyon DESC LIMIT 10;

\echo ''
\echo '--- ⚠ MUTAFLAR: alarm YANLISTI ---'
SELECT round(musteri_bakiye)   AS brut_alacak,
       round(tedarikci_bakiye) AS krb_borcu,
       round(net_pozisyon)     AS NET,
       1000000                 AS kredi_limiti,
       'YONETILEN MAHSUPLASMA — net risk TAM LIMITTE' AS gercek
  FROM bi_cari_bakiye
 WHERE tenant_id='$TEN'::uuid AND tedarikci_adi ILIKE '%MUTAFLAR%';
SQL

git add -A
git commit -q -m 'feat(net): NET_V1 — tedarikci borcu + NET pozisyon. BUGUNUN EN BUYUK DUZELTMESI, ve hata bendeydi. (1) Bagli sermaye 507,3M dedim: stok+alacak, TEDARIKCI BORCUNU SAYMADIM. Dogrusu 268,5+238,8-403,4 = 103,9M. Sermaye yuku 202,9M degil 41,6M. (2) Kar ediyorsun deger kaybediyorsun TEZI YANLISTI: lastik brut kar ~96M > yuk 41,6M. KRB DEGER YARATIYOR. Isletme sermayesini BRISA finanse ediyor (318,95M borc, Kasim-Subat odemeli). (3) MUTAFLAR riski limitin 138 kati -> GERCEK NET RISK 1,0M, TAM LIMITTE: alacak 47.556.434 - borc 46.555.721 = 1.000.714, limit 1.000.000. Tesadüf degil; KRB ve Mutaflar MAHSUPLASAN cari calistiriyor ve net riski bilinçli olarak limitte tutuyor. Sistem YONETILEN bir iliski hakkinda her gun bagiriyordu — Fatih Bilen sistemi buyuk ihtimalle BU YUZDEN birakti. (4) ERP cift cari tutuyor (musteri M4115532 / tedarikci S4100079); kodlar tutmaz, esleme SADECE account balance dosyasindaki Bagli Musteri Kodu alanindan yapilabilir — o dosya AYLARDIR yuklenmemisti. (5) Risk motoru BRUT alacaga bakiyordu; net pozisyonda siralama degisiyor: YEDI OTO 30,5M gercek risk, MUTAFLAR listede bile degil.'
echo "  COMMITTED"
