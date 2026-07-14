#!/usr/bin/env bash
# NET_POZISYON — Fatih hakli: BEN YINE BRUT GOSTERDIM.
#
# ⚠ MUTAFLAR: 47,5M alacak. Ama KRB de ona neredeyse AYNI TUTARDA BORCLU.
#   Net ~1,0M, limiti 1,0M. Yonetilen bir netlestirme — kriz degil.
#   Sistemin 1 numarali alarmi bunu "limitin 138 kati" diye bagiriyordu.
#   Ve ben "en buyuk alacaklar" listesini BRUTTEN verdim. Ayni hatayi bir tur sonra tekrarladim.
#
# ⚠ AYRIM (ikisi de dogru, YERI farkli):
#   TOPLAM 209,3M  -> BRUT alacak. Net isletme sermayesinde DOGRU OLAN BU,
#                     cunku tedarikci borcunu (403,4M) zaten AYRI kalem olarak cikariyorum.
#                     Iki kere netlestirmek yanlis olur.
#   MUSTERI BAZINDA -> BRUT gostermek YANLIS. Sahayi yanlis yere kosturur.
#
# Sadece OLCUYOR. Yazma yok.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) bi_cari_bakiye — ERP'nin KENDI netlestirmesi ############"
$PSQL -c "
SELECT count(*)                                                   AS satir,
       count(*) FILTER (WHERE musteri_kodu IS NOT NULL)           AS musteriyle_eslesen,
       count(*) FILTER (WHERE tedarikci_bakiye <> 0 AND musteri_bakiye <> 0) AS iki_tarafli,
       round(sum(tedarikci_bakiye)/1e6, 1)                        AS tedarikci_borcu_M,
       round(sum(musteri_bakiye)/1e6, 1)                          AS musteri_bakiyesi_M,
       round(sum(net_pozisyon)/1e6, 1)                            AS net_M,
       max(export_date)                                           AS tarih
  FROM bi_cari_bakiye;"
echo "  ⚠ 'iki_tarafli' = hem alacagimiz hem borcumuz olan cariler. NETLESTIRME BUNLARDA sart."

echo
echo "############ 2) ⚠ MUTAFLAR — uc kaynak yan yana ############"
$PSQL -x -c "
SELECT 'bi_musteri_risk (BRUT)'  AS kaynak,
       r.muhatap_adi             AS ad,
       round(r.hesap_bakiyesi)   AS alacak,
       round(r.vadesi_gecmis)    AS vadesi_gecmis,
       round(r.kredi_limiti)     AS limit,
       NULL::numeric             AS bizim_borcumuz,
       NULL::numeric             AS net
  FROM bi_musteri_risk r
 WHERE r.musteri_mi AND r.muhatap_adi ILIKE '%MUTAFLAR%'
UNION ALL
SELECT 'bi_cari_bakiye (NET)',
       c.tedarikci_adi,
       round(c.musteri_bakiye),
       NULL, NULL,
       round(c.tedarikci_bakiye),
       round(c.net_pozisyon)
  FROM bi_cari_bakiye c
 WHERE c.tedarikci_adi ILIKE '%MUTAFLAR%';"

echo
echo "############ 3) ⚠⚠ EN BUYUK ALACAKLAR — BRUT vs NET (dogrusu bu) ############"
$PSQL -c "
SELECT left(r.muhatap_adi, 30)                     AS musteri,
       round(r.hesap_bakiyesi/1e3)                 AS brut_bin,
       round(COALESCE(c.tedarikci_bakiye,0)/1e3)   AS bizim_borcumuz_bin,
       round((r.hesap_bakiyesi - COALESCE(c.tedarikci_bakiye,0))/1e3) AS NET_bin,
       round(r.kredi_limiti/1e3)                   AS limit_bin,
       CASE WHEN r.kredi_limiti > 0
            THEN round((r.hesap_bakiyesi - COALESCE(c.tedarikci_bakiye,0)) / r.kredi_limiti, 1)
       END                                         AS net_limit_kati
  FROM bi_musteri_risk r
  LEFT JOIN bi_cari_bakiye c ON c.musteri_kodu = r.muhatap_kodu
 WHERE r.musteri_mi AND r.hesap_bakiyesi > 0
 ORDER BY r.hesap_bakiyesi DESC
 LIMIT 12;"
echo "  ⚠ 'brut_bin' ile 'NET_bin' ayrisiyorsa: o musteriye BRUT bakmak YANILTICI."

echo
echo "############ 4) NETLESTIRME KAC MUSTERIYI ETKILIYOR? ############"
$PSQL -c "
SELECT count(*)                                                          AS alacakli_musteri,
       count(*) FILTER (WHERE COALESCE(c.tedarikci_bakiye,0) > 0)        AS ayni_zamanda_tedarikci,
       round(sum(r.hesap_bakiyesi)/1e6, 1)                               AS brut_M,
       round(sum(r.hesap_bakiyesi - COALESCE(c.tedarikci_bakiye,0))/1e6, 1) AS net_M
  FROM bi_musteri_risk r
  LEFT JOIN bi_cari_bakiye c ON c.musteri_kodu = r.muhatap_kodu
 WHERE r.musteri_mi AND r.hesap_bakiyesi > 0;"
echo
echo "  ⚠ Eger 'ayni_zamanda_tedarikci' KUCUKSE (ör. 5-10 cari), netlestirme"
echo "     sadece BIRKAC musteride onemli — ama tam da EN BUYUKLERINDE."
echo "     Ekranda BRUT ve NET yan yana durmali; birini digerinin yerine koymak yanlis."
