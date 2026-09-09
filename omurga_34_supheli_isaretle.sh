#!/usr/bin/env bash
# OMURGA 34 — cross-check BAŞARISIZ olan iki çekmeceyi defterde işaretle (test edildi→şüpheli). DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. İŞARETLE — güven=şüpheli + bulgu notu"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_yetenek SET guven='supheli',
  ne_ise_yarar=ne_ise_yarar||' ⚠ CROSS-CHECK BAŞARISIZ (omurga_34): odeme_tarihi gerçek tahsilatı YANSITMIYOR (ort ~0 gün, Çek-Senet 3g imkansız, Sanal Pos −15g); gelecek/sentinel tarih (2026-12-05). DSO için KULLANILMAZ — snapshot ~130 kalır.'
 WHERE ad='bi_odeme_gecmisi' AND tur='tablo';

UPDATE bi_yetenek SET guven='supheli',
  ne_ise_yarar=ne_ise_yarar||' ⚠ CROSS-CHECK BAŞARISIZ (omurga_34): ciro 348.9M vs omurga 382.3M (%9); CONTINENTAL marj −6.1% (marj_fact) vs +9% (bizim drill) — MALİYET BAZI 15 puan ÇELİŞİYOR. Maliyet mutabakatı çözülene dek marj için KULLANMA.'
 WHERE ad='bi_marj_fact' AND tur='tablo';
SQL
echo "  ✅ ikisi şüpheli işaretlendi"

hr "2. MALİYET ÇELİŞKİSİ KÖKÜ — CONTINENTAL: bizim ort maliyet vs marj_fact birim_maliyet (aynı SKU'lar)"
$PSQL -c "
WITH bizim AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) bm FROM bi_stok_hareket WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid AND giris>0 GROUP BY kalem_kodu)
SELECT mf.kalem_kodu, left(max(mf.kalem_tanimi),18) tanim,
       round(avg(mf.birim_maliyet)) marjfact_maliyet,
       round(max(b.bm)) bizim_maliyet,
       round(avg(mf.ort_fiyat)) satis_fiyat
  FROM bi_marj_fact mf LEFT JOIN bizim b ON b.kalem_kodu=mf.kalem_kodu
 WHERE mf.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND upper(mf.marka)='CONTINENTAL'
   AND mf.ay>=date_trunc('month',CURRENT_DATE)-interval '6 month'
 GROUP BY mf.kalem_kodu HAVING avg(mf.ciro)>0 ORDER BY avg(mf.ciro) DESC LIMIT 8;" 2>&1 | sed 's/^/  /'

hr "3. maliyet_kaynak dağılımı — marj_fact maliyeti nereden (satis_hareketi mi başka mı)"
$PSQL -c "SELECT maliyet_kaynak, count(*), round(avg(marj_pct),1) ort_marj FROM bi_marj_fact WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa' AND ay>=date_trunc('month',CURRENT_DATE)-interval '6 month' GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'

hr "BITTI — maliyet çelişkisinin kökü (hangi maliyet doğru) görünür. Sonra mutabakat kararı."
