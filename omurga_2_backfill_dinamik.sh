#!/usr/bin/env bash
# OMURGA 2 — backfill başlangıcını DINAMIK yap (her kiracının kendi min tarihi). Çok-kiracılı doğru.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. GERÇEK VERI ARALIGI — sabit varsayım değil, veriye sor"
$PSQL -c "SELECT min(fatura_tarihi)::text ilk, max(fatura_tarihi)::text son,
                 date_trunc('month',min(fatura_tarihi))::date backfill_baslangic
          FROM bi_satis_faturalari WHERE tenant_id='$T';"
echo "  ⚠ Önceki backfill 2021-10'dan başladı. Gerçek ilk ay bundan eskiyse erken aylar EKSİKTİ."

hr "2. DINAMIK BACKFILL — min(fatura_tarihi)'den, her kiracı kendi tarihinden (idempotent)"
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
WITH sinir AS (
  SELECT date_trunc('month', min(fatura_tarihi))::date bas,
         date_trunc('month', max(fatura_tarihi))::date son_veri
    FROM bi_satis_faturalari WHERE tenant_id='$T'
),
aylar AS (
  SELECT generate_series((SELECT bas FROM sinir),
                         date_trunc('month', CURRENT_DATE)::date, interval '1 month')::date AS ay
)
INSERT INTO bi_metrik_gecmis (tenant_id, metrik, periyot, donem, deger, birim, guven, kaynak, meta)
SELECT '$T'::uuid, m.metrik, 'ay', a.ay,
       metrik_ciro('$T'::uuid, a.ay, m.lastik), 'TL', 'kesin', 'bi_satis_faturalari',
       jsonb_build_object('tam', a.ay < (SELECT son_veri FROM sinir))
  FROM aylar a
  CROSS JOIN (VALUES ('ciro_lastik', true), ('ciro_tum', false)) AS m(metrik, lastik)
ON CONFLICT (tenant_id, metrik, periyot, donem)
  DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
echo "  ✅ dinamik backfill çalıştı (sabit tarih yok — çok-kiracılı doğru)"

hr "3. KAPSAM + BOŞLUK KONTROLÜ — ay sayısı beklenen mi, delik var mı?"
$PSQL -c "
WITH g AS (SELECT donem FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND periyot='ay')
SELECT count(*) gercek_ay,
       (EXTRACT(YEAR FROM age(max(donem),min(donem)))*12 + EXTRACT(MONTH FROM age(max(donem),min(donem))) + 1)::int beklenen_ay,
       min(donem)::text ilk, max(donem)::text son
  FROM g;"
echo "  ⚠ gercek_ay = beklenen_ay ise BOŞLUK YOK (her ay dolu)."
$PSQL -c "
WITH g AS (SELECT donem, lead(donem) OVER (ORDER BY donem) sonraki
             FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND periyot='ay')
SELECT donem::text ay, sonraki::text sonraki_ay FROM g
 WHERE sonraki IS NOT NULL AND sonraki <> (donem + interval '1 month')::date;"
echo "  ⚠ Yukarıda satır varsa = boşluk var; boşsa = kesintisiz."

hr "4. EN ESKI 6 AY — erken tarih gerçekten geldi mi?"
$PSQL -c "SELECT to_char(donem,'YYYY-MM') ay, round(deger/1e6,1) ciro_m
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND periyot='ay'
          ORDER BY donem ASC LIMIT 6;"

hr "BITTI — backfill dinamik + tam. Sabit varsayım kaldırıldı, çok-kiracılı hazır."
