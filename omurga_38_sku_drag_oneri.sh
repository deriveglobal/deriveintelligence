#!/usr/bin/env bash
# OMURGA 38 — SKU DRAG + ÖNERİ + PİYASA: seni aşağı çeken SKU'lar, aritmetik kanıt, fiyat önerisi, piyasa çapraz.
# bi_marj_atom'dan okur (önce omurga_37 çalışmalı). OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
MARKA="${1:-CONTINENTAL}"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. $MARKA marka marjı (atomdan, son 6 ay) — referans"
$PSQL -c "SELECT round(sum(ciro)/1e6,1) ciro_m, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marka_marj_pct FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)=upper('$MARKA') AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month';" 2>&1 | sed 's/^/  /'

hr "1. SENİ AŞAĞI ÇEKEN SKU'lar — aritmetik kanıt (marka ort'a göre kayıp brüt kâr)"
$PSQL -c "
WITH b AS (SELECT sum(brut_kar)::numeric/NULLIF(sum(ciro),0) mm FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)=upper('$MARKA') AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month'),
sku AS (SELECT kalem_kodu, max(ebat) ebat, sum(ciro) ciro, sum(adet) adet,
          round(sum(ciro)/NULLIF(sum(adet),0)) fiyat, round(sum(ciro-brut_kar)/NULLIF(sum(adet),0)) maliyet,
          round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj_pct, round(sum(brut_kar)) brut
        FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)=upper('$MARKA') AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY kalem_kodu)
SELECT ebat, adet, fiyat, maliyet, marj_pct,
       round(brut/1e3) brut_bin,
       round(((SELECT mm FROM b)*ciro - brut)/1e3) marka_ort_olsaydi_ek_kar_bin
  FROM sku WHERE ciro>500000
 ORDER BY ((SELECT mm FROM b)*ciro - brut) DESC LIMIT 8;" 2>&1 | sed 's/^/  /'
echo "  → 'marka_ort_olsaydi_ek_kar': bu SKU marka ortalaması marja çıksa kazanılacak brüt (bin TL). Büyük = en çok çeken."

hr "2. PİYASA ÇAPRAZ — bu ebatlarda $MARKA piyasa fiyatı (rakip_fiyat_gecmis) vs bizim fiyat"
$PSQL -c "
WITH sku AS (SELECT max(ebat) ebat, round(sum(ciro)/NULLIF(sum(adet),0)) bizim_fiyat, round(sum(ciro-brut_kar)/NULLIF(sum(adet),0)) maliyet, sum(ciro) ciro
        FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)=upper('$MARKA') AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY kalem_kodu HAVING sum(ciro)>500000)
SELECT s.ebat, s.bizim_fiyat, s.maliyet,
       (SELECT round(avg(fiyat)) FROM bi_rakip_fiyat_gecmis r
         WHERE r.tenant_id='$T' AND r.marka ILIKE '%'||upper('$MARKA')||'%'
           AND r.genislik = NULLIF(split_part(s.ebat,'/',1),'')::int
           AND r.profil   = NULLIF(split_part(split_part(s.ebat,'/',2),'R',1),'')::int
           AND r.cap      = NULLIF(split_part(s.ebat,'R',2),'')::numeric
           AND r.gecerli_tarih >= CURRENT_DATE-interval '60 day') piyasa_perakende_ort
  FROM sku s ORDER BY s.ciro DESC LIMIT 10;" 2>&1 | sed 's/^/  /'
echo "  ⚠ piyasa = PERAKENDE (tüketici); bizim = BAYİ (toptan) → piyasa doğal olarak yüksek. Yön sinyali, birebir değil."

hr "3. ÖNERİ — hedef %15 marj için gereken fiyat vs bizim vs piyasa (zam alanı var mı)"
$PSQL -c "
WITH sku AS (SELECT max(ebat) ebat, round(sum(ciro)/NULLIF(sum(adet),0)) bizim_fiyat, sum(ciro-brut_kar)/NULLIF(sum(adet),0) maliyet, round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj, sum(ciro) ciro
        FROM bi_marj_atom WHERE tenant_id='$T'::uuid AND upper(marka)=upper('$MARKA') AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY kalem_kodu HAVING sum(ciro)>500000 AND (100*sum(brut_kar)/NULLIF(sum(ciro),0))<10)
SELECT ebat, bizim_fiyat, marj mevcut_marj, round(maliyet/0.85) hedef_fiyat_15marj, round(100*(maliyet/0.85 - bizim_fiyat)/NULLIF(bizim_fiyat,0)) gereken_zam_pct
  FROM sku ORDER BY ciro DESC LIMIT 10;" 2>&1 | sed 's/^/  /'
echo "  → %15 marja çıkmak için gereken zam. Piyasa (§2) bu zamma izin veriyorsa güçlü öneri; vermiyorsa ürünü/tedariği sorgula."

hr "BITTI — hangi SKU çekiyor (kanıt) + fiyat önerisi + piyasa sinyali. Organizma: atom+scraper."
