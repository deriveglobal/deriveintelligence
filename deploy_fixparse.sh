#!/usr/bin/env bash
# FINPARSE_FIX_V1 deploy — robust JSON parse. Bugünkü boş satırı sil, rebuild, regen, doğrula. Idempotent.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
cp server_container.mjs server_container.mjs.bak.$(date +%s)
printf '%s' 'IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIEZJTlBBUlNFX0ZJWF9WMSDigJQgQUkgw6fEsWt0xLFzxLEgSlNPTiBheXLEscWfdMSxcm1hecSxIHNhxJ9sYW1sYcWfdMSxcjogYGBganNvbiBmZW5jZSB0ZW1pemxlLCBkb8SfcnVkYW4gcGFyc2UsCiMge2ljZ29ydWxlcjpbLi4uXX0gc2FybWFsxLEsIGJyYWNrZXQtc2xpY2UgZmFsbGJhY2s7IGJvxZ9zYSBoYW0gbWV0bmkgbG9nbGEgKyBiYWdsYW0uX2hhbSdhIHlheiAodGXFn2hpcykuCiMgbWF4X3Rva2VucyAxNTAwLT4yMjAwLiBJZGVtcG90ZW50LgpkZWYgcmVhZChwKTogcmV0dXJuIG9wZW4ocCwgZW5jb2Rpbmc9InV0Zi04IikucmVhZCgpCmRlZiB3cml0ZShwLCBzKTogb3BlbihwLCAidyIsIGVuY29kaW5nPSJ1dGYtOCIpLndyaXRlKHMpCgpGUCA9ICJzZXJ2ZXJfY29udGFpbmVyLm1qcyIKcyA9IHJlYWQoRlApCmlmICJGSU5QQVJTRV9GSVhfVjEiIGluIHM6CiAgICBwcmludCgiZmlucGFyc2UtZml4OiBhbHJlYWR5IHByZXNlbnQsIHNraXAiKTsgcHJpbnQoIkRPTkUuIik7IHJhaXNlIFN5c3RlbUV4aXQKCiMgKDEpIG1heF90b2tlbnMgYnVtcAphMCA9ICdtb2RlbDogImNsYXVkZS1zb25uZXQtNC02IiwgbWF4X3Rva2VuczogMTUwMCwgc3lzdGVtOiBfRklOX1NZUywnCm4wID0gJ21vZGVsOiAiY2xhdWRlLXNvbm5ldC00LTYiLCBtYXhfdG9rZW5zOiAyMjAwLCBzeXN0ZW06IF9GSU5fU1lTLCAvLyBGSU5QQVJTRV9GSVhfVjEnCmFzc2VydCBzLmNvdW50KGEwKSA9PSAxLCAibWF4X3Rva2VucyBhbmNob3IiCnMgPSBzLnJlcGxhY2UoYTAsIG4wLCAxKQoKIyAoMikgcGFyc2UgYmxvxJ91bnUgc2HEn2xhbWxhxZ90xLFyCm9sZCA9ICgnICBsZXQgdHh0ID0gKG1zZy5jb250ZW50IHx8IFtdKS5maWx0ZXIoeCA9PiB4LnR5cGUgPT09ICJ0ZXh0IikubWFwKHggPT4geC50ZXh0KS5qb2luKCIiKS50cmltKCk7XG4nCiAgICAgICAnICBjb25zdCBpID0gdHh0LmluZGV4T2YoIlsiKSwgaiA9IHR4dC5sYXN0SW5kZXhPZigiXSIpO1xuJwogICAgICAgJyAgbGV0IGFyciA9IFtdO1xuJwogICAgICAgJyAgaWYgKGkgPj0gMCAmJiBqID4gaSkgeyB0cnkgeyBhcnIgPSBKU09OLnBhcnNlKHR4dC5zbGljZShpLCBqICsgMSkpOyB9IGNhdGNoIChlKSB7IGFyciA9IFtdOyB9IH1cbicKICAgICAgICcgIGlmICghQXJyYXkuaXNBcnJheShhcnIpKSBhcnIgPSBbXTtcbicKICAgICAgICcgIHJldHVybiB7IGljZ29ydWxlcjogYXJyLCBiYWdsYW06IGN0eCB9OycpCm5ldyA9ICgnICBsZXQgcmF3ID0gKG1zZy5jb250ZW50IHx8IFtdKS5maWx0ZXIoeCA9PiB4LnR5cGUgPT09ICJ0ZXh0IikubWFwKHggPT4geC50ZXh0KS5qb2luKCIiKS50cmltKCk7XG4nCiAgICAgICAnICBsZXQgdHh0ID0gcmF3LnJlcGxhY2UoL2BgYGpzb24vZ2ksICIiKS5yZXBsYWNlKC9gYGAvZywgIiIpLnRyaW0oKTtcbicKICAgICAgICcgIGNvbnN0IF90cCA9ICh0KSA9PiB7IHRyeSB7IHJldHVybiBKU09OLnBhcnNlKHQpOyB9IGNhdGNoIChlKSB7IHJldHVybiBudWxsOyB9IH07XG4nCiAgICAgICAnICBsZXQgYXJyID0gbnVsbDtcbicKICAgICAgICcgIGxldCBwID0gX3RwKHR4dCk7XG4nCiAgICAgICAnICBpZiAocCAmJiAhQXJyYXkuaXNBcnJheShwKSAmJiBBcnJheS5pc0FycmF5KHAuaWNnb3J1bGVyKSkgcCA9IHAuaWNnb3J1bGVyO1xuJwogICAgICAgJyAgaWYgKEFycmF5LmlzQXJyYXkocCkpIGFyciA9IHA7XG4nCiAgICAgICAnICBpZiAoIWFycikgeyBjb25zdCBpID0gdHh0LmluZGV4T2YoIlsiKSwgaiA9IHR4dC5sYXN0SW5kZXhPZigiXSIpOyBpZiAoaSA+PSAwICYmIGogPiBpKSB7IGNvbnN0IHAyID0gX3RwKHR4dC5zbGljZShpLCBqICsgMSkpOyBpZiAoQXJyYXkuaXNBcnJheShwMikpIGFyciA9IHAyOyB9IH1cbicKICAgICAgICcgIGlmICghQXJyYXkuaXNBcnJheShhcnIpKSBhcnIgPSBbXTtcbicKICAgICAgICcgIGlmICghYXJyLmxlbmd0aCkgeyBjb25zb2xlLmVycm9yKCJbZmluLWljZ29ydV0gcGFyc2UgYm9zIC0gaGFtKDAuLjMwMCk6IiwgcmF3LnNsaWNlKDAsIDMwMCkpOyBjdHguX2hhbSA9IHJhdy5zbGljZSgwLCA4MDApOyB9XG4nCiAgICAgICAnICByZXR1cm4geyBpY2dvcnVsZXI6IGFyciwgYmFnbGFtOiBjdHggfTsnKQphc3NlcnQgcy5jb3VudChvbGQpID09IDEsICJwYXJzZSBibG9jayBhbmNob3IiCnMgPSBzLnJlcGxhY2Uob2xkLCBuZXcsIDEpCgp3cml0ZShGUCwgcykKcHJpbnQoImZpbnBhcnNlLWZpeDogcm9idXN0IEpTT04gcGFyc2UgKyBtYXhfdG9rZW5zIDIyMDAgKyBoYW0gdGXFn2hpcyIpCnByaW50KCJET05FLiIpCg==' | base64 -d > fix_finparse.py
python3 fix_finparse.py
node --check server_container.mjs && echo SERVER_OK

echo "== bugünkü boş satırı sil (regen için) =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "DELETE FROM bi_finansal_icgoru WHERE gun=CURRENT_DATE AND jsonb_array_length(icgoruler)=0;"

docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
echo "== 95sn bekle (scheduler 45sn + üretim) =="
sleep 95
echo "== tablo =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT to_char(gun,'YYYY-MM-DD') gun, jsonb_array_length(icgoruler) n, to_char(uretildi_at,'HH24:MI:SS') uretim FROM bi_finansal_icgoru ORDER BY uretildi_at DESC LIMIT 3;"
echo "== ilk içgörü (varsa) =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT icgoruler->0->>'baslik' baslik, icgoruler->0->>'etki_tl' etki_tl FROM bi_finansal_icgoru WHERE gun=CURRENT_DATE;"
echo "== boşsa ham model çıktısı (_ham) =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT left(baglam->>'_ham',400) ham FROM bi_finansal_icgoru WHERE gun=CURRENT_DATE AND jsonb_array_length(icgoruler)=0;"
echo "-- loglar --"
docker logs --tail 300 krb-assessment 2>&1 | grep -i "fin-icgoru" | tail -6 || echo "(log yok)"
echo "== DONE =="
