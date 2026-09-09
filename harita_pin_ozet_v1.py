#!/usr/bin/env python3
# HARITA_PIN_OZET_V1 — pin balonuna metrikler: pine dokununca ziyaret, satis adet/ciro (12ay),
#   teklif (win/loss), puan yuklenir. /api/saha/harita-musteri-ozet + /api/bi/musteri-skor.
# shells/saha.js. Idempotent, marker-guardli. HARITA_LEAFLET_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_PIN_OZET_V1" in s:
    print("pin-ozet: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_LEAFLET_V1" in s, "once HARITA_LEAFLET_V1 gerekli"

A = (
    '          mk.bindPopup(\n'
    '            `<div style="font-size:13px;font-weight:700;margin-bottom:2px">${esc(m.firma || "")}</div>`\n'
    '            + `<div style="font-size:11px;color:#64748b">${tuk ? "Tuketici" : "Ticari"}${durumEt ? " &middot; " + esc(durumEt) : ""}${yer ? " &middot; " + esc(yer) : ""}</div>`\n'
    '            + `<button class="pin-yol" style="margin-top:7px;padding:4px 10px;border:none;border-radius:6px;background:#0ea5e9;color:#fff;font-size:12px;cursor:pointer">Yol Tarifi</button>`\n'
    '          );\n'
    '          mk.on("popupopen", (e) => {\n'
    '            const b = e.popup.getElement() && e.popup.getElement().querySelector(".pin-yol");\n'
    '            if (b) b.onclick = () => { try { yolTarifi(lat, lng, m.firma); } catch (_) {} };\n'
    '          });\n'
)
assert s.count(A) == 1, "popup block anchor (count!=1)"

N = (
    '          mk.bindPopup( /* HARITA_PIN_OZET_V1 */\n'
    '            `<div style="min-width:212px">`\n'
    '            + `<div style="font-size:13px;font-weight:700;margin-bottom:2px">${esc(m.firma || "")}</div>`\n'
    '            + `<div style="font-size:11px;color:#64748b;margin-bottom:6px">${tuk ? "Tuketici" : "Ticari"}${durumEt ? " &middot; " + esc(durumEt) : ""}${yer ? " &middot; " + esc(yer) : ""}</div>`\n'
    '            + `<div class="pin-ozet" style="font-size:11px;color:#94a3b8;border-top:1px solid #f1f5f9;padding-top:6px;min-height:16px">metrikler yukleniyor...</div>`\n'
    '            + `<button class="pin-yol" style="margin-top:8px;padding:4px 10px;border:none;border-radius:6px;background:#0ea5e9;color:#fff;font-size:12px;cursor:pointer">Yol Tarifi</button>`\n'
    '            + `</div>`\n'
    '          );\n'
    '          mk.on("popupopen", async (e) => {\n'
    '            const root = e.popup.getElement(); if (!root) return;\n'
    '            const b = root.querySelector(".pin-yol");\n'
    '            if (b) b.onclick = () => { try { yolTarifi(lat, lng, m.firma); } catch (_) {} };\n'
    '            const oz = root.querySelector(".pin-ozet");\n'
    '            if (oz && !oz.dataset.yuklendi) {\n'
    '              oz.dataset.yuklendi = "1";\n'
    '              try {\n'
    '                const d = await api("/api/saha/harita-musteri-ozet?id=" + encodeURIComponent(m.id));\n'
    '                let skorTxt = "";\n'
    '                if (d.musteri_kodu) { try { const sk = await api("/api/bi/musteri-skor?musteri=" + encodeURIComponent(d.musteri_kodu)); if (sk && sk.skor != null) skorTxt = String(sk.skor); } catch (_) {} }\n'
    '                const tl = v => "\\u20ba" + Math.round(Number(v||0)).toLocaleString("tr-TR");\n'
    '                const win = d.teklif > 0 ? (Math.round(100*d.kazan/d.teklif) + "%") : "-";\n'
    '                oz.innerHTML =\n'
    '                  `<div style="display:grid;grid-template-columns:auto 1fr;gap:3px 12px;color:#334155">`\n'
    '                  + `<span>Ziyaret</span><b style="text-align:right">${d.ziyaret}</b>`\n'
    '                  + `<span>Satis (12ay)</span><b style="text-align:right">${Number(d.satis_adet||0).toLocaleString("tr-TR")} ad</b>`\n'
    '                  + `<span>Ciro (12ay)</span><b style="text-align:right">${tl(d.satis_ciro)}</b>`\n'
    '                  + `<span>Teklif</span><b style="text-align:right">${d.teklif} \\u00b7 ${d.kazan}\\u2713/${d.kayip}\\u2717 (${win})</b>`\n'
    '                  + (skorTxt !== "" ? `<span>Puan</span><b style="text-align:right">${skorTxt}/100</b>` : "")\n'
    '                  + `</div>`;\n'
    '              } catch (err) {\n'
    '                oz.innerHTML = `<span style="color:#ef4444">metrik alinamadi</span>`;\n'
    '              }\n'
    '            }\n'
    '          });\n'
)
s = s.replace(A, N, 1)
write(FP, s)
print("pin-ozet: popup metrikleri eklendi")
print("marker count:", s.count("HARITA_PIN_OZET_V1"))
print("DONE.")
