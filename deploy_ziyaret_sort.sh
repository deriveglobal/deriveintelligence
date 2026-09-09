#!/usr/bin/env bash
# deploy_ziyaret_sort.sh — Ziyaretler listesi KESIN azalan (en yeni ustte). saha.js (responsive: mobil+masaustu). backups/ HARIC.
set -e
cd /opt/krb-assessment
TS=$(date +%s)
echo "IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIFpJWUFSRVRfU0lSQV9WMSDigJQgWml5YXJldGxlciBsaXN0ZXNpIEtFU0lOIGF6YWxhbiAoZW4geWVuaSB1c3R0ZSk6IGNoZWNraW5fYXQgKGtlc2luIHNhYXQpIC0+IHppeWFyZXRfdGFyaWhpIC0+IHBsYW5sYW5hbl90YXJpaC4KIyAgIHNhaGEuanMgcmVzcG9uc2l2ZSAobW9iaWwrbWFzYXVzdHUgYXluaSBzaGVsbCkuIFN1bnVjdSBkYXRlLURFU0MgZG9udXlvcmR1IGFtYSBheW5pLWd1biBpY2luZGUgY3JlYXRlZF9hdCdhIGR1c3V5b3JkdS4KaW1wb3J0IHN5cwpGUD1zeXMuYXJndlsxXSBpZiBsZW4oc3lzLmFyZ3YpPjEgZWxzZSAiL29wdC9rcmItYXNzZXNzbWVudC9zaGVsbHMvc2FoYS5qcyIKcz1vcGVuKEZQLGVuY29kaW5nPSJ1dGYtOCIpLnJlYWQoKQppZiAiWklZQVJFVF9TSVJBX1YxIiBpbiBzOiBwcmludCgiemF0ZW4geWFtYWxpLCBhdGxhbmRpIik7IHByaW50KCJET05FLiIpOyByYWlzZSBTeXN0ZW1FeGl0Ck9MRD0nJycgICAgY29uc3QgeyB6aXlhcmV0bGVyIH0gPSBhd2FpdCBhcGkoYC9hcGkvc2FoYS96aXlhcmV0bGVyP2R1cnVtPVRBTUFNTEFOREkke3RpcFFTKCl9YCk7CiAgICBTLnppeWFyZXRsZXIgPSB6aXlhcmV0bGVyOycnJwpORVc9JycnICAgIGNvbnN0IHsgeml5YXJldGxlciB9ID0gYXdhaXQgYXBpKGAvYXBpL3NhaGEveml5YXJldGxlcj9kdXJ1bT1UQU1BTUxBTkRJJHt0aXBRUygpfWApOwogICAgLyogWklZQVJFVF9TSVJBX1YxIOKAlCBrZXNpbiBhemFsYW4gKGVuIHllbmkgdXN0dGUpICovCiAgICBjb25zdCBfemsgPSB6ID0+IChEYXRlLnBhcnNlKHouY2hlY2tpbl9hdCB8fCB6LnppeWFyZXRfdGFyaWhpIHx8IHoucGxhbmxhbmFuX3RhcmloIHx8ICIiKSB8fCAwKTsKICAgIHppeWFyZXRsZXIuc29ydCgoYSwgYikgPT4gX3prKGIpIC0gX3prKGEpKTsKICAgIFMueml5YXJldGxlciA9IHppeWFyZXRsZXI7JycnCmM9cy5jb3VudChPTEQpOyBhc3NlcnQgYz09MSwiYW5rb3IgYnVsdW5kdT0lZCIlYwpzPXMucmVwbGFjZShPTEQsTkVXKQpvcGVuKEZQLCJ3IixlbmNvZGluZz0idXRmLTgiKS53cml0ZShzKQpwcmludCgiICB6aXlhcmV0LXNvcnQ6IG9rIik7IHByaW50KCJ5YW1hbGFuZGk6IFpJWUFSRVRfU0lSQV9WMSIpOyBwcmludCgiRE9ORS4iKQo=" | base64 -d > /tmp/patch_ziyaret_sort.py
FILES=$(grep -rl 'durum=TAMAMLANDI' --include=saha.js . 2>/dev/null | grep -v backups || true)
[ -n "$FILES" ] || { echo "HATA: canli saha.js bulunamadi"; exit 1; }
for F in $FILES; do
  echo "hedef: $(ls -la "$F" | awk '{print $NF, $5}')"
  cp "$F" "$F.bak.$TS"
  python3 /tmp/patch_ziyaret_sort.py "$F"
  node --check "$F" && echo "  ✓ $F ok" || { echo "HATA: $F syntax"; exit 1; }
  grep -q 'ZIYARET_SIRA_V1' "$F" && echo "  ✓ sira yamasi mevcut" || { echo "HATA: yama yok"; exit 1; }
done
echo "=== docker build + recreate ==="
docker build -t krb-assessment:secure . >/tmp/build.log 2>&1 && echo "build ok" || { echo "BUILD HATASI:"; tail -25 /tmp/build.log; exit 1; }
docker compose up -d --force-recreate krb-assessment && echo "recreate ok"
echo "BITTI. Ziyaretler artik en yeni ustte (checkin saati -> ziyaret tarihi)."
