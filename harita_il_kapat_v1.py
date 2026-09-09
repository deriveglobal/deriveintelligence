#!/usr/bin/env python3
# HARITA_IL_KAPAT_V1 — sehir kartina KAPAT (x) butonu + bos secim -> kapat.
#   Sorun: il secip sehir kartini actiktan sonra kapatma yolu yoktu (son sehir acik kaliyordu).
# shells/saha.js. Idempotent, marker-guardli. HARITA_IL_SEC_V1 gerektirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "HARITA_IL_KAPAT_V1" in s:
    print("il-kapat: already present, skip"); print("DONE."); raise SystemExit
assert "HARITA_IL_SEC_V1" in s, "once HARITA_IL_SEC_V1 gerekli"

# (1) Karta position:relative + kapat (x) butonu
A1 = '          <div id="ss-sehir-kart" style="display:none;margin-top:10px;background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:12px">\n'
assert s.count(A1) == 1, "ss-sehir-kart anchor"
N1 = (
    '          <div id="ss-sehir-kart" style="display:none;position:relative;margin-top:10px;background:#eff6ff;border:1px solid #bfdbfe;border-radius:10px;padding:12px">\n'
    '            <button id="ss-sehir-kapat" title="Kapat" style="position:absolute;top:6px;right:9px;background:none;border:none;font-size:18px;line-height:1;color:#64748b;cursor:pointer">×</button>\n'
)
s = s.replace(A1, N1, 1)

# (2) haritaIlKapat() — haritaIlSec'ten once
A2 = '    async function haritaIlSec(il) { /* HARITA_IL_SEC_V1 */\n'
assert s.count(A2) == 1, "haritaIlSec anchor"
FUNC = (
    '    function haritaIlKapat() { /* HARITA_IL_KAPAT_V1 */\n'
    '      mapSehir = null;\n'
    '      const kart = document.getElementById("ss-sehir-kart"); if (kart) kart.style.display = "none";\n'
    '      const sel = document.getElementById("ss-il-sec"); if (sel) sel.value = "";\n'
    '      const sonuc = document.getElementById("ss-sehir-sonuc"); if (sonuc) { sonuc.style.display = "none"; sonuc.innerHTML = ""; }\n'
    '    }\n'
)
s = s.replace(A2, FUNC + A2, 1)

# (3) change: bos secim -> kapat + x butonunu bagla (bir kez)
A3 = '            if (!sel.dataset.bound) { sel.dataset.bound = "1"; sel.addEventListener("change", () => { if (sel.value) haritaIlSec(sel.value); }); }\n'
assert s.count(A3) == 1, "change binding anchor"
N3 = '            if (!sel.dataset.bound) { sel.dataset.bound = "1"; sel.addEventListener("change", () => { if (sel.value) haritaIlSec(sel.value); else haritaIlKapat(); }); document.getElementById("ss-sehir-kapat")?.addEventListener("click", haritaIlKapat); } /* HARITA_IL_KAPAT_V1 */\n'
s = s.replace(A3, N3, 1)

write(FP, s)
print("il-kapat: kapat butonu + bos secim kapatma eklendi")
print("marker count:", s.count("HARITA_IL_KAPAT_V1"))
print("DONE.")
