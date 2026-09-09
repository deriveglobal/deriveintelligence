# -*- coding: utf-8 -*-
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAKIP_OCR_BACKFILL_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) Buton — foto ızgarasının altına (yalnız yönetici + foto varsa)
OLD1 = '    <div id="dk-det-foto" class="dk-foto-grid"></div>'
NEW1 = '''    <div id="dk-det-foto" class="dk-foto-grid"></div>
    ${S.role !== "rep" && Number(z.foto_sayisi) ? `<button class="dk-btn dk-btn-sm" id="dk-rakip-oku" style="margin-top:8px">🔍 Fotoğraftan rakip fiyat oku</button><span id="dk-rakip-oku-durum" class="sub2" style="margin-left:8px"></span>` : ""}<!-- RAKIP_OCR_BACKFILL_V1 -->'''
assert s.count(OLD1) == 1, "foto grid anchor count=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# 2) Buton davranışı (yorumlar bölümünden önce)
OLD2 = '  // yorumlar (oku + yaz)'
NEW2 = '''  // RAKIP_OCR_BACKFILL_V1 — fotoğraftaki rakip fiyat listesini oku
  S.container.querySelector("#dk-rakip-oku")?.addEventListener("click", async () => {
    const b = S.container.querySelector("#dk-rakip-oku"), st = S.container.querySelector("#dk-rakip-oku-durum");
    if (b) b.disabled = true;
    if (st) st.textContent = "Okunuyor… (birkaç saniye)";
    try {
      const r = await api(`/api/saha/ziyaretler/${z.id}/foto-oku`, { method: "POST" });
      if (st) st.textContent = r.cikarilan_kalem
        ? `✓ ${r.cikarilan_kalem} rakip fiyat kalemi çıkarıldı (${r.islenen_foto} foto)`
        : `Fiyat listesi bulunamadı — ${r.islenen_foto} foto tarandı`;
    } catch (e) { if (st) st.textContent = e.message; }
    if (b) b.disabled = false;
  });
  // yorumlar (oku + yaz)'''
assert s.count(OLD2) == 1, "yorumlar anchor count=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAKIP_OCR_BACKFILL_V1 (desktop)")
