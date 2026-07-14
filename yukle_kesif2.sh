#!/usr/bin/env bash
# YUKLE_KESIF_2 — execFile'in HEMEN SONRASI. Tek eksik capa. Sadece OKUR.
#
# ⚠ Elimde olanlar:
#     23649  execFile('python3', ['/app/erp_ingest.py', yol, tenantId])
#     27534  async function refreshSahaMasters(db)   -> master_musteri + kirilimlar + fiyat eslesme
#     27507  async function refreshSahaCariCache(db) -> typeahead
#     30182  POST /api/saha/master-refresh -> refreshSahaMasters() ZATEN cagirilabiliyor
#   Yani fonksiyon HAZIR. Sadece YUKLEME SONRASI kimse cagirmiyor.
#
# ⚠ Eksik olan: execFile'in sonucunu isleyen blok. Onu gormeden yama yazarsam
#   yine TAHMIN etmis olurum. Dort tur boyunca capalari dosyadan okudum; bozmayacagim.
set -uo pipefail
cd /opt/krb-assessment

echo "############ execFile blogu — 23600..23720 ############"
awk 'NR>=23600 && NR<=23720 { printf "%5d| %s\n", NR, $0 }' server_container.mjs
