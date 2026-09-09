# -*- coding: utf-8 -*-
# MSG_TIK_DK_V1 (masaustu) — thread'de gonderdigim son mesaj icin "✓✓ Görüldü / ✓ Gönderildi".
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "MSG_TIK_DK_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# E1) imza
OLD1 = "function mesajThread(m, konusmaId, mesajlar, yayimlar, repAdi) {"
NEW1 = "function mesajThread(m, konusmaId, mesajlar, yayimlar, repAdi, karsiOkunduAt) {  /* MSG_TIK_DK_V1 */"
assert s.count(OLD1) == 1, "sig anchor=%d" % s.count(OLD1)
s = s.replace(OLD1, NEW1, 1)

# E2) tik hesap (all satirindan sonra)
OLD2 = "  const all = [...mesajlar.map(x => ({ ...x, _y: false })), ...yayimlar.map(x => ({ ...x, gonderen_id: null, _y: true }))].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));"
NEW2 = """  const all = [...mesajlar.map(x => ({ ...x, _y: false })), ...yayimlar.map(x => ({ ...x, gonderen_id: null, _y: true }))].sort((a, b) => new Date(a.created_at) - new Date(b.created_at));
  const _sonBenim = [...all].reverse().find(x => x.gonderen_id === S.me.id && !x._y);  /* MSG_TIK_DK_V1 */
  const _goruldu = _sonBenim ? (karsiOkunduAt && new Date(karsiOkunduAt) >= new Date(_sonBenim.created_at)) : false;
  const _tikHtml = _sonBenim ? `<div style="text-align:right;font-size:11px;color:${_goruldu ? "var(--mavi)" : "#94a3b8"};margin:2px 4px 4px">${_goruldu ? "✓✓ Görüldü" : "✓ Gönderildi"}</div>` : "";"""
assert s.count(OLD2) == 1, "all anchor=%d" % s.count(OLD2)
s = s.replace(OLD2, NEW2, 1)

# E3) render'a tik ekle
OLD3 = '    <div class="dk-chat-msgs" id="msg-thread">${all.length ? all.map(bubble).join("") : `<div class="dk-empty-s">Henüz mesaj yok.</div>`}</div>'
NEW3 = '    <div class="dk-chat-msgs" id="msg-thread">${all.length ? all.map(bubble).join("") : `<div class="dk-empty-s">Henüz mesaj yok.</div>`}${_tikHtml}</div>'
assert s.count(OLD3) == 1, "render anchor=%d" % s.count(OLD3)
s = s.replace(OLD3, NEW3, 1)

# E4) rep cagri
OLD4 = '  if (S.role === "rep") { mesajThread(m, data.konusma_id, data.mesajlar || [], data.yayimlar || [], null); return; }'
NEW4 = '  if (S.role === "rep") { mesajThread(m, data.konusma_id, data.mesajlar || [], data.yayimlar || [], null, data.karsi_okundu_at); return; }  /* MSG_TIK_DK_V1 */'
assert s.count(OLD4) == 1, "rep-call anchor=%d" % s.count(OLD4)
s = s.replace(OLD4, NEW4, 1)

# E5) yonetici cagri
OLD5 = "    try { const { konusma_id, mesajlar } = await api(`/api/saha/konusmalar/${el.dataset.rep}`); mesajThread(m, konusma_id, mesajlar || [], [], el.dataset.ad); }"
NEW5 = "    try { const { konusma_id, mesajlar, karsi_okundu_at } = await api(`/api/saha/konusmalar/${el.dataset.rep}`); mesajThread(m, konusma_id, mesajlar || [], [], el.dataset.ad, karsi_okundu_at); }  /* MSG_TIK_DK_V1 */"
assert s.count(OLD5) == 1, "mgr-call anchor=%d" % s.count(OLD5)
s = s.replace(OLD5, NEW5, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] MSG_TIK_DK_V1 (masaustu)")
