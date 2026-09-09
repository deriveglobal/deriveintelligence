#!/usr/bin/env bash
# COCKPIT VERİSİ — prototipe gömmek için gerçek veri (JSON). READ-ONLY.
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform -tA"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n═══JSON═══ %s\n' "$1"; }

hr "INSIGHTS (bi_icgoru — cockpit kartlarinin kalbi)"
$PSQL -c "SELECT COALESCE(json_agg(row_to_json(x)),'[]') FROM (
  SELECT bolum,tip,ozet,anlati,oneri,guven,surpriz_skoru,durum,kaynak
  FROM bi_icgoru WHERE tenant_id='$T' ORDER BY surpriz_skoru DESC NULLS LAST, ts DESC LIMIT 40) x;" 2>&1

hr "MARKA (son 12 ay: ciro+marj+adet, atom)"
$PSQL -c "SELECT json_agg(row_to_json(x)) FROM (
  SELECT marka, round(sum(ciro)) ciro, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1) marj, sum(adet)::int adet
  FROM bi_marj_atom WHERE tenant_id='$T' AND ay>=(CURRENT_DATE-interval '12 months')
  GROUP BY marka HAVING sum(ciro)>0 ORDER BY 2 DESC) x;" 2>&1

hr "MARKA_STOK (son ay stok_deger x marka)"
$PSQL -c "SELECT json_agg(row_to_json(x)) FROM (
  SELECT boyut_deger marka, round(deger) stok FROM bi_metrik_gecmis
  WHERE tenant_id='$T' AND metrik='stok_deger' AND boyut_tipi='marka'
    AND donem=(SELECT max(donem) FROM bi_metrik_gecmis WHERE tenant_id='$T' AND metrik='stok_deger' AND boyut_tipi='marka')
  ORDER BY deger DESC) x;" 2>&1

hr "SEGMENT (son 12 ay: ciro+marj)"
$PSQL -c "SELECT json_agg(row_to_json(x)) FROM (
  SELECT kategori_segment(kategori) segment, round(sum(ciro)) ciro, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1) marj, sum(adet)::int adet
  FROM bi_marj_atom WHERE tenant_id='$T' AND ay>=(CURRENT_DATE-interval '12 months')
  GROUP BY 1 ORDER BY 2 DESC) x;" 2>&1

hr "SEZON (son 12 ay: ciro+marj)"
$PSQL -c "SELECT json_agg(row_to_json(x)) FROM (
  SELECT kategori_sezon(kategori) sezon, round(sum(ciro)) ciro, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1) marj
  FROM bi_marj_atom WHERE tenant_id='$T' AND ay>=(CURRENT_DATE-interval '12 months') GROUP BY 1 ORDER BY 2 DESC) x;" 2>&1

hr "TREND (sirket aylik: ciro_lastik + stok_deger, son 13 ay)"
$PSQL -c "SELECT json_agg(row_to_json(x)) FROM (
  SELECT donem::date ay,
    max(deger) FILTER (WHERE metrik='ciro_lastik') ciro,
    max(deger) FILTER (WHERE metrik='stok_deger') stok,
    max(deger) FILTER (WHERE metrik='dso') dso
  FROM bi_metrik_gecmis WHERE tenant_id='$T' AND boyut_tipi='sirket' AND periyot='ay'
    AND donem>=(CURRENT_DATE-interval '13 months')
  GROUP BY donem ORDER BY donem) x;" 2>&1

hr "MARKA_MARJ_TREND (SAILUN + LASSA aylik marj, son 12 ay — cizim icin)"
$PSQL -c "SELECT json_agg(row_to_json(x)) FROM (
  SELECT ay::date, marka, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1) marj
  FROM bi_marj_atom WHERE tenant_id='$T' AND marka IN ('SAILUN','LASSA','CONTINENTAL') AND ay>=(CURRENT_DATE-interval '12 months')
  GROUP BY ay, marka ORDER BY ay, marka) x;" 2>&1

hr "SEBEP (Neden? drill — SAILUN)"
$PSQL -c "SELECT sebep_arastir_marj('$T','SAILUN');" 2>&1

hr "YASALAR (capraz_kontrol SAILUN — atesleyen sinyaller)"
$PSQL -c "SELECT capraz_kontrol('$T'::uuid,'marka','SAILUN');" 2>&1

hr "BITTI"
