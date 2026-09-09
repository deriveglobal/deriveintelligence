#!/usr/bin/env python3
# CEO_SES_V2 — CEO Assistant'a SES: (1) mikrofon (sesle sor) + (2) yanıtları sesli oku (🔊) toggle.
# Mikrofon iki yolu dener: iOS uygulamada NATIVE eklenti (Capacitor SpeechRecognition), web/Android'de
# webkitSpeechRecognition. Hiçbiri yoksa mikrofon GİZLİ kalır (ölü buton yok). Konuşma sentezi
# (speechSynthesis) her yerde çalışır (iOS WKWebView dahil), o yüzden 🔊 her zaman görünür.
# NOT: iOS native mikrofon, uygulamaya @capacitor-community/speech-recognition eklenip yeniden derlenince
# aktifleşir; o build çıkana kadar iOS'ta mikrofon gizli kalır ama 🔊 çalışır. 4 düzenleme (shells/saha.js).
# Idempotent. /opt/krb-assessment içinde çalıştır.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)

if "CEO_SES_V2" in s:
    print("ceo-voice: already present, skip")
    print("DONE.")
    raise SystemExit

# ---------- (1) markup: mic + speaker, gönder butonundan ÖNCE ----------
old_m = '        <button type="submit" id="ceo-send" title="Gönder">➤</button>'
new_m = (
    '        <button type="button" id="ceo-mic" class="ceo-mic" title="Sesle sor" style="display:none">🎙</button>\n'
    '        <button type="button" id="ceo-spk" class="ceo-spk" title="Yanıtları sesli oku" style="display:none">🔊</button>\n'
    '        <button type="submit" id="ceo-send" title="Gönder">➤</button>'
)
assert s.count(old_m) == 1, "markup anchor"
s = s.replace(old_m, new_m, 1)

# ---------- (2) vCeoMobil: ses kurulumu (mic native+web, TTS toggle) ----------
old_j = '  const sendBtn = document.getElementById("ceo-send");'
new_j = old_j + "\n" + r"""
  // CEO_SES_V2 — sesle sor (native iOS eklentisi ya da web speech) + yanıtları sesli oku.
  const micBtn = document.getElementById("ceo-mic");
  const spkBtn = document.getElementById("ceo-spk");
  let sesOku = false;
  function ceoKonus(t) {
    try {
      if (!sesOku || !window.speechSynthesis) return;
      const s = String(t || "").trim();
      if (!s) return;
      window.speechSynthesis.cancel();
      const u = new SpeechSynthesisUtterance(s.slice(0, 1000));
      u.lang = "tr-TR";
      window.speechSynthesis.speak(u);
    } catch (e) {}
  }
  // 🔊 yanıtları sesli oku toggle (her yerde çalışır)
  if (spkBtn && window.speechSynthesis) {
    spkBtn.style.display = "";
    try { sesOku = localStorage.getItem("ceo_ses_oku") === "1"; } catch (e) {}
    if (sesOku) spkBtn.classList.add("aktif");
    spkBtn.addEventListener("click", () => {
      sesOku = !sesOku;
      spkBtn.classList.toggle("aktif", sesOku);
      try { localStorage.setItem("ceo_ses_oku", sesOku ? "1" : "0"); } catch (e) {}
      if (!sesOku) { try { window.speechSynthesis.cancel(); } catch (e) {} }
    });
  }
  // 🎙 mikrofon — native (iOS) öncelikli, yoksa web speech
  (function () {
    const Cap = window.Capacitor;
    const NAT = (Cap && Cap.isNativePlatform && Cap.isNativePlatform() && Cap.Plugins && Cap.Plugins.SpeechRecognition) ? Cap.Plugins.SpeechRecognition : null;
    const WebSR = window.SpeechRecognition || window.webkitSpeechRecognition;
    if (!micBtn || (!NAT && !WebSR)) return;
    micBtn.style.display = "";
    let aktif = false, webRec = null, natLh = null, base = "";
    async function durdur() {
      try {
        if (NAT) { await NAT.stop(); if (natLh) { natLh.remove(); natLh = null; } }
        else if (webRec) { webRec.stop(); }
      } catch (e) {}
      aktif = false; micBtn.classList.remove("dinliyor");
    }
    micBtn.addEventListener("click", async () => {
      if (aktif) { durdur(); return; }
      if (NAT) {
        try {
          let p = {};
          try { p = await NAT.checkPermissions(); } catch (e) {}
          if (!p || p.speechRecognition !== "granted") {
            try { p = await NAT.requestPermissions(); } catch (e) {}
          }
          if (p && p.speechRecognition && p.speechRecognition !== "granted") { uyari("Mikrofon/konuşma izni gerekli."); return; }
          aktif = true; micBtn.classList.add("dinliyor");
          base = inp.value ? inp.value.replace(/\s+$/, "") + " " : "";
          natLh = await NAT.addListener("partialResults", d => {
            const mm = (d && d.matches && d.matches[0]) || "";
            inp.value = base + mm;
            inp.dispatchEvent(new Event("input", { bubbles: true }));
          });
          await NAT.start({ language: "tr-TR", partialResults: true, popup: false });
        } catch (e) { aktif = false; micBtn.classList.remove("dinliyor"); }
        return;
      }
      // web speech yolu
      webRec = new WebSR();
      webRec.lang = "tr-TR"; webRec.continuous = true; webRec.interimResults = false;
      aktif = true; micBtn.classList.add("dinliyor");
      webRec.onresult = ev => {
        const t = Array.from(ev.results).map(r => r[0].transcript).join(" ").trim();
        if (t) { inp.value = inp.value ? inp.value + " " + t : t; inp.dispatchEvent(new Event("input", { bubbles: true })); inp.focus(); }
      };
      webRec.onerror = () => { aktif = false; micBtn.classList.remove("dinliyor"); webRec = null; };
      webRec.onend = () => { aktif = false; micBtn.classList.remove("dinliyor"); webRec = null; };
      webRec.start();
    });
  })();"""
assert s.count(old_j) == 1, "js anchor"
s = s.replace(old_j, new_j, 1)

# ---------- (3) gonder tamamlanınca yanıtı sesli oku ----------
old_t = '      if (!txt.trim()) b.textContent = greeting ? "Merhaba! Nasıl yardımcı olabilirim?" : "…";'
new_t = old_t + "\n      try { ceoKonus(txt.trim() || b.textContent); } catch (e) {} /* CEO_SES_V2 */"
assert s.count(old_t) == 1, "tts-call anchor"
s = s.replace(old_t, new_t, 1)

# ---------- (4) CSS ----------
old_c = "  .ceo-bar button:disabled{opacity:.5}"
new_c = (
    "  .ceo-bar button:disabled{opacity:.5}\n"
    "  .ceo-bar button.ceo-mic,.ceo-bar button.ceo-spk{background:#fff;color:#7c3aed;border:1px solid #cbd5e1}\n"
    "  .ceo-bar button.ceo-mic.dinliyor{background:#ef4444;color:#fff;border-color:#ef4444;animation:sesNabiz .7s ease-in-out infinite}\n"
    "  .ceo-bar button.ceo-spk.aktif{background:#7c3aed;color:#fff;border-color:#7c3aed}"
)
assert s.count(old_c) == 1, "css anchor"
s = s.replace(old_c, new_c, 1)

write(FP, s)
print("ceo-voice: markup+js+tts+css patched")
print("DONE.")
