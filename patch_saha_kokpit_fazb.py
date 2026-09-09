#!/usr/bin/env python3
# FAZB_KOKPIT — saha.js mobil Kokpit: ADDITIVE ust katman. Mevcut vKokpitMobil bolumlerine DOKUNMAZ;
#   sadece vitals'tan SONRA / kanal'dan ONCE: Dikkat karti (/api/bi/mobil-dikkat) + Iki-Is catali (mevcut
#   d.segment'ten, PSR=Tuketici). Vitals "nasildi" -> "YoY" etiketi. Ekstra fetch tek: mobil-dikkat (saha-yetkili).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "FAZB_KOKPIT" in s:
    print("[skip] FAZB_KOKPIT zaten var"); sys.exit(0)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor yok -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# E1) Dikkat verisi fetch (kokpit-data'dan sonra)
rep('    const d = await api("/api/bi/kokpit-data");',
    '    const d = await api("/api/bi/kokpit-data");\n    let _dk = null; try { _dk = await api("/api/bi/mobil-dikkat"); } catch (e) { _dk = null; } /* FAZB_KOKPIT */',
    "fetch")

# E2) Dikkat karti + Iki-Is catali (kanal bolumunden ONCE)
KANAL = '    if (d.kanal?.length) h += `<div class="kok-sec"><div class="kok-sb">📊 Satış Kanalı</div>${list(d.kanal, x => x.k, x => `${money(x.c)} · <span style="color:${mjc(x.mj)}">${pct(x.mj)}</span>`)}</div>`;'
INS = r'''    /* FAZB_KOKPIT — Dikkat sentezi + Iki-Is catali (ust katman) */
    if (_dk && ((_dk.kayip && _dk.kayip.length) || (_dk.buyuyen && _dk.buyuyen.length) || _dk.gecikme)) {
      const _sig = (clr, bg, html) => `<div style="display:flex;gap:8px;padding:7px 0;border-top:1px solid #f5eddc"><span style="width:8px;height:8px;border-radius:50%;background:${clr};box-shadow:0 0 0 3px ${bg};margin-top:5px;flex:0 0 auto"></span><div style="font-size:13px;line-height:1.42;color:#1f2937">${html}</div></div>`;
      let _dl = "";
      if (_dk.kayip && _dk.kayip.length) _dl += _sig("#ef4444", "#fee2e2", `<b>${_dk.kayip.length} müşteri alımını azalttı</b> — kayıp riski: <span style="color:#64748b">${esc(_dk.kayip.slice(0, 3).join(", "))}</span>. Ziyaret?`);
      if (_dk.gecikme) _dl += _sig("#f59e0b", "#fef3c7", `<b>Gecikmenin kaynağı:</b> <span style="color:#64748b">${esc(_dk.gecikme.ad)}</span> <b style="color:#b91c1c">${money(_dk.gecikme.net_m)} net</b>${_dk.gecikme.ilk5_pct != null ? ` — ilk 5 = %${_dk.gecikme.ilk5_pct}` : ""}. Bu hesabı kapat.`);
      if (_dk.buyuyen && _dk.buyuyen.length) _dl += _sig("#10b981", "#d1fae5", `<b>Büyüyenler:</b> <span style="color:#64748b">${esc(_dk.buyuyen.slice(0, 3).join(", "))}</span> — ivme var, kış öncesi dokun.`);
      h += `<div class="kok-sec" style="border-left:3px solid #f59e0b;background:linear-gradient(160deg,#fffdf7,#fff)"><div class="kok-sb">⚡ Bugün ne yapmalı</div>${_dl}</div>`;
    }
    if (d.segment && d.segment.length) {
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
''' + KANAL
rep(KANAL, INS, "dikkat-catal")

# E3) vitals "nasildi" -> "YoY" etiketi (year-ago zaten YoY)
rep('${up ? "▲" : "▼"} nasıldı ${wtxt}', '${up ? "▲" : "▼"} YoY · gy ${wtxt}', "yoy-etiket")

s = s + "\n/* FAZB_KOKPIT */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] FAZB_KOKPIT — mobil Kokpit ust katman: Dikkat karti + Iki-Is catali + YoY etiketi (additive)")
