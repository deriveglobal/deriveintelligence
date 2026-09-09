import sys
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "REP_AKTIVITE_UI_V1" in s:
    print("[skip] zaten var"); sys.exit(0)

A1='  const isOwner = me.tenantRole === "platform_owner";'
assert s.count(A1)==1, "A1 anchor: %d"%s.count(A1)
s=s.replace(A1, A1+'\n  const isYonetim = String(me.email || "").toLowerCase() === "yonetim@krb.com.tr"; /* REP_AKTIVITE_UI_V1 */', 1)

A2='    container, me, role, isOwner, headers,'
assert s.count(A2)==1, "A2 anchor: %d"%s.count(A2)
s=s.replace(A2, '    container, me, role, isOwner, isYonetim, headers,', 1)

A3='    ...(S.isOwner ? [["sistem", "\U0001F527", "Sistem"]] : [])'
assert s.count(A3)==1, "A3 anchor: %d"%s.count(A3)
s=s.replace(A3, '    ...(S.isYonetim ? [["rep-aktivite", "\U0001F4E1", "Aktivite"]] : []),\n'+A3, 1)

A4='sistem: vSistem }[v] || vBugun)();'
assert s.count(A4)==1, "A4 anchor: %d"%s.count(A4)
s=s.replace(A4, "sistem: vSistem, 'rep-aktivite': vRepAktivite }[v] || vBugun)();", 1)

A5='async function vSistem() {'
assert s.count(A5)==1, "A5 anchor: %d"%s.count(A5)
FN=r'''async function vRepAktivite() { /* REP_AKTIVITE_UI_V1 */
  if (!S.isYonetim) { main().innerHTML = `<div class="saha-bos">Bu bolume erisim yetkiniz yok.</div>`; return; }
  const gun = S._aktGun || 7;
  main().innerHTML = `<div class="saha-load">Yukleniyor...</div>`;
  try {
    const d = await api("/api/saha/rep-aktivite?gun=" + gun);
    const reps = d.repler || [];
    const online = reps.filter(r => r.online).length;
    const rel = (ts) => {
      if (!ts) return "—";
      const s = Math.floor((Date.now() - new Date(ts).getTime()) / 1000);
      if (s < 60) return "az once";
      if (s < 3600) return Math.floor(s/60) + " dk once";
      if (s < 86400) return Math.floor(s/3600) + " sa once";
      return Math.floor(s/86400) + " gun once";
    };
    const dt = (ts) => ts ? new Date(ts).toLocaleString("tr-TR", { day:"2-digit", month:"2-digit", hour:"2-digit", minute:"2-digit" }) : "—";
    const odaAd = { bugun:"Bugun", ziyaretler:"Ziyaretler", musteriler:"Musteri", iskonto:"Teklif", rapor:"Rapor", plan:"Plan", "rep-brain":"Asistan", piyasa:"Piyasa", rakip:"Rakip", saha:"Saha", kokpit:"Kokpit", ceo:"CEO" };
    const gunBtn = (g, l) => `<button class="akt-gun" data-g="${g}" style="border:1px solid ${g===gun?"#2563eb":"#cbd5e1"};background:${g===gun?"#2563eb":"#fff"};color:${g===gun?"#fff":"#334155"};border-radius:999px;padding:5px 12px;font-size:12px;font-weight:600;cursor:pointer">${l}</button>`;
    const card = (r) => `
      <div style="background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:14px;margin-bottom:10px">
        <div style="display:flex;align-items:center;gap:8px;margin-bottom:10px">
          <span style="width:9px;height:9px;border-radius:50%;background:${r.online?"#22c55e":"#cbd5e1"};box-shadow:${r.online?"0 0 0 3px rgba(34,197,94,.2)":"none"};flex-shrink:0"></span>
          <span style="font-weight:700;color:#0f172a;font-size:15px;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(r.ad)}</span>
          <span style="font-size:11px;color:${r.online?"#16a34a":"#94a3b8"};font-weight:600">${r.online?"cevrimici":rel(r.son_aktivite)}</span>
        </div>
        <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px 12px;font-size:12px">
          <div><span style="color:#94a3b8">Son giris</span><br><b style="color:#334155">${dt(r.son_giris)}</b></div>
          <div><span style="color:#94a3b8">Son islem</span><br><b style="color:#334155">${rel(r.son_aktivite)}</b></div>
          <div><span style="color:#94a3b8">Uygulamada (bugun)</span><br><b style="color:#334155">${r.dk_bugun} dk</b></div>
          <div><span style="color:#94a3b8">Uygulamada (7 gun)</span><br><b style="color:#334155">${r.dk_hafta} dk</b></div>
          <div><span style="color:#94a3b8">Ziyaret (${gun}g)</span><br><b style="color:#334155">${r.ziyaret}</b></div>
          <div><span style="color:#94a3b8">Hata (${gun}g)</span><br><b style="color:${r.hata>0?"#dc2626":"#334155"}">${r.hata}</b></div>
        </div>
        ${r.en_cok_oda ? `<div style="margin-top:8px;font-size:11px;color:#64748b">En cok: <b>${esc(odaAd[r.en_cok_oda]||r.en_cok_oda)}</b></div>` : ""}
      </div>`;
    main().innerHTML = `
      <div style="padding:16px 16px 4px">
        <div style="font-size:18px;font-weight:700;color:#0f172a">📡 Temsilci Aktivite</div>
        <div style="font-size:12px;color:#64748b;margin-top:2px">${online}/${reps.length} cevrimici · ziyaret/hata penceresi: son ${gun} gun</div>
        <div style="display:flex;gap:6px;margin-top:12px">${gunBtn(1,"Bugun")}${gunBtn(7,"7 gun")}${gunBtn(30,"30 gun")}</div>
      </div>
      <div style="padding:14px 16px 90px">
        ${reps.length ? reps.map(card).join("") : `<div class="saha-bos">Kayit yok</div>`}
      </div>`;
    main().querySelectorAll(".akt-gun").forEach(b => b.addEventListener("click", () => { S._aktGun = parseInt(b.dataset.g, 10); vRepAktivite(); }));
  } catch (e) {
    main().innerHTML = `<div class="saha-bos">Aktivite yuklenemedi: ${esc(e.message)}</div>`;
  }
}
'''
s=s.replace(A5, FN+"\n"+A5, 1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] REP_AKTIVITE_UI_V1 saha.js'e eklendi")
