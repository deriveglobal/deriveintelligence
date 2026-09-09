# -*- coding: utf-8 -*-
# CIRO_UI4_DK_V1 (masaüstü) — "ERP kapsamı" barını DOĞRU metriğe bağla.
#   HATA: server 'kapsam' = ziyaret edilen benzersiz / atanan portföy → rep kendi portföyü
#   dışındaki müşteriyi ziyaret edince %100'ü AŞAR (ekranda %111.2 görüldü) ve etiketle çelişir.
#   DOĞRU: "ERP kapsamı" = ziyaret edilen müşterilerin ERP'ye bağlı oranı = eslesen / benzersiz (0-100).
#   Bu, altındaki "🔒 X müşteri bağlanınca…" rozetiyle TEK bir hikaye anlatır. Sadece frontend.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "CIRO_UI4_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "CIRO_UI3_DK_V1" in s, "HATA: once CIRO_UI3_DK deploy edilmeli"

# 1) hero ortalama: portföy-reach ort. YERINE ekip ERP eşleşme oranı (toplam eslesen / toplam benzersiz)
o1 = ("        const kapsamlar = R.map(r => r.kapsam).filter(x => x != null).map(Number);\n"
      "        const ortKapsam = kapsamlar.length ? Math.round(kapsamlar.reduce((s, x) => s + x, 0) / kapsamlar.length) : null;")
n1 = ("        /* CIRO_UI4_DK_V1: ERP kapsamı = eslesen/benzersiz (0-100), portföy-reach değil */\n"
      "        const toplamEsl = R.reduce((s, r) => s + (Number(r.eslesen) || 0), 0);\n"
      "        const toplamBenz = R.reduce((s, r) => s + (Number(r.benzersiz) || 0), 0);\n"
      "        const ortKapsam = toplamBenz ? Math.round(toplamEsl / toplamBenz * 100) : null;")
assert s.count(o1) == 1, "anchor#1=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) satır kapsam: server r.kapsam YERINE eslesen/benzersiz
o2 = "          const kaps = r.kapsam != null ? Number(r.kapsam) : null;"
n2 = "          const kaps = (r.benzersiz && Number(r.benzersiz) > 0) ? Math.round((Number(r.eslesen) || 0) / Number(r.benzersiz) * 100) : null;  /* CIRO_UI4_DK_V1 */"
assert s.count(o2) == 1, "anchor#2=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] CIRO_UI4_DK_V1 (masaüstü) — ERP kapsamı = eslesen/benzersiz")
