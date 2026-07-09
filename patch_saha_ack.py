#!/usr/bin/env python3
# ACK_UI_V1 — show the agent's reply. Adds an assistant bubble + hooks api()
# to display any {asistan} reply, with a brief "okuyorum" state on rep writes.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK (x%d): %s" % (c, tag))

# ── 1: assistant bubble helpers (inserted before api()) ──
HELPERS = r"""function _asistanBar(mesaj, opts) {
  opts = opts || {};
  let el = document.getElementById("asistan-cevap-bar");
  if (!el) { el = document.createElement("div"); el.id = "asistan-cevap-bar"; document.body.appendChild(el); }
  el.style.cssText = "position:fixed;left:50%;bottom:82px;transform:translateX(-50%);z-index:99999;max-width:92%;background:linear-gradient(135deg,#7c3aed,#4f46e5);color:#fff;padding:12px 15px;border-radius:14px;box-shadow:0 10px 34px rgba(79,70,229,.45);font-size:13.5px;line-height:1.5;display:flex;gap:10px;align-items:flex-start";
  el.innerHTML = '<span style="font-size:18px;flex-shrink:0">🤖</span><span>' + (mesaj ? String(mesaj).replace(/</g, "&lt;") : "") + '</span>';
  if (el._t) clearTimeout(el._t);
  el._t = setTimeout(function () { if (el) { el.style.transition = "opacity .5s"; el.style.opacity = "0"; setTimeout(function () { el && el.remove(); }, 500); } }, opts.sure || 9000);
  return el;
}
function asistanOkuyor() { return _asistanBar("okuyorum…", { sure: 15000 }); }
function asistanCevap(mesaj) { if (!mesaj) { const e = document.getElementById("asistan-cevap-bar"); if (e) e.remove(); return; } _asistanBar(mesaj, { sure: 9000 }); }

async function api(path, options = {}) {"""
rep("async function api(path, options = {}) {", HELPERS, "helpers")

# ── 2: rep-write detector + okuyor state (after t0) ──
rep("  const t0 = Date.now();\n  const res = await fetch(path, {",
    "  const t0 = Date.now();\n  const _repWrite = (options.method === \"POST\" || options.method === \"PUT\") && /\\/api\\/saha\\/(notlar|ziyaretler|teklifler)/.test(path) && !/\\/foto/.test(path) && !/\"action\":\"(checkin|iptal)\"/.test(options.body || \"\");\n  if (_repWrite) asistanOkuyor();\n  const res = await fetch(path, {",
    "okuyor")

# ── 3: show reply before returning data ──
rep("    logHata(\"YAVAS_API\", { endpoint: path, duration_ms });\n  }\n  return data;",
    "    logHata(\"YAVAS_API\", { endpoint: path, duration_ms });\n  }\n  if (_repWrite) { asistanCevap(data && data.asistan); } else if (data && data.asistan) { asistanCevap(data.asistan); }\n  return data;",
    "reply-hook")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
