#!/usr/bin/env bash
# OMURGA 5 — DSO'yu omurgaya kur (TEMİZ kredi deseni). Geçmiş=recon(yaklasik), bileşenler ayrı. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. FONKSİYONLAR — günlük kredili (TEMİZ desen) + alacak recon (tarih-parametreli)"
# quoted heredoc: $$ korunur, tenant param olarak gelir
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- Günlük kredili satış (as_of'ta biten trailing-365). TEMİZ desen: '^çek' gerçek çek/senet,
--   çıplak 'çek' YASAK (Peşin-Kredi Kartı ÇEKİM peşinini yakalıyordu). Akış = KESİN.
CREATE OR REPLACE FUNCTION metrik_gunluk_kredili(p_tenant uuid, p_asof date)
RETURNS numeric AS $$
  SELECT COALESCE(sum(satir_tutar),0)/365
    FROM bi_satis_faturalari
   WHERE tenant_id = p_tenant::text
     AND fatura_tarihi >= p_asof - 365 AND fatura_tarihi < p_asof
     AND ( odeme_kosulu ~* 'vade|mukabili|mahsuben' OR odeme_kosulu ~* '^çek' );
$$ LANGUAGE sql STABLE;

-- Açık alacak reconstruction (as_of'ta): fatura kesildi, o tarihe kadar tahsil edilmedi. YAKLAŞIK ~%7.
CREATE OR REPLACE FUNCTION metrik_alacak_recon(p_tenant uuid, p_asof date)
RETURNS numeric AS $$
  SELECT COALESCE(sum(s.satir_tutar),0)
    FROM bi_satis_faturalari s
    LEFT JOIN (SELECT DISTINCT fatura_no, musteri_kodu, son_tahsilat
                 FROM bi_fatura_tahsilat WHERE tenant_id = p_tenant) t
      ON t.fatura_no = s.fatura_no AND t.musteri_kodu = s.musteri_kodu
   WHERE s.tenant_id = p_tenant::text
     AND s.fatura_tarihi < p_asof
     AND (t.fatura_no IS NULL OR t.son_tahsilat >= p_asof);
$$ LANGUAGE sql STABLE;
SQL
echo "  ✅ metrik_gunluk_kredili + metrik_alacak_recon kuruldu"

hr "2. BACKFILL — dso + alacak + günlük kredili, aylık (trailing-365 tam olsun diye +12 aydan başla)"
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
WITH sinir AS (
  SELECT (date_trunc('month', min(fatura_tarihi)) + interval '12 month')::date AS bas,
         date_trunc('month', max(fatura_tarihi))::date AS son_veri
    FROM bi_satis_faturalari WHERE tenant_id='$T'
),
aylar AS (
  SELECT generate_series((SELECT bas FROM sinir), date_trunc('month',CURRENT_DATE)::date, interval '1 month')::date AS ay
),
h AS (
  SELECT a.ay,
         metrik_alacak_recon('$T'::uuid, a.ay)     AS alacak,
         metrik_gunluk_kredili('$T'::uuid, a.ay)    AS gunluk,
         (a.ay < (SELECT son_veri FROM sinir))      AS tam
    FROM aylar a
)
INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, meta)
SELECT * FROM (
  SELECT '$T'::uuid, 'dso', 'ay', ay,
         CASE WHEN gunluk>0 THEN round(alacak/gunluk) END, 'gun', 'yaklasik', 'reconstruction',
         jsonb_build_object('tam',tam,'yontem','alacak_recon/gunluk_kredili ~%7 yaklasik') FROM h
  UNION ALL
  SELECT '$T'::uuid, 'alacak', 'ay', ay, round(alacak), 'TL', 'yaklasik', 'reconstruction',
         jsonb_build_object('tam',tam) FROM h
  UNION ALL
  SELECT '$T'::uuid, 'gunluk_kredili_satis', 'ay', ay, round(gunluk), 'TL', 'kesin', 'bi_satis_faturalari',
         jsonb_build_object('tam',tam) FROM h
) x
ON CONFLICT (tenant_id, metrik, periyot, donem)
  DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
$PSQL -c "SELECT metrik, count(*) ay, min(donem)::text ilk, max(donem)::text son
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik IN ('dso','alacak','gunluk_kredili_satis') GROUP BY 1;"

hr "3. ⚠ TREND — DSO son 15 ay + AÇILIM (alacak ↑ mı, satış ↓ mı DSO'yu itiyor)"
$PSQL -c "
WITH d AS (SELECT donem, deger dso FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='dso' AND periyot='ay'),
     a AS (SELECT donem, deger alacak FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='alacak' AND periyot='ay'),
     g AS (SELECT donem, deger gunluk FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='gunluk_kredili_satis' AND periyot='ay')
SELECT to_char(d.donem,'YYYY-MM') ay, d.dso dso_gun,
       round(a.alacak/1e6,1) alacak_m, round(g.gunluk/1e6,2) gunluk_kredili_m
  FROM d JOIN a USING(donem) JOIN g USING(donem)
 ORDER BY d.donem DESC LIMIT 15;"
echo "  ⚠ Geçmiş DSO 'yaklasik' (recon ~%7). Bugün+ileri snapshot kesin gelecek (sonraki adım: cron'a DSO ekle)."

hr "4. KANIT — güven dağılımı + en güncel DSO §önceki 130'a yakın mı"
$PSQL -c "SELECT metrik, guven, count(*) FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik IN ('dso','alacak','gunluk_kredili_satis') GROUP BY 1,2 ORDER BY 1;"
$PSQL -c "SELECT deger AS en_guncel_dso_recon FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='dso' AND periyot='ay' ORDER BY donem DESC LIMIT 1;"
echo "  ⚠ recon-DSO ~130 civarı (bugünkü gerçek 130'du); geçmiş recon olduğu için birebir değil, yakın olmalı."

hr "BITTI — DSO omurgada (temiz desen). İleri snapshot cron'a eklenince kesin bugün+ileri gelir."
