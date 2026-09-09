#!/usr/bin/env bash
# server.mjs açılış noktası + fs import + query erişimi (boot footprint hook'u için). OKUR.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. listen / createServer çağrısı (açılış noktası)"
grep -nE "\.listen\(|createServer|http.createServer|httpServer" server_container.mjs | tail -8

hr "2. fs importu var mı"
grep -nE "^import .*['\"](node:)?fs['\"]|require\(['\"]fs['\"]\)|from ['\"]fs" server_container.mjs | head -5

hr "3. query fonksiyonu tanımı (module scope mu)"
grep -nE "^(async )?function query|const query =|async function query" server_container.mjs | head -3

hr "4. dosya SONU (son 15 satır — listen genelde burada)"
tail -15 server_container.mjs

hr "BITTI"
