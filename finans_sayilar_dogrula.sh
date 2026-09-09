#!/usr/bin/env bash
# FİNANS EKRAN SAYILARI DOĞRULA — her biri kaynaktan + STOK bazı çelişkisi. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. STOK — ekran (SON ALIŞ) vs kanonik (AĞIRLIKLI ORT) — ⚠ #128"
echo "  --- Ekranın yöntemi: bi_stok_anlik × SON tedarikçi fatura fiyatı ---"
$PSQL -c "
WITH sa AS (SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku, birim_fiyat_kdv_haric fiyat
             FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0 ORDER BY 1, fatura_tarihi DESC)
SELECT round(sum(st.adet*sa.fiyat)/1e6,1) ekran_son_alis_m
  FROM bi_stok_anlik st LEFT JOIN sa ON sa.sku=bi_sku_norm(st.kalem_kodu)
 WHERE st.tenant_id='$T'::uuid AND st.adet>0 AND st.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid);"
echo "  --- Bizim kanonik: ağırlıklı ort alış (bi_stok_hareket giris) ---"
$PSQL -c "
WITH km AS (SELECT kalem_kodu, sum(giris_tutari) gt, sum(giris) g FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu)
SELECT round(sum(a.adet*(km.gt/km.g))/1e6,1) kanonik_agirlikli_m
  FROM bi_stok_anlik a JOIN km ON km.kalem_kodu=a.kalem_kodu WHERE a.tenant_id='$T'::uuid AND a.adet>0;"

hr "2. ALACAK + BORÇ (ekran değerleri kaynaktan)"
$PSQL -c "SELECT round(sum(hesap_bakiyesi)/1e6,1) alacak_m, round(sum(vadesi_gecmis)/1e6,1) gecikmis_m
          FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi;"
$PSQL -c "SELECT round(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0))/1e6,1) borc_m
          FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;"

hr "3. NET İŞLETME SERMAYESİ — iki stok bazıyla"
$PSQL -c "
WITH sa AS (SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku, birim_fiyat_kdv_haric fiyat FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0 ORDER BY 1, fatura_tarihi DESC),
son AS (SELECT sum(st.adet*sa.fiyat) v FROM bi_stok_anlik st LEFT JOIN sa ON sa.sku=bi_sku_norm(st.kalem_kodu) WHERE st.tenant_id='$T'::uuid AND st.adet>0 AND st.export_date=(SELECT max(export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid)),
agr AS (SELECT sum(a.adet*(km.gt/km.g)) v FROM bi_stok_anlik a JOIN (SELECT kalem_kodu, sum(giris_tutari) gt, sum(giris) g FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND giris>0 GROUP BY kalem_kodu) km ON km.kalem_kodu=a.kalem_kodu WHERE a.tenant_id='$T'::uuid AND a.adet>0),
al AS (SELECT sum(hesap_bakiyesi) v FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi),
bo AS (SELECT abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0)) v FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid)
SELECT round(((SELECT v FROM son)+(SELECT v FROM al)-(SELECT v FROM bo))/1e6,1) net_EKRAN_sonalis_m,
       round(((SELECT v FROM agr)+(SELECT v FROM al)-(SELECT v FROM bo))/1e6,1) net_KANONIK_agirlikli_m;"
echo "  ⚠ Ekran son-alış bazıyla ~74M; kanonik ağırlıklı bazla ~41M. Fark = STOK maliyet bazı (#128)."

hr "4. NAKİT ÇIKIŞI + SERMAYE YÜKÜ — elle mi, varsayım mı"
$PSQL -c "SELECT baslik, tutar_tl, son_tarih::text FROM bi_sinyal WHERE tenant_id='$T'::uuid AND tur='odeme' AND durum='acik' ORDER BY son_tarih LIMIT 3;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT max(sermaye_maliyeti_pct) sermaye_pct_VARSAYIM FROM bi_ayar WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ Nakit çıkışı bi_sinyal'den (Brisa takvimi ELLE girildi). Sermaye %'si bir VARSAYIM (ayardan)."

hr "BITTI — hangi sayı kesin, hangisi baz/varsayım farkı görülecek."
