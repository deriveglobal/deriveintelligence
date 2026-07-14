#!/usr/bin/env bash
# FINANS_TANIM_KILIDI — odayi kurmadan once TANIMLARI kilitle.
#
# ⚠ KENDI DUZELTMEMI DUZELTIYORUM:
#   Bugun "alacak 238,8M YANLIS, gercek 209,3M" dedim. Bu HAKSIZDI.
#   bi_musteri_risk'te IKI farkli kolon var:
#     hesap_bakiyesi = 209,3M  -> fiilen FATURALANMIS, tahsil edilecek para
#     toplam_risk    = 238,8M? -> buna EK olarak odenmemis cek/senet + bekleyen siparis
#   Ikisi de DOGRU sayi, FARKLI sorularin cevabi.
#     Isletme sermayesi     -> hesap_bakiyesi (bekleyen siparis henuz PARA DEGIL)
#     Musteri risk yonetimi -> toplam_risk    (o musteriye toplam maruziyet)
#   Ana sayfadaki 238,8M "uydurma" degildi; YANLIS YERDE KULLANILAN DOGRU BIR SAYIYDI.
#
# ⚠ Bir odayi yanlis tanimli sayilar ustune kurmak, bugunku isi TEKRAR ETTIRIR.
# Sadece OLCER + KOKEN kaydeder.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ⚠ ALACAK — uc kolon, uc anlam ############"
$PSQL -c "
SELECT round(sum(hesap_bakiyesi)/1e6, 1)   AS hesap_bakiyesi_M,
       round(sum(toplam_risk)/1e6, 1)      AS toplam_risk_M,
       round(sum(cek_senet_riski)/1e6, 1)  AS cek_senet_M,
       round(sum(bekleyen_siparis)/1e6, 1) AS bekleyen_siparis_M,
       round(sum(vadesi_gecmis)/1e6, 1)    AS vadesi_gecmis_M,
       round(sum(odenmemis_cekler)/1e6, 1) AS odenmemis_cek_M,
       round(sum(odenmemis_senetler)/1e6,1) AS odenmemis_senet_M
  FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi;"
echo "  ⚠ toplam_risk = hesap_bakiyesi + cek/senet + bekleyen siparis MI? Kontrol:"
$PSQL -c "
SELECT count(*) AS musteri,
       count(*) FILTER (WHERE abs(toplam_risk - (hesap_bakiyesi + cek_senet_riski + bekleyen_siparis)) < 1) AS formul_tutuyor,
       count(*) FILTER (WHERE abs(toplam_risk - hesap_bakiyesi) < 1) AS toplam_risk_EQ_bakiye
  FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND musteri_mi AND toplam_risk <> 0;"

echo
echo "############ 2) ⚠ ISLETME SERMAYESI — dogru tanimla ############"
$PSQL -c "
WITH s AS (SELECT round(268.3, 1) AS stok_M),
a AS (SELECT round(sum(hesap_bakiyesi)/1e6, 1) AS alacak_M FROM bi_musteri_risk
       WHERE tenant_id='$T'::uuid AND musteri_mi),
b AS (SELECT round(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0))/1e6, 1) AS borc_M
        FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid)
SELECT s.stok_M, a.alacak_M, b.borc_M,
       (s.stok_M + a.alacak_M - b.borc_M)        AS net_isletme_sermayesi_M,
       round((s.stok_M + a.alacak_M - b.borc_M) * 0.40, 1) AS yillik_sermaye_yuku_M
  FROM s, a, b;"
echo "  ⚠ Fatih'e once 103,9M dedim (alacak 238,8 ile). Dogru tanimla ne cikiyor?"

echo
echo "############ 3) ⚠ BRISA TAKVIMI — kasimda ne odenecek? ############"
$PSQL -c "
SELECT left(tedarikci_adi, 34) AS tedarikci,
       round(abs(tedarikci_bakiye)/1e6, 1) AS borc_M
  FROM bi_cari_bakiye
 WHERE tenant_id='$T'::uuid AND tedarikci_bakiye < -1e6
 ORDER BY tedarikci_bakiye LIMIT 6;"
