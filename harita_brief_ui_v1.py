#!/usr/bin/env python3
# HARITA_BRIEF_UI_V1 — pin balonuna "AI Ozet" butonu: dokun -> harita-musteri-brief ile
#   o musterinin ziyaret notlarindan kisa AI ozeti + aksiyonlar. Tekrar dokun -> gizle/goster.
# shells/saha.js. Idempotent, marker-guardli. HARITA_PIN_OZET_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_BRIEF_UI_V1" in s:
    print("brief-ui: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_PIN_OZET_V1" in s, "once HARITA_PIN_OZET_V1 gerekli"

# (A) Balona AI buton + sonuc alani — pin-yol butonundan once
A1 = '            + `<button class="pin-yol" style="margin-top:8px;padding:4px 10px;border:none;border-radius:6px;background:#0ea5e9;color:#fff;font-size:12px;cursor:pointer">Yol Tarifi</button>`\n'
assert s.count(A1) == 1, "pin-yol button anchor (count!=1)"
N1 = (
    '            + `<button class="pin-ai" style="margin-top:8px;margin-right:6px;padding:4px 10px;border:none;border-radius:6px;background:#7c3aed;color:#fff;font-size:12px;cursor:pointer">\\ud83e\\udd16 AI \\u00d6zet</button>`\n'
    '            + `<div class="pin-ai-sonuc" style="display:none;margin-top:8px;font-size:11px;color:#334155;line-height:1.5;background:#faf5ff;border:1px solid #e9d5ff;border-radius:8px;padding:8px"></div>`\n'
    + A1
)
s = s.replace(A1, N1, 1)

# (B) popupopen icinde AI buton baglama — yol wiring satirindan sonra
A2 = '            if (b) b.onclick = () => { try { yolTarifi(lat, lng, m.firma); } catch (_) {} };\n'
assert s.count(A2) == 1, "yol wiring anchor (count!=1)"
N2 = A2 + (
    '            const aiBtn = root.querySelector(".pin-ai"); /* HARITA_BRIEF_UI_V1 */\n'
    '            const aiOut = root.querySelector(".pin-ai-sonuc");\n'
    '            if (aiBtn && aiOut && !aiBtn.dataset.bagli) {\n'
    '              aiBtn.dataset.bagli = "1";\n'
    '              aiBtn.onclick = async () => {\n'
    '                if (aiOut.dataset.yuklendi) { aiOut.style.display = (aiOut.style.display === "none" ? "block" : "none"); return; }\n'
    '                aiBtn.disabled = true; aiBtn.textContent = "... ozet cikariliyor";\n'
    '                aiOut.style.display = "block";\n'
    '                aiOut.innerHTML = `<span style="color:#94a3b8">yapay zeka ziyaret notlarini okuyor...</span>`;\n'
    '                try {\n'
    '                  const r = await api("/api/saha/harita-musteri-brief?id=" + encodeURIComponent(m.id));\n'
    '                  aiOut.dataset.yuklendi = "1";\n'
    '                  let h = `<div>${esc(r.brief || "Ozet yok")}</div>`;\n'
    '                  if (r.aksiyonlar && r.aksiyonlar.length) h += `<div style="margin-top:5px">${r.aksiyonlar.map(a => "\\u2022 " + esc(a)).join("<br>")}</div>`;\n'
    '                  aiOut.innerHTML = h;\n'
    '                } catch (err) {\n'
    '                  aiOut.innerHTML = `<span style="color:#ef4444">AI ozeti alinamadi</span>`;\n'
    '                } finally {\n'
    '                  aiBtn.disabled = false; aiBtn.innerHTML = `\\ud83e\\udd16 AI \\u00d6zet`;\n'
    '                }\n'
    '              };\n'
    '            }\n'
)
s = s.replace(A2, N2, 1)

write(FP, s)
print("brief-ui: AI Ozet butonu + baglama eklendi")
print("marker count:", s.count("HARITA_BRIEF_UI_V1"))
print("DONE.")
