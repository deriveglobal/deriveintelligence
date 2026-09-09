#!/usr/bin/env bash
# MÜKERRER ETKİ — ciroyu ne kadar şişiriyor, hangi yıllar, tedarikçide de var mı. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. CİRO ŞİŞMESİ — mevcut (mükerrerli) vs doğal-anahtar dedup"
$PSQL -c "
SELECT round(sum(satir_tutar)/1e6,1) mevcut_ciro_m,
       round((SELECT sum(st) FROM (
          SELECT (array_agg(satir_tutar))[1] st
            FROM bi_satis_faturalari WHERE tenant_id='$T'
           GROUP BY fatura_no,kalem_kodu,fatura_tarihi) d)/1e6,1) dedup_ciro_m
  FROM bi_satis_faturalari WHERE tenant_id='$T';"
echo "  ⚠ Fark = mükerrerin ciroya kattığı şişme."

hr "2. HANGİ YILLAR — mükerrer satırlar yıllara göre (çift-yüklenen 2023/2025/2026 mu?)"
$PSQL -c "
SELECT to_char(fatura_tarihi,'YYYY') yil,
       count(*) toplam_satir,
       count(*) - count(DISTINCT (fatura_no,kalem_kodu,fatura_tarihi)) fazla_satir
  FROM bi_satis_faturalari WHERE tenant_id='$T'
 GROUP BY 1 ORDER BY 1;"

hr "3. ÖRNEK — bir mükerrer grubun satırları (birebir mi kopya)"
$PSQL -c "
WITH d AS (SELECT fatura_no,kalem_kodu,fatura_tarihi FROM bi_satis_faturalari WHERE tenant_id='$T' GROUP BY 1,2,3 HAVING count(*)>1 ORDER BY count(*) DESC LIMIT 1)
SELECT s.fatura_no, left(s.kalem_tanimi,18) kalem, s.miktar, s.birim_fiyat, s.satir_tutar, s.odeme_kosulu, s.musteri_kodu
  FROM bi_satis_faturalari s JOIN d USING(fatura_no,kalem_kodu,fatura_tarihi)
 WHERE s.tenant_id='$T';"

hr "4. TEDARİKÇİ de mükerrer mi (aynı anahtar)"
$PSQL -c "SELECT count(*) - count(DISTINCT (fatura_no,kalem_kodu,fatura_tarihi)) fazla_satir,
                 round((sum(satir_kdv_haric) - (SELECT sum(st) FROM (SELECT (array_agg(satir_kdv_haric))[1] st FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid GROUP BY fatura_no,kalem_kodu,fatura_tarihi) d))/1e6,1) sisme_m
          FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid;"

hr "BITTI — mükerrerin gerçek etkisi (ciro + hangi yıl + tedarikçi) görüldü."
