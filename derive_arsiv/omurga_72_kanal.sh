#!/usr/bin/env bash
# DEPLOY omurga_72 — §6.5 boyut (C): ciro_lastik x KANAL omurgaya. DB-only, rebuild YOK.
# Kanal = musteri sinifi (bi_musteri_risk.grup, muhatap_kodu join) -> kanal_normalize.
# Not: kanal=bugunku musteri sinifi, tarihsel satisa uygulanir (yaklasik gecmis). Tire filtre: grup_adi LIKE 'LASTIK%'.
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform"
PSQLI="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. BAZ — ciro_lastik su an hangi boyutlarda"
$PSQL -c "SELECT boyut_tipi, count(*) FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='ciro_lastik' GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "1. DEPLOY — kanal_normalize fn + backfill(ciro_lastik x kanal, aylik) + footprint, tek transaction"
$PSQLI <<'SQL'
BEGIN;

CREATE OR REPLACE FUNCTION public.kanal_normalize(p text) RETURNS text LANGUAGE sql IMMUTABLE AS $fn$
  SELECT CASE
    WHEN g LIKE 'TOPTAN%'                       THEN 'TOPTAN'
    WHEN g LIKE '%PERAKENDE%'                   THEN 'PERAKENDE'
    WHEN g LIKE 'E-TICARET%' OR g LIKE 'E-TİCARET%' THEN 'E-TİCARET'
    WHEN g LIKE 'TEDAR%'                        THEN 'TEDARİKÇİ'
    WHEN g LIKE 'FILO%' OR g LIKE 'FİLO%'       THEN 'FİLO'
    WHEN g IS NULL OR g=''                      THEN 'DİĞER'
    ELSE 'DİĞER'
  END
  FROM (SELECT regexp_replace(btrim(coalesce(p,'')),'^\.','') AS g) x;
$fn$;

DELETE FROM bi_metrik_gecmis
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND metrik='ciro_lastik' AND boyut_tipi='kanal';

INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, boyut_tipi, boyut_deger, meta, hesaplanma_at)
SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa','ciro_lastik','ay', date_trunc('month',f.fatura_tarihi)::date,
       round(sum(f.satir_tutar)), 'TL','yaklasik','bi_satis_faturalari×bi_musteri_risk','kanal', kanal_normalize(c.grup),
       '{"kaynak_fn":"kanal_normalize","not":"kanal=bugunku musteri sinifi, gecmise uygulandi"}'::jsonb, now()
FROM bi_satis_faturalari f
LEFT JOIN (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, grup FROM bi_musteri_risk
           WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' ORDER BY muhatap_kodu, export_date DESC) c
       ON c.muhatap_kodu=f.musteri_kodu
WHERE f.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND f.grup_adi LIKE 'LASTIK%'
GROUP BY date_trunc('month',f.fatura_tarihi), kanal_normalize(c.grup);

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'omurga_72',
  'Boyut (C): ciro_lastik x KANAL omurgaya. Yeni fn kanal_normalize (musteri sinifi -> TOPTAN/PERAKENDE/FİLO/E-TİCARET/TEDARİKÇİ/DİĞER). Kaynak satis×musteri_risk.',
  'Fatih yakaladi: satis kanali (toptan/perakende) eksikti; marka/segment marji kanal gorunmeden yarim. Kanal musteri sinifinda yasiyor (bi_musteri_risk.grup, muhatap_kodu). Icgoru: TOPTAN %4,7 (hacim/ince) vs PERAKENDE %15,9 vs E-TICARET %21,7.',
  '{"tur":"DB-only","yeni_fn":"kanal_normalize","metrik":"ciro_lastik","boyut":"kanal","kaynak":"bi_satis_faturalari(grup_adi LIKE LASTIK) x bi_musteri_risk.grup","not":"kanal=bugunku sinif gecmise uygulandi; TEDARIKCI mahsup? teyit","script":"omurga_72_kanal.sh"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_72');

COMMIT;
SQL

hr "2. YENI DAGILIM — ciro_lastik artik kanal boyutlu mu"
$PSQL -c "SELECT boyut_tipi, count(*) satir, count(DISTINCT boyut_deger) deger, min(donem)::date ilk, max(donem)::date son FROM bi_metrik_gecmis WHERE tenant_id::text='$T' AND metrik='ciro_lastik' GROUP BY 1 ORDER BY 1;" 2>&1 | sed 's/^/  /'

hr "3. KANAL — son 12 ay ciro (backbone'dan; toptan/perakende resmi)"
$PSQL -c "SELECT boyut_deger kanal, round(sum(deger)/1e6,1) ciro_M FROM bi_metrik_gecmis
  WHERE tenant_id::text='$T' AND metrik='ciro_lastik' AND boyut_tipi='kanal' AND donem>=(CURRENT_DATE-INTERVAL '12 months')
  GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'

hr "4. KANAL_NORMALIZE test — ham grup -> temiz kanal esleme dogru mu"
$PSQL -c "SELECT g ham, kanal_normalize(g) temiz FROM (VALUES ('.PERAKENDE'),('TOPTAN'),('FILO TICARI'),('FILO TUKETICI'),('E-TICARET'),('TEDARİKÇİ'),('KURUM'),('IHRACAT'),('')) v(g);" 2>&1 | sed 's/^/  /'

hr "BITTI — BEKLE: (2) ciro_lastik'e 'kanal' boyutu eklendi; (3) TOPTAN/PERAKENDE/FİLO... ciro; (4) normalize dogru. Sonra .md footprint (omurga_72 + cockpit tasarimi)."
