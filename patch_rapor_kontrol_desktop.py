# -*- coding: utf-8 -*-
# RAPOR_KONTROL_DK_V1 (masaüstü) — Rapor başlık kontrollerini bağlamsal yap + segment-seçici bug'ı düzelt.
#   1) Tarih aralığı (.rp-bar): Risk + Rotam'da gizle (tarih kullanmıyorlar).
#   2) Segment seçici (#dk-seg): Rotam'da gizle (rota tip-agnostik); diğerlerinde kalır.
#   3) Sekme etiketi rol-duyarlı: yönetici "🌅 Bugün Sahada", rep "🌅 Rotam".
#   4) BUG: Özet DIŞI sekmede segment seçince tüm view yeniden çizilip Özet'e DÖNÜYORDU. Artık segment
#      değişimi yalnız AKTİF sekmeyi yeniler (Harita'daki _haritaSeg deseni → _raporSeg), sekme korunur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "RAPOR_KONTROL_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_DK_V3" in s, "HATA: once SABAH_ROTAM_DK_V3 olmali"

# 1) sekme etiketi rol-duyarlı — REP DIŞI herkes (yönetici/admin/viewer) gözlemci → "Bugün Sahada"
l_old = '    ["rotam", "🌅 Bugün Sahada"],  /* SABAH_ROTAM_DK_V1 SABAH_ROTAM_DK_V3 */'
l_new = '    ["rotam", (S.role !== "rep") ? "🌅 Bugün Sahada" : "🌅 Rotam"],  /* SABAH_ROTAM_DK_V1 DK_V3 RAPOR_KONTROL_DK_V1 */'
assert s.count(l_old) == 1, "label anchor=%d" % s.count(l_old)
s = s.replace(l_old, l_new, 1)

# 2) go(): segment seçici YALNIZ yönetici/admin'e görünsün (rep/viewer=Saha kullanıcısı için anlamsız) + rapor hook temizle
g_old = 'function go(dest) {\n  S.view = dest;\n  S.q = "";'
g_new = ('function go(dest) {\n  S.view = dest;\n'
         '  { const _sg = S.container.querySelector("#dk-seg"); if (_sg) _sg.style.display = ["manager","admin"].includes(S.role) ? "" : "none"; }  /* RAPOR_KONTROL_DK_V1 — segment yalnız yönetici */\n'
         '  if (dest !== "rapor") S._raporSeg = null;\n'
         '  S.q = "";')
assert s.count(g_old) == 1, "go anchor=%d" % s.count(g_old)
s = s.replace(g_old, g_new, 1)

# 2b) wire(): açılışta segment seçiciyi Saha kullanıcısında gizle (ilk boyamada da)
w_old = '  renderNav();\n}'
w_new = '  if (!["manager","admin"].includes(S.role)) { const _sg0 = S.container.querySelector("#dk-seg"); if (_sg0) _sg0.style.display = "none"; }  /* RAPOR_KONTROL_DK_V1 */\n  renderNav();\n}'
assert s.count(w_old) == 1, "wire anchor=%d" % s.count(w_old)
s = s.replace(w_old, w_new, 1)

# 3) segment seçici tıklaması: rapor'da tam re-render yerine yalnız aktif sekmeyi yenile
sg_old = '    if (S.view === "harita" && typeof S._haritaSeg === "function") { S._haritaSeg(); return; }'
sg_new = ('    if (S.view === "rapor" && typeof S._raporSeg === "function") { S._raporSeg(); return; }  /* RAPOR_KONTROL_DK_V1 */\n'
          '    if (S.view === "harita" && typeof S._haritaSeg === "function") { S._haritaSeg(); return; }')
assert s.count(sg_old) == 1, "seg handler anchor=%d" % s.count(sg_old)
s = s.replace(sg_old, sg_new, 1)

# 4) Rapor sekme geçişi: bağlamsal kontrol + segment-yenile hook'u kaydet
h_old = '''  m.querySelectorAll("#rp-tabs button").forEach(b => b.addEventListener("click", () => {
    aktif = b.dataset.t;
    m.querySelectorAll("#rp-tabs button").forEach(x => x.classList.toggle("on", x === b));
    ciz();
  }));'''
h_new = '''  const rpKontrol = () => { const bar = m.querySelector(".rp-bar"); if (bar) bar.style.display = (aktif === "risk" || aktif === "rotam") ? "none" : ""; const seg = S.container.querySelector("#dk-seg"); if (seg) seg.style.display = (["manager","admin"].includes(S.role) && aktif !== "rotam") ? "" : "none"; };  /* RAPOR_KONTROL_DK_V1 */
  m.querySelectorAll("#rp-tabs button").forEach(b => b.addEventListener("click", () => {
    aktif = b.dataset.t;
    m.querySelectorAll("#rp-tabs button").forEach(x => x.classList.toggle("on", x === b));
    rpKontrol();
    ciz();
  }));
  rpKontrol();
  S._raporSeg = () => { rpKontrol(); ciz(); };  /* RAPOR_KONTROL_DK_V1 — segment değişince yalnız aktif sekme */'''
assert s.count(h_old) == 1, "handler anchor=%d" % s.count(h_old)
s = s.replace(h_old, h_new, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] RAPOR_KONTROL_DK_V1 (masaüstü)")
