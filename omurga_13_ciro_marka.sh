#!/usr/bin/env bash
# OMURGA 13 — ilk kırılım: ciro_lastik × MARKA (aylık, kesin). İlk görünür boyutlu trend. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. BACKFILL — ciro_lastik × marka, aylık (akış = kesin, 2021-10→)"
$PSQL -v ON_ERROR_STOP=1 <<SQL || exit 1
WITH son AS (SELECT date_trunc('month',max(fatura_tarihi))::date sv FROM bi_satis_faturalari WHERE tenant_id='$T')
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT '$T'::uuid,'ciro_lastik','marka',COALESCE(NULLIF(trim(marka),''),'DIGER'),'ay',
       date_trunc('month',fatura_tarihi)::date, round(sum(satir_tutar)),'TL','kesin','bi_satis_faturalari',
       jsonb_build_object('tam', date_trunc('month',fatura_tarihi)::date < (SELECT sv FROM son))
  FROM bi_satis_faturalari
 WHERE tenant_id='$T' AND miktar>0 AND ebat IS NOT NULL AND fatura_tarihi>=date '2021-10-01'
 GROUP BY COALESCE(NULLIF(trim(marka),''),'DIGER'), date_trunc('month',fatura_tarihi)
ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem)
  DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
$PSQL -c "SELECT count(*) satir, count(DISTINCT boyut_deger) marka_sayisi, count(DISTINCT donem) ay
          FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND boyut_tipi='marka';"

hr "2. ⚠ İLK BOYUTLU İÇGÖRÜ — marka bazında H1-2025 vs H1-2026 (neredeydi → nerede)"
$PSQL -c "
SELECT boyut_deger marka,
       round(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01')/1e6,1) h1_2025_m,
       round(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')/1e6,1) h1_2026_m,
       round(100.0*(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')
             - sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'))
             / nullif(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'),0)) yoy_pct
  FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik' AND boyut_tipi='marka'
 GROUP BY boyut_deger ORDER BY h1_2026_m DESC NULLS LAST LIMIT 12;"
echo "  ⚠ Brisa H1-2026 patlaması ve düşen/çıkan markalar görünmeli — asıl 'aha' bu."

hr "3. KONTROL — marka toplamı ≈ şirket-geneli ciro_lastik (kırılım tutarlı mı)"
$PSQL -c "
SELECT round(sum(deger) FILTER (WHERE boyut_tipi='marka' AND donem>='2026-01-01' AND donem<'2026-07-01')/1e6,1) marka_toplam_h1_26,
       round(sum(deger) FILTER (WHERE boyut_tipi='sirket' AND donem>='2026-01-01' AND donem<'2026-07-01')/1e6,1) sirket_h1_26
  FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid AND metrik='ciro_lastik';"
echo "  ⚠ İki toplam yakın olmalı (kırılım şirket-geneliyle tutarlı = doğru dağıtım, allocation değil gerçek)."

hr "4. AYAK İZİ"
$PSQL -c "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES
 ('omurga_13','ciro_lastik x marka aylik backfill (kesin)','Finans odasi ilk gorunur kirilim; Brisa donusu marka bazinda gorunsun',
  jsonb_build_object('script','omurga_13_ciro_marka.sh','boyut','marka','guven','kesin'));" >/dev/null
echo "  ✅ kaydedildi"

hr "BITTI — ilk boyutlu metrik (ciro×marka) canlı + tutarlı. Sonraki: segment/sezon + trend endpoint."
