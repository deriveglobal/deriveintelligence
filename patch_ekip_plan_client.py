#!/usr/bin/env python3
# EKIP_PLAN_V1 (mobil client) — Yonetici tarafi ziyaret plani gorunumu (Huseyin Bilgi 10 Agu; Fatih onayli).
#   PASIF gorunum (rep bir sey gondermez): (1) Plan sekmesi yoneticide KENDI planlari (S.me.id filtre),
#   (2) yeni "Ekip Planı" yonetici sekmesi = tum ekibin gelecek planlari, rep filtreli konsolide pano,
#   (3) rep detay modalinda o rep'in gelecek plani. Server DEGISMEZ — /api/saha/ziyaretler zaten
#   yoneticiye rep-filtresiz + ?rep_id ile doner. Idempotent (marker: EKIP_PLAN_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "EKIP_PLAN_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

edits = []

# ── 1) vEkipPlan + _planSatir — vPlan'dan once ──
edits.append(("fonksiyonlar",
  '''async function vPlan() {''',
  '''async function vEkipPlan() {  /* ''' + MARK + ''' — yonetici: tum ekibin gelecek planlari (pasif) */
  if (!["manager","admin"].includes(S.role)) { main().innerHTML = `<div class="saha-bos">Bu bölüm sadece yönetim içindir.</div>`; return; }
  try {
    const bugun = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
    const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`);
    const ileri = (ziyaretler || []).filter(z => (z.planlanan_tarih || "").slice(0, 10) >= bugun);
    const grup = {};
    ileri.forEach(z => { const k = z.rep_id || "?"; if (!grup[k]) grup[k] = { ad: z.rep_full_name || z.rep_adi || "—", items: [] }; grup[k].items.push(z); });
    const repler = Object.values(grup).sort((a, b) => String(a.ad).localeCompare(String(b.ad), "tr"));
    repler.forEach(r => r.items.sort((a, b) => (a.planlanan_tarih || "").localeCompare(b.planlanan_tarih || "")));
    const m = main();
    if (!repler.length) { m.innerHTML = `<div style="padding:12px"><b style="font-size:15px">Ekip Planı</b><div class="saha-bos">Gelecek planlı ziyaret yok.</div></div>`; return; }
    const secenek = ['<option value="">Tüm temsilciler</option>'].concat(repler.map((r, i) => `<option value="${i}">${esc(r.ad)} (${r.items.length})</option>`)).join("");
    m.innerHTML = `
      <div style="padding:12px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px;gap:8px">
          <b style="font-size:15px">Ekip Planı</b>
          <select id="ep-rep" class="giris" style="max-width:60%">${secenek}</select>
        </div>
        <div style="font-size:12px;color:#64748b;margin-bottom:10px">${ileri.length} planlı ziyaret · ${repler.length} temsilci · bugünden itibaren</div>
        <div id="ep-liste"></div>
      </div>`;
    const render = (sel) => {
      const liste = m.querySelector("#ep-liste");
      const goster = sel === "" ? repler : [repler[Number(sel)]].filter(Boolean);
      liste.innerHTML = goster.map(r => `
        <div style="background:#fff;border:1px solid #e5e7eb;border-radius:10px;padding:12px;margin-bottom:10px">
          <div style="font-weight:600;font-size:14px;margin-bottom:4px">${esc(r.ad)} <span style="font-size:12px;color:#94a3b8;font-weight:400">· ${r.items.length} ziyaret</span></div>
          ${r.items.map(z => _planSatir(z)).join("")}
        </div>`).join("");
    };
    render("");
    m.querySelector("#ep-rep")?.addEventListener("change", e => render(e.target.value));
  } catch (e) { main().innerHTML = hata(e); }
}
function _planSatir(z) {  /* ''' + MARK + ''' — tek plan satiri (tarih · firma · il) */
  const bugun = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
  const d = (z.planlanan_tarih || "").slice(0, 10);
  const tarih = d ? new Date(d + "T12:00:00").toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", weekday: "short", day: "numeric", month: "short" }) : "—";
  const gecmis = d && d < bugun;
  const yer = [z.il, z.ilce].filter(Boolean).join(" / ");
  return `<div style="display:flex;align-items:center;gap:10px;padding:6px 0;border-top:1px solid #f1f5f9">
    <span style="font-size:12px;color:${gecmis ? '#b45309' : '#0284c7'};min-width:96px;font-weight:600">${tarih}</span>
    <span style="flex:1;font-size:13px;color:#1e293b;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">${esc(z.firma || "—")}</span>
    ${yer ? `<span style="font-size:11px;color:#94a3b8;flex-shrink:0">${esc(yer)}</span>` : ""}
  </div>`;
}

async function vPlan() {'''))

