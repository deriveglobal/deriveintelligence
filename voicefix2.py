#!/usr/bin/env python3
# VOICE_FIX_2 (shells/saha.js) — iki düzeltme:
# (1) CEO sohbetinde pull-to-refresh, iç sohbet kaydırmasını (.ceo-msgs) ele geçiriyordu; PTR
#     saha-main scrollTop=0 sanıp her yukarı çekişte "yenile" tetikliyordu. CEO açıkken PTR no-op.
# (2) Sesli yanıt robotik: en iyi Türkçe sesi seç (Siri/premium/enhanced tercih, compact'tan kaçın),
#     rate/pitch ayarla. (Gerçek ChatGPT-tarzı doğallık için sunucu-taraflı neural TTS ayrı iş.)
# Idempotent. /opt/krb-assessment içinde çalıştır.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)

if "VOICE_FIX_2" in s:
    print("voicefix2: already present, skip")
    print("DONE.")
    raise SystemExit

# ---------- (1) PTR: CEO sohbeti açıkken devre dışı ----------
old_sc = 'function sc() { return document.getElementById("saha-main"); }'
new_sc = 'function sc() { if (document.querySelector(".ceo-wrap")) return null; /* VOICE_FIX_2 */ return document.getElementById("saha-main"); }'
c1 = s.count(old_sc)
assert c1 == 1, "PTR sc() anchor bulunamadi (count=%d)" % c1
s = s.replace(old_sc, new_sc, 1)

# ---------- (2) ceoKonus: en iyi TR sesi + tune ----------
old_konus = (
    "  function ceoKonus(t) {\n"
    "    try {\n"
    "      if (!sesOku || !window.speechSynthesis) return;\n"
    "      const s = String(t || \"\").trim();\n"
    "      if (!s) return;\n"
    "      window.speechSynthesis.cancel();\n"
    "      const u = new SpeechSynthesisUtterance(s.slice(0, 1000));\n"
    "      u.lang = \"tr-TR\";\n"
    "      window.speechSynthesis.speak(u);\n"
    "    } catch (e) {}\n"
    "  }"
)
new_konus = (
    "  let _ceoVoice = null; /* VOICE_FIX_2 */\n"
    "  function _ceoPickVoice() {\n"
    "    try {\n"
    "      const vs = (window.speechSynthesis.getVoices && window.speechSynthesis.getVoices()) || [];\n"
    "      const tr = vs.filter(v => /(^|[-_])tr([-_]|$)/i.test(v.lang || \"\"));\n"
    "      if (!tr.length) return null;\n"
    "      const puan = v => {\n"
    "        const n = (v.name || \"\").toLowerCase(); let p = 0;\n"
    "        if (n.indexOf(\"siri\") >= 0) p += 6;\n"
    "        if (/premium|enhanced|neural|gelis/.test(n)) p += 5;\n"
    "        if (n.indexOf(\"yelda\") >= 0) p += 2;\n"
    "        if (n.indexOf(\"compact\") >= 0) p -= 4;\n"
    "        if (v.localService) p += 1;\n"
    "        return p;\n"
    "      };\n"
    "      tr.sort((a, b) => puan(b) - puan(a));\n"
    "      return tr[0];\n"
    "    } catch (e) { return null; }\n"
    "  }\n"
    "  try {\n"
    "    _ceoVoice = _ceoPickVoice();\n"
    "    if (window.speechSynthesis) window.speechSynthesis.onvoiceschanged = () => { _ceoVoice = _ceoPickVoice(); };\n"
    "  } catch (e) {}\n"
    "  function ceoKonus(t) {\n"
    "    try {\n"
    "      if (!sesOku || !window.speechSynthesis) return;\n"
    "      const s = String(t || \"\").trim();\n"
    "      if (!s) return;\n"
    "      window.speechSynthesis.cancel();\n"
    "      const u = new SpeechSynthesisUtterance(s.slice(0, 1000));\n"
    "      u.lang = \"tr-TR\";\n"
    "      if (!_ceoVoice) _ceoVoice = _ceoPickVoice();\n"
    "      if (_ceoVoice) u.voice = _ceoVoice;\n"
    "      u.rate = 1.0; u.pitch = 1.0;\n"
    "      window.speechSynthesis.speak(u);\n"
    "    } catch (e) {}\n"
    "  }"
)
c2 = s.count(old_konus)
assert c2 == 1, "ceoKonus anchor bulunamadi (count=%d)" % c2
s = s.replace(old_konus, new_konus, 1)

write(FP, s)
print("voicefix2: PTR-CEO-noop + ceoKonus-voice patched")
print("DONE.")
