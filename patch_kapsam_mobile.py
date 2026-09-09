# -*- coding: utf-8 -*-
# KAPSAM_MOB_V1 (saha.js) — Kapsam & Beyaz Alan mobil sekmesi (rep-scoped).
#   rep: kendi kapsamı + kendi beyaz alanı; ✔️Gittim / 📅Planla / 🔇Sustur.
#   yönetici: 📌İlet / 🔇Sustur. Aynı /api/saha/rapor/kapsam + /musteri-aksiyon.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_MOB_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) _rNEW += kapsam (yönetici varsayılan görür; rep yalnız yetkiliyse)
o1 = 'const _rNEW = ["ciro", "risk", "rotam"], _rHasNew = _rd.some(d => _rNEW.includes(d));'
n1 = 'const _rNEW = ["ciro", "risk", "rotam", "kapsam"], _rHasNew = _rd.some(d => _rNEW.includes(d));  /* KAPSAM_MOB_V1 */'
assert s.count(o1) == 1, "_rNEW anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) rpTabs += kapsam
o2 = '    ["rotam",       "🌅 Rotam"],  /* SABAH_ROTAM_V1 */'
n2 = '    ["rotam",       "🌅 Rotam"],  /* SABAH_ROTAM_V1 */\n    ["kapsam",      "📍 Kapsam"],  /* KAPSAM_MOB_V1 */'
assert s.count(o2) == 1, "rpTabs anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) switch dispatch
o3 = '      case "rotam":       rpRotam();       break;'
n3 = '      case "rotam":       rpRotam();       break;\n      case "kapsam":      rpKapsam();      break;  /* KAPSAM_MOB_V1 */'
assert s.count(o3) == 1, "switch anchor=%d" % s.count(o3)
s = s.replace(o3, n3, 1)

