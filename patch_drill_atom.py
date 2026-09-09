#!/usr/bin/env python3
# OMURGA 40 — marka drill (finans-marka-detay) atomdan okusun: gerçek dönem-maliyetli marj ekranda.
import sys, subprocess
SRV='/opt/krb-assessment/server_container.mjs'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
s=rd(SRV)

if 'FROM bi_marj_atom' in s and 'finans-marka-detay' in s and s.count('FROM bi_marj_atom')>=1 and 'atom' in s[s.find('finans-marka-detay'):s.find('finans-marka-detay')+2000]:
    # kaba idempotent kontrol
    pass

OLD = '''        const KM = `WITH km AS (SELECT kalem_kodu, sum(giris_tutari)/NULLIF(sum(giris),0) AS bmaliyet FROM bi_stok_hareket WHERE tenant_id=$1::uuid AND giris>0 GROUP BY kalem_kodu)`;
        const [cur, prev] = await Promise.all([
          query(`${KM}
            SELECT to_char(date_trunc('month',s.fatura_tarihi),'YYYY-MM') AS donem,
                   round(sum(s.satir_tutar)) AS ciro, sum(s.miktar)::bigint AS adet,
                   round(sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END)) AS marj,
                   round(100.0*count(*) FILTER (WHERE km.bmaliyet IS NOT NULL)/nullif(count(*),0)) AS marj_kapsam
              FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
             WHERE s.tenant_id=$1::text AND s.ebat IS NOT NULL AND s.miktar > 0 AND upper(s.marka)=upper($2)
               AND s.fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$3::int))
               AND s.fatura_tarihi < date_trunc('month',CURRENT_DATE)
             GROUP BY 1 ORDER BY 1`, [T, marka, ay]),
          query(`${KM}
            SELECT round(sum(s.satir_tutar)) AS ciro, sum(s.miktar)::bigint AS adet,
                   round(sum(CASE WHEN km.bmaliyet IS NOT NULL THEN s.satir_tutar - s.miktar*km.bmaliyet END)) AS marj
              FROM bi_satis_faturalari s LEFT JOIN km ON km.kalem_kodu=s.kalem_kodu
             WHERE s.tenant_id=$1::text AND s.ebat IS NOT NULL AND s.miktar > 0 AND upper(s.marka)=upper($2)
               AND s.fatura_tarihi >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$3::int+12))
               AND s.fatura_tarihi < (date_trunc('month',CURRENT_DATE) - make_interval(months=>12))`, [T, marka, ay])
        ]);'''

NEW = '''        // KANONİK ATOM (omurga_40): gerçek dönem-eşleşmeli marj — eski tüm-geçmiş maliyet DEĞİL
        const [cur, prev] = await Promise.all([
          query(`
            SELECT to_char(ay,'YYYY-MM') AS donem, round(sum(ciro)) AS ciro, sum(adet)::bigint AS adet,
                   round(sum(brut_kar)) AS marj,
                   round(100.0*count(*) FILTER (WHERE maliyet_kaynak='donem')/nullif(count(*),0)) AS marj_kapsam
              FROM bi_marj_atom
             WHERE tenant_id=$1::uuid AND upper(marka)=upper($2)
               AND ay >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$3::int))
               AND ay < date_trunc('month',CURRENT_DATE)
             GROUP BY ay ORDER BY ay`, [T, marka, ay]),
          query(`
            SELECT round(sum(ciro)) AS ciro, sum(adet)::bigint AS adet, round(sum(brut_kar)) AS marj
              FROM bi_marj_atom
             WHERE tenant_id=$1::uuid AND upper(marka)=upper($2)
               AND ay >= (date_trunc('month',CURRENT_DATE) - make_interval(months=>$3::int+12))
               AND ay < (date_trunc('month',CURRENT_DATE) - make_interval(months=>12))`, [T, marka, ay])
        ]);'''

c = s.count(OLD)
if c != 1:
    print(f'  ✗ anchor {c} kez (1 bekleniyor) — DURDU (belki zaten atoma çevrildi)'); sys.exit(1)
s = s.replace(OLD, NEW, 1)
wr(SRV, s)
print('  ✅ finans-marka-detay atoma çevrildi')

r=subprocess.run(['node','--check',SRV],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
s2=rd(SRV)
print('  atomdan  :', 'FROM bi_marj_atom' in s2)
print('  km gitti :', 'km.bmaliyet' not in s2[s2.find("finans-marka-detay"):s2.find("finans-marka-detay")+2500])
print('\n  ✅ YAMA TAMAM — docker build; sonra LASSA drill ~%5 (gerçek) gösterir')
