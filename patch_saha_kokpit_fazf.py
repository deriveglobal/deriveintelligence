#!/usr/bin/env python3
# FAZF_TAKIP (Izle->Ogren F-2 frontend) — aksiyon dux gmesi takibi BASLATIR + kokpitte "Takip · sonuclar" bolumu.
#   Dux gmeye basinca /api/bi/takip-baslat POST (tur/konular/baz) + CEO acilir. Kokpit acilisinda /api/bi/takip-durum.
#   Onkosul: FAZE_AKSIYON (saha.js) + KOKPIT_TAKIP (server).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "FAZF_TAKIP" in s:
    print("[skip] FAZF_TAKIP zaten var"); sys.exit(0)
if "FAZE_AKSIYON" not in s:
    print("HATA: once FAZE_AKSIYON uygulanmali"); sys.exit(1)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor yok -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# 1) _actBtn -> meta (takip data)
rep(
r'''      const _actBtn = (label, prompt) => `<div style="margin-top:6px"><button class="kok-act" data-prompt="${esc(prompt)}" style="border:1px solid #f59e0b;background:#fff;color:#b45309;border-radius:16px;padding:5px 12px;font-size:12px;font-weight:700;font-family:inherit;cursor:pointer">${label}</button></div>`;''',
r'''      const _actBtn = (label, prompt, meta) => { const _md = meta ? ` data-tur="${esc(meta.tur)}" data-aksiyon="${esc(meta.aksiyon || "")}" data-konular="${esc(JSON.stringify(meta.konular || []))}" data-baz="${esc(JSON.stringify(meta.baz || {}))}"` : ""; return `<div style="margin-top:6px"><button class="kok-act" data-prompt="${esc(prompt)}"${_md} style="border:1px solid #f59e0b;background:#fff;color:#b45309;border-radius:16px;padding:5px 12px;font-size:12px;font-weight:700;font-family:inherit;cursor:pointer">${label}</button></div>`; };''',
    "actbtn-meta")

# 2/3/4) 3 sinyal cagrisina meta ekle
rep('öğrenmelerini iste.")}',
    'öğrenmelerini iste.", { tur: "kayip", aksiyon: "ziyaret", konular: _dk.kayip })}', "meta-kayip")
rep('takip hatırlatması kur.")}',
    'takip hatırlatması kur.", { tur: "gecikme", aksiyon: "tahsilat", konular: [_dk.gecikme.ad], baz: { net: _dk.gecikme.net_m } })}', "meta-gecikme")
rep('hacim büyütme/fırsat görevi aç ve temsilciye ata.")}',
    'hacim büyütme/fırsat görevi aç ve temsilciye ata.", { tur: "firsat", aksiyon: "firsat", konular: _dk.buyuyen })}', "meta-firsat")

# 5) takip placeholder (Nabiz zone'dan once)
rep('    h += zone("#0f172a", "🩺 Nabız · para & nakit", "Karar: işler yolunda mı, nakit güvende mi");',
    '    h += `<div id="kok-takip"></div>`; /* FAZF_TAKIP */\n    h += zone("#0f172a", "🩺 Nabız · para & nakit", "Karar: işler yolunda mı, nakit güvende mi");',
    "takip-placeholder")

# 6) click handler -> takip-baslat POST
rep(
r'''        const pr = b.getAttribute("data-prompt") || "";
        try { setRoom("ceo"); } catch (e) {}''',
r'''        const pr = b.getAttribute("data-prompt") || "";
        const _tur = b.getAttribute("data-tur");
        if (_tur) { let _kon = [], _baz = {}; try { _kon = JSON.parse(b.getAttribute("data-konular") || "[]"); } catch (e) {} try { _baz = JSON.parse(b.getAttribute("data-baz") || "{}"); } catch (e) {} api("/api/bi/takip-baslat", { method: "POST", body: JSON.stringify({ tur: _tur, aksiyon: b.getAttribute("data-aksiyon") || "", konular: _kon, baz: _baz }) }).catch(function () {}); } /* FAZF_TAKIP */
        try { setRoom("ceo"); } catch (e) {}''',
    "handler-takip")

# 7) _loadTakip + cagri (aksiyon wiring'den sonra, _loadDonem oncesi)
rep('    }); /* FAZE_AKSIYON */\n    _loadDonem("sonay");',
r'''    }); /* FAZE_AKSIYON */
    async function _loadTakip() { /* FAZF_TAKIP */
      const el = document.getElementById("kok-takip"); if (!el) return;
      let t = null; try { t = await api("/api/bi/takip-durum"); } catch (e) { t = null; }
      if (!t || !t.takipler || !t.takipler.length) { el.innerHTML = ""; return; }
      const _clr = x => x.iyi === true ? "#16a34a" : x.iyi === false ? "#b91c1c" : "#94a3b8";
      const _ic = x => x.iyi === true ? " ✓" : "";
      const _rows = t.takipler.slice(0, 12).map(x => `<div class="kok-row"><span class="rk" style="max-width:54%">${esc(x.konu)} <span style="color:#94a3b8;font-size:11px">· ${x.gun}g</span></span><span class="rv" style="color:${_clr(x)};font-weight:700">${esc(x.sonuc)}${_ic(x)}</span></div>`).join("");
      el.innerHTML = `<div class="kok-sec" style="border-left:3px solid #10b981"><div class="kok-sb">🔁 Takip · aksiyon sonuçları <span style="color:#94a3b8;font-weight:700">${t.takipler.length}</span></div>${_rows}</div>`;
    }
    _loadTakip();
    _loadDonem("sonay");''',
    "loadtakip")

s = s + "\n/* FAZF_TAKIP */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] FAZF_TAKIP — aksiyon takibi baslatir + kokpitte Takip bolumu (Izle->Ogren dongusu kapandi)")
