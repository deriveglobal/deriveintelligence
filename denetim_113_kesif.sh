#!/usr/bin/env bash
# DENETIM_113_KESIF — LLM guvenligi: iki yolu OKU. Yamadan once.
#   1) _applyIntents: onem>=3 -> _pushSevereSignals -> patrona ANLIK e-posta (nerede, nasil)
#   2) _applyIntents: rakip sinyali -> saha_rakip_teklif'e DOGRUDAN yaziyor (onay yok)
set -uo pipefail
cd /opt/krb-assessment || exit 1
SRC="server_container.mjs"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. _applyIntents — TAM govde (nerede baslar, ne yaziyor)"
LN=$(grep -nE "_applyIntents|async function _applyIntents|const _applyIntents" "$SRC" | head -1 | cut -d: -f1)
echo "  _applyIntents satiri: $LN"
sed -n "${LN},$((LN+120))p" "$SRC" | nl -ba -v"$LN" | sed 's/^/  /'

hr "2. onem / severe / _pushSevereSignals — aciliyet e-postasi nerede tetikleniyor?"
grep -nE "onem|severe|_pushSevereSignals|pushSevere|onem *>= *3|_sahaGunlukOzet" "$SRC" | head -25 | sed 's/^/  /'

hr "3. _pushSevereSignals — TAM govde (e-posta nasil gidiyor, kime, ne siklikta)"
PN=$(grep -nE "function _pushSevereSignals|_pushSevereSignals *=" "$SRC" | head -1 | cut -d: -f1)
if [ -n "${PN:-}" ]; then sed -n "${PN},$((PN+60))p" "$SRC" | nl -ba -v"$PN" | sed 's/^/  /'; else echo "  (bulunamadi — grep ile ara)"; grep -nE "_pushSevereSignals" "$SRC" | sed 's/^/  /'; fi

hr "4. saha_rakip_teklif'e LLM DOGRUDAN mi yaziyor? (kaynak='ZIYARET'/otomatik)"
grep -nE "INSERT INTO saha_rakip_teklif|saha_rakip_teklif" "$SRC" | head -15 | sed 's/^/  /'
echo "--- rakip sinyalinin yazildigi yer (kaynak/otomatik/supheli) ---"
grep -nE "rakip.*INSERT|kaynak.*ZIYARET|supheli|otomatik|dogrulanma|taslak|onay" "$SRC" | grep -iE "rakip|supheli|taslak" | head -15 | sed 's/^/  /'

hr "5. saha_rakip_teklif — kaynak dagilimi (LLM mi insan mi besliyor)"
$PSQL -c "SELECT kaynak, count(*) FROM saha_rakip_teklif GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'
echo "--- supheli / dogrulanmis kolonlari var mi? ---"
$PSQL -c "SELECT column_name FROM information_schema.columns
          WHERE table_name='saha_rakip_teklif' AND
          (column_name ILIKE '%supheli%' OR column_name ILIKE '%dogrula%' OR column_name ILIKE '%onay%' OR column_name ILIKE '%taslak%' OR column_name ILIKE '%kaynak%');" 2>&1 | sed 's/^/  /'

hr "6. _sahaGunlukOzet — birikim/gunluk ozet zaten var mi? (e-posta oraya akmali)"
grep -nE "_sahaGunlukOzet|gunluk.*ozet|gunluk_ozet|daily.*digest" "$SRC" | head | sed 's/^/  /'

hr "BITTI — iki yama: (a) aciliyet e-postasi birikime/gunluk ozete, (b) rakip yazimi taslak/supheli"
