#!/usr/bin/env bash
# VERI MIMARISI — ingest soy agaci + guard kurallari icin BILINEN-DEGER kumeleri. SADECE OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. INGEST SOY AGACI — erp_ingest.py: query_type -> hedef tablo + kolon eslesmesi"
grep -nE '"query_type"|"tablo"|DELETE FROM|"birim_maliyet"|"birim_fiyat|"hesap_bakiyesi|"tedarikci_bakiye|"satir_tutar|"adet"' erp_ingest.py 2>/dev/null | head -40 | sed 's/^/  /'

hr "2. GUARD — para_birimi (iki tablo) bilinen degerler"
$PSQL -c "SELECT 'satis' t, para_birimi, count(*) FROM bi_satis_faturalari GROUP BY 2 ORDER BY 3 DESC;"
$PSQL -c "SELECT 'fiyat_liste' t, para_birimi, count(*) FROM bi_fiyat_listesi_kalemler GROUP BY 2;"

hr "3. GUARD — odeme_kosulu bilinen degerler (satis)"
$PSQL -c "SELECT odeme_kosulu, count(*) FROM bi_satis_faturalari GROUP BY 1 ORDER BY 2 DESC LIMIT 30;"

hr "4. GUARD — grup_adi (stok + tedarikci) + kdv_orani + tahsilat_turu"
echo "  --- bi_stok_anlik.grup_adi ---"
$PSQL -c "SELECT grup_adi, count(*) FROM bi_stok_anlik GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'
echo "  --- bi_satis_faturalari kdv_orani (yoksa bak) / bi_tedarikci_faturalari kdv_orani ---"
$PSQL -c "SELECT kdv_orani, count(*) FROM bi_tedarikci_faturalari GROUP BY 1 ORDER BY 2 DESC LIMIT 10;" 2>&1 | sed 's/^/  /'
echo "  --- bi_fatura_tahsilat.tahsilat_turu ---"
$PSQL -c "SELECT tahsilat_turu, count(*) FROM bi_fatura_tahsilat GROUP BY 1 ORDER BY 2 DESC LIMIT 10;" 2>&1 | sed 's/^/  /'

hr "5. GUARD — marka bilinen kumesi (stok) + belge_turu/hareket_sinifi"
$PSQL -c "SELECT count(DISTINCT marka) AS marka_sayisi FROM bi_stok_anlik;"
$PSQL -c "SELECT belge_turu, count(*) FROM bi_stok_hareket GROUP BY 1 ORDER BY 2 DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "6. GUARD — ARALIKLAR (tarih + tutar tavan, x10000 dedektoru icin)"
$PSQL -c "
SELECT 'satis fatura_tarihi' k, min(fatura_tarihi)::text a, max(fatura_tarihi)::text b FROM bi_satis_faturalari
UNION ALL SELECT 'satis satir_tutar max', '0', round(max(satir_tutar))::text FROM bi_satis_faturalari
UNION ALL SELECT 'musteri_risk hesap_bakiye max', round(min(hesap_bakiyesi))::text, round(max(hesap_bakiyesi))::text FROM bi_musteri_risk;" 2>&1 | sed 's/^/  /'

hr "7. INGEST — DELETE FROM davranisi (append moduna gecerse cift sayim riski)"
sed -n '650,670p' erp_ingest.py 2>/dev/null | sed 's/^/  /'

hr "BITTI — bu, mimari soy agaci + somut guard whitelist'ini besleyecek"
