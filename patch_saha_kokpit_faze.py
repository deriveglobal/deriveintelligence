#!/usr/bin/env python3
# FAZE_AKSIYON — kokpiti DINAMIK yapar: Dikkat sinyallerine "aksiyon" duxgmeleri.
#   Kayip->Ziyaret gorevi, Gecikme->Tahsilat gorevi, Buyuyen->Firsat gorevi, + genel "Asistana danis".
#   Mekanizma: setRoom("ceo") + #ceo-inp'i HAZIR talimatla doldur (owner onaylayip gonderir).
#   Asistan zaten create_task/set_reminder/send_email araclariyla uygular. Onkosul: FAZD_OWNERLENS.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "saha.js"
s = open(F, encoding="utf-8").read()
if "FAZE_AKSIYON" in s:
    print("[skip] FAZE_AKSIYON zaten var"); sys.exit(0)
if "FAZD_OWNERLENS" not in s:
    print("HATA: once FAZD_OWNERLENS uygulanmali"); sys.exit(1)

def rep(old, new, tag):
    global s
    assert old in s, "HATA: anchor yok -> " + tag
    assert s.count(old) == 1, "HATA: anchor tek degil (%d) -> %s" % (s.count(old), tag)
    s = s.replace(old, new, 1)

# E1) Dikkat _dl blogu -> aksiyon duxgmeli versiyon
OLD = r'''      let _dl = "";
      if (_dk.kayip && _dk.kayip.length) _dl += _sig("#ef4444", "#fee2e2", `<b>${_dk.kayip.length} müşteri alımını azalttı</b> — kayıp riski: <span style="color:#64748b">${esc(_dk.kayip.slice(0, 3).join(", "))}</span>. Ziyaret?`);
      if (_dk.gecikme) _dl += _sig("#f59e0b", "#fef3c7", `<b>Gecikmenin kaynağı:</b> <span style="color:#64748b">${esc(_dk.gecikme.ad)}</span> <b style="color:#b91c1c">${money(_dk.gecikme.net_m)} net</b>${_dk.gecikme.ilk5_pct != null ? ` — ilk 5 = %${_dk.gecikme.ilk5_pct}` : ""}. Bu hesabı kapat.`);
      if (_dk.buyuyen && _dk.buyuyen.length) _dl += _sig("#10b981", "#d1fae5", `<b>Büyüyenler:</b> <span style="color:#64748b">${esc(_dk.buyuyen.slice(0, 3).join(", "))}</span> — kış öncesi dokun.`);
      h += zone("#b45309", "⚡ Bugün ne yapmalı", "Karar: kimi ara, hangi hesabı kapat");'''
NEW = r'''      const _actBtn = (label, prompt) => `<div style="margin-top:6px"><button class="kok-act" data-prompt="${esc(prompt)}" style="border:1px solid #f59e0b;background:#fff;color:#b45309;border-radius:16px;padding:5px 12px;font-size:12px;font-weight:700;font-family:inherit;cursor:pointer">${label}</button></div>`;
      let _dl = "";
      if (_dk.kayip && _dk.kayip.length) _dl += _sig("#ef4444", "#fee2e2", `<b>${_dk.kayip.length} müşteri alımını azalttı</b> — kayıp riski: <span style="color:#64748b">${esc(_dk.kayip.slice(0, 3).join(", "))}</span>. Ziyaret?${_actBtn("→ Ziyaret görevi aç", "Şu müşteriler alımını azalttı, kayıp riski var: " + _dk.kayip.join(", ") + ". Her biri için temsilciye ziyaret görevi aç ve neden azaldığını (rakibe mi kaydı) öğrenmelerini iste.")}`);
      if (_dk.gecikme) _dl += _sig("#f59e0b", "#fef3c7", `<b>Gecikmenin kaynağı:</b> <span style="color:#64748b">${esc(_dk.gecikme.ad)}</span> <b style="color:#b91c1c">${money(_dk.gecikme.net_m)} net</b>${_dk.gecikme.ilk5_pct != null ? ` — ilk 5 = %${_dk.gecikme.ilk5_pct}` : ""}. Bu hesabı kapat.${_actBtn("→ Tahsilat görevi aç", _dk.gecikme.ad + " en büyük gecikmiş hesap (" + money(_dk.gecikme.net_m) + " net" + (_dk.gecikme.ilk5_pct != null ? ", ilk 5 hesap gecikmişin %" + _dk.gecikme.ilk5_pct + "'i" : "") + "). Bu hesap için tahsilat görevi aç, finansa ata ve bana takip hatırlatması kur.")}`);
      if (_dk.buyuyen && _dk.buyuyen.length) _dl += _sig("#10b981", "#d1fae5", `<b>Büyüyenler:</b> <span style="color:#64748b">${esc(_dk.buyuyen.slice(0, 3).join(", "))}</span> — kış öncesi dokun.${_actBtn("→ Fırsat görevi aç", "Şu müşteriler büyüyor: " + _dk.buyuyen.join(", ") + ". Kış sezonu öncesi her biri için hacim büyütme/fırsat görevi aç ve temsilciye ata.")}`);
      _dl += `<div style="padding-top:9px;margin-top:3px;border-top:1px solid #f5eddc"><button class="kok-act" data-prompt="${esc("Kokpitteki bugünkü uyarılara (kayıp riski, gecikme kaynağı, büyüyen müşteriler) göre öncelikli bir aksiyon planı çıkar ve gerekli görevleri aç.")}" style="border:1px solid #8b5cf6;background:#faf5ff;color:#7c3aed;border-radius:16px;padding:6px 12px;font-size:12px;font-weight:700;font-family:inherit;cursor:pointer">🧠 Asistana danış — aksiyon planı</button></div>`;
      h += zone("#b45309", "⚡ Bugün ne yapmalı", "Karar: kimi ara, hangi hesabı kapat");'''
rep(OLD, NEW, "dikkat-aksiyon")

# E2) aksiyon click wiring (setRoom ceo + prefill) — _loadDonem("sonay") oncesi
rep('    _loadDonem("sonay");',
r'''    (m.querySelectorAll ? m.querySelectorAll(".kok-act") : []).forEach(function (b) {
      b.addEventListener("click", function (ev) {
        if (ev && ev.stopPropagation) ev.stopPropagation();
        const pr = b.getAttribute("data-prompt") || "";
        try { setRoom("ceo"); } catch (e) {}
        setTimeout(function () { const inp = document.getElementById("ceo-inp"); if (inp) { inp.value = pr; try { inp.focus(); inp.dispatchEvent(new Event("input", { bubbles: true })); } catch (e) {} } }, 90);
      });
    }); /* FAZE_AKSIYON */
    _loadDonem("sonay");''',
    "aksiyon-wiring")

s = s + "\n/* FAZE_AKSIYON */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] FAZE_AKSIYON — Dikkat sinyallerine aksiyon duxgmeleri (setRoom ceo + prefill); kokpit dinamik")
