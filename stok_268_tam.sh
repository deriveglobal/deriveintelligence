#!/usr/bin/env bash
# STOK_268_TAM — 268,5M'nin TANIMINI gormeden hicbir sey duzeltemem.
#
# ⚠ ELIMDE BES FARKLI STOK DEGERI VAR:
#     268,5M   ana sayfa (Fatih'e SOYLEDIGIM)
#     348,1M   canli stok × son hareket maliyeti
#     433,9M   SAP'in kendi stok bakiyesi (stok_bakiye_tutari)
#     510,3M   canli stok × liste fiyati
#   1.468,3M   olu tablo (bozuk)
#
# ⚠ VE DAHA ONCE SAP bakiyesini 282,4M olcup 268,5M ile "%5,1 uyumlu" demistim.
#   Bugun ayni hesap 433,9M veriyor. Ya o zamanki olcumum yanlisti ya bugunku. IKISI DE BENIM.
#
# ⚠ VE MALIYET VERISI CURUK GORUNUYOR:
#   BRIDGESTONE 385/65R22.5: maliyet 30.195 · liste fiyati 30.195  -> BIREBIR AYNI
#   SAILUN 175/65R14        : maliyet  2.833 · liste fiyati  2.833  -> BIREBIR AYNI
#   Bu urunlerde "maliyet" diye tutulan sey, SATIS FIYATININ KOPYASI.
#   (Satis faturasindaki Kalem Maliyeti icin de ayni seyi bulmustuk: %50,4'u kopya.)
#
# Sadece OKUR. 268,5M'nin TANIMINI ariyorum.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ANA SAYFA SORGUSU — TAMAMI (23805-23860) ############"
awk 'NR>=23805 && NR<=23860 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 2) 'sa.fiyat' NEDIR? — kaynagini bul ############"
$PSQL -c "SELECT table_name FROM information_schema.tables
          WHERE table_name LIKE '%fiyat%' ORDER BY table_name;"
echo "  --- bi_fiyat_listesi_kalemler ---"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_fiyat_listesi_kalemler' ORDER BY ordinal_position;"
$PSQL -x -c "SELECT * FROM bi_fiyat_listesi_kalemler LIMIT 1;"

echo
echo "############ 3) ⚠ MALIYET = LISTE FIYATI olan SKU'lar KAC TANE? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet
    FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND birim_maliyet > 0
   ORDER BY kalem_kodu, belge_tarihi DESC
)
SELECT count(*)                                                        AS sku,
       count(*) FILTER (WHERE abs(s.birim_maliyet - a.liste_fiyati) < 1) AS maliyet_EQ_liste,
       count(*) FILTER (WHERE s.birim_maliyet > a.liste_fiyati)          AS maliyet_liste_ustunde,
       count(*) FILTER (WHERE s.birim_maliyet < a.liste_fiyati * 0.95)   AS maliyet_makul
  FROM bi_stok_anlik a
  LEFT JOIN son s ON s.kalem_kodu = a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid AND a.liste_fiyati > 0
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);"
echo "  ⚠ 'maliyet_EQ_liste' buyukse: ERP maliyeti degil, SATIS FIYATINI kopyalamis."
echo "     O SKU'larda marj SIFIR gorunur — ve stok degeri SISKIN cikar."

echo
echo "############ 4) ⚠ TEDARIKCI FATURASI — GERCEK odenen fiyat ############"
echo "  (ERP maliyetine guvenemiyorsak, GERCEKTEN NE ODEDIGIMIZE bakalim)"
$PSQL -c "
WITH gercek AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
         satir_tutar / NULLIF(miktar,0) AS odenen_birim
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$T'::uuid AND miktar > 0 AND satir_tutar > 0
   ORDER BY kalem_kodu, fatura_tarihi DESC
)
SELECT round(sum(a.adet * g.odenen_birim)/1e6, 1) AS stok_degeri_GERCEK_ODENEN_M,
       count(*) FILTER (WHERE g.odenen_birim IS NULL) AS faturasi_olmayan_sku,
       count(*)                                       AS toplam_sku
  FROM bi_stok_anlik a
  LEFT JOIN gercek g ON g.kalem_kodu = a.kalem_kodu
 WHERE a.tenant_id='$T'::uuid
   AND a.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);" 2>&1 | head -6
echo "  ⚠ Bu, KRB'nin o urune GERCEKTEN odedigi para. ERP'nin 'maliyet' dedigi sey degil."
