# -*- coding: utf-8 -*-
# BUGUN_ZIYARET_TIKLA_V1 — Masaustu Bugun ekraninda bir ziyarete tiklayinca o ziyaretin
#   detayi acilmiyor, bunun yerine Ziyaretler sekmesine gidiyordu (go("ziyaretler")).
#   Cozum: tiklanan zid'i al, zengin ziyaret nesnesini S.ziyaretler'den (yoksa
#   /api/saha/ziyaretler?durum=TAMAMLANDI ile cekip) bul ve ziyaretDetay(z) ac.
#   Bulunamazsa ( or. PLANLANDI ziyaret) Bugun satirindaki ince nesneden minimal detay ac.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "BUGUN_ZIYARET_TIKLA_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

OLD = '  m.querySelectorAll("[data-zid]").forEach(el => el.addEventListener("click", () => go("ziyaretler")));'
NEW = '''  m.querySelectorAll("[data-zid]").forEach(el => el.addEventListener("click", async () => {  /* BUGUN_ZIYARET_TIKLA_V1 */
    const zid = el.dataset.zid;
    let z = (S.ziyaretler || []).find(x => String(x.id) === String(zid));
    if (!z) {
      try {
        const { ziyaretler: full = [] } = await api(`/api/saha/ziyaretler?durum=TAMAMLANDI${tipQS()}`);
        S.ziyaretler = full;
        z = full.find(x => String(x.id) === String(zid));
      } catch { /* sessiz */ }
    }
    if (!z) {
      const b = ziyaretler.find(x => String(x.id) === String(zid));
      if (b) z = { id: b.id, firma: b.musteri_adi, ziyaret_tarihi: b.ziyaret_tarihi, rep_adi: b.rep_adi };
    }
    if (z) ziyaretDetay(z); else go("ziyaretler");
  }));'''
assert s.count(OLD) == 1, "anchor count=%d" % s.count(OLD)
s = s.replace(OLD, NEW, 1)
open(F, "w", encoding="utf-8").write(s)
print("[done] BUGUN_ZIYARET_TIKLA_V1")
