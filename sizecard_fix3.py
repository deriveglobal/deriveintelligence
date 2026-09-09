#!/usr/bin/env python3
# SIZECARD fix3 — (a) tools as a compact "Araçlar" pill row (not room tiles),
#                 (b) always show brand in the search result name.
# Idempotent. Run in /opt/krb-assessment.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

# ---- (a) shells/saha.js: compact tools row ----
FP = "shells/saha.js"
t = read(FP)
if "ARAC_YETKI_V2" in t:
    print("SAHA: already V2, skip")
else:
    i = t.index("  // ARAC_YETKI_V1")
    j = t.index("  // PUSH_KAYIT_V1", i)
    new = r'''  // ARAC_YETKI_V2 — araclar ayri kompakt bolum (odalardan gorsel olarak farkli).
  (async () => {
    try {
      const { araclar = [] } = await api("/api/saha/araclarim");
      const tanim = { musteri_kart: ["musterikart", "🧾", "Müşteri Kartı"], ebat_kart: ["ebatkart", "📐", "Ebat Kartı"] };
      const codes = araclar.filter(k => tanim[k]);
      if (!codes.length) return;
      const wrap = m.querySelector(".rec-wrap");
      if (!wrap || wrap.querySelector(".rec-arac")) return;
      const sec = document.createElement("div");
      sec.style.marginTop = "18px";
      sec.innerHTML = '<div class="rec-sub">Araçlar</div><div class="rec-arac" style="display:flex;gap:8px;flex-wrap:wrap;margin-top:6px"></div>';
      wrap.appendChild(sec);
      const row = sec.querySelector(".rec-arac");
      codes.forEach(kod => {
        const d = tanim[kod];
        const b = document.createElement("button");
        b.dataset.room = d[0];
        b.style.cssText = "display:flex;align-items:center;gap:7px;padding:9px 14px;border:1px solid #e2e8f0;border-radius:999px;background:#fff;color:#0f172a;cursor:pointer;font-size:13px";
        b.innerHTML = '<span style="font-size:17px">' + d[1] + '</span><b>' + d[2] + '</b>';
        b.addEventListener("click", () => setRoom(d[0]));
        row.appendChild(b);
      });
    } catch (e) {}
  })();
'''
    t = t[:i] + new + t[j:]
    write(FP, t)
    print("SAHA: tools moved to compact Araçlar row (V2)")

# ---- (b) server_container.mjs: brand always in search-result name ----
SP = "server_container.mjs"
s = read(SP)
old_map = 'rows.map(r => ({ kalem_kodu: r.kalem_kodu, ad: (r.ad || [r.marka, r.ebat].filter(Boolean).join(" ") || r.kalem_kodu), adet: r.adet != null ? Number(r.adet) : null }))'
new_map = 'rows.map(r => { const _ad = r.ad || ""; const _mk = r.marka || ""; let disp = _ad; if (_ad && _mk && _ad.toLowerCase().indexOf(_mk.toLowerCase()) === -1) disp = _mk + " " + _ad; if (!disp) disp = [_mk, r.ebat].filter(Boolean).join(" ") || r.kalem_kodu; return { kalem_kodu: r.kalem_kodu, ad: disp, adet: r.adet != null ? Number(r.adet) : null }; })'
if "const _mk = r.marka" in s:
    print("SERVER: brand-in-name already applied, skip")
elif old_map in s:
    s = s.replace(old_map, new_map, 1)
    write(SP, s)
    print("SERVER: brand prepended to search-result name")
else:
    print("WARN: server map anchor not found")
print("DONE.")
