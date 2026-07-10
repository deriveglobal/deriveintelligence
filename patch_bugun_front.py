# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# BUGUN_V1 (front) — Bugün home: use real unread count for the badge; show
# reader count (👁 X/Y gördü), tip tag, and "Yeni" flag on each duyuru card.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# 1) destructure new fields
rep('const { bugun, ziyaretler, duyurular_okunmamis, mesaj_okunmamis, teklifler, hatirlatmalar } = await api("/api/saha/bugun");',
    'const { bugun, ziyaretler, duyurular_okunmamis, duyurular_yeni_sayisi = 0, rep_sayisi = 0, mesaj_okunmamis, teklifler, hatirlatmalar } = await api("/api/saha/bugun");',
    "destructure")

# 2) badge uses real unread count
rep('if (duyurular_okunmamis.length) tabBadge("duyurular", duyurular_okunmamis.length);',
    'if (duyurular_yeni_sayisi) tabBadge("duyurular", duyurular_yeni_sayisi);',
    "badge")

# 3) richer duyuru cards (reader count + tip + Yeni)
OLD_HTML = '''    const duyuruHtml = duyurular_okunmamis.length === 0
      ? empty("Okunmamış duyuru yok ✓")
      : duyurular_okunmamis.map(d => `
          <div class="kart" data-did="${d.id}" style="padding:10px 12px;margin-bottom:6px;cursor:pointer;border-left:3px solid ${onemRenk[d.onem] || "#0284c7"}">
            <div style="font-size:10px;font-weight:700;color:${onemRenk[d.onem]};margin-bottom:3px">${onemEtiket[d.onem] || "📢"}</div>
            <div style="font-size:13px;font-weight:600;color:#0f172a">${esc(d.baslik)}</div>
            <div style="font-size:11px;color:#64748b;margin-top:2px">${esc(d.yazan_adi)} · ${new Date(d.created_at).toLocaleDateString("tr-TR")}</div>
          </div>`).join("");'''
NEW_HTML = '''    const duyuruHtml = duyurular_okunmamis.length === 0
      ? empty(S.role === "rep" ? "Okunmamış duyuru yok ✓" : "Henüz duyuru yok")
      : duyurular_okunmamis.map(d => `
          <div class="kart" data-did="${d.id}" style="padding:10px 12px;margin-bottom:6px;cursor:pointer;border-left:3px solid ${onemRenk[d.onem] || "#0284c7"}">
            <div style="font-size:10px;font-weight:700;color:${d.tip === "PIYASA" ? "#0891b2" : onemRenk[d.onem]};margin-bottom:3px">${d.tip === "PIYASA" ? "📊 PİYASA" : (onemEtiket[d.onem] || "📢")}</div>
            <div style="font-size:13px;font-weight:600;color:#0f172a">${esc(d.baslik)}</div>
            <div style="font-size:11px;color:#64748b;margin-top:2px">${esc(d.yazan_adi)} · ${new Date(d.created_at).toLocaleDateString("tr-TR")}</div>
            <div style="font-size:11px;color:#64748b;margin-top:3px">👁 ${d.okuyan_sayisi}${rep_sayisi ? "/" + rep_sayisi : ""} gördü${!d.okundu ? ` · <span style="color:#0284c7;font-weight:600">● Yeni</span>` : ""}</div>
          </div>`).join("");'''
rep(OLD_HTML, NEW_HTML, "duyuru-cards")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
