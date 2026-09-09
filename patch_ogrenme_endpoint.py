#!/usr/bin/env python3
# OMURGA 48 — ÖĞRENME endpoint'leri: GET /api/bi/sistem-soru (gör) + POST .../cevap (cevapla→hatırla)
import re, sys
F = "server_container.mjs"
s = open(F, encoding="utf-8").read()

if "/api/bi/sistem-soru" in s:
    print("  ⏭ zaten var, atlandı"); sys.exit(0)

# Çapa: yukle/durum GET satırının tamamı (baştaki boşluğu koru)
m = re.search(r"^([ \t]*)if \(request\.method === 'GET' && url\.pathname === '/api/bi/yukle/durum'\) \{", s, re.M)
if not m:
    print("  ❌ çapa bulunamadı (yukle/durum)"); sys.exit(1)
ind = m.group(1)

blok = f'''{ind}// ÖĞRENME: açık sistem sorularını göster (omurga_48)
{ind}if (request.method === 'GET' && url.pathname === '/api/bi/sistem-soru') {{
{ind}  try {{
{ind}    const session = await requireModuleAccess(request, "intelligence");
{ind}    const r = await query(`SELECT id, anahtar, soru, kanit, secenekler, to_char(olusma,'YYYY-MM-DD') tarih
{ind}      FROM bi_sistem_sorusu WHERE tenant_id=$1::uuid AND durum='acik' ORDER BY olusma DESC LIMIT 20`, [session.tenantId]);
{ind}    sendJson(response, 200, {{ sorular: r.rows }});
{ind}  }} catch (e) {{ console.error("[sistem-soru]", e && e.message); sendJson(response, 500, {{ error: String(e && e.message) }}); }}
{ind}  return;
{ind}}}

{ind}// ÖĞRENME: soruyu cevapla → durum=cevaplandi (ogren_bilinen buradan hatırlar) (omurga_48)
{ind}if (request.method === 'POST' && url.pathname === '/api/bi/sistem-soru-cevap') {{
{ind}  try {{
{ind}    const session = await requireModuleAccess(request, "intelligence");
{ind}    const payload = await readJson(request);
{ind}    const id = String(payload && payload.id || '').trim();
{ind}    const cevap = String(payload && payload.cevap || '').trim();
{ind}    if (!id || !cevap) {{ sendJson(response, 400, {{ error: 'id ve cevap gerekli' }}); return; }}
{ind}    const u = await query(`UPDATE bi_sistem_sorusu SET cevap=$3, cevap_zamani=now(), durum='cevaplandi'
{ind}      WHERE id=$1::uuid AND tenant_id=$2::uuid AND durum='acik' RETURNING anahtar`, [id, session.tenantId, cevap]);
{ind}    if (!u.rowCount) {{ sendJson(response, 404, {{ error: 'soru bulunamadı ya da zaten cevaplandı' }}); return; }}
{ind}    sendJson(response, 200, {{ ok: true, anahtar: u.rows[0].anahtar,
{ind}      mesaj: 'Öğrendim. Bu açıklamayı bu desen için sakladım — aynı yerde bir daha sormayacağım.' }});
{ind}  }} catch (e) {{ console.error("[sistem-soru-cevap]", e && e.message); sendJson(response, 500, {{ error: String(e && e.message) }}); }}
{ind}  return;
{ind}}}

'''

s = s[:m.start()] + blok + s[m.start():]
open(F, "w", encoding="utf-8").write(s)
print("  ✅ 2 endpoint eklendi (GET sistem-soru + POST sistem-soru-cevap)")
