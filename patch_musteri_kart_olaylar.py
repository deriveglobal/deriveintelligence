# -*- coding: utf-8 -*-
# MUSTERI_KART_OLAYLAR_V1 (mobil saha.js · musteriDetayModal)
#   Kartın üstüne istihbarat başlığı (özet + EKG) + açık takip + inline Not/Takip formu;
#   "Ziyaret Geçmişi" → "🕐 Hareketler" (union /olaylar, tip-filtreli, katlanır).
#   Sıcak DS palet, scoped .mk* (yeni <style>, saha DS_TEMA deseni). Mevcut bölümler/işlev korunur.
#   Veri: GET /api/saha/musteriler/:id/olaylar · POST .../not. Yeni buton: 📝 Not/Takip.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "MUSTERI_KART_OLAYLAR_V1" in s:
    print("[skip] zaten yamalı"); sys.exit(0)

# ── A) h3'ten sonra: scoped CSS + istihbarat/takip/notform placeholder ──
aA = '    <h3>${esc(m.firma)}</h3>'
assert s.count(aA) == 1, "h3 anchor=%d" % s.count(aA)
CSS_HDR = r'''    <h3>${esc(m.firma)}</h3>
    <style> /* MUSTERI_KART_OLAYLAR_V1 */
      #saha-modal .mk{--z0:#FBFBFA;--z1:#FFF;--z2:#F4F4F2;--cz:rgba(0,0,0,.09);--czg:rgba(0,0,0,.16);--t0:#16161A;--t1:#5F5F66;--t2:#85858C;--t3:#A8A8AE;--kr:#C43D28;--krz:#FDF0ED;--sr:#8A5D06;--srz:#FEF6E7;--ys:#106B4A;--ysz:#EAF7F1;--mv:#2a78d6;--mvz:#EAF2FC;color-scheme:light}
      .mk-intel{background:linear-gradient(180deg,#fff,var(--z0));border:1px solid var(--cz);border-radius:14px;padding:13px;margin:2px 0 11px}
      .mk-sh{font-size:10px;font-weight:800;letter-spacing:.07em;text-transform:uppercase;color:var(--t2);margin-bottom:6px}
      .mk-st{font-size:13px;line-height:1.5;color:var(--t1)}.mk-st b{color:var(--t0)}
      .mk-ekg{margin-top:11px}.mk-ekl{display:flex;justify-content:space-between;font-size:9px;color:var(--t3);margin-bottom:4px;font-weight:600}
      .mk-lane{position:relative;height:52px;border-radius:8px;border:1px solid var(--cz);overflow:hidden;background:var(--ysz)}
      .mk-bar{position:absolute;bottom:8px;width:7px;border-radius:2px 2px 0 0;background:linear-gradient(180deg,#3a9b74,var(--ys))}
      .mk-dot{position:absolute;width:4px;height:4px;border-radius:50%;background:var(--mv);bottom:3px;transform:translateX(-50%)}
      .mk-mk{position:absolute;top:3px;transform:translateX(-50%);font-size:10px}
      .mk-sb{position:absolute;left:0;right:0;bottom:0;height:3px}
      .mk-lg{display:flex;gap:9px;font-size:9px;color:var(--t2);margin-top:6px;flex-wrap:wrap}.mk-lg span{display:inline-flex;gap:3px;align-items:center}.mk-d{width:6px;height:6px;border-radius:50%;display:inline-block}
      .mk-pill{font-size:10px;font-weight:700;padding:2px 8px;border-radius:999px}.mk-pill.ak{background:var(--ysz);color:var(--ys)}.mk-pill.so{background:var(--srz);color:var(--sr)}.mk-pill.pa{background:var(--krz);color:var(--kr)}
      .mk-takip{display:flex;gap:8px;align-items:flex-start;background:var(--srz);border:1px solid rgba(138,93,6,.25);border-radius:12px;padding:9px 11px;margin:0 0 11px;font-size:11.5px;line-height:1.4;color:#6b4a06}.mk-takip b{color:#4a3304}.mk-takip .x{margin-left:auto;font-weight:700;color:var(--sr);cursor:pointer;white-space:nowrap}
      .mk-hh{display:flex;align-items:center;justify-content:space-between;cursor:pointer;margin:16px 0 0}
      .mk-htt{font-size:11px;color:var(--t2);text-transform:uppercase;letter-spacing:.08em;font-weight:800}
      .mk-hbody{margin-top:9px}.mk-hbody.kapali{display:none}
      .mk-chips{display:flex;gap:6px;flex-wrap:wrap;margin-bottom:8px}.mk-chip{background:var(--z1);border:1px solid var(--cz);border-radius:9px;padding:4px 9px;font-size:11px;color:var(--t1);font-weight:700;cursor:pointer}.mk-chip.on{background:var(--mvz);border-color:#bcd6f5;color:var(--mv)}
      .mk-ev{display:flex;gap:9px;padding:7px 1px;border-bottom:1px solid var(--cz)}.mk-ic{flex:0 0 auto;font-size:13px;width:18px;text-align:center}
      .mk-c{flex:1;min-width:0}.mk-m{font-size:12px;color:var(--t0);line-height:1.35}.mk-m b{font-weight:700}.mk-s{font-size:10px;color:var(--t2);margin-top:1px}
      .mk-r{flex:0 0 auto;font-size:10px;color:var(--t3);white-space:nowrap}.mk-empty{font-size:12px;color:var(--t2);padding:10px 0}
      .mk-nf{background:var(--z0);border:1px solid var(--cz);border-radius:12px;padding:12px;margin:0 0 11px}
      .mk-nf textarea{width:100%;box-sizing:border-box;border:1px solid var(--czg);border-radius:9px;padding:9px;font-size:15px;background:#fff;color:var(--t0);min-height:60px}
      .mk-neden{display:flex;gap:6px;flex-wrap:wrap;margin:8px 0}.mk-nd{background:#fff;border:1px solid var(--cz);border-radius:999px;padding:4px 11px;font-size:11.5px;color:var(--t1);cursor:pointer}.mk-nd.on{background:var(--t0);color:#fff;border-color:var(--t0)}
      .mk-nf-row{display:flex;gap:8px;align-items:center;margin-top:8px;flex-wrap:wrap}.mk-nf-row label{font-size:11px;color:var(--t2)}.mk-nf-row input[type=date]{border:1px solid var(--czg);border-radius:8px;padding:6px 8px;font-size:13px;background:#fff}
      .mk-nf-btn{display:flex;gap:8px;justify-content:flex-end;margin-top:10px}
    </style>
    <div class="mk">
      <div id="mk-intel" class="mk-intel" style="display:none"></div>
      <div id="mk-takip-w"></div>
      <div id="mk-notform"></div>
    </div>'''
