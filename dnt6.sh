echo "═══════════ 22000: POST /api/tenant/users/invite ═══════════"
sed -n '22000,22030p' server_container.mjs
echo
echo "═══════════ 25210: POST /api/bi/ingest ═══════════"
sed -n '25210,25248p' server_container.mjs
echo
echo "═══════════ 16488: POST /api/frameworks/import-fleet (auth yok teyidi) ═══════════"
sed -n '16480,16495p' server_container.mjs
echo
echo "═══════════ tid — 20981 kapsaminda gercekten var mi ═══════════"
grep -nE "^\s*(const|let|var) tid\b|^\s*(const|let|var) \{[^}]*tid[^}]*\}" server_container.mjs | head
echo "--- handleApi disinda tid tanimi:"
awk 'NR<20981 && /(const|let|var) tid *=/ {print NR": "$0}' server_container.mjs | tail -3
