#!/usr/bin/env bash
# POST body-okuma + sendJson deseni (itiraz route). OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. POST /api/bi/itiraz TAM (body parse + sendJson deseni) 23867-23935"
sed -n '23867,23935p' server_container.mjs

hr "2. sendJson imzası + body-read helper var mı"
grep -nE "function sendJson|async function readBody|function readBody|readJsonBody|parseBody|for await" server_container.mjs | head -10 | sed 's/^/  /'

hr "BITTI"
