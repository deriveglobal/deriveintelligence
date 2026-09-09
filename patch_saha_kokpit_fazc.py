#!/usr/bin/env python3
# FAZC_TOGGLE — saha.js mobil Kokpit donem seciciyi (Bu ay·canli/Son ay/Son 3 ay/YTD) baglar.
#   Vitals: Ciro+Marj DONEM-aware (umbrella + yoy), Stok+DSO 'su an' sabit (kokpit-data). Iki-Is donem-aware.
#   Faz B statik Iki-Is (d.segment) KALDIRILIR (umbrella period versiyonu yerine gecer). Onkosul: FAZB_KOKPIT + UMBRELLA_YOY.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "FAZC_TOGGLE" in s:
    print("[skip] FAZC_TOGGLE zaten var"); sys.exit(0)
if "FAZB_KOKPIT" not in s:
    print("HATA: once FAZB_KOKPIT uygulanmali"); sys.exit(1)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor yok -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# E1) vitals grid -> chip row + #kok-p placeholder
V = '''    let h = `<div class="kok-wrap">
      <div class="kok-vitals">
        <div class="kok-v"><div class="l">Ciro (son ay)</div><div class="n">${money(v.ciro)}</div>${wasNow(v.ciro, v.ciro_was, "m")}</div>
        <div class="kok-v"><div class="l">Stok Değeri</div><div class="n">${money(v.stok)}</div>${wasNow(v.stok, v.stok_was, "m")}</div>
        <div class="kok-v"><div class="l">DSO</div><div class="n">${v.dso != null ? Math.round(v.dso) + " gün" : "—"}</div>${wasNow(v.dso, v.dso_was, "gun", true)}</div>
        <div class="kok-v"><div class="l">Şirket Marj</div><div class="n">${pct(v.marj)}</div><div class="w" style="color:#94a3b8">brüt · teşvik öncesi</div></div>
      </div>`;'''
V2 = r'''    let h = `<div class="kok-wrap">
      <div class="kok-donem" style="display:flex;gap:6px;overflow-x:auto;margin-bottom:12px;padding-bottom:2px">
        ${["buay:Bu ay","sonay:Son ay","3ay:Son 3 ay","ytd:YTD"].map(function(x){var pp=x.split(":");return `<button class="kok-chip" data-p="${pp[0]}" style="flex:0 0 auto;border:1px solid #e2e8f0;background:#fff;color:#64748b;border-radius:20px;padding:7px 13px;font-size:12.5px;font-weight:700;white-space:nowrap;font-family:inherit">${pp[1]}</button>`;}).join("")}
      </div>
      <div id="kok-p"></div>`;'''
rep(V, V2, "vitals->chips")

# E2) Faz B statik Iki-Is blogunu kaldir (umbrella period versiyonu _loadDonem'de)
IIB = '''    if (d.segment && d.segment.length) {
      const _psr = d.segment.find(x => x.s === "PSR");
      const _tk = _psr ? (_psr.c || 0) : 0;
      const _tcArr = d.segment.filter(x => x.s !== "PSR");
      const _tc = _tcArr.reduce((a, x) => a + (x.c || 0), 0);
      const _tot = _tk + _tc;
      if (_tot > 0) {
        const _tkp = Math.round(_tk / _tot * 100), _tcp = 100 - _tkp;
        const _tw = _tcArr.reduce((a, x) => ({ n: a.n + (x.c || 0) * (x.mj || 0), d: a.d + (x.c || 0) }), { n: 0, d: 0 });
        const _tcMj = _tw.d ? +(_tw.n / _tw.d).toFixed(1) : null;
        const _tkMj = _psr ? _psr.mj : null;
        h += `<div class="kok-sec"><div class="kok-sb">⑂ İki İş · ciro payı <span style="color:#94a3b8">lastik işi</span></div>
          <div style="display:flex;height:26px;border-radius:8px;overflow:hidden;background:#f1f5f9">
            <div style="width:${_tkp}%;min-width:44px;background:linear-gradient(180deg,#34d399,#10b981);color:#053528;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:800">Tük %${_tkp}</div>
            <div style="width:${_tcp}%;min-width:44px;background:linear-gradient(180deg,#60a5fa,#3b82f6);color:#06203f;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:800">Tic %${_tcp}</div>
          </div>
          <div style="display:flex;justify-content:space-between;margin-top:8px;font-size:11.5px;color:#475569;font-weight:600"><span>Tüketici <span style="color:#94a3b8">marj ${pct(_tkMj)}</span></span><span>Ticari <span style="color:#94a3b8">marj ${pct(_tcMj)}</span></span></div>
        </div>`;
      }
    }
'''
rep(IIB, "    /* FAZC_TOGGLE — Iki-Is artik _loadDonem'de (donem-aware) */\n", "iki-is-kaldir")