$PSQL -c "
SELECT to_char(son_tarih,'DD Mon YYYY') AS odeme_tarihi,
       baslik, round(tutar_tl/1e6, 1) AS tutar_M
  FROM bi_sinyal
 WHERE tenant_id='$T'::uuid AND tur='odeme'
 ORDER BY son_tarih;"

echo
echo "############ 4) ⚠ KREDI LIMITI BOSLUGU ############"
$PSQL -c "
SELECT count(*)                                          AS bakiyeli_musteri,
       count(*) FILTER (WHERE kredi_limiti <= 1)         AS limiti_YOK,
       round(sum(net_pozisyon) FILTER (WHERE kredi_limiti <= 1)/1e6, 1) AS limitsiz_alacak_M,
       round(sum(vadesi_gecmis) FILTER (WHERE kredi_limiti <= 1)/1e6, 1) AS limitsiz_GECIKMIS_M
  FROM master_musteri
 WHERE son_bakiye IS NOT NULL AND net_pozisyon > 0;"

echo
echo "############ 5) KOKEN — Finans sayilarini kaydet ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
INSERT INTO bi_sayi_koken (anahtar, kaynak, formul, varsayim, sinir, guven) VALUES
('alacak_bakiye',
 'bi_musteri_risk.hesap_bakiyesi (accountriskreport, 12 Tem, 38.403 müşteri)',
 'SUM(hesap_bakiyesi) WHERE musteri_mi',
 'Fiilen faturalanmış, tahsil edilecek tutar. Bekleyen sipariş ve çek/senet HARİÇ.',
 '⚠ İŞLETME SERMAYESİ İÇİN BU KULLANILIR. toplam_risk (238,8M) DEĞİL — o, bekleyen siparişi de sayar ve bekleyen sipariş henüz PARA DEĞİLDİR. Eski bi_musteri_bakiye tablosu 399 müşteri gösteriyordu ve KOLONLARI KAYMIŞTI (bakiye diye vadesi geçmiş tutarı yazıyordu).',
 'yuksek'),
('vadesi_gecmis',
 'bi_musteri_risk.vadesi_gecmis',
 'SUM(vadesi_gecmis) WHERE musteri_mi',
 'Vadesi dolmuş ve hâlâ tahsil edilmemiş tutar.',
 '⚠ Alacağın %69''u. Bu bir oran değil, bir DURUM: 209,3M alacağın 145,4M''si zaten gecikmiş. Brisa ödemeleri Kasım''da başlıyor.',
 'yuksek'),
('limitsiz_alacak',
 'master_musteri (bi_musteri_risk''ten türetilmiş)',
 'SUM(net_pozisyon) WHERE kredi_limiti <= 1',
 'ERP''de kredi limiti tanımlanmamış müşterilerdeki alacak.',
 '⚠ "Limit aşıldı" ile "limit hiç konulmamış" AYNI ŞEY DEĞİL. Birincisi ihlal — müdahale ister. İkincisi boşluk — KARAR ister. ERP''de limit 0 veya 1 TL olarak duruyor.',
 'yuksek')
ON CONFLICT (anahtar) DO UPDATE
  SET kaynak=EXCLUDED.kaynak, formul=EXCLUDED.formul, varsayim=EXCLUDED.varsayim,
      sinir=EXCLUDED.sinir, guven=EXCLUDED.guven;

-- ⚠ net_sermaye kokenini DUZELT: alacak tanimi degisti
UPDATE bi_sayi_koken
   SET sinir = '⚠ 14 Tem''de DÜZELTİLDİ: alacak bacağı toplam_risk (238,8M) yerine hesap_bakiyesi (209,3M) oldu. toplam_risk bekleyen siparişi de sayıyordu ve bekleyen sipariş henüz PARA DEĞİL. Ayrıca 13 Tem''e kadar tedarikçi borcu (403,4M) HİÇ sayılmıyordu.'
 WHERE anahtar = 'net_sermaye';
SQL
echo "  ✅ koken kaydedildi"
$PSQL -c "SELECT anahtar, guven FROM bi_sayi_koken ORDER BY anahtar;"
