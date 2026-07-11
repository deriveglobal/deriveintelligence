# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# BILDIRIM_LOG — a successful notification currently logs NOTHING, so "no error in
# the logs" tells us nothing about whether mail actually went out. Log every
# outcome: sent / skipped (and why) / failed (with Graph's own error text).
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

rep(
'''    alicilar = [...new Set(alicilar.filter(Boolean))];
    if (!alicilar.length) return;''',
'''    alicilar = [...new Set(alicilar.filter(Boolean))];
    if (!alicilar.length) {
      console.log(`[oneriBildirim] SKIP olay=${olay} oneri=${oneriId} — alici yok (sahip=${t0.sahip_email || "-"} aktor=${aktorUserId})`);
      return;
    }''',
    "bildirim-log-skip")

rep(
'''    for (const adr of alicilar) {
      await sendGraphMail({ to: adr, subject: `[Derive Saha] ${ust}: ${t0.baslik}`, body: html });
    }''',
'''    for (const adr of alicilar) {
      try {
        await sendGraphMail({ to: adr, subject: `[Derive Saha] ${ust}: ${t0.baslik}`, body: html });
        console.log(`[oneriBildirim] SENT olay=${olay} -> ${adr} ("${t0.baslik}")`);
      } catch (me) {
        console.error(`[oneriBildirim] FAILED olay=${olay} -> ${adr} :: ${me && me.message}`);
      }
    }''',
    "bildirim-log-sent")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
