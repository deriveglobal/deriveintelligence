# -*- coding: utf-8 -*-
# SABAH_ROTAM_DK_V2 (masaüstü) — Rotam sekmesi YÖNETİCİ görünümü ("Bugün Sahada" ekip panosu).
#   Desktop Rapor mgr-only olduğu için burada asıl izleyici yönetici. rol=="yonetici" → ekip panosu.
#   Rep dalı (kişisel rota) yerinde kalır (edge). Mobil = rep rotası.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_DK_V2" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_DK_V1" in s, "HATA: once SABAH_ROTAM_DK_V1 olmali"

# 1) rpRotam içine yönetici dalı (fetch sonrası)
o1 = '''    const box = icerik(); if (!box) return;
    const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
    const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(Math.round(m % 60)).padStart(2, "0");'''
n1 = '''    const box = icerik(); if (!box) return;
    if (d && d.rol === "yonetici") { return rpRotamEkip(d, box); }  /* SABAH_ROTAM_DK_V2 */
    const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
    const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(Math.round(m % 60)).padStart(2, "0");'''
assert s.count(o1) == 1, "rpRotam branch anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rpRotamEkip fonksiyonu — rpRotam'dan önce
anchor = "  async function rpRotam() {  /* SABAH_ROTAM_DK_V1 */"
FN = r'''  function rpRotamEkip(d, box) {  /* SABAH_ROTAM_DK_V2 */
    const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
    const ALAN = { TICARI: { ad: "Ticari", c: "#f59e0b" }, TUKETICI: { ad: "Tüketici", c: "#0ea5e9" } };
    const alanOf = (t) => { const a = String(t || "").toUpperCase(); return a === "TUKETICI" ? "TUKETICI" : a === "TICARI" ? "TICARI" : null; };
    const T = d.toplam || {}, ekip = d.ekip || [], kritik = d.kritik || [];
    const CSS = `<style>
      .rt{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mor:#6d5ae0;--mor-z:#f0edfd;--mavi:#2563eb;--mavi-z:#EEF3FE;color-scheme:light;color:var(--tx-0);font-family:var(--sans,-apple-system,'Segoe UI',system-ui,sans-serif)}
      .rt *{box-sizing:border-box}
      .rt-hd{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:2px 2px 4px}.rt-hd .t{font-size:20px;font-weight:800;letter-spacing:-.02em}
      .rt-live{display:flex;align-items:center;gap:6px;font-size:11px;font-weight:700;color:var(--yesil)}.rt-live .dot{width:8px;height:8px;border-radius:50%;background:var(--yesil);animation:rtp2 1.8s infinite}
      @keyframes rtp2{0%{box-shadow:0 0 0 0 rgba(16,107,74,.45)}70%{box-shadow:0 0 0 7px rgba(16,107,74,0)}100%{box-shadow:0 0 0 0 rgba(16,107,74,0)}}
      .rt-sub{font-size:12.5px;color:var(--tx-2);font-weight:600;margin:0 2px 12px}
      .rt-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:14px 16px;margin-bottom:14px}
      .rt-intro h3{margin:0 0 6px;font-size:13.5px;font-weight:800}.rt-intro p{margin:0;font-size:12.5px;line-height:1.6;color:var(--tx-1)}
      .rt-intro .calc{display:flex;flex-direction:column;gap:5px;margin-top:9px;padding-top:10px;border-top:1px solid var(--cizgi)}.rt-intro .calc div{font-size:12px;color:var(--tx-1);line-height:1.5}.rt-intro .calc b{color:var(--tx-0)}
      .rt-grid{display:grid;gap:10px;grid-template-columns:repeat(4,1fr)}
      .rt-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:13px 14px}.rt-tile .n{font-size:24px;font-weight:800;line-height:1;font-variant-numeric:tabular-nums}.rt-tile .l{font-size:11px;color:var(--tx-1);margin-top:6px;font-weight:500}
      .rt-tile.al{border-color:rgba(196,61,40,.3);background:linear-gradient(180deg,#fff,#fdf6f4)}.rt-tile.al .n{color:var(--kirmizi)}
      .rt-sech{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.06em;margin:20px 2px 10px}
      .rt-rep{display:flex;flex-direction:column;gap:9px}
      .rt-rrow{display:grid;grid-template-columns:1fr 130px 210px;gap:16px;align-items:center;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:13px;padding:13px 15px}
      .rt-rnm{font-size:14.5px;font-weight:700;display:flex;align-items:center;gap:8px}.rt-seg{font-size:9.5px;font-weight:800;padding:1px 7px;border-radius:999px}
      .rt-rsub{font-size:11.5px;color:var(--tx-2);margin-top:4px}.rt-rsub b{color:var(--tx-1);font-variant-numeric:tabular-nums}
      .rt-prog .pl{display:flex;justify-content:space-between;font-size:10.5px;color:var(--tx-2);font-weight:600;margin-bottom:4px}.rt-prog .pl b{color:var(--tx-0);font-variant-numeric:tabular-nums}
      .rt-track{height:7px;border-radius:999px;background:var(--zemin-2);overflow:hidden}.rt-fill{height:100%;border-radius:999px;background:linear-gradient(90deg,#106B4A,#12b981)}.rt-fill.low{background:linear-gradient(90deg,#C43D28,#e5734f)}
      .rt-skip{background:var(--kirmizi-z);border:1px solid rgba(196,61,40,.18);border-radius:10px;padding:8px 10px;cursor:pointer}.rt-skip .k{font-size:9.5px;font-weight:800;color:var(--kirmizi);text-transform:uppercase;letter-spacing:.04em}.rt-skip .v{font-size:12px;font-weight:700;color:var(--tx-0);margin-top:2px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .rt-skip.none{background:var(--yesil-z);border-color:rgba(16,107,74,.18);cursor:default}.rt-skip.none .k{color:var(--yesil)}
      .rt-crit{display:flex;flex-direction:column;gap:8px}
      .rt-crow{display:grid;grid-template-columns:34px 1fr 160px 120px;gap:12px;align-items:center;background:var(--zemin-1);border:1px solid rgba(196,61,40,.22);border-radius:13px;padding:11px 14px}
      .rt-cs{font-size:18px;font-weight:800;color:var(--kirmizi);text-align:center;font-variant-numeric:tabular-nums}
      .rt-cfirm{font-size:14px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.rt-cmeta{font-size:11px;color:var(--tx-2);margin-top:2px}
      .rt-cwhy{display:flex;gap:5px;flex-wrap:wrap}.rt-chip{font-size:10px;font-weight:700;padding:2px 7px;border-radius:999px}.rt-chip.r{color:var(--kirmizi);background:var(--kirmizi-z)}.rt-chip.c{color:var(--sari);background:var(--sari-z)}
      .rt-cbtn{width:100%;font-size:11.5px;font-weight:700;padding:7px 10px;border-radius:9px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);cursor:pointer}
      .rt-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}
    </style>`;
    const bugunTarih = new Date().toLocaleDateString("tr-TR", { day: "numeric", month: "long", weekday: "long" });
    const repRows = ekip.map((r) => { const meta = alanOf(r.saha_tip) ? ALAN[alanOf(r.saha_tip)] : { ad: "—", c: "#85858C" }; const pct = r.plan ? Math.round(r.yapilan / r.plan * 100) : 0;
      return `<div class="rt-rrow"><div><div class="rt-rnm">${esc(r.rep)}<span class="rt-seg" style="color:${meta.c};background:${meta.c}1f">${meta.ad}</span></div>
        <div class="rt-rsub"><b>${r.plan}</b> planlı · <b>${r.oneri}</b> öncelikli öneri</div></div>
        <div class="rt-prog"><div class="pl"><span>Bugün yapılan</span><b>${r.yapilan}/${r.plan}</b></div><div class="rt-track"><div class="rt-fill${pct < 50 ? " low" : ""}" style="width:${Math.max(4, pct)}%"></div></div></div>
        ${r.skip ? `<div class="rt-skip" data-kart="${esc(r.skip.id)}"><div class="k">⚠ Atladığı en yüksek</div><div class="v">${esc(r.skip.f)} · skor ${r.skip.s}</div></div>` : `<div class="rt-skip none"><div class="k">✓ Öncelikler kapsanıyor</div><div class="v">atlanan yüksek yok</div></div>`}</div>`; }).join("");
    const critRows = kritik.map((c) => `<div class="rt-crow"><div class="rt-cs">${c.skor}</div>
      <div style="min-width:0"><div class="rt-cfirm">${esc(c.firma)}</div><div class="rt-cmeta">${esc(c.il || "")}${c.ilce ? " · " + esc(c.ilce) : ""}${c.rep ? " · sorumlu: " + esc(c.rep) : ` · <b style="color:var(--kirmizi)">sorumlu atanmamış</b>`}</div></div>
      <div class="rt-cwhy">${c.overdue > 0 ? `<span class="rt-chip r">${kisa(c.overdue)} gecikmiş</span>` : ""}${c.gun === null ? `<span class="rt-chip c">hiç ziyaret</span>` : c.gun > 30 ? `<span class="rt-chip c">${c.gun} gün</span>` : ""}</div>
      <div><button class="rt-cbtn" data-kart="${esc(c.id)}">👤 Müşteri kartı</button></div></div>`).join("");
    box.innerHTML = CSS + `<div class="rt">
      <div class="rt-hd"><div class="t">🌅 Bugün Sahada — Ekip</div><div class="rt-live"><span class="dot"></span>CANLI</div></div>
      <div class="rt-sub">${bugunTarih} · ${ekip.length} temsilci</div>
      <div class="rt-intro"><h3>🌅 Bugün Sahada — yönetici için ne anlatır?</h3>
        <p>Temsilci rotası kişiseldir; bu onun <b>ekip görünümü</b>. Tek soru: <b>bugün ekip doğru müşterilere mi yönelmiş?</b> Kimin planı dolu/boş, hangi temsilci kolay durakları yaparken yüksek-öncelikli hesabı atlıyor, ve <b>hangi kritik hesap kimsenin planında değil.</b></p>
        <div class="calc">
          <div><b>Planlı</b> = bugüne PLANLANDI ziyaret. <b>Öncelikli öneri</b> = motorun o rep için ürettiği skor≥40 durak. <b>Yapılan</b> = bugün TAMAMLANDI (canlı).</div>
          <div><b>Atladığı en yüksek</b> = rep'in bugün planlamadığı en yüksek skorlu müşterisi. <b>Sahipsiz kritik</b> = skor≥55 ama bugün kimsenin planında olmayan hesaplar.</div>
        </div></div>
      <div class="rt-grid">
        <div class="rt-tile"><div class="n">${T.plan || 0}</div><div class="l">Bugün planlı durak (ekip)</div></div>
        <div class="rt-tile"><div class="n">${T.oneri || 0}</div><div class="l">Öncelikli öneri</div></div>
        <div class="rt-tile"><div class="n" style="color:var(--yesil)">${T.yapilan || 0}</div><div class="l">Bugün yapılan (canlı)</div></div>
        <div class="rt-tile al"><div class="n">${T.kritik || 0}</div><div class="l">Kritik hesap · ${T.sahipsiz || 0} sahipsiz</div></div>
      </div>
      <div class="rt-sech">Ekip · bugünkü dağılım & öncelik uyumu</div>
      ${ekip.length ? `<div class="rt-rep">${repRows}</div>` : `<div class="rt-empty">Temsilci yok.</div>`}
      <div class="rt-sech">🚨 Sahipsiz / atlanan kritik hesaplar</div>
      ${kritik.length ? `<div class="rt-crit">${critRows}</div>` : `<div class="rt-empty">Kritik açık hesap yok. 👍</div>`}
    </div>`;
    box.querySelectorAll("[data-kart]").forEach(b => b.addEventListener("click", async () => {
      const id = b.dataset.kart; if (!id) return; let c = (S.musteriler || []).find(x => x.id === id);
      if (!c) { try { const res = await api(`/api/saha/musteriler/${id}`); c = res.musteri || res; } catch (e) {} }
      if (c) musteriDetay(c);
    }));
  }
  async function rpRotam() {  /* SABAH_ROTAM_DK_V1 */'''
assert s.count(anchor) == 1, "rpRotamEkip anchor=%d" % s.count(anchor)
s = s.replace(anchor, FN, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_DK_V2 (masaüstü)")
