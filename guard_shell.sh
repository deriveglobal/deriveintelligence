#!/usr/bin/env bash
# guard_shell.sh — refuse to deploy a truncated / incomplete shell or server file.
#
# Catches the failure that killed kapatModal on 2026-07-07: a "reduced" saha.js
# silently replaced the full build. It was valid JS, so `node --check` passed —
# it was just missing half the app. Size + symbol checks catch that.
#
# Usage:  guard_shell.sh shells/saha.js
# Override (rare, intentional shrink):  GUARD_FORCE=1 guard_shell.sh shells/saha.js
set -uo pipefail
cd /opt/krb-assessment

F="${1:-}"
[ -n "$F" ] || { echo "GUARD_FAIL: no file given"; exit 1; }
[ -f "$F" ] || { echo "GUARD_FAIL: $F does not exist"; exit 1; }

# ── 1) syntax must parse ──────────────────────────────────────────────
cp "$F" /tmp/_guard_check.mjs
if ! node --check /tmp/_guard_check.mjs 2>/dev/null; then
  echo "GUARD_FAIL: $F does not parse (syntax error)"; exit 1
fi

# ── 2) byte-size shrink vs last committed version ─────────────────────
NEW_B=$(wc -c < "$F" | tr -d ' ')
OLD_B=$(git show "HEAD:$F" 2>/dev/null | wc -c | tr -d ' ')
OLD_B=${OLD_B:-0}

# ── 3) function-count shrink (generic truncation detector) ────────────
NEW_F=$(grep -cE '^\s*(async +)?function +[a-zA-Z_]' "$F" || true)
OLD_F=$(git show "HEAD:$F" 2>/dev/null | grep -cE '^\s*(async +)?function +[a-zA-Z_]' || true)
OLD_F=${OLD_F:-0}

FAILED=0
if [ "$OLD_B" -gt 0 ]; then
  MIN_B=$(( OLD_B * 90 / 100 ))
  if [ "$NEW_B" -lt "$MIN_B" ]; then
    echo "GUARD_FAIL: $F shrank to ${NEW_B}B from committed ${OLD_B}B (>10% smaller)"
    FAILED=1
  fi
fi
if [ "$OLD_F" -gt 0 ]; then
  MIN_F=$(( OLD_F * 90 / 100 ))
  if [ "$NEW_F" -lt "$MIN_F" ]; then
    echo "GUARD_FAIL: $F has $NEW_F functions vs committed $OLD_F (>10% fewer)"
    FAILED=1
  fi
fi

# ── 4) must-exist symbols (saha.js: the ones a truncation would drop) ──
case "$F" in
  */saha.js)
    for sym in \
      "function kapatModal" \
      "window.kapatModal" \
      "function loadView" \
      "function musteriSecModal" \
      "function yeniMusteriModal" \
      "function ziyaretFormModal" \
      "function musteriDetayModal" \
      "function vBugun" \
      "function vMusteriler" \
      "function vSistem" \
      "function kontrolPaneliYukle"
    do
      grep -qF "$sym" "$F" || { echo "GUARD_FAIL: $F missing required symbol: $sym"; FAILED=1; }
    done
    ;;
esac

if [ "$FAILED" -ne 0 ]; then
  if [ "${GUARD_FORCE:-0}" = "1" ]; then
    echo "GUARD_FORCE=1 → overriding the failures above. Hope you meant it."
  else
    echo "GUARD: refusing to deploy $F. If this shrink is intentional, re-run with GUARD_FORCE=1."
    exit 1
  fi
fi

echo "GUARD_OK: $F — ${NEW_B}B / ${NEW_F} fns (committed: ${OLD_B}B / ${OLD_F} fns)"
exit 0
