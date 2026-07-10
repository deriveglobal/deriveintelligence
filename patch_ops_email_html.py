# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# OPS_EMAIL_HTML — sendGraphMail renders body as HTML, so plain-text \n collapsed
# into a wall of text. Replace the text body with a clean HTML table (severity
# badge + title + detail + meta per incident).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = (
'      const lines = inc.rows.map(r => "- [" + r.category + "] " + r.title + " - " + (r.detail || "") + " (ilk gorulme: " + new Date(r.first_seen).toLocaleString("tr-TR") + ", tekrar: " + r.occurrences + ")").join("\\n");\n'
'      const subject = "Ops uyarisi: " + inc.rows.length + " kritik durum";\n'
'      const body = "Merhaba,\\n\\nDerive Ops izleme katmani asagidaki KRITIK durumlari tespit etti:\\n\\n" + lines + "\\n\\nBu bir teshis bildirimidir; otomatik mudahale YAPILMADI. Paneli inceleyebilirsin.\\n\\n-- Ops Monitor";'
)

NEW = (
'      const _esc = t => String(t == null ? "" : t).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");\n'
'      const rowsHtml = inc.rows.map(r => \'<tr><td style="padding:9px 10px;border-bottom:1px solid #eee;vertical-align:top;white-space:nowrap"><span style="display:inline-block;background:#dc2626;color:#fff;font-size:11px;font-weight:700;border-radius:4px;padding:2px 7px">KRITIK</span></td><td style="padding:9px 10px;border-bottom:1px solid #eee">\' + \'<div style="font-weight:600;color:#111">\' + _esc(r.title) + \'</div><div style="color:#555;font-size:13px;margin-top:2px">\' + _esc(r.detail || "") + \'</div><div style="color:#999;font-size:12px;margin-top:3px">\' + _esc(r.category) + \' &middot; ilk gorulme \' + new Date(r.first_seen).toLocaleString("tr-TR") + \' &middot; tekrar \' + r.occurrences + \'</div></td></tr>\').join("");\n'
'      const subject = "Ops uyarisi: " + inc.rows.length + " kritik durum";\n'
'      const body = \'<div style="font-family:-apple-system,Segoe UI,Roboto,Arial,sans-serif;max-width:640px;margin:0 auto;color:#222">\' + \'<h2 style="margin:0 0 4px;font-size:18px">Ops uyarisi</h2><p style="margin:0 0 14px;color:#555">Derive Ops izleme katmani <b>\' + inc.rows.length + \'</b> kritik durum tespit etti.</p><table style="border-collapse:collapse;width:100%;border:1px solid #eee;border-radius:8px;overflow:hidden">\' + rowsHtml + \'</table><p style="margin:16px 0 0;color:#888;font-size:12px">Bu bir teshis bildirimidir &mdash; otomatik mudahale <b>yapilmadi</b>. Paneli inceleyebilirsin.</p><p style="margin:2px 0 0;color:#aaa;font-size:12px">&mdash; Ops Monitor</p></div>\';'
)

c = s.count(OLD)
assert c == 1, "ABORT: notify body anchor found %d" % c
s = s.replace(OLD, NEW)
print("OK: ops-email-html")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
