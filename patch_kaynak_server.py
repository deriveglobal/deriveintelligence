# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# KAYNAK_SERVER — quote source (kaynak) on POST /api/saha/teklifler (auto ZIYARET
# when ziyaret_id, else from payload) + assistant teklif_olustur accepts/infers it.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

# POST teklifler — add kaynak column/value/param
rep("kampanya_indirim_deger, musteri_ek_iskonto_pct, durum)",
    "kampanya_indirim_deger, musteri_ek_iskonto_pct, kaynak, durum)", "post-cols")
rep("$19,$20,$21,$22,$23,$24,$25,$26,'TASLAK')",
    "$19,$20,$21,$22,$23,$24,$25,$26,$27,'TASLAK')", "post-values")
rep("          ilk.ekIsk > 0 ? ilk.ekIsk : null]);",
    "          ilk.ekIsk > 0 ? ilk.ekIsk : null,\n          (p.ziyaret_id ? 'ZIYARET' : (['TELEFON','WHATSAPP','EMAIL','DIGER'].includes(String(p.kaynak||'').toUpperCase()) ? String(p.kaynak).toUpperCase() : 'DIGER'))]);",
    "post-params")

# assistant teklif_olustur — tool schema
rep("rakip_marka:{type:'string'}, rakip_fiyat:{type:'number'}, notlar:{type:'string'} }, required:['kalemler'] } },",
    "rakip_marka:{type:'string'}, rakip_fiyat:{type:'number'}, kaynak:{type:'string', enum:['TELEFON','WHATSAPP','EMAIL','ZIYARET'], description:'Musteri nasil ulasti: aradi=TELEFON, whatsapp=WHATSAPP, mail/eposta=EMAIL. Belirtmezse TELEFON.'}, notlar:{type:'string'} }, required:['kalemler'] } },",
    "asst-schema")

# assistant teklif_olustur — insert cols/values
rep("notlar,durum,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$7,$8,$9,$10,$11,'ONAY_BEKLIYOR',$3)",
    "notlar,kaynak,durum,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$7,$8,$9,$10,$11,$12,'ONAY_BEKLIYOR',$3)",
    "asst-insert")

# assistant teklif_olustur — params
rep("inp.rakip_fiyat!=null?Number(inp.rakip_fiyat):null, inp.notlar||null]);",
    "inp.rakip_fiyat!=null?Number(inp.rakip_fiyat):null, inp.notlar||null, (['TELEFON','WHATSAPP','EMAIL','ZIYARET'].includes(String(inp.kaynak||'').toUpperCase()) ? String(inp.kaynak).toUpperCase() : 'TELEFON')]);",
    "asst-params")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
