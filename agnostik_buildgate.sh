#!/bin/sh
# AGNOSTIK BUILD-GATE — Dockerfile RUN'da calisir; image /app/server.mjs'i tarar.
# MUTLAK drift (KRB-uuid · LIKE 'LASTIK%' · taksonomi $N::uuid param) -> build patlar.
# Dosya yoksa WARN + gecer (yanlis yol build'i briklemesin).
f="${1:-/app/server.mjs}"
if [ ! -f "$f" ]; then
  echo "AGNOSTIK-GATE [uyari]: $f yok — atlaniyor (COPY yolu'nu kontrol et)"; exit 0
fi
hit=$(grep -nE "f8a5d20f-ecf8-4ce2-a492-69268fbb03fa|grup_adi I?LIKE 'LASTIK%'|(kategori_segment|kategori_sezon)\([^)]*\\\$[0-9]+::uuid" "$f")
if [ -n "$hit" ]; then
  echo "############################################################"
  echo "# AGNOSTIK-GATE: MUTLAK DRIFT -> BUILD DURDURULDU (devir kural 2)"
  echo "############################################################"
  echo "$hit" | head -20
  echo "Kural: tenant'i helper'a DAIMA SUTUN ver (kategori_segment(kategori, tenant_id::uuid)); LASTIK%/KRB-uuid GOMME."
  exit 1
fi
echo "AGNOSTIK-GATE: temiz ✓ ($f)"
exit 0
