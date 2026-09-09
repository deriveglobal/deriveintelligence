#!/usr/bin/env bash
# OMURGA 27 (Katman 4+6 çekirdek) — içgörü şeması + topraklanmış motor. KUR + KRB'de üret + göster. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ŞEMA — 4 tablo (icgoru · geribildirim · paylaşım · etkinlik)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_icgoru (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid, bolum text, tip text, ozet text, kanit jsonb,
  surpriz_skoru numeric, guven text, durum text DEFAULT 'yeni', ts timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS bi_icgoru_geribildirim (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  icgoru_id uuid, kullanici text, faydali boolean, aksiyon_alindi boolean, ts timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS bi_paylasim_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid, kullanici text, icgoru_id uuid, alici text, kanal text, icerik_ozeti text, ts timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS bi_etkinlik (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid, kullanici text, oda text, bolum text, olay_tipi text, ref_id uuid, payload jsonb, ts timestamptz DEFAULT now());
CREATE INDEX IF NOT EXISTS ix_icgoru_tenant ON bi_icgoru(tenant_id, bolum, durum);
CREATE INDEX IF NOT EXISTS ix_etkinlik_oda ON bi_etkinlik(tenant_id, oda, ts DESC);
SQL
echo "  ✅ 4 tablo + index"

hr "2. MOTOR — icgoru_uret_finans (2 kural: ciro↑marj↓ · materyal düşüş)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION icgoru_uret_finans(p_tenant uuid) RETURNS int AS $fn$
DECLARE n int;
  m0 date := date_trunc('month',CURRENT_DATE)::date;
BEGIN
  DELETE FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='marka-trend' AND durum='yeni';
  WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) bmaliyet
                FROM bi_stok_hareket WHERE tenant_id=p_tenant AND giris>0 GROUP BY kalem_kodu),
  b AS (
    SELECT upper(s.marka) marka,
      sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=m0-interval '6 month'  AND s.fatura_tarihi<m0) ciro_s,
      sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0-interval '6 month') ciro_o,
      sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END) FILTER (WHERE s.fatura_tarihi>=m0-interval '6 month'  AND s.fatura_tarihi<m0) marj_s,
      sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END) FILTER (WHERE s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0-interval '6 month') marj_o,
      round(100.0*count(*) FILTER (WHERE km.bmaliyet IS NOT NULL AND s.fatura_tarihi>=m0-interval '6 month' AND s.fatura_tarihi<m0)
            /nullif(count(*) FILTER (WHERE s.fatura_tarihi>=m0-interval '6 month' AND s.fatura_tarihi<m0),0)) kapsam_s
    FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
    WHERE s.tenant_id::text=p_tenant::text AND s.ebat IS NOT NULL AND s.miktar>0
      AND s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0
    GROUP BY 1)
  INSERT INTO bi_icgoru (tenant_id,bolum,tip,ozet,kanit,surpriz_skoru,guven,durum)
  SELECT p_tenant,'marka-trend','ciro↑marj↓',
    marka||': ciro %'||round(100*(ciro_s-ciro_o)/nullif(ciro_o,0))||' arttı ('||round(ciro_o/1e6,1)||'→'||round(ciro_s/1e6,1)||'M) ama marj oranı %'||round(100*marj_o/nullif(ciro_o,0))||'→%'||round(100*marj_s/nullif(ciro_s,0))||' düştü. Fiyat/iskonto gözden geçir.',
    jsonb_build_object('marka',marka,'ciro_o',ciro_o,'ciro_s',ciro_s,'marj_pct_o',round(100.0*marj_o/nullif(ciro_o,0),1),'marj_pct_s',round(100.0*marj_s/nullif(ciro_s,0),1),'kapsam',kapsam_s),
    round((100*(ciro_s-ciro_o)/nullif(ciro_o,0)) + (100*marj_o/nullif(ciro_o,0) - 100*marj_s/nullif(ciro_s,0))),
    CASE WHEN kapsam_s>=99 THEN 'kesin' ELSE 'yaklasik' END, 'yeni'
  FROM b
  WHERE ciro_s>5000000 AND kapsam_s>=90 AND ciro_o>0 AND ciro_s>ciro_o*1.15
    AND (marj_s/nullif(ciro_s,0)) < (marj_o/nullif(ciro_o,0)) - 0.03;

  WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) bmaliyet FROM bi_stok_hareket WHERE tenant_id=p_tenant AND giris>0 GROUP BY kalem_kodu),
  b AS (
    SELECT upper(s.marka) marka,
      sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=m0-interval '6 month'  AND s.fatura_tarihi<m0) ciro_s,
      sum(s.satir_tutar) FILTER (WHERE s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0-interval '6 month') ciro_o
    FROM bi_satis_faturalari s WHERE s.tenant_id::text=p_tenant::text AND s.ebat IS NOT NULL AND s.miktar>0
      AND s.fatura_tarihi>=m0-interval '12 month' AND s.fatura_tarihi<m0 GROUP BY 1)
  INSERT INTO bi_icgoru (tenant_id,bolum,tip,ozet,kanit,surpriz_skoru,guven,durum)
  SELECT p_tenant,'marka-trend','ciro-düşüş',
    marka||': ciro %'||round(100*(ciro_s-ciro_o)/nullif(ciro_o,0))||' düştü ('||round(ciro_o/1e6,1)||'→'||round(ciro_s/1e6,1)||'M). Neden — stok? tedarik? rakip? müşteri kaybı?',
    jsonb_build_object('marka',marka,'ciro_o',ciro_o,'ciro_s',ciro_s),
    round(abs(100*(ciro_s-ciro_o)/nullif(ciro_o,0))), 'kesin','yeni'
  FROM b WHERE ciro_o>10000000 AND ciro_s<ciro_o*0.6;

  SELECT count(*) INTO n FROM bi_icgoru WHERE tenant_id=p_tenant AND bolum='marka-trend' AND durum='yeni';
  RETURN n;
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ icgoru_uret_finans"

hr "3. ÜRET — KRB"
$PSQL -c "SELECT icgoru_uret_finans('$T'::uuid) AS uretilen_icgoru;" 2>&1 | sed 's/^/  /'

hr "4. İÇGÖRÜLER — motor ne buldu (sürpriz sırasına göre)"
$PSQL -c "SELECT tip, guven, surpriz_skoru surpriz, ozet FROM bi_icgoru
          WHERE tenant_id='$T'::uuid AND bolum='marka-trend' AND durum='yeni'
          ORDER BY surpriz_skoru DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "BITTI — içgörüler mantıklı + bariz-olmayan mı? Öyleyse kart UI + geri-bildirim sırada."
