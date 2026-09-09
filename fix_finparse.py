#!/usr/bin/env python3
# FINPARSE_FIX_V1 — AI çıktısı JSON ayrıştırmayı sağlamlaştır: ```json fence temizle, doğrudan parse,
# {icgoruler:[...]} sarmalı, bracket-slice fallback; boşsa ham metni logla + baglam._ham'a yaz (teşhis).
# max_tokens 1500->2200. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "FINPARSE_FIX_V1" in s:
    print("finparse-fix: already present, skip"); print("DONE."); raise SystemExit

# (1) max_tokens bump
a0 = 'model: "claude-sonnet-4-6", max_tokens: 1500, system: _FIN_SYS,'
n0 = 'model: "claude-sonnet-4-6", max_tokens: 2200, system: _FIN_SYS, // FINPARSE_FIX_V1'
assert s.count(a0) == 1, "max_tokens anchor"
s = s.replace(a0, n0, 1)

# (2) parse bloğunu sağlamlaştır
old = ('  let txt = (msg.content || []).filter(x => x.type === "text").map(x => x.text).join("").trim();\n'
       '  const i = txt.indexOf("["), j = txt.lastIndexOf("]");\n'
       '  let arr = [];\n'
       '  if (i >= 0 && j > i) { try { arr = JSON.parse(txt.slice(i, j + 1)); } catch (e) { arr = []; } }\n'
       '  if (!Array.isArray(arr)) arr = [];\n'
       '  return { icgoruler: arr, baglam: ctx };')
new = ('  let raw = (msg.content || []).filter(x => x.type === "text").map(x => x.text).join("").trim();\n'
       '  let txt = raw.replace(/```json/gi, "").replace(/```/g, "").trim();\n'
       '  const _tp = (t) => { try { return JSON.parse(t); } catch (e) { return null; } };\n'
       '  let arr = null;\n'
       '  let p = _tp(txt);\n'
       '  if (p && !Array.isArray(p) && Array.isArray(p.icgoruler)) p = p.icgoruler;\n'
       '  if (Array.isArray(p)) arr = p;\n'
       '  if (!arr) { const i = txt.indexOf("["), j = txt.lastIndexOf("]"); if (i >= 0 && j > i) { const p2 = _tp(txt.slice(i, j + 1)); if (Array.isArray(p2)) arr = p2; } }\n'
       '  if (!Array.isArray(arr)) arr = [];\n'
       '  if (!arr.length) { console.error("[fin-icgoru] parse bos - ham(0..300):", raw.slice(0, 300)); ctx._ham = raw.slice(0, 800); }\n'
       '  return { icgoruler: arr, baglam: ctx };')
assert s.count(old) == 1, "parse block anchor"
s = s.replace(old, new, 1)

write(FP, s)
print("finparse-fix: robust JSON parse + max_tokens 2200 + ham teşhis")
print("DONE.")
