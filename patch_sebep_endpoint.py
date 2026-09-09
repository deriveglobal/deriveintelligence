#!/usr/bin/env python3
# OMURGA 51a — GET /api/bi/finans-marka-sebep?marka=X → sebep_arastir_marj anlatısı + açık kök-soru
import re, sys
F="server_container.mjs"; s=open(F,encoding="utf-8").read()
if "/api/bi/finans-marka-sebep" in s:
    print("  ⏭ zaten var"); sys.exit(0)
m=re.search(r"^([ \t]*)if \(request\.method === 'GET' && url\.pathname === '/api/bi/yukle/durum'\) \{", s, re.M)
if not m: print("  ❌ çapa yok"); sys.exit(1)
ind=m.group(1)
blok=f'''{ind}// SEBEP anlatısı (omurga_51) — sebep_arastir_marj + varsa açık kök-neden sorusu
{ind}if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-sebep') {{
{ind}  try {{
{ind}    const session = await requireModuleAccess(request, "intelligence");
{ind}    const marka = (url.searchParams.get('marka') || '').trim();
{ind}    if (!marka) {{ sendJson(response, 400, {{ error: 'marka gerekli' }}); return; }}
{ind}    const s = await query(`SELECT sebep_arastir_marj($1::uuid,$2) AS j`, [session.tenantId, marka]);
{ind}    const j = (s.rows[0] && s.rows[0].j) || {{}};
{ind}    let soru = null;
{ind}    if (j.sorulan_soru_id) {{
{ind}      const q = await query(`SELECT id, soru, secenekler FROM bi_sistem_sorusu WHERE id=$1::uuid AND tenant_id=$2::uuid AND durum='acik'`, [j.sorulan_soru_id, session.tenantId]);
{ind}      if (q.rowCount) soru = q.rows[0];
{ind}    }}
{ind}    sendJson(response, 200, Object.assign({{}}, j, {{ soru }}));
{ind}  }} catch (e) {{ console.error("[finans-marka-sebep]", e && e.message); sendJson(response, 500, {{ error: String(e && e.message) }}); }}
{ind}  return;
{ind}}}

'''
s=s[:m.start()]+blok+s[m.start():]
open(F,"w",encoding="utf-8").write(s)
print("  ✅ endpoint eklendi")
