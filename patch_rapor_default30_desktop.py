# -*- coding: utf-8 -*-
# RAPOR_DEF30_DK_V1 (masaüstü) — Rapor tarih aralığı VARSAYILANI: son 30 gün.
#   Eskiden ay-başı → bugün açılıyordu. Artık (bugün-30 → bugün), yani "30 gün" preset'iyle aynı;
#   o preset düğmesi açılışta 'on' vurgulanır. Sadece Rapor fonksiyonu (harita'ya dokunmaz).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_DEF30_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

EXPR = "new Date(simdi.getTime() - 30 * 864e5).toISOString().slice(0, 10)"

# 1) from input varsayilan degeri (ayBasi -> son 30 gun) — Rapor'a özgü, tek eşleşme
o1 = '<input type="date" class="rp-date" id="rp-from" value="${ayBasi}">'
n1 = '<input type="date" class="rp-date" id="rp-from" value="${' + EXPR + '}"><!--RAPOR_DEF30_DK_V1-->'
assert s.count(o1) == 1, "anchor#1=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rpFrom fallback (ayBasi -> son 30 gun)
o2 = 'const rpFrom = () => $("rp-from")?.value || ayBasi;'
n2 = 'const rpFrom = () => $("rp-from")?.value || ' + EXPR + ';  /* RAPOR_DEF30_DK_V1 */'
assert s.count(o2) == 1, "anchor#2=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) acilista "30 gun" preset'ini 'on' vurgula (Rapor preset handler'i sonrasi — ciz() ile biten blok tekildir)
o3 = ('    m.querySelectorAll(".rp-preset").forEach(x => x.classList.toggle("on", x === b));\n'
      '    ciz();\n'
      '  }));')
n3 = (o3 + '\n  m.querySelector(\'.rp-preset[data-days="30"]\')?.classList.add("on");  /* RAPOR_DEF30_DK_V1 */')
assert s.count(o3) == 1, "anchor#3=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_DEF30_DK_V1 (masaüstü) — varsayilan son 30 gun")
