#!/usr/bin/env python3
# CEO_GECMIS_YUKLE — mobil CEO Assistant sekme değişince sohbeti kaybediyordu (her girişte boş
# açılıyordu). Geçmiş zaten brain_conversations'ta (tenant-paylaşımlı) kayıtlı; sadece yüklenmiyordu.
# (1) server: GET /api/brain/history ekle. (2) saha.js: girişte geçmişi yükle, boşsa selamla.
# Böylece sekme değişince sohbet kaybolmaz ve aynı soruyu tekrar sorup token harcamana gerek kalmaz.
# Idempotent. Run in /opt/krb-assessment.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

# ---------- (1) server_container.mjs: GET /api/brain/history ----------
SP = "server_container.mjs"
s = read(SP)
anchor_s = "          if (url.pathname === '/api/brain/chat' && request.method === 'POST') {"
route_s = (
    "          if (url.pathname === '/api/brain/history' && request.method === 'GET') {\n"
    "            try {\n"
    "              const _bh = await query('SELECT role, content FROM brain_conversations WHERE tenant_id=$1 ORDER BY created_at DESC LIMIT 40', [session.tenantId]);\n"
    "              sendJson(response, 200, { mesajlar: _bh.rows.reverse() });\n"
    "            } catch (e) { sendJson(response, 200, { mesajlar: [] }); }\n"
    "            return;\n"
    "          }\n"
)
if "'/api/brain/history'" in s:
    print("server: /api/brain/history already present, skip")
elif anchor_s in s:
    s = s.replace(anchor_s, route_s + anchor_s, 1)
    write(SP, s)
    print("server: /api/brain/history added")
else:
    print("WARN: server anchor not found")

# ---------- (2) shells/saha.js: load history on CEO entry ----------
FP = "shells/saha.js"
t = read(FP)
anchor_c = "  // günlük selamlama (önbellekli, ucuz) — açılışta\n  gonder(null, true);"
new_c = (
    "  // CEO_GECMIS_YUKLE — gerçek bir asistan gibi davran: günün sohbetini ekranda tut (sekme\n"
    "  // değişince kaybolmasın, aynı soruyu tekrar sordurma) ve sabah SADECE BİR KEZ selamla.\n"
    "  (async () => {\n"
    "    try {\n"
    "      const _h = await fetch(\"/api/brain/history\", { headers: S.headers() });\n"
    "      const { mesajlar = [] } = _h.ok ? await _h.json() : {};\n"
    "      if (mesajlar.length) { mesajlar.forEach(mm => bubble(mm.role === \"user\" ? \"user\" : \"assistant\", mm.content)); return; }\n"
    "    } catch (e) {}\n"
    "    // geçmiş boş: bugün daha önce selamlanmadıysa bir kez selamla (insan gibi, her girişte değil)\n"
    "    try {\n"
    "      const _g = new Date().toLocaleDateString(\"en-CA\", { timeZone: \"Europe/Istanbul\" });\n"
    "      if (localStorage.getItem(\"ceo_selam_gun\") === _g) return;\n"
    "      localStorage.setItem(\"ceo_selam_gun\", _g);\n"
    "    } catch (e) {}\n"
    "    gonder(null, true);\n"
    "  })();"
)
if "CEO_GECMIS_YUKLE" in t:
    print("saha.js: already patched, skip")
elif anchor_c in t:
    t = t.replace(anchor_c, new_c, 1)
    write(FP, t)
    print("saha.js: CEO history-load added")
else:
    print("WARN: saha.js anchor not found")
print("DONE.")
