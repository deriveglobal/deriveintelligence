#!/usr/bin/env python3
# EKIP_PLAN_DK_V1 (masaustu client, saha_desktop.js) — Yonetici tarafi ziyaret plani (Huseyin Bilgi; Fatih onayli).
#   Mobil EKIP_PLAN_V1 ile ayni davranis, dk- stilleri: (1) Plan gorunumu yoneticide KENDI planlari,
#   (2) yeni "Ekip Planı" yonetim nav girisi = tum ekibin gelecek planlari, rep filtreli tablo.
#   Server DEGISMEZ. Idempotent (marker: EKIP_PLAN_DK_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "EKIP_PLAN_DK_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

edits = []

# ── 1) nav: Yonetim Analiz grubuna Ekip Plani ──
edits.append(("nav",
  '''if (mgmt) g.push(["Yönetim Analiz", [["harita", "🗺️", "Harita"],''',
  '''if (mgmt) g.push(["Yönetim Analiz", [["ekip-plan", "👥", "Ekip Planı"], ["harita", "🗺️", "Harita"],'''))

# ── 2) TITLE ──
edits.append(("title",
  '''  kokpit: "Kokpit", ceo: "CEO Asistan", "yon-portfoy": "Yönetici Portföy", temsilciler: "Ekip", sistem: "Sistem",''',
  '''  kokpit: "Kokpit", ceo: "CEO Asistan", "yon-portfoy": "Yönetici Portföy", "ekip-plan": "Ekip Planı", temsilciler: "Ekip", sistem: "Sistem",'''))

# ── 3) SEG_VIEW (semsiye toggle Plan gibi) ──
edits.append(("seg",
  '''const SEG_VIEW = new Set(["bugun", "ziyaretler", "plan", "musteriler", "rapor", "harita", "kokpit"]);''',
  '''const SEG_VIEW = new Set(["bugun", "ziyaretler", "plan", "musteriler", "rapor", "harita", "kokpit", "ekip-plan"]);  /* ''' + MARK + ''' */'''))

# ── 4) VIEWS["ekip-plan"] ──
edits.append(("view",
  '''const VIEWS = {};''',
  '''const VIEWS = {};
VIEWS["ekip-plan"] = async (m) => {  /* ''' + MARK + ''' — yonetici: tum ekibin gelecek planlari (pasif gorunum) */
  if (!["manager","admin"].includes(S.role)) { m.innerHTML = `<div class="dk-card"><div class="dk-empty"><div class="ic">🔒</div><h3>Erişim yok</h3><p>Bu bölüm yönetim içindir.</p></div></div>`; return; }
  const bugun = new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
  const { ziyaretler = [] } = await api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`);
  const ileri = ziyaretler.filter(z => (z.planlanan_tarih || "").slice(0, 10) >= bugun)
    .sort((a, b) => { const ra = String(a.rep_full_name || a.rep_adi || "").localeCompare(String(b.rep_full_name || b.rep_adi || ""), "tr"); return ra !== 0 ? ra : (a.planlanan_tarih || "").localeCompare(b.planlanan_tarih || ""); });
  const repAdlari = [...new Set(ileri.map(z => z.rep_full_name || z.rep_adi || "—"))].sort((a, b) => a.localeCompare(b, "tr"));
  const trh = z => { const d = (z.planlanan_tarih || "").slice(0, 10); return d ? new Date(d + "T12:00:00").toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul", weekday: "short", day: "numeric", month: "short" }) : "—"; };
  const satirlar = () => {
    const sel = (m.querySelector("#ep-rep") || {}).value || "";
    const rows = ileri.filter(z => !sel || (z.rep_full_name || z.rep_adi || "—") === sel);
    if (!rows.length) return `<tr><td colspan="4" style="text-align:center;color:var(--tx-2);padding:16px">Gelecek planlı ziyaret yok.</td></tr>`;
    return rows.map(z => `<tr><td class="firm">${esc(z.rep_full_name || z.rep_adi || "—")}</td><td>${esc(z.firma || "—")}</td><td>${trh(z)}</td><td class="sub2">${esc([z.il, z.ilce].filter(Boolean).join(" / "))}</td></tr>`).join("");
  };
  m.innerHTML = `
    <div class="dk-card" style="padding:0;overflow:hidden">
      <div class="dk-card-h" style="padding:14px 18px;margin:0;border-bottom:1px solid var(--cizgi);gap:10px;display:flex;align-items:center">
        <h3>👥 Ekip Planı</h3>
        <span class="sub" style="margin-left:6px">${ileri.length} planlı · ${repAdlari.length} temsilci · bugünden itibaren</span>
        <select id="ep-rep" class="dk-select" style="margin-left:auto"><option value="">Tüm temsilciler</option>${repAdlari.map(a => `<option value="${esc(a)}">${esc(a)}</option>`).join("")}</select>
      </div>
      <div style="overflow-x:auto"><table class="dk-t">
        <thead><tr><th>Temsilci</th><th>Firma</th><th>Tarih</th><th>İl / İlçe</th></tr></thead>
        <tbody id="ep-body">${satirlar()}</tbody></table></div>
    </div>`;
  m.querySelector("#ep-rep")?.addEventListener("change", () => { const b = m.querySelector("#ep-body"); if (b) b.innerHTML = satirlar(); });
};'''))

# ── 5) VIEWS.plan: yoneticide KENDI planlari ──
edits.append(("plan-own",
  '''  const [{ ziyaretler = [] }, notResp] = await Promise.all([
    api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`),
    api("/api/saha/notlar").catch(() => ({ notlar: [] }))
  ]);''',
  '''  const [_planR = {}, notResp] = await Promise.all([
    api(`/api/saha/ziyaretler?durum=PLANLANDI${tipQS()}`),
    api("/api/saha/notlar").catch(() => ({ notlar: [] }))
  ]);
  /* ''' + MARK + ''' — Plan yoneticide KENDI planlari; ekip plani ayri nav */
  const ziyaretler = ["manager","admin"].includes(S.role) ? (_planR.ziyaretler || []).filter(z => z.rep_id === S.me.id) : (_planR.ziyaretler || []);'''))

for ad, old, new in edits:
    c = src.count(old)
    if c != 1:
        print("HATA: anchor '" + ad + "' " + str(c) + " kez (1 bekleniyor)"); sys.exit(1)
    src = src.replace(old, new, 1); print("[+] " + ad)

if src == orig: print("[=] Degisiklik yok"); sys.exit(1)
with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path, "(", len(edits), "blok )")
