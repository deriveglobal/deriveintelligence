#!/usr/bin/env python3
# OMURGA 43 — /api/bi/finans-marka-drag: seni aşağı çeken SKU'lar (atomdan) + öneri + piyasa.
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
s=rd(SRV)
if '/api/bi/finans-marka-drag' in s:
    print('  ⏭ zaten yamalı'); sys.exit(0)

ENDPOINT = r'''    if (request.method === 'GET' && url.pathname === '/api/bi/finans-marka-drag') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const marka = (url.searchParams.get('marka') || '').trim();
        const ay = [3,6,12].includes(parseInt(url.searchParams.get('ay'))) ? parseInt(url.searchParams.get('ay')) : 6;
        if (!marka) { sendJson(response, 400, { error: 'marka gerekli' }); return; }
        const r = await query(`
          WITH b AS (SELECT sum(brut_kar)::numeric/NULLIF(sum(ciro),0) mm FROM bi_marj_atom
                       WHERE tenant_id=$1::uuid AND upper(marka)=upper($2) AND ay>=date_trunc('month',CURRENT_DATE)-make_interval(months=>$3::int)),
          sku AS (SELECT max(ebat) ebat, sum(ciro) ciro, sum(adet) adet,
                    round(sum(ciro)/NULLIF(sum(adet),0)) fiyat, round(sum(ciro-brut_kar)/NULLIF(sum(adet),0)) maliyet,
                    round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) marj_pct, round(sum(brut_kar)) brut
                  FROM bi_marj_atom WHERE tenant_id=$1::uuid AND upper(marka)=upper($2) AND ay>=date_trunc('month',CURRENT_DATE)-make_interval(months=>$3::int)
                  GROUP BY kalem_kodu HAVING sum(ciro)>500000)
          SELECT ebat, adet::bigint, fiyat, maliyet, marj_pct,
                 round(((SELECT mm FROM b)*ciro - brut)) ek_kar,
                 round(maliyet/0.85) hedef_fiyat_15,
                 round(100*(maliyet/0.85 - fiyat)/NULLIF(fiyat,0)) gereken_zam,
                 (SELECT round(avg(fiyat)) FROM bi_rakip_fiyat_gecmis rr
                   WHERE rr.tenant_id=$1::text AND rr.marka ILIKE '%'||upper($2)||'%'
                     AND rr.genislik=NULLIF(split_part(sku.ebat,'/',1),'')::int
                     AND rr.profil=NULLIF(split_part(split_part(sku.ebat,'/',2),'R',1),'')::int
                     AND rr.cap=NULLIF(split_part(sku.ebat,'R',2),'')::numeric
                     AND rr.gecerli_tarih>=CURRENT_DATE-interval '90 day') piyasa
            FROM sku ORDER BY ((SELECT mm FROM b)*ciro - brut) DESC LIMIT 10`, [T, marka, ay]);
        const marka_marj = await query(`SELECT round(100*sum(brut_kar)/NULLIF(sum(ciro),0),1) m, round(sum(ciro)/1e6,1) c FROM bi_marj_atom WHERE tenant_id=$1::uuid AND upper(marka)=upper($2) AND ay>=date_trunc('month',CURRENT_DATE)-make_interval(months=>$3::int)`, [T, marka, ay]);
        sendJson(response, 200, { marka, ay, marka_marj_pct: Number(marka_marj.rows[0]?.m ?? 0), marka_ciro_m: Number(marka_marj.rows[0]?.c ?? 0),
          satirlar: r.rows.map(x => ({ ebat:x.ebat, adet:Number(x.adet), fiyat:Number(x.fiyat), maliyet:Number(x.maliyet),
            marj_pct:x.marj_pct==null?null:Number(x.marj_pct), ek_kar:Number(x.ek_kar), hedef_fiyat:Number(x.hedef_fiyat_15),
            gereken_zam:x.gereken_zam==null?null:Number(x.gereken_zam), piyasa:x.piyasa==null?null:Number(x.piyasa) })) });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }

'''
ANCHOR = "    if (request.method === 'GET' && url.pathname === '/api/bi/yukle/durum') {"
if s.count(ANCHOR)!=1:
    print(f'  ✗ anchor {s.count(ANCHOR)} kez — DURDU'); sys.exit(1)
s=s.replace(ANCHOR, ENDPOINT+ANCHOR, 1)
wr(SRV,s)
print('  ✅ endpoint eklendi')
r=subprocess.run(['node','--check',SRV],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
print('  var :', '/api/bi/finans-marka-drag' in rd(SRV))
print('\n  ✅ YAMA TAMAM — docker build; sonra kart UI')
