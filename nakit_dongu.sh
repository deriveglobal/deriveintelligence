#!/usr/bin/env bash
# Salt okuma. ⚠ ONCEKI RAKAM YANLIS DONEMDI.
#   deploy_tahsilat.sh bolum 6 'CURRENT_DATE - 365' kullaniyordu = SON 12 AY,
#   YTD 2026 DEGIL. Fatih hakli.
#
# ⚠⚠ VE DAHA ONEMLI BIR YANLILIK VAR — SAG KALAN YANLILIGI:
#   Tahsilat dosyasinda ACIK FATURA YOK (0 satir). DSO sadece TAHSIL EDILMIS
#   faturalardan hesaplaniyor. Henuz odenmemis -- ozellikle GEC odeyen --
#   faturalar hesabin DISINDA. Yani DSO OLDUGUNDAN DUSUK.
#   2026 mutabakati %72 idi: bu yilki faturalarin ~%28'i henuz tahsil edilmemis.
#
#   Bu, bugun sistemde 4. kez gordugumuz desen: sayi dogru, KAPSAM yanlis, kimse soylemiyor.
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) DSO — UC DONEM YAN YANA ############"
$PSQL -c "
WITH d AS (
  SELECT 'a) YTD 2026 (01.01.2026 - bugun)' AS donem, fatura_tutari, tahsilat_gun
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL
     AND fatura_tarihi >= DATE '2026-01-01'
  UNION ALL
  SELECT 'b) Son 12 ay (onceki rakam)', fatura_tutari, tahsilat_gun
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL
     AND fatura_tarihi >= CURRENT_DATE - 365
  UNION ALL
  SELECT 'c) Tum zamanlar (2021-2026)', fatura_tutari, tahsilat_gun
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL)
SELECT donem, count(*) AS fatura,
       round(sum(fatura_tutari)/1e6,1) AS tutar_MTL,
       round(sum(fatura_tutari*tahsilat_gun)/NULLIF(sum(fatura_tutari),0),1) AS DSO_gun
  FROM d GROUP BY 1 ORDER BY 1;"

echo
echo "############ 2) DPO — UC DONEM YAN YANA ############"
$PSQL -c "
WITH d AS (
  SELECT 'a) YTD 2026' AS donem, satir_kdv_haric AS t, vade_gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND vade_gun IS NOT NULL AND miktar > 0
     AND fatura_tarihi >= DATE '2026-01-01'
  UNION ALL
  SELECT 'b) Son 12 ay', satir_kdv_haric, vade_gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND vade_gun IS NOT NULL AND miktar > 0
     AND fatura_tarihi >= CURRENT_DATE - 365
  UNION ALL
  SELECT 'c) Tum zamanlar', satir_kdv_haric, vade_gun
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND vade_gun IS NOT NULL AND miktar > 0)
SELECT donem, count(*) AS satir,
       round(sum(t)/1e6,1) AS tutar_MTL,
       round(sum(t*vade_gun)/NULLIF(sum(t),0),1) AS DPO_gun
  FROM d GROUP BY 1 ORDER BY 1;"

echo
echo "############ 3) ⚠⚠ SAG KALAN YANLILIGI — DSO ne kadar IYIMSER? ############"
echo "   2026 faturalarinin kaci HENUZ TAHSIL EDILMEMIS? (DSO'ya hic girmiyor)"
$PSQL -c "
WITH satis AS (
  SELECT round(sum(satir_tutar)/1e6,1) AS satis_MTL
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'),
tahsil AS (
  SELECT count(*) AS fatura, round(sum(fatura_tutari)/1e6,1) AS tahsil_edilen_MTL
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'),
acik AS (
  SELECT round(sum(vadesi_gecmis)/1e6,1) AS vadesi_gecmis_MTL,
         round(sum(toplam_risk)/1e6,1)   AS acik_risk_MTL
    FROM bi_musteri_risk
   WHERE tenant_id='$TEN' AND musteri_mi)
SELECT s.satis_MTL AS satis_2026_KDVharic,
       t.tahsil_edilen_MTL AS tahsilat_dosyasinda_KDVdahil,
       a.acik_risk_MTL AS acik_alacak_bugun,
       a.vadesi_gecmis_MTL AS bunun_vadesi_gecmis
  FROM satis s, tahsil t, acik a;"
echo "  ^ 'acik_alacak_bugun' (238,8M) DSO hesabinda YOK. Bu paranin tahsilat"
echo "    suresi HENUZ BILINMIYOR ve buyuk ihtimalle ORTALAMANIN USTUNDE."
echo "    Yani gercek DSO, asagidaki rakamdan YUKSEK."

echo
echo "############ 4) ⚠ IYIMSERLIGI OLC — 'gecikmis alacak da odenecek' senaryosu ############"
$PSQL -c "
WITH t AS (
  SELECT sum(fatura_tutari) AS tut, sum(fatura_tutari*tahsilat_gun) AS agir
    FROM bi_fatura_tahsilat
   WHERE tenant_id='$TEN' AND tahsilat_gun IS NOT NULL
     AND fatura_tarihi >= DATE '2026-01-01'),
r AS (
  SELECT sum(toplam_risk) AS acik,
         sum(vadesi_gecmis) AS vg
    FROM bi_musteri_risk WHERE tenant_id='$TEN' AND musteri_mi)
SELECT round(t.agir/NULLIF(t.tut,0),1)                                  AS DSO_bugun_gorunen,
       round((t.agir + r.acik*60)/NULLIF(t.tut + r.acik,0),1)           AS DSO_acik_60gunde_odenirse,
       round((t.agir + r.acik*90)/NULLIF(t.tut + r.acik,0),1)           AS DSO_acik_90gunde_odenirse
  FROM t, r;"
echo "  ^ Acik alacak 60-90 gunde tahsil edilirse GERCEK DSO bu olur."
echo "    Bu bir TAHMIN, veri DEGIL — ama yonu dogru: gorunen DSO IYIMSER."

echo
echo "############ 5) ⚠ NAKIT DONGUSUNUN EKSIK PARCASI: STOK GUNU ############"
$PSQL -c "
SELECT 'invmoving24 (stok hareketi)' AS kaynak,
       (SELECT count(*) FROM information_schema.tables
         WHERE table_name = 'bi_stok_hareket') AS tablo_var_mi,
       (SELECT max(export_date)::text FROM bi_stok WHERE tenant_id='$TEN'::uuid) AS son_stok_tarihi;" 2>&1 | head -5
echo "  ⚠ GERCEK NAKIT DONGUSU = STOK GUNU + DSO − DPO"
echo "    Stok gunu YOK (invmoving24 yuklenmedi, stok 12 Haziran'da donuk)."
echo "    Yani '28 gun nakit uretiyoruz' YARIM CUMLE. Stok 60 gun bekliyorsa"
echo "    gercek dongu +32 gun olur ve nakit URETMIYORUZ, TUKETIYORUZ."
echo "    Finans sekmesinde bu parca EKSIK diye GOSTERILECEK, gizlenmeyecek."
