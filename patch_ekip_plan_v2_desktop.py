#!/usr/bin/env python3
# EKIP_PLAN_DK_V2 (masaustu) — Ekip Planı gorsel yeniden tasarim. v1 duz tablo → renkli gruplu kart panosu.
#   Rep secimi tiklanabilir renkli cipler; gune gore bolumler + "⚠ Tarihi gecmis". Tema-degiskenleriyle (koyu/acik).
#   Sadece VIEWS["ekip-plan"] gövdesi degisir.
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
if "EKIP_PLAN_DK_V2" in src: print("[=] zaten mevcut (idempotent)"); sys.exit(0)

START = 'VIEWS["ekip-plan"] = async (m) => {  /* EKIP_PLAN_DK_V1'
END = '\nVIEWS["yon-portfoy"] = (m) => {  /* YONPORTFOY_VIEW_DK_V1 */'
i = src.find(START); j = src.find(END)
if i < 0 or j < 0 or j < i: print("HATA: v1 desktop sinirlari bulunamadi (i=%d j=%d)" % (i, j)); sys.exit(1)

NEW = r'''VIEWS["ekip-plan"] = async (m) => {  /* EKIP_PLAN_DK_V2 — gorsel gruplu kart panosu: rep cipleri + gune gore bolumler + gecikmis */
  if (!["manager","admin"].includes(S.role)) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">🔒</div><h3>Erişim yok</h3><p>Bu bölüm yönetim içindir.</p></div></div>`; return; }
  const { ziyaretler = [] } = await api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`);
  const plan = ziyaretler.filter(z => z.planlanan_tarih);
  if (!plan.length) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">🗓️</div><h3>Plan yok</h3><p>Temsilciler Plan sekmesinden ileri tarihli ziyaret ekledikçe burada görünür.</p></div></div>`; return; }
  const PAL = ['#0ea5e9','#16a34a','#f59e0b','#7c3aed','#dc2626','#0891b2','#db2777','#65a30d'];
  const repAdOf = z => z.rep_full_name || z.rep_adi || "—";
  const repAdlari = [...new Set(plan.map(repAdOf))].sort((a,b) => a.localeCompare(b, "tr"));
  const renkOf = {}; repAdlari.forEach((a,i) => renkOf[a] = PAL[i % PAL.length]);
  const bugun = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
  const yd = new Date(bugun+"T12:00:00"); yd.setDate(yd.getDate()+1); const yarin = yd.toLocaleDateString('en-CA');
  const hd = new Date(bugun+"T12:00:00"); hd.setDate(hd.getDate()+7); const haftaIso = hd.toLocaleDateString('en-CA');
  const gun = z => (z.planlanan_tarih || "").slice(0,10);
  let sate = "";
  const kart = z => {
    const r = renkOf[repAdOf(z)] || "#64748b";
    const d = gun(z);
    const t = d ? new Date(d+"T12:00:00").toLocaleDateString("tr-TR", { timeZone:"Europe/Istanbul", weekday:"short", day:"numeric", month:"short" }) : "—";
    const yer = [z.il, z.ilce].filter(Boolean).join(" / ");
    return `<div style="background:rgba(127,127,127,.06);border:1px solid var(--cizgi);border-left:4px solid ${r};border-radius:10px;padding:10px 12px">
      <div style="display:flex;justify-content:space-between;gap:10px;align-items:baseline"><span style="font-weight:600;font-size:14px;color:var(--tx-1)">${esc(z.firma || "—")}</span><span style="color:#0ea5e9;font-weight:600;font-size:12px;white-space:nowrap">${t}</span></div>
      <div style="display:flex;justify-content:space-between;gap:10px;margin-top:4px;font-size:12px;color:var(--tx-2)"><span style="display:flex;align-items:center;gap:5px"><span style="width:8px;height:8px;border-radius:50%;background:${r};display:inline-block"></span>${esc(repAdOf(z))}</span>${yer ? `<span>${esc(yer)}</span>` : ""}</div>
    </div>`;
  };
  const bolum = (etk, rows, renk) => rows.length ? `<div style="font-size:13px;font-weight:700;color:${renk||'var(--tx-1)'};margin:16px 0 8px;display:flex;align-items:center;gap:8px">${etk}<span style="background:${renk||'#475569'};color:#fff;font-size:11px;border-radius:9px;padding:0 7px">${rows.length}</span></div><div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(270px,1fr));gap:10px">${rows.map(kart).join("")}</div>` : "";
  const cizPano = () => {
    const rows = (sate ? plan.filter(z => repAdOf(z) === sate) : plan).slice().sort((a,b) => gun(a).localeCompare(gun(b)));
    const F = f => rows.filter(f);
    let h = "";
    h += bolum("Bugün", F(z => gun(z) === bugun));
    h += bolum("Yarın", F(z => gun(z) === yarin));
    h += bolum("Bu hafta", F(z => gun(z) > bugun && gun(z) <= haftaIso && gun(z) !== yarin));
    h += bolum("Gelecek", F(z => gun(z) > haftaIso));
    h += bolum("⚠ Tarihi geçmiş (tamamlanmamış)", F(z => gun(z) < bugun), "#b45309");
    return h || `<div style="color:var(--tx-2);padding:16px">Bu temsilci için plan yok.</div>`;
  };
  const cip = (lbl, val, renk, n) => { const on = sate === val; return `<button class="ep-cip" data-r="${val === "" ? "" : esc(val)}" style="border:1px solid ${on ? (renk||'#0f172a') : 'var(--cizgi)'};background:${on ? (renk||'#0f172a') : 'transparent'};color:${on ? '#fff' : 'var(--tx-1)'};border-radius:16px;padding:5px 12px;font-size:12px;cursor:pointer;display:inline-flex;align-items:center;gap:6px">${renk ? `<span style="width:8px;height:8px;border-radius:50%;background:${on ? '#fff' : renk};display:inline-block"></span>` : ""}${esc(lbl)} (${n})</button>`; };
  const cipler = () => cip("Tümü", "", null, plan.length) + repAdlari.map(a => cip(a, a, renkOf[a], plan.filter(z => repAdOf(z) === a).length)).join("");
  m.innerHTML = `<div class="dk-card">
    <div class="dk-card-h" style="display:flex;align-items:center;gap:10px"><h3>👥 Ekip Planı</h3><span class="sub">${plan.length} planlı ziyaret · ${repAdlari.length} temsilci</span></div>
    <div id="ep-cipler" style="display:flex;flex-wrap:wrap;gap:8px;margin:10px 0 4px">${cipler()}</div>
    <div id="ep-pano">${cizPano()}</div>
  </div>`;
  const wire = () => m.querySelectorAll(".ep-cip").forEach(b => b.addEventListener("click", () => { sate = b.dataset.r; m.querySelector("#ep-cipler").innerHTML = cipler(); m.querySelector("#ep-pano").innerHTML = cizPano(); wire(); }));
  wire();
};'''

src = src[:i] + NEW + src[j:]
print("[+] VIEWS[ekip-plan] gorsel v2")

# ── governance: CATALOG'a ekip-plan ekle → yetki matrisinde kolon (EKIP_PLAN_DK_V2) ──
cat_old = '''["Yönetim & Analiz", [["rapor","Rapor"],["kokpit","Kokpit"],["ceo","CEO"],["rep-aktivite","Aktivite"]]],'''
cat_new = '''["Yönetim & Analiz", [["rapor","Rapor"],["ekip-plan","Ekip Planı"],["kokpit","Kokpit"],["ceo","CEO"],["rep-aktivite","Aktivite"]]],  /* EKIP_PLAN_DK_V2 — matris kolonu */'''
if cat_old not in src:
    print("HATA: CATALOG 'Yönetim & Analiz' anchor bulunamadi"); sys.exit(1)
src = src.replace(cat_old, cat_new, 1)
print("[+] CATALOG'a ekip-plan (matris kolonu)")

with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path)