s = s.replace(aA, CSS_HDR, 1)

# ── B) Ziyaret Geçmişi → Hareketler placeholder ──
aB = '    <h4 class="bolum-baslik">Ziyaret Geçmişi</h4>\n    <div id="mus-gecmis" class="mini-durum">Yükleniyor…</div>'
assert s.count(aB) == 1, "ziyaret gecmisi anchor=%d" % s.count(aB)
s = s.replace(aB, '    <div class="mk"><div id="mk-hareketler" class="mini-durum">Yükleniyor…</div></div>  <!-- MUSTERI_KART_OLAYLAR_V1 -->', 1)

# ── C) Not/Takip butonu (Planla'dan önce) ──
aC = '      <button class="btn cizgili" id="md-planla">🗓️ Planla</button>'
assert s.count(aC) == 1, "planla btn anchor=%d" % s.count(aC)
s = s.replace(aC, '      <button class="btn cizgili" id="md-not" style="border-color:#106B4A;color:#106B4A">📝 Not/Takip</button>\n' + aC, 1)

# ── D) lokYukle'den önce: /olaylar loader + Not formu ──
aD = '  const lokYukle = async () => {'
assert s.count(aD) == 1, "lokYukle anchor=%d" % s.count(aD)
LOADER = r'''  // ── MUSTERI_KART_OLAYLAR_V1 — istihbarat başlığı + Hareketler + Not/Takip ──
  const _mkTL = (n) => { n = Math.round(Number(n) || 0); const a = Math.abs(n); if (a >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (a >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + n; };
  const _mkGun = (ts) => { if (!ts) return ""; const d = new Date(ts); if (isNaN(d)) return ""; const g = Math.floor((Date.now() - d.getTime()) / 86400000); if (g <= 0) return "bugün"; if (g < 30) return g + "g"; if (g < 365) return Math.round(g / 30) + "ay"; return Math.round(g / 365) + "y"; };
  const _mkIK = { ziyaret: "🚗", alim: "💰", not: "📝", takip: "📌", rakip: "🏷️", firsat: "✨", risk: "⚠️", teklif: "📄", teklif_talep: "📩", aksiyon: "⚙️" };
  function _mkEkg(d) {
    const now = new Date(); const nym = now.getFullYear() * 12 + now.getMonth();
    const slot = (ts) => { const x = new Date(ts); if (isNaN(x)) return null; const i = 11 - (nym - (x.getFullYear() * 12 + x.getMonth())); return (i >= 0 && i <= 11) ? i : null; };
    const aylar = (d.ekg && d.ekg.aylar) || []; const mx = Math.max(1, ...aylar.map(a => Number(a.ciro) || 0));
    let bars = ""; aylar.forEach(a => { const i = slot(a.ay + "-15"); if (i == null) return; const h = Math.max(5, Math.round((Number(a.ciro) || 0) / mx * 40)); bars += `<div class="mk-bar" style="left:${3 + i * 8}%;height:${h}px"></div>`; });
    let dots = ""; ((d.ekg && d.ekg.ziyaret) || []).forEach(z => { const i = slot(z); if (i != null) dots += `<div class="mk-dot" style="left:${6.5 + i * 8}%"></div>`; });
    let mks = ""; ((d.ekg && d.ekg.isaret) || []).forEach(x => { const i = slot(x.ts); if (i != null) mks += `<div class="mk-mk" style="left:${6.5 + i * 8}%">${x.tip === "rakip" ? "🏷️" : "📝"}</div>`; });
    const dur = d.musteri.durum; const rec = Number(d.musteri.recency_ay) || 0;
    let sb;
    if (dur === "aktif" || !dur) sb = "background:var(--ys)";
    else { const split = Math.max(0, Math.min(100, 100 - Math.min(rec, 12) / 12 * 100)); sb = `background:linear-gradient(90deg,var(--ys) 0 ${split}%,var(--sr) ${split}% 100%)`; }
    const lg = dur === "soguyor" ? '<span><span class="mk-d" style="background:var(--sr)"></span>soğuma</span>' : dur === "pasif" ? '<span><span class="mk-d" style="background:var(--kr)"></span>pasif</span>' : '<span><span class="mk-d" style="background:var(--ys)"></span>aktif</span>';
    return `<div class="mk-ekg"><div class="mk-ekl"><span>12 ay önce</span><span>bugün</span></div>
      <div class="mk-lane">${bars}${dots}${mks}<div class="mk-sb" style="${sb}"></div></div>
      <div class="mk-lg"><span><span class="mk-d" style="background:var(--ys)"></span>alım</span><span><span class="mk-d" style="background:var(--mv)"></span>ziyaret</span><span>📝 not</span>${lg}</div></div>`;
  }
  async function _mkYukle() {
    let d; try { d = await api(`/api/saha/musteriler/${m.id}/olaylar`); } catch (e) { const h = document.getElementById("mk-hareketler"); if (h) { h.classList.remove("mini-durum"); h.textContent = "Hareketler yüklenemedi."; } return; }
    // istihbarat başlığı
    const intel = document.getElementById("mk-intel");
    if (intel && d.ozet) { intel.style.display = "block"; intel.innerHTML = `<div class="mk-sh">🩺 bu müşteriyle ne oluyor?</div><div class="mk-st">${esc(d.ozet)}</div>` + _mkEkg(d); }
    // açık takip
    const tw = document.getElementById("mk-takip-w");
    if (tw && d.takip && d.takip.length) { const t = d.takip[0]; tw.innerHTML = `<div class="mk-takip"><span>🔔</span><div><b>${d.takip.length} açık takip</b> · ${esc(String(t.ozet || "").slice(0, 120))}${t.kim ? " · " + esc(t.kim) : ""}</div></div>`; }
    // hareketler
    const hare = document.getElementById("mk-hareketler"); if (!hare) return;
    hare.classList.remove("mini-durum");
    const say = d.sayac || {};
    const chips = [["", "tümü", say.toplam], ["ziyaret", "🚗 ziyaret", say.ziyaret], ["alim", "💰 alım", say.alim], ["not", "📝 not", say.not], ["teklif", "📄 teklif", say.teklif]].filter(c => c[0] === "" || (c[2] || 0) > 0);
    let filt = "", acik = false;
    const eslesir = (o) => !filt || (filt === "not" ? ["not", "takip", "rakip", "firsat", "risk", "teklif_talep"].includes(o.tip) : o.tip === filt);
    const draw = () => {
      const list = (d.olaylar || []).filter(eslesir).slice(0, 40);
      hare.innerHTML = `<div class="mk-hh" id="mk-htog"><span class="mk-htt">🕐 Hareketler${say.toplam ? " · " + say.toplam : ""}</span><span id="mk-hcar">${acik ? "▴" : "▾"}</span></div>
        <div class="mk-hbody${acik ? "" : " kapali"}">
          <div class="mk-chips">${chips.map(c => `<span class="mk-chip${filt === c[0] ? " on" : ""}" data-f="${c[0]}">${c[1]}${c[0] && c[2] ? " " + c[2] : ""}</span>`).join("")}</div>
          ${list.map(o => `<div class="mk-ev"><div class="mk-ic">${_mkIK[o.tip] || "•"}</div><div class="mk-c"><div class="mk-m">${esc(String(o.baslik || ""))}</div>${(o.alt || o.kim) ? `<div class="mk-s">${[o.alt, o.kim].filter(Boolean).map(x => esc(String(x))).join(" · ")}</div>` : ""}</div><div class="mk-r">${_mkGun(o.ts)}</div></div>`).join("") || `<div class="mk-empty">Kayıt yok.</div>`}
        </div>`;
      document.getElementById("mk-htog")?.addEventListener("click", () => { acik = !acik; draw(); });
      hare.querySelectorAll(".mk-chip").forEach(c => c.addEventListener("click", (e) => { e.stopPropagation(); filt = c.dataset.f; acik = true; draw(); }));
    };
    draw();
  }
  _mkYukle();
  // Not / Takip inline formu
  document.getElementById("md-not")?.addEventListener("click", () => {
    const w = document.getElementById("mk-notform"); if (!w) return;
    if (w.innerHTML) { w.innerHTML = ""; return; }
    const NED = [["rakip", "Rakip fiyatı"], ["fiyat", "Fiyat"], ["stok", "Stok"], ["tahsilat", "Tahsilat"], ["iliski", "İlişki"], ["mevsim", "Mevsim"]];
    w.innerHTML = `<div class="mk-nf">
      <textarea id="mk-nt" placeholder="Not: müşteriyle ne konuşuldu, neden yavaşlıyor, plan…"></textarea>
      <div class="mk-neden">${NED.map(n => `<span class="mk-nd" data-n="${n[0]}">${n[1]}</span>`).join("")}</div>
      <div class="mk-nf-row"><label><input type="checkbox" id="mk-tk"> Takip: tekrar bak</label><input type="date" id="mk-tkd" style="display:none"></div>
      <div class="mk-nf-btn"><button class="btn kucuk gri" id="mk-niptal">Vazgeç</button><button class="btn kucuk" id="mk-nkaydet" style="background:#106B4A;color:#fff">Kaydet</button></div>
    </div>`;
    let neden = "";
    w.querySelectorAll(".mk-nd").forEach(b => b.addEventListener("click", () => { neden = (neden === b.dataset.n) ? "" : b.dataset.n; w.querySelectorAll(".mk-nd").forEach(x => x.classList.toggle("on", x.dataset.n === neden)); }));
    document.getElementById("mk-tk")?.addEventListener("change", (e) => { const dd = document.getElementById("mk-tkd"); if (dd) dd.style.display = e.target.checked ? "inline-block" : "none"; });
    document.getElementById("mk-niptal")?.addEventListener("click", () => { w.innerHTML = ""; });
    document.getElementById("mk-nkaydet")?.addEventListener("click", async () => {
      const metin = (document.getElementById("mk-nt")?.value || "").trim(); if (!metin) { uyari("Not metni girin."); return; }
      const tk = document.getElementById("mk-tk")?.checked; const tkd = (document.getElementById("mk-tkd")?.value || "");
      const btn = document.getElementById("mk-nkaydet"); if (btn) { btn.disabled = true; btn.textContent = "…"; }
      try {
        await api(`/api/saha/musteriler/${m.id}/not`, { method: "POST", body: JSON.stringify({ metin, neden: neden || null, takip_tarihi: (tk && tkd) ? tkd : null }) });
        uyari("✓ Not kaydedildi.", true); w.innerHTML = ""; _mkYukle();
      } catch (e) { uyari(e.message); if (btn) { btn.disabled = false; btn.textContent = "Kaydet"; } }
    });
  });
  const lokYukle = async () => {'''
s = s.replace(aD, LOADER, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MUSTERI_KART_OLAYLAR_V1 (mobil kart) — istihbarat + Hareketler + Not/Takip")
