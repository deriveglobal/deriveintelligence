# -*- coding: utf-8 -*-
# RAPOR_DEF30_V1 (mobil) — Rapor tarih VARSAYILANI son 30 gün (bugün-29..bugün) + aktif preset VURGUSU.
#   Mobilde varsayılan ay-başıydı ve preset hiç vurgulanmıyordu ("30 gün seçili mi belli değil").
#   Artık: varsayılan = son 30 gün; "30G" açılışta vurgulu; preset tıklanınca vurgu taşınır;
#   ileri/geri kaydırınca vurgu kalkar. Mobil preset math zaten -days+1 (30 gün dahil) — masaüstüyle aynı.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_DEF30_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

EXPR = "new Date(simdi.getTime() - 29 * 864e5).toISOString().slice(0, 10)"

# 1) varsayilan from degeri: ayBasi -> son 30 gun
o1 = 'id="rp-from" value="${ayBasi}"'
n1 = 'id="rp-from" value="${' + EXPR + '}"'
assert s.count(o1) == 1, "anchor#1=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rpFrom fallback: ayBasi -> son 30 gun
o2 = 'const rpFrom  = () => document.getElementById("rp-from")?.value  || ayBasi;'
n2 = 'const rpFrom  = () => document.getElementById("rp-from")?.value  || ' + EXPR + ';'
assert s.count(o2) == 1, "anchor#2=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) preset vurgu: rpMark fonksiyonu + tıkla-vurgula + açılışta 30G vurgusu
o3 = '''  main().querySelectorAll(".rp-preset").forEach(btn => {
    btn.addEventListener("click", () => {
      const days = Number(btn.dataset.days);
      const t = new Date(), f = new Date(); f.setDate(f.getDate() - days + 1);
      document.getElementById("rp-from").value = f.toISOString().slice(0, 10);
      document.getElementById("rp-to").value   = t.toISOString().slice(0, 10);
      if (activeTab === "harita") { try { if (window._haritaDonemHook) window._haritaDonemHook(); } catch (_) {} } else { loadTab(activeTab); }
    });
  });'''
n3 = '''  const rpMark = (days) => { main().querySelectorAll(".rp-preset").forEach(b => { const on = Number(b.dataset.days) === days; b.style.background = on ? "#3b82f6" : "#fff"; b.style.color = on ? "#fff" : "#374151"; b.style.borderColor = on ? "#3b82f6" : "#e5e7eb"; b.style.fontWeight = on ? "700" : "500"; }); };  /* RAPOR_DEF30_V1 */
  main().querySelectorAll(".rp-preset").forEach(btn => {
    btn.addEventListener("click", () => {
      const days = Number(btn.dataset.days);
      const t = new Date(), f = new Date(); f.setDate(f.getDate() - days + 1);
      document.getElementById("rp-from").value = f.toISOString().slice(0, 10);
      document.getElementById("rp-to").value   = t.toISOString().slice(0, 10);
      rpMark(days);
      if (activeTab === "harita") { try { if (window._haritaDonemHook) window._haritaDonemHook(); } catch (_) {} } else { loadTab(activeTab); }
    });
  });
  rpMark(30);'''
assert s.count(o3) == 1, "anchor#3=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) ileri/geri kaydırınca vurgu kalksın (masaüstü ile parite)
o4 = '    fEl.value = f.toISOString().slice(0, 10); tEl.value = t.toISOString().slice(0, 10);'
n4 = o4 + '\n    if (typeof rpMark === "function") rpMark(0);  /* RAPOR_DEF30_V1 */'
assert s.count(o4) == 1, "anchor#4=%d" % s.count(o4)
s = s.replace(o4, n4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_DEF30_V1 (mobil) — son 30 gün varsayılan + preset vurgusu")
