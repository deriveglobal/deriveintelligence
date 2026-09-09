#!/usr/bin/env bash
set -uo pipefail
cd /opt/krb-assessment || exit 1
echo "──── _finansTrendCiz kuyruk (724-756) ────"
sed -n '724,756p' shells/bi.js
echo "──── el.innerHTML = h; kaç kez tüm dosyada ────"
grep -c "el.innerHTML = h;" shells/bi.js
echo "──── 'marka-satir' zaten var mı ────"
grep -c "marka-satir" shells/bi.js || true
