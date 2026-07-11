# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ONERI_GORULDU — "seen by" indicator. The data already exists (saha_oneri_okuma
# records who opened a thread and when); it was simply never shown.
#   thread : "✓✓ Görüldü — Eftal Yıldız (14:32)"  vs  "✓ Gönderildi — henüz görülmedi"
#   list   : staff sees "✓ görülmedi" on tickets where the rep has not yet read
#            the latest message (i.e. your answer is still unseen).
import sys
which = sys.argv[1]
fn = sys.argv[2]
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

if which == "server":
    # 1) thread detail: return who has read it (fetch BEFORE marking self read)
    rep(
'''      await pool.query(
        `INSERT INTO saha_oneri_okuma (tenant_id, oneri_id, user_id, okundu_at) VALUES ($1,$2,$3,now())
         ON CONFLICT (oneri_id, user_id) DO UPDATE SET okundu_at = now()`,
        [session.tenantId, m[1], session.userId]);
      sendJson(response, 200, { oneri: tk, mesajlar: msgs.rows, staff, ben: session.userId });
      return;
    }''',
'''      const oku = await pool.query(
        `SELECT r.user_id, COALESCE(u.full_name, u.email) AS ad, r.okundu_at
           FROM saha_oneri_okuma r JOIN users u ON u.id = r.user_id
          WHERE r.oneri_id = $1 AND r.tenant_id = $2
          ORDER BY r.okundu_at DESC`, [m[1], session.tenantId]);
      await pool.query(
        `INSERT INTO saha_oneri_okuma (tenant_id, oneri_id, user_id, okundu_at) VALUES ($1,$2,$3,now())
         ON CONFLICT (oneri_id, user_id) DO UPDATE SET okundu_at = now()`,
        [session.tenantId, m[1], session.userId]);
      sendJson(response, 200, { oneri: tk, mesajlar: msgs.rows, okumalar: oku.rows, staff, ben: session.userId });
      return;
    }''',
        "gorundu-thread-server")

    # 2) list: has the ticket OWNER seen the latest message?
    rep(
'''                    WHERE r.oneri_id = o.id AND r.user_id = $2), 'epoch'::timestamptz)) AS okunmamis
          FROM saha_oneri o''',
'''                    WHERE r.oneri_id = o.id AND r.user_id = $2), 'epoch'::timestamptz)) AS okunmamis,
               (COALESCE((SELECT r2.okundu_at FROM saha_oneri_okuma r2
                           WHERE r2.oneri_id = o.id AND r2.user_id = o.user_id),
                         'epoch'::timestamptz) >= o.son_mesaj_at) AS sahip_gordu
          FROM saha_oneri o''',
        "gorundu-list-server")

elif which == "front":
    # 3) thread modal: compute + render the seen line
    rep(
'''  const { oneri: o, mesajlar = [], staff, ben } = d;''',
'''  const { oneri: o, mesajlar = [], okumalar = [], staff, ben } = d;

  // "Seen by" — anyone other than me who opened the thread AFTER the last message.
  const sonMsg = mesajlar.length ? mesajlar[mesajlar.length - 1] : null;
  const gorenler = sonMsg
    ? okumalar.filter(r => r.user_id !== ben && new Date(r.okundu_at) >= new Date(sonMsg.ts))
    : [];
  const gorulduHtml = !sonMsg ? "" : (gorenler.length
    ? `<div style="text-align:right;font-size:11px;color:#0284c7;margin-top:6px">✓✓ Görüldü — ${gorenler.map(r => `${esc(r.ad)} (${new Date(r.okundu_at).toLocaleString("tr-TR", { day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" })})`).join(", ")}</div>`
    : `<div style="text-align:right;font-size:11px;color:#94a3b8;margin-top:6px">✓ Gönderildi — henüz görülmedi</div>`);''',
        "gorundu-thread-calc")

    rep(
'''    <div id="ot-thread" style="max-height:300px;overflow-y:auto;padding:8px;background:#fff;border:1px solid #e2e8f0;border-radius:10px">
      ${mesajlar.map(satir).join("")}
    </div>''',
'''    <div id="ot-thread" style="max-height:300px;overflow-y:auto;padding:8px;background:#fff;border:1px solid #e2e8f0;border-radius:10px">
      ${mesajlar.map(satir).join("")}
    </div>
    ${gorulduHtml}''',
        "gorundu-thread-render")

    # 4) list card: flag tickets whose owner has NOT seen the latest message
    rep(
'''        <div style="font-size:11px;color:#64748b;margin-top:3px">
          ${esc(ONERI_KAT[o.kategori] || o.kategori)}${staff ? " · " + esc(o.kullanici || "-") : ""}
          · ${o.mesaj_sayisi || 1} mesaj
          · ${new Date(o.son_mesaj_at || o.ts).toLocaleDateString("tr-TR")}
        </div>''',
'''        <div style="font-size:11px;color:#64748b;margin-top:3px">
          ${esc(ONERI_KAT[o.kategori] || o.kategori)}${staff ? " · " + esc(o.kullanici || "-") : ""}
          · ${o.mesaj_sayisi || 1} mesaj
          · ${new Date(o.son_mesaj_at || o.ts).toLocaleDateString("tr-TR")}
          ${staff && o.sahip_gordu === false ? `· <span style="color:#d97706">✓ görülmedi</span>` : ""}
          ${staff && o.sahip_gordu === true && (o.mesaj_sayisi || 1) > 1 ? `· <span style="color:#0284c7">✓✓ görüldü</span>` : ""}
        </div>''',
        "gorundu-list-render")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