# E3) _loadDonem + chip wiring (m.innerHTML = h'den sonra)
A3 = "    h += `</div>`;\n    m.innerHTML = h;"
LOAD = A3 + r'''
    /* FAZC_TOGGLE */
    const _donemCfg = { buay: { q: "?ay=1", canli: true, lbl: "Bu ay" }, sonay: { q: "?ay=1", lbl: "Son ay" }, "3ay": { q: "?ay=3", lbl: "Son 3 ay" }, ytd: { q: "?ytd=1", lbl: "YTD" } };
    const _yc = (now, gy, unit) => {
      if (now == null || gy == null || gy == 0) return `<div class="w" style="color:#94a3b8">YoY —</div>`;
      const dp = unit === "p" ? (now - gy) : ((now - gy) / Math.abs(gy) * 100);
      const up = dp >= 0;
      const txt = unit === "p" ? `${up ? "▲" : "▼"}${Math.abs(dp).toFixed(1)}p` : `${up ? "▲" : "▼"}${Math.abs(Math.round(dp))}%`;
      const gyt = unit === "p" ? pct(gy) : (unit === "n" ? Number(gy).toLocaleString("tr-TR") : money(gy));
      return `<div class="w" style="color:${up ? "#3ecf8e" : "#ff6b5a"}">${txt} YoY · gy ${gyt}</div>`;
    };
    async function _loadDonem(p) {
      const cfg = _donemCfg[p] || _donemCfg.sonay;
      const pel = document.getElementById("kok-p"); if (!pel) return;
      const chips = m.querySelectorAll ? m.querySelectorAll(".kok-chip") : [];
      chips.forEach(function (c) { const on = c.getAttribute("data-p") === p; c.style.background = on ? "#0f172a" : "#fff"; c.style.color = on ? "#fff" : "#64748b"; c.style.borderColor = on ? "#0f172a" : "#e2e8f0"; });
      pel.innerHTML = `<div style="padding:16px;color:#94a3b8;font-size:13px">Dönem yükleniyor…</div>`;
      let u = null; try { u = await api("/api/bi/kokpit-umbrella" + cfg.q); } catch (e) { u = null; }
      const v = d.vitals || {};
      let ciro = null, marj = null, ciroGy = null, marjGy = null;
      if (cfg.canli && u && u.canli) { ciro = u.canli.ciro; marj = u.canli.marj; ciroGy = u.canli_gy ? u.canli_gy.ciro : null; marjGy = null; }
      else if (u && u.toplam) { ciro = u.toplam.ciro; marj = u.toplam.marj; ciroGy = u.yoy ? u.yoy.ciro : null; marjGy = u.yoy ? u.yoy.marj : null; }
      let vg = `<div class="kok-vitals">
        <div class="kok-v"><div class="l">Ciro · ${esc(cfg.lbl)}</div><div class="n">${money(ciro)}</div>${_yc(ciro, ciroGy, "m")}</div>
        <div class="kok-v"><div class="l">Stok <span style="font-size:9px;color:#64748b">· şu an</span></div><div class="n">${money(v.stok)}</div>${wasNow(v.stok, v.stok_was, "m")}</div>
        <div class="kok-v"><div class="l">DSO <span style="font-size:9px;color:#64748b">· şu an</span></div><div class="n">${v.dso != null ? Math.round(v.dso) + " gün" : "—"}</div>${wasNow(v.dso, v.dso_was, "gun", true)}</div>
        <div class="kok-v"><div class="l">Şirket marj · ${esc(cfg.lbl)}</div><div class="n">${pct(marj)}</div>${_yc(marj, marjGy, "p")}</div>
      </div>`;
      let ii = "";
      if (u && u.tuketici && u.ticari) {
        const _tk = u.tuketici.ciro || 0, _tc = u.ticari.ciro || 0, _tot = _tk + _tc;
        if (_tot > 0) {
          const _tkp = Math.round(_tk / _tot * 100), _tcp = 100 - _tkp;
          ii = `<div class="kok-sec"><div class="kok-sb">⑂ İki İş · ciro payı <span style="color:#94a3b8">${esc(cfg.lbl)}</span></div>
            <div style="display:flex;height:26px;border-radius:8px;overflow:hidden;background:#f1f5f9">
              <div style="width:${_tkp}%;min-width:44px;background:linear-gradient(180deg,#34d399,#10b981);color:#053528;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:800">Tük %${_tkp}</div>
              <div style="width:${_tcp}%;min-width:44px;background:linear-gradient(180deg,#60a5fa,#3b82f6);color:#06203f;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:800">Tic %${_tcp}</div>
            </div>
            <div style="display:flex;justify-content:space-between;margin-top:8px;font-size:11.5px;color:#475569;font-weight:600"><span>Tüketici <span style="color:#94a3b8">marj ${pct(u.tuketici.marj)}</span></span><span>Ticari <span style="color:#94a3b8">marj ${pct(u.ticari.marj)}</span></span></div>
          </div>`;
        }
      }
      pel.innerHTML = vg + ii;
    }
    (m.querySelectorAll ? m.querySelectorAll(".kok-chip") : []).forEach(function (c) { c.addEventListener("click", function () { _loadDonem(c.getAttribute("data-p")); }); });
    _loadDonem("sonay");'''
rep(A3, LOAD, "loaddonem")

s = s + "\n/* FAZC_TOGGLE */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] FAZC_TOGGLE — donem toggle + donem-aware vitals(Ciro/Marj)+Iki-Is + YoY, Stok/DSO sabit")
