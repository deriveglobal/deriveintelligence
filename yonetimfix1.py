#!/usr/bin/env python3
# HIDE_YONETIM_MOBILE (2026-07-21) — The floating #tenant-admin-toggle ("👤 Yönetim") admin button
# overlaps the mobile saha bottom nav (Daha tab + badge) and shouldn't appear on mobile (desktop-only,
# per Fatih). Hide it whenever the mobile saha nav is present — .saha-nav exists ONLY in the mobile
# saha surface, so desktop/BI is untouched (değişmez kural 12). If :has() is unsupported on an old
# desktop browser the rule simply doesn't apply → button stays as today (safe degradation).
# Verified live on device via Safari Web Inspector (display -> none). Idempotent. Run in /opt/krb-assessment.
import re

def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

MARK = "HIDE_YONETIM_MOBILE"

c = read("styles.css")
if MARK in c:
    print("styles.css: already patched, skip")
else:
    block = (
        "\n\n/* " + MARK + " — floating #tenant-admin-toggle (Yonetim) overlaps the mobile saha nav\n"
        "   and is desktop-only; hide it when the mobile saha nav is present. .saha-nav exists only in\n"
        "   the mobile saha surface, so desktop/BI is untouched (kural 12). */\n"
        "body:has(.saha-nav) #tenant-admin-toggle { display: none !important; }\n"
    )
    write("styles.css", c.rstrip() + block)
    print("styles.css: appended", MARK)

# cache-bust styles.css version so the reload picks up the new CSS
h = read("index.html")
new_v = "v=20260721-yonetim"
h2, n = re.subn(r'styles\.css\?v=[^"\']+', "styles.css?" + new_v, h)
if n and h2 != h:
    write("index.html", h2)
    print("index.html: styles.css version ->", new_v, "(", n, "yer )")
else:
    print("index.html: version unchanged (already bumped or anchor missing)")
print("DONE.")
