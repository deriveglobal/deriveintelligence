# -*- coding: utf-8 -*-
# SABAH_ROTAM_V1 (mobil) — Rapor'a "🌅 Rotam" sekmesi (rep kişisel rota, dar ekran).
#   Başlangıç öner-onayla / check-in (geolocation); sözler(bugün PLANLANDI) + AI öneri (skor); haversine + güne sığdır;
#   konum-pin uyarısı; gerçek butonlar (kart/ara/yol). Yönetici → masaüstü ekip panosuna yönlendirme.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_V1" in s and "async function rpRotam" in s:
    print("[skip] zaten yamali"); sys.exit(0)

t_old = '    ["risk",        "🚨 Risk"],  /* RISK_SAHA_V1 */'
t_new = t_old + '\n    ["rotam",       "🌅 Rotam"],  /* SABAH_ROTAM_V1 */'
assert s.count(t_old) == 1, "tab anchor=%d" % s.count(t_old)
s = s.replace(t_old, t_new, 1)

d_old = '      case "risk":        rpRisk();        break;'
d_new = d_old + '\n      case "rotam":       rpRotam();       break;'
assert s.count(d_old) == 1, "dispatch anchor=%d" % s.count(d_old)
s = s.replace(d_old, d_new, 1)

anchor = "  async function rpCiro() {"
RP = r'''  async function rpRotam() {  /* SABAH_ROTAM_V1 */
    const el = icerik(); if (!el) return; el.innerHTML = `<div class="saha-load">Yükleniyor…</div>`;
    let d;
    try { d = await api(`/api/saha/rapor/sabah-rotam`); } catch (e) { const b = icerik(); if (b) b.innerHTML = hata(e); return; }
    const box = icerik(); if (!box) return;
    const kisa = (n) => { n = Number(n) || 0; if (n >= 1e6) return "₺" + (Math.round(n / 1e5) / 10) + "M"; if (n >= 1e3) return "₺" + Math.round(n / 1e3) + "K"; return "₺" + Math.round(n); };
    const hhmm = (m) => String(Math.floor(m / 60)).padStart(2, "0") + ":" + String(Math.round(m % 60)).padStart(2, "0");
    const hav = (a, b) => { if (!a || !b || a.lat == null || b.lat == null) return null; const R = 6371, dLat = (b.lat - a.lat) * Math.PI / 180, dLng = (b.lng - a.lng) * Math.PI / 180, la1 = a.lat * Math.PI / 180, la2 = b.lat * Math.PI / 180; const h = Math.sin(dLat / 2) ** 2 + Math.cos(la1) * Math.cos(la2) * Math.sin(dLng / 2) ** 2; return 2 * R * Math.asin(Math.sqrt(h)); };
    const CSS = `<style>
      .rt{--zemin-0:#FBFBFA;--zemin-1:#FFFFFF;--zemin-2:#F4F4F2;--cizgi:rgba(0,0,0,.09);--tx-0:#16161A;--tx-1:#5F5F66;--tx-2:#85858C;--tx-3:#A8A8AE;--kirmizi:#C43D28;--kirmizi-z:#FDF0ED;--sari:#8A5D06;--sari-z:#FEF6E7;--yesil:#106B4A;--yesil-z:#EAF7F1;--mor:#6d5ae0;--mor-z:#f0edfd;--mavi:#0284c7;--mavi-z:#EEF3FE;color-scheme:light;padding:10px 12px 90px;color:var(--tx-0)}
      .rt *{box-sizing:border-box}
      .rt-hd{display:flex;align-items:center;justify-content:space-between;gap:10px;margin:2px 2px 4px}.rt-hd .t{font-size:19px;font-weight:800;letter-spacing:-.02em}
      .rt-live{display:flex;align-items:center;gap:6px;font-size:11px;font-weight:700;color:var(--yesil)}.rt-live .dot{width:8px;height:8px;border-radius:50%;background:var(--yesil);animation:rtpm 1.8s infinite}
      @keyframes rtpm{0%{box-shadow:0 0 0 0 rgba(16,107,74,.45)}70%{box-shadow:0 0 0 7px rgba(16,107,74,0)}100%{box-shadow:0 0 0 0 rgba(16,107,74,0)}}
      .rt-sub{font-size:12px;color:var(--tx-2);font-weight:600;margin:0 2px 12px}
      .rt-ai{background:linear-gradient(135deg,#eef3fe,#fff);border:1px solid rgba(37,99,235,.2);border-radius:14px;padding:12px 14px;margin-bottom:12px;display:flex;gap:10px;align-items:flex-start}.rt-ai .ico{font-size:17px}.rt-ai .tx{font-size:12.5px;line-height:1.5}.rt-ai .tx b{font-weight:800}
      .rt-setp{background:linear-gradient(135deg,#f0edfd,#fff);border:1px solid rgba(109,90,224,.28);border-radius:14px;padding:14px;margin-bottom:12px}
      .rt-setp .t{font-size:13.5px;font-weight:800;color:var(--mor)}.rt-setp .p{font-size:12px;color:var(--tx-1);line-height:1.5;margin:6px 0 0}
      .rt-setp .sug{font-size:12px;font-weight:700;background:var(--zemin-1);border:1px solid rgba(109,90,224,.22);border-radius:10px;padding:9px 11px;margin-top:10px}
      .rt-setp .btns{display:flex;gap:8px;margin-top:10px;flex-wrap:wrap}.rt-setp .btn{flex:1;min-width:130px;text-align:center;font-size:12.5px;font-weight:700;padding:10px;border-radius:10px;cursor:pointer;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1)}.rt-setp .btn.pri{background:var(--mor);color:#fff;border-color:var(--mor)}
      .rt-cap{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:12px 14px;margin-bottom:12px}.rt-cap .row{display:flex;justify-content:space-between;align-items:baseline;font-size:12px}.rt-cap .row .l{color:var(--tx-1);font-weight:600}.rt-cap .row .r{font-weight:800;font-variant-numeric:tabular-nums}
      .rt-cap .bar{height:9px;border-radius:999px;background:var(--zemin-2);overflow:hidden;margin:9px 0 6px;display:flex}.rt-cap .s1{background:linear-gradient(90deg,#6d5ae0,#8b7bec)}.rt-cap .s2{background:linear-gradient(90deg,#2563eb,#3b82f6)}.rt-cap .s3{background:repeating-linear-gradient(45deg,#e4e4e2,#e4e4e2 5px,#efefee 5px,#efefee 10px)}
      .rt-cap .lgn{display:flex;gap:12px;font-size:10px;color:var(--tx-2);font-weight:600}.rt-cap .lgn i{display:inline-block;width:8px;height:8px;border-radius:2px;margin-right:4px;vertical-align:middle}
      .rt-start{display:flex;align-items:center;gap:10px;background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:10px 13px;margin-bottom:12px;flex-wrap:wrap}.rt-start .o{font-size:12px;font-weight:700;flex:1;min-width:130px}.rt-start .o span{color:var(--tx-2);font-weight:600}.rt-start .chg{font-size:11px;font-weight:700;color:var(--mavi);cursor:pointer}
      .rt-sech{font-size:11px;font-weight:800;color:var(--tx-1);text-transform:uppercase;letter-spacing:.05em;margin:18px 2px 8px;display:flex;align-items:center;gap:8px}.rt-sech .cnt{color:var(--tx-2)}
      .rt-route{display:flex;flex-direction:column;gap:9px}
      .rt-stop{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:12px 13px;position:relative;overflow:hidden}.rt-stop:before{content:"";position:absolute;left:0;top:0;bottom:0;width:4px}
      .rt-stop.commit:before{background:var(--mor)}.rt-stop.hot:before{background:var(--kirmizi)}.rt-stop.warm:before{background:var(--sari)}.rt-stop.ok:before{background:var(--yesil)}.rt-stop.over{opacity:.72}
      .rt-top{display:flex;align-items:center;gap:10px}
      .rt-rank{width:27px;height:27px;border-radius:50%;background:var(--tx-0);color:#fff;font-size:13px;font-weight:800;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-variant-numeric:tabular-nums}.rt-stop.commit .rt-rank{background:var(--mor)}.rt-stop.hot .rt-rank{background:var(--kirmizi)}
      .rt-firm{flex:1;min-width:0;font-size:14px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
      .rt-skor{text-align:right;flex-shrink:0}.rt-skor .n{font-size:18px;font-weight:800;font-variant-numeric:tabular-nums;line-height:1}.rt-stop.hot .rt-skor .n{color:var(--kirmizi)}.rt-stop.warm .rt-skor .n{color:var(--sari)}.rt-stop.ok .rt-skor .n{color:var(--yesil)}.rt-stop.commit .rt-skor .n{color:var(--mor)}.rt-skor .l{font-size:8.5px;color:var(--tx-2);font-weight:700;text-transform:uppercase;letter-spacing:.04em;margin-top:2px}
      .rt-loc{font-size:11px;color:var(--tx-2);margin-top:3px;display:flex;gap:7px;flex-wrap:wrap;align-items:center}.rt-loc .eta{color:var(--tx-0);font-weight:800;background:var(--zemin-2);padding:1px 6px;border-radius:999px}.rt-loc .dist{color:var(--tx-1);font-weight:700}
      .rt-nopin{color:var(--sari);font-weight:700;background:var(--sari-z);padding:1px 6px;border-radius:999px;font-size:10px}
      .rt-why{display:flex;gap:5px;flex-wrap:wrap;margin-top:10px}.rt-chip{font-size:10.5px;font-weight:700;padding:2px 8px;border-radius:999px;white-space:nowrap}.rt-chip.commit{color:var(--mor);background:var(--mor-z)}.rt-chip.r{color:var(--kirmizi);background:var(--kirmizi-z)}.rt-chip.c{color:var(--sari);background:var(--sari-z)}.rt-chip.v{color:var(--yesil);background:var(--yesil-z)}.rt-chip.o{color:var(--mavi);background:var(--mavi-z)}
      .rt-acts{display:flex;gap:6px;margin-top:11px}.rt-act{flex:1;text-align:center;border:1px solid var(--cizgi);background:var(--zemin-1);color:var(--tx-1);font-size:12px;font-weight:700;padding:9px 4px;border-radius:9px;cursor:pointer;text-decoration:none;display:inline-block}.rt-act.pri{background:var(--tx-0);color:#fff;border-color:var(--tx-0)}.rt-act.off{opacity:.4;pointer-events:none}
      .rt-over{font-size:12px;font-weight:800;color:var(--tx-2);margin:15px 2px 8px}
      .rt-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:12.5px}
      .rt-note{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:14px;padding:16px;text-align:center;color:var(--tx-1);font-size:13px;line-height:1.6}
      .rt-grid{display:grid;gap:8px;grid-template-columns:repeat(2,1fr);margin-top:10px}.rt-tile{background:var(--zemin-1);border:1px solid var(--cizgi);border-radius:12px;padding:11px 12px}.rt-tile .n{font-size:20px;font-weight:800;font-variant-numeric:tabular-nums}.rt-tile .l{font-size:10.5px;color:var(--tx-1);margin-top:5px;font-weight:500}
    </style>`;
    const bugunTarih = new Date().toLocaleDateString("tr-TR", { day: "numeric", month: "long", weekday: "long" });

    if (d.rol === "yonetici") {
      const T = d.toplam || {};
      box.innerHTML = CSS + `<div class="rt">
        <div class="rt-hd"><div class="t">🌅 Bugün Sahada</div><div class="rt-live"><span class="dot"></span>CANLI</div></div>
        <div class="rt-sub">${bugunTarih}</div>
        <div class="rt-grid">
          <div class="rt-tile"><div class="n">${T.plan || 0}</div><div class="l">Planlı durak (ekip)</div></div>
          <div class="rt-tile"><div class="n" style="color:var(--yesil)">${T.yapilan || 0}</div><div class="l">Bugün yapılan</div></div>
          <div class="rt-tile"><div class="n">${T.oneri || 0}</div><div class="l">Öncelikli öneri</div></div>
          <div class="rt-tile" style="border-color:rgba(196,61,40,.3)"><div class="n" style="color:var(--kirmizi)">${T.kritik || 0}</div><div class="l">Kritik · ${T.sahipsiz || 0} sahipsiz</div></div>
        </div>
        <div class="rt-note" style="margin-top:12px">Ekip dağılımı, öncelik uyumu ve sahipsiz kritik hesapların tam listesi <b>masaüstü Rapor › Rotam</b>'da.</div>
      </div>`;
      return;
    }

    const durak = d.duraklar || [];
    const commits = durak.filter(x => x.plan_bugun);
    const rest = durak.filter(x => !x.plan_bugun).sort((a, b) => (b.skor || 0) - (a.skor || 0));
    const tier = (s2) => s2 >= 65 ? "hot" : s2 >= 40 ? "warm" : "ok";
    const chips = (c) => { const o = [];
      if (c.plan_bugun) o.push(`<span class="rt-chip commit">📅 Bugün planlı</span>`);
      if (c.overdue > 0) o.push(`<span class="rt-chip r">🔴 ${kisa(c.overdue)} gecikmiş</span>`);
      if (c.gun === null) o.push(`<span class="rt-chip c">🥶 Hiç ziyaret</span>`); else if (c.gun > 30) o.push(`<span class="rt-chip c">🥶 ${c.gun} gün</span>`);
      if (c.ciro >= 30e6) o.push(`<span class="rt-chip v">💰 ${kisa(c.ciro)}/yıl</span>`);
      if (c.teklif > 0) o.push(`<span class="rt-chip o">📋 ${c.teklif} teklif</span>`);
      return o.join(""); };
    const acts = (c) => { const yol = (c.lat != null) ? `https://www.google.com/maps/dir/?api=1&destination=${c.lat},${c.lng}` : null;
      return `<div class="rt-acts"><button class="rt-act pri" data-kart="${esc(c.id)}">👤 Kart</button>${c.telefon ? `<a class="rt-act" href="tel:${esc(String(c.telefon).replace(/[^0-9+]/g, ""))}">📞 Ara</a>` : `<span class="rt-act off">📞 Ara</span>`}${yol ? `<a class="rt-act" href="${yol}" target="_blank" rel="noopener">🧭 Yol</a>` : `<span class="rt-act off">🧭 Yol</span>`}</div>`; };
    const bindKart = () => box.querySelectorAll("[data-kart]").forEach(b => b.addEventListener("click", async () => { const id = b.dataset.kart; let c = (S.musteriler || []).find(x => x.id === id); if (!c) { try { const res = await api(`/api/saha/musteriler/${id}`); c = res.musteri || res; } catch (e) {} } if (c) musteriDetayModal(c); }));

    if (!d.baslangic) {
      const ob = d.oneri_baslangic;
      const cards = [...commits, ...rest].map((c, i) => card(c, i + 1, c.plan_bugun ? "commit" : tier(c.skor), null));
      box.innerHTML = CSS + `<div class="rt">
        <div class="rt-hd"><div class="t">🌅 Sabah Rotam</div><div class="rt-live"><span class="dot"></span>CANLI</div></div>
        <div class="rt-sub">${bugunTarih} · ${durak.length} durak</div>
        <div class="rt-setp"><div class="t">🏁 Başlangıç noktanı belirle</div>
          <div class="p">Rotanı mesafeye göre sıralayıp güne kaç durak sığdığını hesaplayabilmem için nereden başladığını bilmem gerek.</div>
          ${ob ? `<div class="sug">📍 Öneri: son check-in konumun — burayı başlangıç yapayım mı?</div>` : `<div class="sug">📍 Şu an neredeysen oradan başla.</div>`}
          <div class="btns">${ob ? `<button class="btn pri" id="rt-kabul">✓ Evet, burayı kullan</button>` : ""}<button class="btn${ob ? "" : " pri"}" id="rt-checkin">📍 Buradan başla</button></div>
        </div>
        <div class="rt-sech">Bugünkü duraklar <span class="cnt">· öncelik</span></div>
        ${durak.length ? `<div class="rt-route">${cards.join("")}</div>` : `<div class="rt-empty">Portföyünde durak yok.</div>`}
      </div>`;
      const kaydet = async (lat, lng, ad, kaynak) => { try { await api(`/api/saha/rep-baslangic`, { method: "POST", body: JSON.stringify({ lat, lng, ad, kaynak }) }); rpRotam(); } catch (e) { alert("Kaydedilemedi: " + (e.message || e)); } };
      const kb = box.querySelector("#rt-kabul"); if (kb && ob) kb.addEventListener("click", () => kaydet(Number(ob.lat), Number(ob.lng), "Son check-in", "oneri_kabul"));
      const ci = box.querySelector("#rt-checkin"); if (ci) ci.addEventListener("click", () => { if (!navigator.geolocation) { alert("Konum desteklenmiyor"); return; } ci.textContent = "📍 Konum alınıyor…"; navigator.geolocation.getCurrentPosition(p => kaydet(p.coords.latitude, p.coords.longitude, "Check-in", "checkin"), err => { ci.textContent = "📍 Buradan başla"; alert("Konum alınamadı: " + err.message); }); });
      bindKart();
      return;
    }

    const bas = { lat: Number(d.baslangic.lat), lng: Number(d.baslangic.lng) };
    const WSTART = 9 * 60, WEND = 17 * 60, VISIT = 34, SPEED = 40;
    const legDk = (from, to) => { const km = hav(from, to); return km == null ? 30 : Math.max(6, Math.round(km / SPEED * 60)); };
    const ordered = [...commits, ...rest];
    let clk = WSTART, prev = bas, capIdx = ordered.length, yolTop = 0;
    const sched = ordered.map((c, i) => { const from = (c.lat != null ? { lat: c.lat, lng: c.lng } : null); const leg = legDk(prev, from); const arr = clk + leg, dep = arr + VISIT, fits = dep <= WEND; if (fits) { clk = dep; prev = from || prev; yolTop += leg; } else if (capIdx === ordered.length) capIdx = i; return { c, leg, arr, dep, fits }; });
    const bugun = sched.slice(0, capIdx), yarin = sched.slice(capIdx);
    const bitis = bugun.length ? bugun[bugun.length - 1].dep : WSTART;
    const gorTop = bugun.length * VISIT, span = WEND - WSTART;
    const pG = Math.round(gorTop / span * 100), pY = Math.round(yolTop / span * 100), pB = Math.max(0, 100 - pG - pY);
    const enUst = rest[0];
    box.innerHTML = CSS + `<div class="rt">
      <div class="rt-hd"><div class="t">🌅 Sabah Rotam</div><div class="rt-live"><span class="dot"></span>CANLI</div></div>
      <div class="rt-sub">${bugunTarih}</div>
      <div class="rt-ai"><div class="ico">✨</div><div class="tx"><b>Bugün ${commits.length ? commits.length + " planın var" : "planın yok"}.</b> ${enUst ? `En öncelikli öneri: <b>${esc(enUst.firma)}</b> (skor ${enUst.skor}). ` : ""}Güne <b>${bugun.length} durak</b> sığıyor${yarin.length ? `, ${yarin.length} uzak durak yarına` : ""}.</div></div>
      <div class="rt-cap"><div class="row"><span class="l">Bugünün kapasitesi</span><span class="r">${bugun.length} durak · ~${hhmm(bitis)}</span></div>
        <div class="bar"><div class="s1" style="width:${pG}%"></div><div class="s2" style="width:${pY}%"></div><div class="s3" style="width:${pB}%"></div></div>
        <div class="lgn"><span><i style="background:#6d5ae0"></i>Görüşme ~${Math.round(gorTop / 60 * 10) / 10}sa</span><span><i style="background:#2563eb"></i>Yol ~${Math.round(yolTop / 60 * 10) / 10}sa</span><span><i style="background:#e4e4e2"></i>Boş</span></div></div>
      <div class="rt-start"><div class="o">🏁 Başlangıç: <span>${esc(d.baslangic.ad || "Konum")} · 09:00</span></div><span class="chg" id="rt-degis">değiştir</span></div>
      <div class="rt-sech">🚗 Bugünün rotası <span class="cnt">· ${bugun.length}</span></div>
      ${bugun.length ? `<div class="rt-route">${bugun.map((sc, i) => card(sc.c, i + 1, sc.c.plan_bugun ? "commit" : tier(sc.c.skor), sc)).join("")}</div>` : `<div class="rt-empty">Bugün için durak yok.</div>`}
      ${yarin.length ? `<div class="rt-over">⏭ Yarına (${yarin.length})</div><div class="rt-route">${yarin.map((sc, i) => card(sc.c, bugun.length + i + 1, sc.c.plan_bugun ? "commit" : tier(sc.c.skor), sc)).join("")}</div>` : ""}
    </div>`;
    const dg = box.querySelector("#rt-degis"); if (dg) dg.addEventListener("click", () => { if (!navigator.geolocation) { alert("Konum desteklenmiyor"); return; } dg.textContent = "alınıyor…"; navigator.geolocation.getCurrentPosition(async p => { try { await api(`/api/saha/rep-baslangic`, { method: "POST", body: JSON.stringify({ lat: p.coords.latitude, lng: p.coords.longitude, ad: "Check-in", kaynak: "checkin" }) }); rpRotam(); } catch (e) { alert(e.message || e); } }, err => { dg.textContent = "değiştir"; alert("Konum alınamadı: " + err.message); }); });
    bindKart();

    function card(c, rank, cls, sc) {
      const eta = sc && sc.arr != null ? `<span class="eta">~${hhmm(sc.arr)}</span>` : "";
      const dist = (c.lat != null) ? (sc ? `<span class="dist">${sc.leg} dk yol</span>` : (d.baslangic ? `<span class="dist">${Math.round((hav(bas, { lat: c.lat, lng: c.lng }) || 0))} km</span>` : "")) : `<span class="rt-nopin">📍 Konum sabitlenmemiş</span>`;
      const son = (c.gun != null && !c.plan_bugun) ? `son ${c.gun}g` : "";
      return `<div class="rt-stop ${cls}${sc && !sc.fits ? " over" : ""}"><div class="rt-top"><div class="rt-rank">${rank}</div>
        <div style="flex:1;min-width:0"><div class="rt-firm">${esc(c.firma)}</div><div class="rt-loc">${eta}<span>${esc(c.il || "")}${c.ilce ? " · " + esc(c.ilce) : ""}</span>${dist}${son ? `<span>${son}</span>` : ""}</div></div>
        <div class="rt-skor"><div class="n">${c.plan_bugun ? "📌" : c.skor}</div><div class="l">${c.plan_bugun ? "plan" : "öncelik"}</div></div></div>
        <div class="rt-why">${chips(c)}</div>${acts(c)}</div>`;
    }
  }
  async function rpCiro() {'''
assert s.count(anchor) == 1, "rpCiro anchor=%d" % s.count(anchor)
s = s.replace(anchor, RP, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_V1 (mobil)")
