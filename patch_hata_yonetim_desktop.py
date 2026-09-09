import sys
F=sys.argv[1] if len(sys.argv)>1 else "saha_desktop.js"
s=open(F,encoding="utf-8").read()
if "HATA_YONETIM_V1" in s: print("[skip] zaten var"); sys.exit(0)

A1='  if (S.isOwner) yon.push(["sistem", "\U0001F527", "Sistem"]);'
assert s.count(A1)==1, "desktop A1: %d"%s.count(A1)
s=s.replace(A1, '  if (S.isOwner || S.isYonetim) yon.push(["sistem", "\U0001F527", "Sistem"]); /* HATA_YONETIM_V1 */', 1)

A2='const VIEWS = {};'
assert s.count(A2)==1, "desktop A2: %d"%s.count(A2)
FN=r'''const VIEWS = {};

VIEWS.sistem = async (m) => { /* HATA_YONETIM_V1 — hata raporu (yonetim + platform_owner) */
  if (!S.isOwner && !S.isYonetim) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">🔒</div><h3>Erişim yok</h3><p>Bu bölüm yalnız yönetime özeldir.</p></div></div>`; return; }
  const gun = S._sisGun || 7;
  const d = await api("/api/saha/hata-raporu?gun=" + gun);
  const renk = { API_HATA:"#ef4444", JS_HATA:"#f97316", AG_HATA:"#8b5cf6", YAVAS_API:"#f59e0b", SESSIZ_HATA:"#6b7280" };
  const tipRow = (t) => `<div style="display:flex;justify-content:space-between;align-items:center;padding:7px 0;border-bottom:1px solid var(--cizgi)"><span style="background:${renk[t.tip]||"#64748b"};color:#fff;border-radius:4px;padding:2px 9px;font-size:11px;font-weight:700">${esc(t.tip)}</span><b style="font-size:18px">${t.sayi}</b></div>`;
  const epRow = (e) => `<div style="padding:7px 0;border-bottom:1px solid var(--cizgi);font-size:12px"><div style="font-family:monospace;color:var(--tx-1);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(e.endpoint||"-")}</div><div style="display:flex;gap:14px;margin-top:2px"><span style="color:#f87171">${e.sayi} hata</span>${e.ort_ms?`<span style="color:#94a3b8">ort ${e.ort_ms}ms</span>`:""}</div></div>`;
  const uRow = (u) => `<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--cizgi);font-size:12px"><span>${esc(u.kullanici||"-")}</span><span style="color:#f87171;font-weight:600">${u.sayi}</span></div>`;
  const sRow = (h) => `<div style="padding:9px 0;border-bottom:1px solid var(--cizgi);font-size:12px"><div style="display:flex;justify-content:space-between;margin-bottom:3px"><span style="background:${renk[h.tip]||"#64748b"};color:#fff;border-radius:3px;padding:1px 7px;font-size:10px">${esc(h.tip)}</span><span style="color:#94a3b8">${new Date(h.ts).toLocaleString("tr-TR")}</span></div><div style="color:var(--tx-0);margin-bottom:2px">${esc(h.hata_mesaji||"-")}</div><div style="color:#94a3b8;font-family:monospace">${esc(h.endpoint||h.view_adi||"")}</div></div>`;
  const gbtn = (g,l) => `<button class="sis-g" data-g="${g}" style="border:1px solid var(--cizgi);background:${g===gun?"#2563eb":"transparent"};color:${g===gun?"#fff":"var(--tx-1)"};border-radius:8px;padding:6px 14px;font-size:13px;font-weight:600;cursor:pointer;margin-right:6px">${l}</button>`;
  m.innerHTML = `
    <div style="margin:2px 0 14px">${gbtn(1,"Bugün")}${gbtn(7,"7 gün")}${gbtn(30,"30 gün")}</div>
    <div class="dk-card"><div class="dk-card-h"><h3>🐛 Hata Özeti</h3><span class="sub">son ${gun} gün</span></div>${(d.ozet&&d.ozet.length)?d.ozet.map(tipRow).join(""):`<div class="dk-empty-s">Hata kaydı yok 🎉</div>`}</div>
    ${(d.endpoint_ozet&&d.endpoint_ozet.length)?`<div class="dk-card" style="margin-top:14px"><div class="dk-card-h"><h3>En Çok Hata Veren Endpoint</h3></div>${d.endpoint_ozet.slice(0,15).map(epRow).join("")}</div>`:""}
    ${(d.user_ozet&&d.user_ozet.length)?`<div class="dk-card" style="margin-top:14px"><div class="dk-card-h"><h3>Kullanıcı Bazlı</h3></div>${d.user_ozet.slice(0,15).map(uRow).join("")}</div>`:""}
    <div class="dk-card" style="margin-top:14px"><div class="dk-card-h"><h3>Son Hatalar</h3><span class="sub">${(d.son_hatalar||[]).length}</span></div>${(d.son_hatalar&&d.son_hatalar.length)?d.son_hatalar.slice(0,50).map(sRow).join(""):`<div class="dk-empty-s">Kayıt yok</div>`}</div>`;
  m.querySelectorAll(".sis-g").forEach(b => b.addEventListener("click", () => { S._sisGun = parseInt(b.dataset.g,10); go("sistem"); }));
};'''
s=s.replace(A2, FN, 1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] HATA_YONETIM_V1 saha_desktop.js (Sistem nav + VIEWS.sistem hata raporu)")
