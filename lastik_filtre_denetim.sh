#!/usr/bin/env bash
# Salt okuma. TAM ciro yuklendi -> artik tabloda 17.000 SERVIS satiri var.
# Soru: hangi sorgular bunlari LASTIK sanip marka/ebat analizini bozuyor?
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
S=/opt/krb-assessment/server_container.mjs

echo "############ 1) HASARIN BOYUTU: lastik disi satirlar ############"
$PSQL -c "
SELECT CASE WHEN grup_adi LIKE 'LASTIK%' THEN 'LASTIK' ELSE 'LASTIK DISI' END AS tur,
       count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL,
       count(*) FILTER (WHERE ebat IS NULL OR ebat='')   AS ebati_BOS,
       count(*) FILTER (WHERE marka IS NULL OR marka='') AS markasi_BOS
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'
 GROUP BY 1 ORDER BY 2 DESC;"

echo "############ 2) ⚠ 'marka' sanilan seyler (filtresiz GROUP BY marka boyle gorunur) ############"
$PSQL -c "
SELECT COALESCE(NULLIF(marka,''),'(BOS)') AS marka, count(*) AS satir,
       round(sum(satir_tutar)/1e6,2) AS ciro_MTL,
       string_agg(DISTINCT grup_adi, ', ') FILTER (WHERE grup_adi NOT LIKE 'LASTIK%') AS lastik_disi_gruplar
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'
 GROUP BY 1 ORDER BY 2 DESC LIMIT 12;"
echo "  ^ '(BOS)' en ustteyse: marka analizi artik SERVIS'i en buyuk 'marka' sanar."

echo "############ 3) ⚠ 'ebat' sanilan seyler ############"
$PSQL -c "
SELECT COALESCE(NULLIF(ebat,''),'(BOS)') AS ebat, count(*) AS satir
  FROM bi_satis_faturalari
 WHERE tenant_id='$TEN' AND fatura_tarihi >= DATE '2026-01-01'
 GROUP BY 1 ORDER BY 2 DESC LIMIT 8;"

echo
echo "############ 4) KODDA: satis tablosunu okuyan sorgular — filtre VAR MI? ############"
echo "  (LASTIK filtresi olmayan her satir SUPHELI)"
grep -n "bi_satis_faturalari" $S | grep -i "FROM\|JOIN" | while IFS=: read -r ln rest; do
  # o satirdan sonraki 12 satirda grup_adi filtresi var mi?
  if sed -n "${ln},$((ln+12))p" $S | grep -q "grup_adi LIKE 'LASTIK\|grup_adi LIKE '%LASTIK\|LASTIK%'"; then
    printf "  ✅ %-6s FILTRELI\n" "$ln"
  else
    # marka/ebat ile gruplaniyor mu? oyleyse KRITIK
    if sed -n "${ln},$((ln+12))p" $S | grep -qi "marka\|ebat\|jant"; then
      printf "  ❌ %-6s FILTRESIZ + marka/ebat kullaniyor  -> BOZUK\n" "$ln"
    else
      printf "  ·  %-6s filtresiz (ciro/musteri -> sorun degil)\n" "$ln"
    fi
  fi
done

echo
echo "############ 5) urun master eslesmesi de etkilendi mi? ############"
grep -rn "bi_satis_faturalari" /opt/price_monitor/*.py 2>/dev/null | head
echo "  ^ sm_master.py satis tablosundan KRB ciro/kalem cekiyorsa, servis satirlari"
echo "    urun master'a 'urun' diye girebilir."

echo
echo "═══════════════════════════════════════════════════════════════"
echo " ❌ isaretli her satir yamalanacak:  AND grup_adi LIKE 'LASTIK%'"
echo "═══════════════════════════════════════════════════════════════"
