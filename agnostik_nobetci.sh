#!/usr/bin/env bash
# ============================================================
# Derive · AGNOSTİK NÖBETÇİ (pre-deploy gate) — SALT-OKUNUR.
# text=uuid tuzagi ($N::uuid param) + LIKE 'LASTIK%' + KRB-uuid drift'ini
# DEPLOY ONCESI yakalar. Exit 0 = temiz · Exit 1 = drift (deploy dur).
# ============================================================
set -uo pipefail
SRC="${SRC:-/opt/krb-assessment/server_container.mjs}"
KRB="${KRB:-f8a5d20f-ecf8-4ce2-a492-69268fbb03fa}"
ALLOW_GRUP_IN_LASTIK="${ALLOW_GRUP_IN_LASTIK:-2}"   # servis/yenileme + _KB taksonomi kovasi (kasitli)
# Helper-wrapper muaf: 'SELECT evren_x($N::uuid)' tek-basina lookup -> text=uuid IMKANSIZ.
EVREN_WRAP_MUAF="${EVREN_WRAP_MUAF:-SELECT evren_[a-z_]+\(\\\$[0-9]+::uuid\)}"

if [ ! -f "$SRC" ]; then
  echo "NÖBETÇİ: kaynak bulunamadi: $SRC  (SRC=... ile yol ver)"; exit 2
fi

FAIL=0
hr(){ printf '%s\n' "------------------------------------------------------------"; }

gate(){
  local etiket="$1" pat="$2" cap="$3" excl="${4:-}"
  local hits n
  if [ -n "$excl" ]; then
    hits=$(grep -nE "$pat" "$SRC" 2>/dev/null | grep -vE "$excl" || true)
  else
    hits=$(grep -nE "$pat" "$SRC" 2>/dev/null || true)
  fi
  n=$(printf '%s' "$hits" | grep -c . || true); n=${n:-0}
  if [ "$n" -le "$cap" ]; then
    printf "  [OK]   %-46s %s (izin<=%s)\n" "$etiket" "$n" "$cap"
  else
    printf "  [FAIL] %-46s %s (izin<=%s)\n" "$etiket" "$n" "$cap"
    printf '%s\n' "$hits" | head -8 | sed 's/^/         · /'
    FAIL=1
  fi
}
warn(){
  local etiket="$1" pat="$2" n
  n=$(grep -cE "$pat" "$SRC" 2>/dev/null || true); n=${n:-0}
  printf "  [uyari] %-45s %s\n" "$etiket" "$n"
}

echo "############ AGNOSTİK NÖBETÇİ · kaynak: $SRC ############"
hr
echo "SERT GEÇİTLER (herhangi biri FAIL -> exit 1, deploy dur):"
gate "taksonomi(kategori,\$N::uuid) param tuzagi" \
     "(kategori_segment|kategori_sezon)\([^)]*\\\$[0-9]+::uuid" 0
gate "evren_*(\$N) bind-param (sutun bekle)" \
     "(evren_desen|evren_gruplar|evren_tanim|evren_cekirdek|evren_yuksek_marj)\(\s*\\\$[0-9]+" 0 \
     "$EVREN_WRAP_MUAF"
gate "grup_adi (I)LIKE 'LASTIK%'" \
     "grup_adi[[:space:]]+I?LIKE[[:space:]]*'LASTIK%'" 0
gate "KRB tenant uuid hardcode" "$KRB" 0
gate "grup_adi IN (...'LASTIK...)" \
     "grup_adi[[:space:]]+IN[[:space:]]*\([^)]*'LASTIK" "$ALLOW_GRUP_IN_LASTIK"

hr
echo "YUMUŞAK İZLEME (bloklamaz):"
warn "krb.com.tr (e-posta literali)"        "krb\.com\.tr"
warn "'lastik toptanc' kimlik ifadesi"      "lastik toptanc"
warn "ciplak PSR/TBR/OTR SQL literali"      "'(PSR|TBR|OTR)'"
warn "evren_desen( kullanimi (saglik)"      "evren_desen\("
warn "evren_gruplar( kullanimi (saglik)"    "evren_gruplar\("

hr
if [ "$FAIL" -eq 0 ]; then
  echo "NÖBETÇİ: TEMİZ ✓  — deploy'a devam."; exit 0
else
  echo "NÖBETÇİ: DRİFT ✗  — [FAIL] satirlarini kapat, sonra build et."
  echo "  Kural (devir §2): tenant'i helper'a DAİMA SÜTUN ver — kategori_segment(kategori, tenant_id::uuid) — ASLA \$N::uuid param."
  exit 1
fi
