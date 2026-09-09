import sys
F=sys.argv[1] if len(sys.argv)>1 else "saha_desktop.js"
s=open(F,encoding="utf-8").read()
if "REP_AKTIVITE_UI_V1" in s:
    print("[skip] zaten var"); sys.exit(0)

A1='  const isOwner = me.tenantRole === "platform_owner";'
assert s.count(A1)==1, "A1: %d"%s.count(A1)
s=s.replace(A1, A1+'\n  const isYonetim = String(me.email || "").toLowerCase() === "yonetim@krb.com.tr"; /* REP_AKTIVITE_UI_V1 */', 1)

A2='    container, me, sub, role, isOwner, headers,'
assert s.count(A2)==1, "A2: %d"%s.count(A2)
s=s.replace(A2, '    container, me, sub, role, isOwner, isYonetim, headers,', 1)

A3='  if (S.isOwner) yon.push(["sistem", "\U0001F527", "Sistem"]);'
assert s.count(A3)==1, "A3: %d"%s.count(A3)
s=s.replace(A3, '  if (S.isYonetim) yon.push(["rep-aktivite", "📡", "Aktivite"]);\n'+A3, 1)

A4='  ebatkart: "Ebat Kartı", musterikart: "Müşteri Kartı"'
assert s.count(A4)==1, "A4: %d"%s.count(A4)
s=s.replace(A4, A4+',\n  "rep-aktivite": "Temsilci Aktivite"', 1)

A5='const VIEWS = {};'
assert s.count(A5)==1, "A5: %d"%s.count(A5)
FN=r'''const VIEWS = {};

VIEWS["rep-aktivite"] = async (m) => { /* REP_AKTIVITE_UI_V1 */
  if (!S.isYonetim) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">🔒</div><h3>Erisim yok</h3><p>Bu bolum yalniz yonetime ozeldir.</p></div></div>`; return; }
  const gun = S._aktGun || 7;
  const d = await api("/api/saha/rep-aktivite?gun=" + gun);
  const reps = d.repler || [];
  const online = reps.filter(r => r.online).length;
  const rel = (ts) => { if (!ts) return "—"; const s = Math.floor((Date.now() - new Date(ts).getTime())/1000); if (s<60) return "az once"; if (s<3600) return Math.floor(s/60)+" dk once"; if (s<86400) return Math.floor(s/3600)+" sa once"; return Math.floor(s/86400)+" gun once"; };
  const dt = (ts) => ts ? new Date(ts).toLocaleString("tr-TR",{day:"2-digit",month:"2-digit",hour:"2-digit",minute:"2-digit"}) : "—";
  const odaAd = { bugun:"Bugun", ziyaretler:"Ziyaretler", musteriler:"Musteri", iskonto:"Teklif", rapor:"Rapor", plan:"Plan", "rep-brain":"Asistan", asistan:"Asistan", piyasa:"Piyasa", rakip:"Rakip", saha:"Saha", kokpit:"Kokpit", ceo:"CEO" };
  const gbtn = (g,l) => `<button class="ak-g" data-g="${g}" style="border:1px solid var(--cizgi);background:${g===gun?"#2563eb":"transparent"};color:${g===gun?"#fff":"var(--tx-1)"};border-radius:8px;padding:6px 14px;font-size:13px;font-weight:600;cursor:pointer;margin-right:6px">${l}</button>`;
  const row = (r) => `<tr style="border-bottom:1px solid var(--cizgi)">
    <td style="padding:10px 8px;white-space:nowrap"><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:${r.online?"#22c55e":"#94a3b8"};margin-right:8px"></span><b>${esc(r.ad)}</b></td>
    <td style="padding:10px 8px;color:var(--tx-1);white-space:nowrap">${dt(r.son_giris)}</td>
    <td style="padding:10px 8px;color:${r.online?"#16a34a":"var(--tx-1)"};white-space:nowrap">${r.online?"cevrimici":rel(r.son_aktivite)}</td>
    <td style="padding:10px 8px;text-align:center">${r.dk_bugun} dk</td>
    <td style="padding:10px 8px;text-align:center">${r.dk_hafta} dk</td>
    <td style="padding:10px 8px;text-align:center">${r.ziyaret}</td>
    <td style="padding:10px 8px;text-align:center;color:${r.hata>0?"#dc2626":"inherit"};font-weight:${r.hata>0?"700":"400"}">${r.hata}</td>
    <td style="padding:10px 8px;color:var(--tx-1);white-space:nowrap">${r.en_cok_oda?esc(odaAd[r.en_cok_oda]||r.en_cok_oda):"—"}</td>
  </tr>`;
  m.innerHTML = `
    <div class="dk-card">
      <div class="dk-card-h"><h3>📡 Temsilci Aktivite</h3><span class="sub">${online}/${reps.length} cevrimici</span></div>
      <div style="margin:6px 0 14px">${gbtn(1,"Bugun")}${gbtn(7,"7 gun")}${gbtn(30,"30 gun")}<span style="color:#94a3b8;font-size:12px;margin-left:8px">ziyaret/hata penceresi</span></div>
      ${reps.length ? `<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;font-size:13px">
        <thead><tr style="border-bottom:2px solid var(--cizgi);text-align:left;color:#94a3b8;font-size:12px">
          <th style="padding:8px">Temsilci</th><th style="padding:8px">Son giris</th><th style="padding:8px">Son islem</th>
          <th style="padding:8px;text-align:center">Bugun</th><th style="padding:8px;text-align:center">7 gun</th>
          <th style="padding:8px;text-align:center">Ziyaret</th><th style="padding:8px;text-align:center">Hata</th><th style="padding:8px">En cok</th>
        </tr></thead><tbody>${reps.map(row).join("")}</tbody></table></div>` : `<div class="dk-empty-s">Kayit yok</div>`}
    </div>`;
  m.querySelectorAll(".ak-g").forEach(b => b.addEventListener("click", () => { S._aktGun = parseInt(b.dataset.g, 10); go("rep-aktivite"); }));
};'''
s=s.replace(A5, FN, 1)
open(F,"w",encoding="utf-8").write(s)
print("[ok] REP_AKTIVITE_UI_V1 saha_desktop.js'e eklendi")
