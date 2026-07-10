# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# FIYAT_SORGU — rep Asistan price lookup was broken + incomplete:
#   (1) exact `ebat=$1` match on scraped data (stored as full title) -> "veri yok"
#       even though there is huge e-ticaret data. Fix: normalized substring match.
#   (2) tool only knew competitor sources. Add KRB's own price list
#       (bi_fiyat_listesi_kalemler, active upload) -> liste/bayi/net.
# Result: rakip_fiyat now returns all THREE monitored sources, ebat-normalized.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# R1 — normalize ebat/marka into LIKE keys (replace eRows builder)
rep("const eRows = inp.marka ? [ebat, inp.marka] : [ebat];",
    "const _k=(inp.ebat||'').toLowerCase().replace(/[^0-9a-z]/g,''); "
    "if(_k.length<3) return { hata:'ebat cok kisa, tam ebat ver (orn 205/55R16)' }; "
    "const _like='%'+_k+'%'; "
    "const _mk = inp.marka ? '%'+String(inp.marka).toLowerCase().replace(/[^0-9a-z]/g,'')+'%' : null; "
    "const eRows = _mk ? [_like, _mk] : [_like];",
    "R1-normalize")

# R2 — e-ticaret query normalized + add KRB price-list query right after
rep('const et = await pool.query("SELECT MIN(fiyat) AS min, MAX(fiyat) AS max, COUNT(*) AS n FROM bi_rakip_fiyat_son WHERE ebat=$1" + (inp.marka?" AND lower(marka)=lower($2)":""), eRows);',
    'const et = await pool.query("SELECT MIN(fiyat)::numeric AS min, MAX(fiyat)::numeric AS max, ROUND(AVG(fiyat)::numeric,0) AS ort, COUNT(*)::int AS n FROM bi_rakip_fiyat_son WHERE fiyat>0 AND regexp_replace(lower(coalesce(ebat,\'\')),\'[^0-9a-z]\',\'\',\'g\') LIKE $1" + (_mk?" AND regexp_replace(lower(coalesce(marka,\'\')),\'[^0-9a-z]\',\'\',\'g\') LIKE $2":""), eRows);\n'
    '          const _pl = await pool.query("SELECT COUNT(*)::int AS n, MIN(k.liste_fiyati)::numeric AS liste_min, MAX(k.liste_fiyati)::numeric AS liste_max, MIN(k.bayi_fiyati)::numeric AS bayi_min, MAX(k.bayi_fiyati)::numeric AS bayi_max, MIN(k.net_fiyati)::numeric AS net_min, MAX(k.net_fiyati)::numeric AS net_max, MAX(k.para_birimi) AS para FROM bi_fiyat_listesi_kalemler k JOIN bi_fiyat_listesi_uploads u ON u.id=k.upload_id WHERE u.aktif=true AND k.tenant_id=$1::uuid AND regexp_replace(lower(coalesce(k.ebat,\'\')),\'[^0-9a-z]\',\'\',\'g\') LIKE $2", [session.tenantId, _like]);',
    "R2-eticaret+pricelist")

# R3 — saha params use normalized keys
rep("const sRows = inp.marka ? [session.tenantId, ebat, inp.marka] : [session.tenantId, ebat];",
    "const sRows = _mk ? [session.tenantId, _like, _mk] : [session.tenantId, _like];",
    "R3-saha-params")

# R4 — saha query normalized
rep('const sa = await pool.query("SELECT MIN(rakip_fiyat) AS min, MAX(rakip_fiyat) AS max, COUNT(*) AS n FROM saha_rakip_teklif WHERE tenant_id=$1 AND ebat=$2" + (inp.marka?" AND lower(rakip_marka)=lower($3)":""), sRows);',
    'const sa = await pool.query("SELECT MIN(rakip_fiyat)::numeric AS min, MAX(rakip_fiyat)::numeric AS max, ROUND(AVG(rakip_fiyat)::numeric,0) AS ort, COUNT(*)::int AS n FROM saha_rakip_teklif WHERE tenant_id=$1 AND rakip_fiyat>0 AND regexp_replace(lower(coalesce(ebat,\'\')),\'[^0-9a-z]\',\'\',\'g\') LIKE $2" + (_mk?" AND regexp_replace(lower(coalesce(rakip_marka,\'\')),\'[^0-9a-z]\',\'\',\'g\') LIKE $3":""), sRows);',
    "R4-saha-query")

# R5 — return all three labeled sources
rep("return { eticaret_piyasa: et.rows[0], saha_gercek: sa.rows[0] };",
    "return { ebat: (inp.ebat||'').trim(), internet_eticaret: et.rows[0], kendi_fiyat_listemiz: _pl.rows[0], saha_manuel_piyasa: sa.rows[0] };",
    "R5-return")

# R6 — broaden tool description (model reads this)
rep("description: 'Bir ebat/marka için e-ticaret ve saha rakip fiyat aralığı.',",
    "description: 'Bir ebat (ops. marka) icin TUM fiyat kaynaklari: internet/e-ticaret piyasa, KRB kendi guncel fiyat listemiz (liste/bayi/net) ve saha manuel piyasa fiyatlari. Fiyatla ilgili HER soruda bunu kullan; ebati 205/55R16 gibi ver.',",
    "R6-tool-desc")

# R7 — system-prompt bullet
rep('"- rakip_fiyat: bir ebat/marka için piyasa (e-ticaret) ve saha rakip fiyat aralığını getir.\\n" +',
    '"- rakip_fiyat: bir ebat (ops. marka) için TÜM fiyat kaynakları — internet/e-ticaret piyasa, KRB kendi fiyat listemiz (liste/bayi/net) ve saha manuel piyasa. Fiyatla ilgili HER soruda bunu çağır; hangi kaynakta veri varsa net rakamlarla söyle, boş kaynağı zorlama.\\n" +',
    "R7-sys-bullet")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