# ── 2) view dispatch map ──
edits.append(("view-map",
  ''' 'rep-brain': vRepBrain, piyasa: vPiyasa, rakip: vRakip, duyurular: vDuyurular, mesajlar: vMesajlar, oneriler: vOneriler, sistem: vSistem, 'rep-aktivite': vRepAktivite }[v] || vBugun)();''',
  ''' 'rep-brain': vRepBrain, piyasa: vPiyasa, rakip: vRakip, duyurular: vDuyurular, mesajlar: vMesajlar, oneriler: vOneriler, sistem: vSistem, 'rep-aktivite': vRepAktivite, 'ekip-plan': vEkipPlan /* ''' + MARK + ''' */ }[v] || vBugun)();'''))

# ── 3) sekme listesi — yonetici-gated Ekip Plani ──
edits.append(("sekme",
  '''    ["ziyaretler", "📋", "Ziyaretler"], ["plan", "🗓️", "Plan"],''',
  '''    ["ziyaretler", "📋", "Ziyaretler"], ["plan", "🗓️", "Plan"],
    ...(["manager","admin"].includes(S.role) ? [["ekip-plan", "🗺️", "Ekip Planı"]] : []),  /* ''' + MARK + ''' */'''))

# ── 4) vPlan: yoneticide KENDI planlari ──
edits.append(("vplan-own",
  '''    const [{ ziyaretler }, notResp] = await Promise.all([
      api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`),
      api("/api/saha/notlar").catch(() => ({ notlar: [] }))
    ]);''',
  '''    const [_planR, notResp] = await Promise.all([
      api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`),
      api("/api/saha/notlar").catch(() => ({ notlar: [] }))
    ]);
    /* ''' + MARK + ''' — Plan sekmesi yoneticide KENDI planlari; ekip plani ayri sekmede */
    const ziyaretler = ["manager","admin"].includes(S.role) ? (_planR.ziyaretler || []).filter(z => z.rep_id === S.me.id) : (_planR.ziyaretler || []);'''))

# ── 5) rep detay modalinda gelecek plani — container + async fill ──
edits.append(("repdetay-html",
  '''    <div style="display:flex;align-items:center;gap:12px;margin-bottom:16px">
      <div style="width:52px;height:52px;border-radius:50%;background:${rolRenk};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:20px">${esc(initials)}</div>
      <div>
        <div style="font-weight:700;font-size:16px">${esc(rep.full_name)}</div>
        <div style="font-size:12px;color:#6b7280">${esc(rep.email)}</div>
      </div>
    </div>''',
  '''    <div style="display:flex;align-items:center;gap:12px;margin-bottom:16px">
      <div style="width:52px;height:52px;border-radius:50%;background:${rolRenk};color:#fff;display:flex;align-items:center;justify-content:center;font-weight:700;font-size:20px">${esc(initials)}</div>
      <div>
        <div style="font-weight:700;font-size:16px">${esc(rep.full_name)}</div>
        <div style="font-size:12px;color:#6b7280">${esc(rep.email)}</div>
      </div>
    </div>
    <div style="margin-bottom:14px"><!-- ''' + MARK + ''' -->
      <div class="giris-etiket">Gelecek planı</div>
      <div id="tr-plan" style="border:1px solid #e5e7eb;border-radius:8px;padding:8px"><span style="font-size:12px;color:#94a3b8">yükleniyor…</span></div>
    </div>'''))
edits.append(("repdetay-fill",
  '''  // City checkbox logic''',
  '''  (async () => {  /* ''' + MARK + ''' — rep detayinda gelecek plani */
    const box = document.getElementById("tr-plan"); if (!box) return;
    try {
      const bugun = new Date().toLocaleDateString('en-CA', { timeZone: 'Europe/Istanbul' });
      const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=PLANLANDI&rep_id=${encodeURIComponent(rep.id)}`);
      const ileri = (ziyaretler || []).filter(z => (z.planlanan_tarih || "").slice(0, 10) >= bugun).sort((a, b) => (a.planlanan_tarih || "").localeCompare(b.planlanan_tarih || ""));
      box.innerHTML = ileri.length ? ileri.map(z => _planSatir(z)).join("") : '<span style="font-size:12px;color:#94a3b8">Gelecek planlı ziyaret yok.</span>';
    } catch (e) { box.innerHTML = '<span style="font-size:12px;color:#94a3b8">Plan yüklenemedi.</span>'; }
  })();

  // City checkbox logic'''))

for ad, old, new in edits:
    c = src.count(old)
    if c != 1:
        print("HATA: anchor '" + ad + "' " + str(c) + " kez (1 bekleniyor)"); sys.exit(1)
    src = src.replace(old, new, 1); print("[+] " + ad)

if src == orig: print("[=] Degisiklik yok"); sys.exit(1)
with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path, "(", len(edits), "blok )")
