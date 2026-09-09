# -*- coding: utf-8 -*-
# BRAIN_CACHE_V1 — CEO Assistant sistem promptunun buyuk STATIK blogunu (SISTEM
#   HARITASI + Gorevin + DURUSTLUK) + tool tanimlarini Anthropic prompt-cache'e al.
#   Kazanc: her soruda 2-4 arac turunda ~6-8k token TEKRAR gonderiliyor; opus-4-8'de
#   pahali. Cache read %90 ucuz -> ~$30-50/ay tasarruf (krediler dolunca gecerli).
#   GUVENLIK: isaret bulunmazsa/kisa ise _brainSysCache duz string doner -> davranis AYNEN korunur.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "BRAIN_CACHE_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# 1) Yardimci fonksiyon — _handleBrainChat'ten hemen once ekle
HELPER = r'''      function _brainSysCache(sp) {  /* BRAIN_CACHE_V1 — sistem promptunun buyuk STATIK blogunu prompt-cache'le */
        try {
          if (typeof sp !== "string") return sp;
          const cut = sp.indexOf("\n\nSISTEM HARITASI");
          if (cut < 1) return sp;                       // isaret yok -> aynen string dondur (davranis degismez)
          const dinamik = sp.slice(0, cut);             // profil + tanitim + zaman/hava/gorev/hafiza (her cagride degisir)
          const statik  = sp.slice(cut);                // SISTEM HARITASI + Gorevin + DURUSTLUK (sabit ~5-7k token)
          if (statik.length < 3000) return sp;          // cok kisaysa cache esigi altinda -> ugrasma
          return [
            { type: "text", text: statik, cache_control: { type: "ephemeral" } },
            { type: "text", text: dinamik }
          ];
        } catch (e) { return sp; }
      }

'''
anchor1 = 'async function _handleBrainChat(session, request, response) {'
assert s.count(anchor1) == 1, "handleBrainChat anchor count=%d" % s.count(anchor1)
s = s.replace(anchor1, HELPER + '      ' + anchor1, 1)

# 2) messages.create'te system: string -> cache'li array (helper uzerinden)
#    "system: systemPrompt," dosyada 2 kez geciyor; DOGRU olan hemen "tools: _BRAIN_TOOLS"
#    satirindan onceki (CEO chat handler). Ona gore hedefle.
NEEDLE = 'system: systemPrompt,'
assert s.count('tools: _BRAIN_TOOLS') == 1, "_BRAIN_TOOLS usage count=%d" % s.count('tools: _BRAIN_TOOLS')
tk = s.index('tools: _BRAIN_TOOLS')
pos = s.rfind(NEEDLE, 0, tk)
assert pos != -1, "system anchor CEO handler'da bulunamadi"
assert tk - pos < 80, "system, tools'tan cok uzak (%d) — yanlis eslesme olabilir" % (tk - pos)
s = s[:pos] + 'system: _brainSysCache(systemPrompt),  /* BRAIN_CACHE_V1 */' + s[pos + len(NEEDLE):]

open(F, "w", encoding="utf-8").write(s)
print("[done] BRAIN_CACHE_V1")
