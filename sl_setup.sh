#!/usr/bin/env bash
# SL cok-tenant kurulum (BIR KEZ): sl.d/ dizini + KRB env dosyasi (mevcut sl.env'den).
# Secret'lara DOKUNMAZ — mevcut sl.env'i temel alir, yalniz SL_TENANT + SL_BASE_URL ekler.
set -euo pipefail
BASE=/opt/krb-assessment
mkdir -p "$BASE/sl.d"
if [ -f "$BASE/sl.d/krb.env" ]; then
  echo "sl.d/krb.env zaten var — dokunulmadi."
else
  if [ ! -f "$BASE/sl.env" ]; then echo "HATA: $BASE/sl.env yok"; exit 1; fi
  {
    cat "$BASE/sl.env"
    grep -q 'SL_TENANT'   "$BASE/sl.env" || echo 'export SL_TENANT=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
    grep -q 'SL_BASE_URL' "$BASE/sl.env" || echo 'export SL_BASE_URL=http://185.86.246.212:8090'
  } > "$BASE/sl.d/krb.env"
  chmod 600 "$BASE/sl.d/krb.env"
  echo "olusturuldu: sl.d/krb.env (KRB)"
fi
echo "--- sl.d/ icerik (secret degerleri gizli) ---"
for f in "$BASE"/sl.d/*.env; do
  echo "  $f:"; sed -E 's/(SL_(USER|PASS|SECRET|TOKEN))=.*/\1=***/' "$f" | sed 's/^/    /'
done
echo "Yeni tenant SL istenirse: $BASE/sl.d/<ad>.env (SL_TENANT/SL_USER/SL_PASS/SL_BASE_URL)."