# 4) rpKapsam fonksiyonu — rpRisk'ten önce
FN = r'''  async function rpKapsam() {  /* KAPSAM_MOB_V1 */
    const el = icerik(); if (!el) return;
    el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    let d; try { d = await api(`/api/saha/rapor/kapsam?gun=90${tipQS()}`); } catch (e) { const b = icerik(); if (b) b.innerHTML = hata(e); return; }
    const box = icerik(); if (!box) return;
    const yon = d.rol === "yonetici", o = d.ozet || {};
    const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
    const sonTxt = (g) => g == null ? `<span class="kp-c hic">hiç</span>` : g > 45 ? `<span class="kp-c eski">${g}g</span>` : `${g}g`;
    const segEt = (t) => t === "TICARI" ? "Ticari" : t === "TUKETICI" ? "Tüketici" : "";
    const R = 36, CIRC = 2 * Math.PI * R, off = CIRC * (1 - (o.kapsam || 0) / 100);
    const CSS = `<style>
      .kp{--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mavi:#0284c7;--mor:#6d5ae0;--mor-z:#f0edfd;color-scheme:light;padding:10px 12px 90px;color:var(--tx-0)}
      .kp *{box-sizing:border-box}
      .kp-intro{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:13px 15px;margin-bottom:12px}
      .kp-intro h3{margin:0 0 6px;font-size:13.5px;font-weight:800}.kp-intro p{margin:0;font-size:12px;line-height:1.55;color:var(--tx-1)}
      .kp-hero{display:flex;align-items:center;gap:16px;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:15px;padding:15px;margin-bottom:10px}
      .kp-ring{position:relative;width:88px;height:88px;flex-shrink:0}.kp-ring svg{transform:rotate(-90deg)}.kp-ring .c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}.kp-ring .c b{font-size:22px;font-weight:800}.kp-ring .c small{font-size:8px;color:var(--tx-2);text-transform:uppercase;letter-spacing:.08em}
      .kp-hv{flex:1;min-width:0}.kp-hv .g{font-size:21px;font-weight:800;color:var(--sari);font-variant-numeric:tabular-nums;line-height:1}.kp-hv .l{font-size:11.5px;color:var(--tx-1);margin-top:4px}.kp-hv .s{font-size:10.5px;color:var(--tx-2);margin-top:6px}
      .kp-sec{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.05em;margin:16px 2px 8px}
      .kp-row{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:11px 13px;margin-bottom:8px}
      .kp-top{display:flex;align-items:baseline;gap:10px}.kp-firm{flex:1;min-width:0;font-size:13.5px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.kp-amt{font-size:15px;font-weight:800;color:var(--sari);font-variant-numeric:tabular-nums;white-space:nowrap}
      .kp-meta{font-size:11px;color:var(--tx-2);margin-top:5px}.kp-c{font-weight:700}.kp-c.hic{color:var(--kirmizi)}.kp-c.eski{color:var(--sari)}
      .kp-acts{display:flex;gap:6px;margin-top:10px}
      .kp-act{flex:1;text-align:center;font-size:12px;font-weight:700;padding:9px 6px;border-radius:9px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-family:inherit;cursor:pointer}
      .kp-act.pri{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}.kp-act.ok{background:var(--yesil-z);color:var(--yesil);border-color:rgba(16,107,74,.25)}.kp-act.dis{flex:0 0 46px;background:var(--kirmizi-z);color:var(--kirmizi);border-color:rgba(196,61,40,.2)}.kp-act.esles{background:var(--mor-z);color:var(--mor);border-color:rgba(109,90,224,.25)}
      .kp-reason{margin-top:9px;padding:11px;background:var(--zemin-2);border:1px dashed var(--cizgi);border-radius:10px}.kp-reason .q{font-size:11.5px;font-weight:700;color:var(--tx-1);margin-bottom:8px}
      .kp-opts{display:flex;gap:5px;flex-wrap:wrap}.kp-ropt{font-size:11.5px;font-weight:700;padding:6px 11px;border-radius:99px;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);cursor:pointer}.kp-ropt.sel{background:var(--kirmizi);color:#fff;border-color:var(--kirmizi)}
      .kp-in{margin-top:9px;width:100%;font-size:16px;padding:9px 11px;border:1px solid var(--cizgi);border-radius:8px}
      .kp-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:12.5px}
      .kp-how{border:1px solid var(--cizgi);border-radius:12px;background:var(--zemin-1);margin-top:14px;overflow:hidden}.kp-how>summary{cursor:pointer;list-style:none;padding:12px 14px;font-size:12.5px;font-weight:800;display:flex;gap:8px;align-items:center}.kp-how>summary::-webkit-details-marker{display:none}.kp-how>summary:after{content:'▾';margin-left:auto;color:var(--tx-2)}.kp-how[open]>summary:after{content:'▴'}.kp-howb{padding:2px 14px 14px;font-size:12px;color:var(--tx-1);line-height:1.55}.kp-howb p{margin:0 0 8px}.kp-howb b{color:var(--tx-0)}
    </style>`;
    const beyaz = d.beyaz || [], esiz = d.eslesmemis || [];
    const acts = (x) => yon
      ? `<button class="kp-act pri" data-aks="ILET" data-mid="${esc(x.id)}">📌 İlet</button><button class="kp-act dis" data-aks="SUSTUR" data-mid="${esc(x.id)}">🔇</button>`
      : `<button class="kp-act ok" data-aks="GITTIM" data-mid="${esc(x.id)}">✔️ Gittim</button><button class="kp-act pri" data-aks="PLANLA" data-mid="${esc(x.id)}">📅 Planla</button><button class="kp-act dis" data-aks="SUSTUR" data-mid="${esc(x.id)}">🔇</button>`;
    const card = (x) => `<div class="kp-row" data-row="${esc(x.id)}"><div class="kp-top"><div class="kp-firm">${esc(x.firma)}</div><div class="kp-amt">${x.ciro > 0 ? kisa(x.ciro) : "—"}</div></div><div class="kp-meta">${esc(x.il || "—")}${x.tip ? " · " + segEt(x.tip) : ""} · son ${sonTxt(x.gun)}${yon && x.rep ? " · " + esc(x.rep) : ""}</div><div class="kp-acts">${acts(x)}</div></div>`;
    const esizCard = (x) => `<div class="kp-row" data-row="${esc(x.id)}"><div class="kp-top"><div class="kp-firm">${esc(x.firma)}</div></div><div class="kp-meta">${esc(x.il || "—")} · son ${sonTxt(x.gun)}${yon && x.rep ? " · " + esc(x.rep) : ""}</div><div class="kp-acts">${yon ? "" : `<button class="kp-act ok" data-aks="GITTIM" data-mid="${esc(x.id)}">✔️ Gittim</button>`}<button class="kp-act dis" data-aks="SUSTUR" data-mid="${esc(x.id)}">🔇</button></div></div>`;

    box.innerHTML = CSS + `<div class="kp">
      <div class="kp-intro"><h3>📍 Kapsam & Beyaz Alan</h3><p>${yon ? "Ekibin nereye dokunduğu ve <b>dokunulmayan değerli müşteriler</b>." : "<b>Senin</b> kitabının ne kadarını tarıyorsun ve hangi <b>değerli müşterin karanlıkta</b>. Gittiysen ✔️ de, listeden düşer."}</p></div>
      <div class="kp-hero">
        <div class="kp-ring"><svg width="88" height="88" viewBox="0 0 88 88"><circle cx="44" cy="44" r="${R}" fill="none" stroke="var(--zemin-2)" stroke-width="8"/><circle cx="44" cy="44" r="${R}" fill="none" stroke="var(--yesil)" stroke-width="8" stroke-linecap="round" stroke-dasharray="${CIRC.toFixed(1)}" stroke-dashoffset="${off.toFixed(1)}"/></svg><div class="c"><b>${o.kapsam || 0}%</b><small>Kapsam</small></div></div>
        <div class="kp-hv"><div class="g">${kisa(o.beyaz_ciro || 0)}</div><div class="l">karanlıktaki ciro · ${o.beyaz_sayi || 0} müşteri</div><div class="s">${o.ulasilan || 0}/${o.portfoy || 0} müşteriye ulaşıldı · son 90 gün</div></div>
      </div>
      <div class="kp-sec">💰 Dokunulmayan değerli müşteriler</div>
      ${beyaz.length ? beyaz.map(card).join("") : `<div class="kp-empty">🎉 Beyaz alan yok — hepsine dokunmuşsun.</div>`}
      ${esiz.length ? `<div class="kp-sec">⚠️ Eşleşmemiş — kör nokta (${o.eslesmemis_sayi || 0})</div>${esiz.slice(0, 30).map(esizCard).join("")}` : ""}
      <details class="kp-how"><summary>🔍 Nasıl hesaplanıyor?</summary><div class="kp-howb"><p><b>Kapsam</b> = son 90 günde uygulamada kayıtlı ziyaretin olan farklı müşteri ÷ portföy.</p><p><b>Karanlıktaki ciro</b> = son 12 ay cirosu olan ama 90 gündür ziyaret edilmeyen müşteriler.</p><p><b>✔️ Gittim</b> ziyareti geri-yazar; <b>📅 Planla</b> Sabah Rotam'a düşürür; <b>🔇 Sustur</b> gerekçesiyle listeden çıkarır (yönetici görür). Her aksiyon loglanır.</p></div></details>
    </div>`;

    const post = async (mid, tur, extra) => { try { await api(`/api/saha/musteri-aksiyon`, { method: "POST", body: JSON.stringify({ musteri_id: mid, tur, ...(extra || {}) }) }); rpKapsam(); } catch (e) { alert("Olmadı: " + (e.message || e)); } };
    box.querySelectorAll("[data-aks]").forEach(b => b.addEventListener("click", () => {
      const mid = b.dataset.mid, tur = b.dataset.aks, row = b.closest(".kp-row"); if (!row) return;
      if (tur !== "SUSTUR") { post(mid, tur); return; }
      box.querySelectorAll(".kp-reason").forEach(p => p.remove());
      const div = document.createElement("div"); div.className = "kp-reason";
      div.innerHTML = `<div class="q">🔇 Neden susturuluyor? — listeden düşer${yon ? ", loglanır" : ", yönetici görür"}</div><div class="kp-opts">${[["KAPANDI", "Kapandı"], ["RAKIP", "Rakip"], ["SEZON", "Sezon dışı"], ["PAS", "Pas"], ["YANLIS", "Yanlış kayıt"], ["DIGER", "Diğer…"]].map(([v, l]) => `<span class="kp-ropt" data-g="${v}">${l}</span>`).join("")}</div><input class="kp-in" placeholder="Diğer / ek açıklama (opsiyonel)"><div style="display:flex;gap:6px;margin-top:9px"><button class="kp-act dis" style="flex:1" data-ok="1">🔇 Sustur</button><button class="kp-act" style="flex:1" data-cancel="1">Vazgeç</button></div>`;
      row.appendChild(div);
      let g = null; div.querySelectorAll(".kp-ropt").forEach(r => r.addEventListener("click", () => { div.querySelectorAll(".kp-ropt").forEach(x => x.classList.remove("sel")); r.classList.add("sel"); g = r.dataset.g; }));
      div.querySelector("[data-cancel]").addEventListener("click", () => div.remove());
      div.querySelector("[data-ok]").addEventListener("click", () => { const txt = div.querySelector(".kp-in").value.trim(); if (!g && !txt) { alert("Gerekçe seç ya da yaz."); return; } post(mid, "SUSTUR", { gerekce: g || "DIGER", gerekce_metin: txt || null }); });
    }));
  }

'''
o4 = '  async function rpRisk() {  /* RISK_SAHA_V1 */'
assert s.count(o4) == 1, "rpRisk anchor=%d" % s.count(o4)
s = s.replace(o4, FN + o4, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_MOB_V1 (saha.js)")
