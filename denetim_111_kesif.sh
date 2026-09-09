#!/usr/bin/env bash
# DENETIM_111_KESIF — enum ailesi. SADECE OKUR. Yamadan once baglami gor.
#   1) rapor durum IN (...) — ESKI_NOKTA neden disarida, ne anlama geliyor?
#   2) durum uretim fonksiyonu — RISKLI_NOKTA uretiyor mu?
#   3) para_birimi TL/TRY — nerede YAZILIYOR (ingest), nerede OKUNUYOR (filtre)?
#   4) teklif SUNULDU->KAZANILDI ucu (29722) + arayuz tetikleyicisi var mi?
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SRC="server_container.mjs"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. RAPOR — durum IN (...) BAGLAMI (30640-30680, 30760-30790)"
sed -n '30640,30680p' "$SRC" | nl -ba -v30640 | sed 's/^/  /'
echo "  ── ikinci yer ──"
sed -n '30760,30790p' "$SRC" | nl -ba -v30760 | sed 's/^/  /'

hr "2. durum URETIM FONKSIYONU — hangi degerleri uretiyor?"
$PSQL -c "SELECT pg_get_functiondef('saha_musteri_durum_yenile()'::regprocedure);" 2>&1 | grep -iE "YENI_NOKTA|AKTIF|PASIF|ESKI|RISKLI|WHEN|son_fatura|interval" | sed 's/^/  /'
echo "  ⚠ RISKLI_NOKTA bu ciktida YOKSA: fonksiyon uretmiyor, kod baska yerde yaziyor ya da olu deger."
echo "--- RISKLI_NOKTA'yi YAZAN baska kod var mi? (SET/UPDATE/INSERT ile) ---"
grep -nE "durum *= *'RISKLI_NOKTA'|'RISKLI_NOKTA'" "$SRC" | sed 's/^/  /'

hr "3. PARA_BIRIMI — YAZAN (ingest) ve OKUYAN (filtre) yerler"
echo "--- kodda para_birimi gecen TUM satirlar ---"
grep -nE "para_birimi" "$SRC" | head -30 | sed 's/^/  /'
echo "--- erp_ingest.py'de para_birimi/TL/TRY yaziliyor mu? ---"
grep -nE "para_birimi|'TL'|'TRY'|\"TL\"|\"TRY\"" erp_ingest.py 2>/dev/null | head -20 | sed 's/^/  /'
echo "--- fiyat listesi YUKLEME ucu para_birimi'ni nasil set ediyor? ---"
grep -nE "para_birimi" "$SRC" | grep -iE "insert|values|=|VALUES|COALESCE" | head | sed 's/^/  /'

hr "4. TEKLIF SONUC ucu (29722 civari) + arayuz"
sed -n '29710,29760p' "$SRC" | nl -ba -v29710 | sed 's/^/  /'
echo "--- arayuz: saha.js'te SUNULDU/KAZANILDI/sonuc-isaretle butonu var mi? ---"
grep -nE "KAZANILDI|KAYBEDILDI|SUNULDU|sonuc|Kazan|Kaybet" shells/saha.js | head -20 | sed 's/^/  /'

hr "BITTI — yama planini bu ciktidan kuracagim"
