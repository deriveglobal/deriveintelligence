#!/usr/bin/env python3
# IOS_LOGIN_ZOOM_FIX (2026-07-21) — Auth/login inputs were 13px. iOS auto-zooms (~1.23x = 16/13)
# when a focused input is <16px, and WKWebView KEEPS that zoom after login, so the saha reception
# rendered zoomed + panned ~41px left (content clipped at the left edge; "runs off the viewport").
# Root cause verified on device via Safari Web Inspector: visualViewport.scale=1.2318, offsetLeft=41,
# loginInputFS=13px. Saha's own inputs are already 16px; the login form in styles.css was missed.
# Fix: force auth inputs to 16px, iOS-ONLY via @supports(-webkit-touch-callout:none) — true on iOS
# Safari/WKWebView, false on macOS Safari + Android Chrome — so desktop and Android stay untouched
# (degismez kural 12). Also cache-bust styles.css v= so the app fetches the new CSS on reload.
# Idempotent. Run in /opt/krb-assessment.
import re

def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

MARK = "IOS_LOGIN_ZOOM_FIX"

# ---- styles.css: 16px auth inputs, iOS only ----
c = read("styles.css")
if MARK in c:
    print("styles.css: already patched, skip")
else:
    block = (
        "\n\n/* " + MARK + " — iOS zooms when a focused input is <16px and WKWebView keeps that\n"
        "   zoom after login, shifting the saha reception ~41px. Force auth inputs to 16px on iOS\n"
        "   ONLY (@supports -webkit-touch-callout: true on iOS Safari/WKWebView, false on macOS +\n"
        "   Android Chrome) so desktop and Android stay pixel-identical. */\n"
        "@supports (-webkit-touch-callout: none) {\n"
        "  #auth-screen input, #auth-screen select, #auth-screen textarea { font-size: 16px; }\n"
        "}\n"
    )
    write("styles.css", c.rstrip() + block)
    print("styles.css: appended", MARK)

# ---- index.html: cache-bust styles.css version so the reload picks up the new CSS ----
h = read("index.html")
new_v = "v=20260721-ioszoom"
h2, n = re.subn(r'styles\.css\?v=[^"\']+', "styles.css?" + new_v, h)
if n and h2 != h:
    write("index.html", h2)
    print("index.html: styles.css version ->", new_v, "(", n, "yer )")
else:
    print("index.html: version unchanged (already bumped or anchor missing)")
print("DONE.")
