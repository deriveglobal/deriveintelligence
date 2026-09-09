#!/usr/bin/env bash
# IOS_NOZOOM_V1 deploy — form kontrolleri 16px (iOS odak-zoom engeli). Rule 5. Idempotent.
set -e
cd /opt/krb-assessment
if [ -f shells/saha.js ]; then SAHA=shells/saha.js; else SAHA=$(find . -maxdepth 3 -name saha.js -not -path '*/backups/*' -not -path '*/node_modules/*'|head -1); fi
[ -f "$SAHA" ] || { echo "HATA: saha.js yok"; exit 1; }
cp "$SAHA" "$SAHA.bak.$(date +%s)"
printf '%s' 'IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIElPU19OT1pPT01fVjEg4oCUIGlPUywgZm9udC1zaXplIDwgMTZweCBvbGFuIGlucHV0J2Egb2Rha2xhbsSxbmNhIHNheWZhecSxIFpPT00nbGFyIHZlIHpvb20ga2FsxLFyCiMgKCJla3JhbiBiw7x5w7xkw7wiKS4gVMO8bSBmb3JtIGtvbnRyb2xsZXJpIDE2cHgnZSBzYWJpdGxlbmlyIOKGkiBvZGFrdGEgem9vbSBvbG1hei4gRWJhdCBhcmFtYSBrdXR1c3UgKDE0cHgpCiMgYW5hIHRldGlrbGV5aWNpeWRpOyBheXLEsWNhIDE2cHgnZSDDp2VraWxkaS4gc2FoYS5qcyBDU1MuIElkZW1wb3RlbnQuCmRlZiByZWFkKHApOiByZXR1cm4gb3BlbihwLCBlbmNvZGluZz0idXRmLTgiKS5yZWFkKCkKZGVmIHdyaXRlKHAsIHMpOiBvcGVuKHAsICJ3IiwgZW5jb2Rpbmc9InV0Zi04Iikud3JpdGUocykKCkZQID0gInNhaGEuanMiCnMgPSByZWFkKEZQKQppZiAiSU9TX05PWk9PTV9WMSIgaW4gczoKICAgIHByaW50KCJub3pvb206IGFscmVhZHkgcHJlc2VudCwgc2tpcCIpOyBwcmludCgiRE9ORS4iKTsgcmFpc2UgU3lzdGVtRXhpdAoKIyAoMSkgZ2xvYmFsIGt1cmFsOiBmb3JtIGtvbnRyb2xsZXJpID49MTZweCAoaU9TIG9kYWstem9vbSBlxZ9pxJ9pKQphMSA9ICIgIC5jaGlwLm9ue2JhY2tncm91bmQ6IzM4YmRmODtib3JkZXItY29sb3I6IzM4YmRmODtjb2xvcjojMGYxNzJhO2ZvbnQtd2VpZ2h0OjcwMH0iCm4xID0gKCIgIC5jaGlwLm9ue2JhY2tncm91bmQ6IzM4YmRmODtib3JkZXItY29sb3I6IzM4YmRmODtjb2xvcjojMGYxNzJhO2ZvbnQtd2VpZ2h0OjcwMH1cbiIKICAgICAgIiAgaW5wdXQsc2VsZWN0LHRleHRhcmVhe2ZvbnQtc2l6ZToxNnB4ICFpbXBvcnRhbnR9IC8qIElPU19OT1pPT01fVjEg4oCUIDwxNnB4IGlucHV0dGEgaU9TIG9kYWt0YSB6b29tIHlhcGFyICovIikKYXNzZXJ0IHMuY291bnQoYTEpID09IDEsICJjaGlwLm9uIGFuY2hvciIKcyA9IHMucmVwbGFjZShhMSwgbjEsIDEpCgojICgyKSBFYmF0IGFyYW1hIGt1dHVzdSBpbmxpbmUgMTRweCAtPiAxNnB4IChuZXQgb2xzdW4pCmEyID0gInBhZGRpbmc6MTFweDtib3JkZXI6MXB4IHNvbGlkICNjYmQ1ZTE7Ym9yZGVyLXJhZGl1czo4cHg7Zm9udC1zaXplOjE0cHg7YmFja2dyb3VuZDojZmZmO2NvbG9yOiMwZjE3MmFcIj4iCm4yID0gInBhZGRpbmc6MTFweDtib3JkZXI6MXB4IHNvbGlkICNjYmQ1ZTE7Ym9yZGVyLXJhZGl1czo4cHg7Zm9udC1zaXplOjE2cHg7YmFja2dyb3VuZDojZmZmO2NvbG9yOiMwZjE3MmFcIj4iCmFzc2VydCBzLmNvdW50KGEyKSA9PSAxLCAiZWstcSBpbnB1dCBhbmNob3IiCnMgPSBzLnJlcGxhY2UoYTIsIG4yLCAxKQoKd3JpdGUoRlAsIHMpCnByaW50KCJub3pvb206IGlucHV0IDE2cHgga3VyYWzEsSArIGVrLXEgMTZweCIpCnByaW50KCJET05FLiIpCg==' | base64 -d > /tmp/ios_nozoom.py
SDIR=$(dirname "$SAHA"); cp /tmp/ios_nozoom.py "$SDIR/ios_nozoom.py"
( cd "$SDIR" && python3 ios_nozoom.py ) && rm -f "$SDIR/ios_nozoom.py"
node --check "$SAHA" && echo SAHA_OK
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 4
docker exec krb-assessment sh -c "grep -c IOS_NOZOOM_V1 /app/shells/saha.js" || true
echo "== DONE =="
