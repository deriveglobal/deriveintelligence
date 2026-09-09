#!/usr/bin/env python3
# PUSH_HOOKS_V2 — teklif onay/red + mesaj (coklu/yayim) otomatik push tetikleyicileri.
# Requires PUSH_ENGINE_V1 (pushToUsers). Idempotent. Run in /opt/krb-assessment.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)

if "PUSH_HOOKS_V2" in s:
    print("PUSH_HOOKS_V2: already present, skip")
    print("DONE.")
    raise SystemExit

n = 0

# 1) teklif SELECT: add rep_id so we can notify the owner
a1 = 'SELECT durum, marka, ebat, notlar FROM saha_teklif'
b1 = 'SELECT durum, marka, ebat, notlar, rep_id FROM saha_teklif'
if a1 in s:
    s = s.replace(a1, b1, 1); n += 1

# 2) teklif ONAYLANDI -> notify rep
a2 = "            return { success: true, message: 'Teklif ONAYLANDI: ' + urunAd };"
b2 = ('            try { if (cur.rows[0].rep_id) pushToUsers(tenantId, [cur.rows[0].rep_id], '
      '"✅ Teklifiniz onaylandı", urunAd, { room: "saha", type: "teklif_onay", id: input.id }); } '
      'catch (e) {} /* PUSH_HOOKS_V2 */\n') + a2
if a2 in s:
    s = s.replace(a2, b2, 1); n += 1

# 3) teklif REDDEDILDI -> notify rep
a3 = "            return { success: true, message: 'Teklif reddedildi (taslağa döndürüldü): ' + urunAd + ' — ' + neden };"
b3 = ('            try { if (cur.rows[0].rep_id) pushToUsers(tenantId, [cur.rows[0].rep_id], '
      '"↩️ Teklifiniz taslağa döndü", urunAd + " — " + neden, { room: "saha", type: "teklif_red", id: input.id }); } '
      'catch (e) {}\n') + a3
if a3 in s:
    s = s.replace(a3, b3, 1); n += 1

# 4) mesaj coklu -> notify targeted reps
a4 = '      sendJson(response, 200, { ok: true, sayi: rep_ids.length });'
b4 = ('      try { pushToUsers(session.tenantId, rep_ids, "\U0001f4ac Yeni mesaj", '
      'String(icerik).slice(0,120), { room: "saha", type: "mesaj" }); } catch (e) {}\n') + a4
if a4 in s:
    s = s.replace(a4, b4, 1); n += 1

# 5) mesaj yayim -> notify all reps
a5 = ('      const reps = await pool.query(\n'
      '        `SELECT DISTINCT u.id FROM users u\n'
      "          JOIN user_modules um ON um.user_id=u.id AND um.module='saha'\n"
      "          WHERE u.status != 'disabled'`,\n"
      '        [session.tenantId]\n'
      '      );')
b5 = a5 + ('\n      try { pushToUsers(session.tenantId, reps.rows.map(function (x) { return x.id; }), '
           '"\U0001f4e3 Yeni yayım", String(icerik).slice(0,120), { room: "saha", type: "yayim" }); } catch (e) {}')
if a5 in s:
    s = s.replace(a5, b5, 1); n += 1

write(FP, s)
print("PUSH_HOOKS_V2: applied", n, "of 5 hooks")
print("DONE.")
