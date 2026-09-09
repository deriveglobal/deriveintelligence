#!/usr/bin/env python3
# EKIP_PLAN_V2 (mobil) — Ekip Planı panosunu gorsel yeniden tasarim. v1 duz liste/menu → renkli gruplu pano.
#   Rep secimi TIKLANABILIR renkli cipler; gune gore bolumler (Bugün/Yarın/Bu hafta/Gelecek) + "⚠ Tarihi gecmis".
#   Veri: TUM PLANLANDI (gelecek 0, gecmis 9 idi) → gecmis-tamamlanmamis da gosterilir. Sadece vEkipPlan gövdesi degisir.
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
if "EKIP_PLAN_V2" in src: print("[=] zaten mevcut (idempotent)"); sys.exit(0)

START = "async function vEkipPlan() {  /* EKIP_PLAN_V1"
END = "\nfunction _planSatir(z) {  /* EKIP_PLAN_V1"
i = src.find(START); j = src.find(END)
if i < 0 or j < 0 or j < i: print("HATA: v1 vEkipPlan sinirlari bulunamadi (i=%d j=%d)" % (i, j)); sys.exit(1)

NEW = r'''async function vEkipPlan() {  /* EKIP_PLAN_V2 — gorsel gruplu pano: rep cipleri + gune gore bolumler + gecikmis */
  if (!["manager","admin"].includes(S.role)) { main().innerHTML = `<div class="saha-bos">Bu bölüm sadece yönetim içindir.</div>`; return; }
  try {
    const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`);
    const plan = (ziyaretler || []).filter(z => z.planlanan_tarih);
    const m = main();
    if (!plan.length) { m.innerHTML = `<div style="padding:16px"><b style="font-size:15px">Ekip Planı</b><div class="saha-bos" style="margin-top:16px">Henüz planlanmış ziyaret yok.<br><span style="font-size:12px;color:#94a3b8">Temsilciler Plan sekmesinden ileri tarihli ziyaret ekledikçe burada görünür.</span></div></div>`; return; }
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
      return `<div style="background:#fff;border:1px solid #e5e7eb;border-left:4px solid ${r};border-radius:10px;padding:10px 12px;margin-bottom:8px">
        <div style="display:flex;justify-content:space-between;gap:8px;align-items:baseline">
          <span style="font-size:14px;font-weight:600;color:#1e293b;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(z.firma || "—")}</span>
          <span style="font-size:12px;color:#0284c7;font-weight:600;flex-shrink:0">${t}</span>
        </div>
        <div style="display:flex;justify-content:space-between;gap:8px;margin-top:4px;font-size:12px;color:#64748b">
          <span style="display:flex;align-items:center;gap:5px"><span style="width:8px;height:8px;border-radius:50%;background:${r};display:inline-block"></span>${esc(repAdOf(z))}</span>
          ${yer ? `<span style="flex-shrink:0">${esc(yer)}</span>` : ""}
        </div>
      </div>`;
    };
    const baslik = (etk, n, renk) => `<div style="display:flex;align-items:center;gap:8px;margin:16px 0 8px"><span style="font-size:13px;font-weight:700;color:${renk||'#334155'}">${etk}</span><span style="background:${renk||'#334155'};color:#fff;font-size:11px;border-radius:9px;padding:0 7px">${n}</span></div>`;
    const cizPano = () => {
      const rows = (sate ? plan.filter(z => repAdOf(z) === sate) : plan).slice().sort((a,b) => gun(a).localeCompare(gun(b)));
      const F = f => rows.filter(f);
      let h = "";
      const bg = F(z => gun(z) === bugun); if (bg.length) h += baslik("Bugün", bg.length) + bg.map(kart).join("");
      const yr = F(z => gun(z) === yarin); if (yr.length) h += baslik("Yarın", yr.length) + yr.map(kart).join("");
      const bh = F(z => gun(z) > bugun && gun(z) <= haftaIso && gun(z) !== yarin); if (bh.length) h += baslik("Bu hafta", bh.length) + bh.map(kart).join("");
      const il = F(z => gun(z) > haftaIso); if (il.length) h += baslik("Gelecek", il.length) + il.map(kart).join("");
      const gc = F(z => gun(z) < bugun); if (gc.length) h += baslik("⚠ Tarihi geçmiş (tamamlanmamış)", gc.length, "#b45309") + gc.map(kart).join("");
      return h || `<div class="saha-bos">Bu temsilci için plan yok.</div>`;
    };
    const cip = (lbl, val, renk, n) => { const on = sate === val; return `<button class="ep-cip" data-r="${val === "" ? "" : esc(val)}" style="border:1px solid ${on ? (renk||'#0f172a') : '#e2e8f0'};background:${on ? (renk||'#0f172a') : '#fff'};color:${on ? '#fff' : '#334155'};border-radius:16px;padding:4px 12px;font-size:12px;cursor:pointer;margin:0 6px 6px 0;display:inline-flex;align-items:center;gap:6px">${renk ? `<span style="width:8px;height:8px;border-radius:50%;background:${on ? '#fff' : renk};display:inline-block"></span>` : ""}${esc(lbl)} (${n})</button>`; };
    const cipler = () => cip("Tümü", "", null, plan.length) + repAdlari.map(a => cip(a, a, renkOf[a], plan.filter(z => repAdOf(z) === a).length)).join("");
    m.innerHTML = `<div style="padding:12px">
      <b style="font-size:15px">Ekip Planı</b>
      <div style="font-size:12px;color:#64748b;margin:2px 0 10px">${plan.length} planlı ziyaret · ${repAdlari.length} temsilci</div>
      <div id="ep-cipler" style="margin-bottom:4px">${cipler()}</div>
      <div id="ep-pano">${cizPano()}</div>
    </div>`;
    const wire = () => m.querySelectorAll(".ep-cip").forEach(b => b.addEventListener("click", () => { sate = b.dataset.r; m.querySelector("#ep-cipler").innerHTML = cipler(); m.querySelector("#ep-pano").innerHTML = cizPano(); wire(); }));
    wire();
  } catch (e) { main().innerHTML = hata(e); }
}'''

src = src[:i] + NEW + src[j:]
with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] vEkipPlan v2 yazildi:", path)
