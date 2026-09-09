#!/usr/bin/env bash
# GECMIS GOSTER + BOZUK VERI ANLA. SADECE OKUR (henuz duzeltme yok — once anla).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ⚠ GECMIS GORUNUYOR — AYLIK LASTIK CIRO (akis metrigi, 6 yil kesin)"
$PSQL -c "
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay,
       round(sum(satir_tutar) FILTER (WHERE ebat IS NOT NULL)/1e6,1) lastik_ciro_m,
       round(sum(satir_tutar)/1e6,1) tum_ciro_m
  FROM bi_satis_faturalari WHERE tenant_id='$T' AND miktar>0
   AND fatura_tarihi >= DATE '2024-01-01'
 GROUP BY 1 ORDER BY 1;"
echo "  ⚠ Iste gecmis — her ay ayri, kesin. Ekranda cizgi/trend olarak gosterilebilir."

hr "2. ⚠ GECMIS ALACAK (reconstruct, ~%7 yaklasik) — ceyrek ceyrek"
for D in 2025-07-01 2025-10-01 2026-01-01 2026-04-01 2026-07-01; do
  V=$($PSQL -tAc "
    SELECT round(sum(s.satir_tutar)/1e6,1) FROM bi_satis_faturalari s
     LEFT JOIN (SELECT DISTINCT fatura_no,musteri_kodu,son_tahsilat FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid) t
       ON t.fatura_no=s.fatura_no AND t.musteri_kodu=s.musteri_kodu
     WHERE s.tenant_id='$T' AND s.fatura_tarihi<='$D'
       AND (t.fatura_no IS NULL OR t.son_tahsilat>'$D')" | tr -d '[:space:]')
  printf "    %s : ~%s M (yaklasik)\n" "$D" "$V"
done
echo "  ⚠ Pozisyon metrigi ama hareket geçmişinden KURULABILIYOR. Trend gorunuyor."

hr "3. ⚠ BOZUK #1 — kdv_orani = 1 (7133 satir) NE? (once ANLA, sonra duzelt)"
$PSQL -c "
SELECT round(100.0*sum(kdv_tutari)/nullif(sum(satir_kdv_haric),0),1) AS ima_edilen_kdv_pct,
       count(*) satir, round(sum(satir_kdv_haric)/1e6,1) tutar_m
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND kdv_orani=1;"
echo "  --- ornek satirlar ---"
$PSQL -c "SELECT left(kalem_tanimi,34) kalem, round(satir_kdv_haric) haric, round(kdv_tutari) kdv, kdv_orani
          FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND kdv_orani=1 AND satir_kdv_haric>0 LIMIT 6;" 2>&1 | sed 's/^/  /'
echo "  ⚠ ima_edilen ~20 ise: kdv_orani '1' ETIKET yanlis, gercek %20 -> KDV etkilenmez, sadece etiket."

hr "4. ⚠ BOZUK #2 — para_birimi BOS (19945 satis) NE? (donem/tip?)"
$PSQL -c "
SELECT to_char(date_trunc('year',fatura_tarihi),'YYYY') yil, count(*),
       round(sum(satir_tutar)/1e6,1) tutar_m, round(avg(satir_tutar)) ort_satir
  FROM bi_satis_faturalari WHERE tenant_id='$T' AND (para_birimi IS NULL OR para_birimi='')
 GROUP BY 1 ORDER BY 1;"
echo "  ⚠ Tutarlar TL olcegindeyse (yuzler-binler): bos = TRY, guvenle doldurulabilir."

hr "5. ⚠ BOZUK #3 — junk odeme_kosulu / belge_turu"
$PSQL -c "SELECT odeme_kosulu, count(*) FROM bi_satis_faturalari WHERE tenant_id='$T' AND odeme_kosulu ~ '^[0-9]+$|^Kredi kartı$' GROUP BY 1;"
echo "  ⚠ Bunlar az sayida; ne demek istedigi belirsiz -> karantina/duzeltme."

hr "BITTI — 1-2 gecmisi GOSTERIR; 3-5 bozugu ANLAR (duzeltme sonraki adim, once karar)"
