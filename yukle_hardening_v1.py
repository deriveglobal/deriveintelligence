#!/usr/bin/env python3
# YUKLE_HARDENING_V1 — /api/bi/yukle iki sertlestirme:
#   (2) TURET_UYARI: erp_ingest turetme (marj kubu/sinyal) sonucunu tazelenen'e yaz — basari VE hata GORUNSUN
#       (eskiden turetme sessizce yutuluyordu; "ok:true" ama kup bayat = sessiz yalan).
#   (3) CACHE_BUST: yukleme sonrasi gunluk onbellekleri temizle (bi_finansal_icgoru, bi_morning_briefings,
#       agent_greeting_cache) — yoksa kokpit/mobil bu sabahki onbellekli sayilari gun boyu gosterir.
# server_container.mjs. Idempotent, marker-guardli.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "CACHE_BUST_V1" in s:
    print("yukle-hardening: already present, skip"); print("DONE."); raise SystemExit

A = '        sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc, tazelenen, saglik });\n'
assert s.count(A) == 1, "sendJson anchor (count=%d)" % s.count(A)

N = (
    '        // TURET_UYARI_V1 — turetme (marj kubu/sinyal) sonucu GORUNSUN (basari + hata)\n'
    '        if (sonuc.ok && sonuc.turetme) {\n'
    '          if (Array.isArray(sonuc.turetme.turetilen) && sonuc.turetme.turetilen.length) tazelenen.push("türetildi: " + sonuc.turetme.turetilen.join(", "));\n'
    '          if (Array.isArray(sonuc.turetme.uyari) && sonuc.turetme.uyari.length) { for (const _u of sonuc.turetme.uyari) tazelenen.push("⚠ TÜRETME: " + String(_u).slice(0, 180)); }\n'
    '        }\n'
    '        // CACHE_BUST_V1 — gunluk onbellekleri temizle (yoksa kokpit bu sabahki sayilari gosterir)\n'
    '        if (sonuc.ok) {\n'
    '          try {\n'
    '            await query("DELETE FROM bi_finansal_icgoru WHERE tenant_id::text=$1 AND gun=CURRENT_DATE", [session.tenantId]);\n'
    '            await query("DELETE FROM bi_morning_briefings WHERE tenant_id = $1 AND briefing_date = CURRENT_DATE", [session.tenantId]);\n'
    '            await query("DELETE FROM agent_greeting_cache WHERE tenant_id = $1 AND greet_date = CURRENT_DATE", [session.tenantId]);\n'
    '            tazelenen.push("önbellek temizlendi (içgörü/brief/selam)");\n'
    '          } catch (e) { console.error("[yukle] cache-bust:", e && e.message); tazelenen.push("⚠ ÖNBELLEK HATASI: " + String(e && e.message).slice(0, 120)); }\n'
    '        }\n'
    + A
)
s = s.replace(A, N, 1)
write(FP, s)
print("yukle-hardening: TURET_UYARI + CACHE_BUST eklendi")
print("markers:", s.count("CACHE_BUST_V1"), s.count("TURET_UYARI_V1"))
print("DONE.")
