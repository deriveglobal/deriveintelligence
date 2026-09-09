#!/usr/bin/env python3
# HARITA_IL_SEC_V1 — Faz 3: harita ustune IL SECICI + sehir metrikleri + pin'de "Il analizi".
#   Il secilince/pin'den tetiklenince: harita-il-ozet metriklerini ss-sehir-kart'a doldur,
#   mapSehir set et, karti goster -> mevcut "Bu sehri analiz et" butonu saha-sesi'yi calistirir.
# shells/saha.js. Idempotent, marker-guardli. HARITA_BRIEF_UI_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_IL_SEC_V1" in s:
    print("il-sec: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_BRIEF_UI_V1" in s, "once HARITA_BRIEF_UI_V1 gerekli"

# (1) Il secici HTML — harita konteynerinden once
A1 = '          <div id="ss-harita" style="position:relative;background:#eef2f7;border:1px solid #e5e7eb;border-radius:10px;overflow:hidden;height:440px">\n'
assert s.count(A1) == 1, "ss-harita container anchor"
SEL = (
    '          <!-- Il secici (HARITA_IL_SEC_V1) -->\n'
    '          <select id="ss-il-sec" style="font-size:12px;padding:6px 8px;width:100%;box-sizing:border-box;margin-bottom:8px;border:1px solid #e5e7eb;border-radius:8px;background:#fff;color:#0f172a"><option value="">İl seç — şehir analizi…</option></select>\n'
)
s = s.replace(A1, SEL + A1, 1)

# (2) haritaIlSec() — loadHarita'dan once
A2 = '    async function loadHarita() { /* HARITA_LEAFLET_V1 */\n'
assert s.count(A2) == 1, "loadHarita anchor"
FUNC = (
    '    async function haritaIlSec(il) { /* HARITA_IL_SEC_V1 */\n'
    '      if (!il) return;\n'
    '      mapSehir = il;\n'
    '      const kart = document.getElementById("ss-sehir-kart");\n'
    '      const bas = document.getElementById("ss-sehir-baslik");\n'
    '      const stats = document.getElementById("ss-sehir-stats");\n'
    '      const sonuc = document.getElementById("ss-sehir-sonuc");\n'
    '      const abtn = document.getElementById("ss-sehir-analiz-btn");\n'
    '      if (!kart) return;\n'
    '      kart.style.display = "block";\n'
    '      if (bas) bas.textContent = il;\n'
    '      if (sonuc) { sonuc.style.display = "none"; sonuc.innerHTML = ""; }\n'
    '      if (abtn) { abtn.textContent = "🤖 Bu şehri analiz et"; abtn.dataset.forceRefresh = "0"; abtn.disabled = false; }\n'
    '      const sel = document.getElementById("ss-il-sec"); if (sel && sel.value !== il) sel.value = il;\n'
    '      if (stats) stats.innerHTML = `<span style="color:#94a3b8">metrikler yükleniyor…</span>`;\n'
    '      try {\n'
    '        const d = await api("/api/saha/harita-il-ozet?il=" + encodeURIComponent(il));\n'
    '        const tl = v => "₺" + Math.round(Number(v||0)).toLocaleString("tr-TR");\n'
    '        const win = d.teklif > 0 ? (Math.round(100*d.kazan/d.teklif) + "%") : "-";\n'
    '        if (stats) stats.innerHTML =\n'
    '          `<div style="display:grid;grid-template-columns:auto 1fr;gap:2px 12px">`\n'
    '          + `<span>Müşteri</span><b style="text-align:right">${d.musteri}</b>`\n'
    '          + `<span>Ziyaret</span><b style="text-align:right">${d.ziyaret}</b>`\n'
    '          + `<span>Satış (12ay)</span><b style="text-align:right">${Number(d.satis_adet||0).toLocaleString("tr-TR")} ad</b>`\n'
    '          + `<span>Ciro (12ay)</span><b style="text-align:right">${tl(d.satis_ciro)}</b>`\n'
    '          + `<span>Teklif</span><b style="text-align:right">${d.teklif} · ${d.kazan}✓/${d.kayip}✗ (${win})</b>`\n'
    '          + `</div>`;\n'
    '      } catch (e) {\n'
    '        if (stats) stats.innerHTML = `<span style="color:#ef4444">metrik alınamadı</span>`;\n'
    '      }\n'
    '      try { kart.scrollIntoView({ behavior: "smooth", block: "nearest" }); } catch (_) {}\n'
    '    }\n'
)
s = s.replace(A2, FUNC + A2, 1)

# (3) Secici doldur + change bagla — fitBounds'tan once (loadHarita ici)
A3 = '        if (pts.length) map.fitBounds(pts, { padding: [30, 30], maxZoom: 12 });\n'
assert s.count(A3) == 1, "fitBounds anchor"
POP = (
    '        try {\n'
    '          const iller = [...new Set(musteriler.map(x => x.il).filter(Boolean))].sort((a,b) => String(a).localeCompare(String(b), "tr"));\n'
    '          const sel = document.getElementById("ss-il-sec");\n'
    '          if (sel) {\n'
    '            const cur = sel.value;\n'
    '            sel.innerHTML = `<option value="">İl seç — şehir analizi…</option>` + iller.map(i => `<option value="${esc(i)}">${esc(i)}</option>`).join("");\n'
    '            if (cur) sel.value = cur;\n'
    '            if (!sel.dataset.bound) { sel.dataset.bound = "1"; sel.addEventListener("change", () => { if (sel.value) haritaIlSec(sel.value); }); }\n'
    '          }\n'
    '        } catch (_) {}\n'
)
s = s.replace(A3, POP + A3, 1)

# (4) Pin balonuna "Il analizi" butonu — pin-ai-sonuc div'inden sonra
A4 = '            + `<div class="pin-ai-sonuc" style="display:none;margin-top:8px;font-size:11px;color:#334155;line-height:1.5;background:#faf5ff;border:1px solid #e9d5ff;border-radius:8px;padding:8px"></div>`\n'
assert s.count(A4) == 1, "pin-ai-sonuc anchor"
ILBTN = '            + `<button class="pin-il" style="margin-top:8px;margin-right:6px;padding:4px 10px;border:none;border-radius:6px;background:#0891b2;color:#fff;font-size:12px;cursor:pointer">🗺 İl analizi</button>`\n'
s = s.replace(A4, A4 + ILBTN, 1)

# (5) Pin "Il analizi" baglama — aiBtn satirindan once
A5 = '            const aiBtn = root.querySelector(".pin-ai"); /* HARITA_BRIEF_UI_V1 */\n'
assert s.count(A5) == 1, "aiBtn anchor"
ILWIRE = (
    '            const ilBtn = root.querySelector(".pin-il"); /* HARITA_IL_SEC_V1 */\n'
    '            if (ilBtn) { if (!m.il) { ilBtn.style.display = "none"; } else if (!ilBtn.dataset.bagli) { ilBtn.dataset.bagli = "1"; ilBtn.onclick = () => { try { map.closePopup(); } catch (_) {} haritaIlSec(m.il); }; } }\n'
)
s = s.replace(A5, ILWIRE + A5, 1)

write(FP, s)
print("il-sec: il secici + sehir metrikleri + pin il-analizi eklendi")
print("marker count:", s.count("HARITA_IL_SEC_V1"))
print("DONE.")
