#!/usr/bin/env bash
# 62_SORGU_HARITASI — "62 sorgu" dedim ama HANGI EKRANLAR oldugunu bilmiyordum.
#
# ⚠ Sayiyi grep'ten aldim, ANLAMINI degil. Bu bir liste, bir ANLAYIS degil.
#   Hangi ekran · hangi sayi · kim goruyor — bunu bilmeden
#   "62 sorguyu duzelttim" demek, bugun elestirdigim seyin ta kendisi olur.
#
# Her referansin HANGI UC NOKTANIN icinde oldugunu cikariyorum. Sadece OKUR.
set -uo pipefail
cd /opt/krb-assessment

echo "############ HER REFERANS -> HANGI UC NOKTA ############"
python3 - <<'PY'
import re, pathlib
s = pathlib.Path("server_container.mjs").read_text(encoding="utf-8").split("\n")

# uc nokta tanimlarini topla: satir no -> yol
uc = []
pat = re.compile(r'''(?:path|url\.pathname)\s*===?\s*["'`](/api/[^"'`]+)["'`]|path\.match\(new RegExp\(`\^(/api/[^$`]+)''')
for i, l in enumerate(s, 1):
    m = pat.search(l)
    if m:
        yol = m.group(1) or m.group(2)
        met = "GET"
        mm = re.search(r'method\s*===?\s*["\'](\w+)["\']', l)
        if mm: met = mm.group(1)
        uc.append((i, met, yol))

def sahip(satir):
    """bu satirdan GERIYE dogru en yakin uc nokta"""
    en = None
    for (i, met, yol) in uc:
        if i <= satir: en = (i, met, yol)
        else: break
    return en

OLU = ["bi_stok_durumu", "bi_stok_hareketleri", "bi_musteri_bakiye", "bi_odeme_gecmisi"]
for t in OLU:
    print(f"\n══════════ {t} ══════════")
    gruplar = {}
    for i, l in enumerate(s, 1):
        if t in l and not l.strip().startswith("//") and not l.strip().startswith("--"):
            sh = sahip(i)
            k = f"{sh[1]} {sh[2]}" if sh else "(uc nokta disi — sema/sablon)"
            gruplar.setdefault(k, []).append(i)
    for k in sorted(gruplar, key=lambda x: -len(gruplar[x])):
        satirlar = gruplar[k]
        print(f"  {len(satirlar):2d}×  {k}")
        print(f"        satirlar: {', '.join(map(str, satirlar[:12]))}{' …' if len(satirlar)>12 else ''}")
PY

echo
echo "############ ⚠ ARAYUZDE HANGI EKRAN? — bi.js hangi uc noktalari cagiriyor ############"
for E in /api/bi/ana /api/bi/analiz /api/bi/finans /api/bi/stok /api/bi/sezon /api/bi/maliyet; do
  N=$(grep -c "$E" shells/bi.js 2>/dev/null || echo 0)
  [ "$N" -gt 0 ] && echo "  $E  -> bi.js'de $N kez"
done
echo
echo "  --- bi.js'nin cagirdigi TUM /api/bi uc noktalari ---"
grep -o '/api/bi/[a-z0-9/_-]*' shells/bi.js | sort | uniq -c | sort -rn | head -20
