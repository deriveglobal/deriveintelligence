#!/usr/bin/env bash
# OMURGA 53 (Parça A) — içgörü motoru ATOMA: kayda değer marj-düşüşü markalarını seç, facts sakla.
# bi_icgoru'ya anlati/oneri/kaynak kolonları (LLM anlatısı buraya yazılacak).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_icgoru — anlati/oneri/kaynak kolonları (yoksa ekle)"
$PSQL -v ON_ERROR_STOP=1 -c "
ALTER TABLE bi_icgoru ADD COLUMN IF NOT EXISTS anlati text;
ALTER TABLE bi_icgoru ADD COLUMN IF NOT EXISTS oneri text;
ALTER TABLE bi_icgoru ADD COLUMN IF NOT EXISTS kaynak text;
ALTER TABLE bi_icgoru ADD COLUMN IF NOT EXISTS anlati_at timestamptz;" 2>&1 | sed 's/^/  /'

hr "2. icgoru_uret_finans — ATOM tabanlı (kayda değer marj-düşüşü seçer)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION icgoru_uret_finans(p_tenant uuid) RETURNS int AS $fn$
DECLARE n int; m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  -- sadece bu bölümün 'yeni' (henüz karar verilmemiş) kayıtlarını tazele
  DELETE FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='marka-marj' AND durum='yeni';
  WITH b AS (
    SELECT upper(marka) marka,
      sum(ciro)     FILTER (WHERE ay>=m0-interval '6 month'  AND ay<m0) ciro_s,
      sum(ciro)     FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') ciro_o,
      sum(brut_kar) FILTER (WHERE ay>=m0-interval '6 month'  AND ay<m0) k_s,
      sum(brut_kar) FILTER (WHERE ay>=m0-interval '12 month' AND ay<m0-interval '6 month') k_o
    FROM bi_marj_atom WHERE tenant_id=p_tenant AND ay>=m0-interval '12 month' GROUP BY 1),
  c AS (
    SELECT marka, ciro_s, ciro_o,
      round(100.0*k_o/nullif(ciro_o,0),1) marj_o,
      round(100.0*k_s/nullif(ciro_s,0),1) marj_s
    FROM b WHERE ciro_s>=5000000 AND ciro_o>0)
  INSERT INTO bi_icgoru (tenant_id,bolum,tip,ozet,kanit,surpriz_skoru,guven,durum)
  SELECT p_tenant,'marka-marj','marj-dusus',
    marka||': marj %'||replace(marj_o::text,'.',',')||' → %'||replace(marj_s::text,'.',',')||' (ciro '||round(ciro_o/1e6,1)||'→'||round(ciro_s/1e6,1)||'M)',
    jsonb_build_object('marka',marka,'marj_pct_o',marj_o,'marj_pct_s',marj_s,'ciro_o_m',round(ciro_o/1e6,1),'ciro_s_m',round(ciro_s/1e6,1)),
    round((marj_o-marj_s) + greatest(0, 100.0*(ciro_s-ciro_o)/nullif(ciro_o,0))),  -- ciro artıp marj düşerse daha şaşırtıcı
    'yaklasik','yeni'
  FROM c WHERE (marj_o - marj_s) >= 3;   -- en az 3 puan düşüş = kayda değer
  SELECT count(*) INTO n FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='marka-marj' AND durum='yeni';
  RETURN n;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ icgoru_uret_finans (atom)"

hr "3. ÇALIŞTIR — kaç kayda değer içgörü seçildi"
$PSQL -c "SELECT icgoru_uret_finans('$T'::uuid) AS secilen_icgoru;" 2>&1 | sed 's/^/  /'

hr "4. SEÇİLEN içgörüler (sürpriz sırasına göre) — anlati henüz boş (LLM Parça B'de)"
$PSQL -c "SELECT surpriz_skoru skor, ozet FROM bi_icgoru WHERE tenant_id='$T'::uuid AND bolum='marka-marj' AND durum='yeni' ORDER BY surpriz_skoru DESC;" 2>&1 | sed 's/^/  /'

hr "BITTI — motor atomdan seçiyor. Parça B: her seçilene LLM anlatısı yaz."
