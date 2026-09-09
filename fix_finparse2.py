#!/usr/bin/env python3
# FINPARSE_FIX_V2 — parse'ı truncation'a dayanıklı yap: (a) max_tokens 2200->4000,
# (b) salvage: dizi bozuksa her tam {…} nesnesini tek tek parse et (kesik son nesne düşer),
# (c) string-içi literal newline'ları normalize et. Idempotent. FINPARSE_FIX_V1 bloğunu değiştirir.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "FINPARSE_FIX_V2" in s:
    print("finparse2: already present, skip"); print("DONE."); raise SystemExit

# (1) max_tokens 2200 -> 4000
a0 = 'model: "claude-sonnet-4-6", max_tokens: 2200, system: _FIN_SYS, // FINPARSE_FIX_V1'
n0 = 'model: "claude-sonnet-4-6", max_tokens: 4000, system: _FIN_SYS, // FINPARSE_FIX_V2'
assert s.count(a0) == 1, "max_tokens anchor"
s = s.replace(a0, n0, 1)

# (2) FINPARSE_FIX_V1 parse bloğunu V2 (salvage) ile değiştir
old = ('  let raw = (msg.content || []).filter(x => x.type === "text").map(x => x.text).join("").trim();\n'
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
new = ('  let raw = (msg.content || []).filter(x => x.type === "text").map(x => x.text).join("").trim(); // FINPARSE_FIX_V2\n'
       '  let txt = raw.replace(/```json/gi, "").replace(/```/g, "").trim();\n'
       '  const _tp = (t) => { try { return JSON.parse(t); } catch (e) { return null; } };\n'
       '  const _norm = (t) => t.replace(/[\\r\\n\\t]+/g, " ");\n'
       '  let arr = null;\n'
       '  for (const cand of [txt, _norm(txt)]) {\n'
       '    let p = _tp(cand);\n'
       '    if (p && !Array.isArray(p) && Array.isArray(p.icgoruler)) p = p.icgoruler;\n'
       '    if (Array.isArray(p)) { arr = p; break; }\n'
       '    const i = cand.indexOf("["), j = cand.lastIndexOf("]");\n'
       '    if (i >= 0 && j > i) { const p2 = _tp(cand.slice(i, j + 1)); if (Array.isArray(p2)) { arr = p2; break; } }\n'
       '  }\n'
       '  if (!arr || !arr.length) {\n'
       '    const objs = _norm(txt).match(/\\{[^{}]*\\}/g) || [];\n'
       '    const sal = [];\n'
       '    for (const o of objs) { const x = _tp(o); if (x && (x.baslik || x.ozet)) sal.push(x); }\n'
       '    if (sal.length) arr = sal;\n'
       '  }\n'
       '  if (!Array.isArray(arr)) arr = [];\n'
       '  if (!arr.length) { console.error("[fin-icgoru] parse bos - ham(0..300):", raw.slice(0, 300)); ctx._ham = raw.slice(0, 800); }\n'
       '  return { icgoruler: arr, baglam: ctx };')
assert s.count(old) == 1, "V1 parse block anchor"
s = s.replace(old, new, 1)

write(FP, s)
print("finparse2: salvage parser + max_tokens 4000")
print("DONE.")
