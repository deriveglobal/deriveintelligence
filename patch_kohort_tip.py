#!/usr/bin/env python3
# MANAGER_PF_KOHORT_TIP — kohortu müşteri tipine (b2b/perakende/eticaret/diger) göre böler.
# cd /opt/krb-assessment && python3 patch_kohort_tip.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SRC="/opt/krb-assessment/server_container.mjs"
SHELLF="manager_portfoyum.html"; SHELLD="/opt/krb-assessment/shells/manager_portfoyum.html"
src=open(SRC,encoding="utf-8").read()

OLD_Q = '''  const kohort = (await query(
    `SELECT extract(year from ilk_fatura)::int yil, count(*) kazanilan,
            count(*) FILTER (WHERE son_fatura >= CURRENT_DATE - INTERVAL '12 months') aktif
       FROM master_musteri WHERE tenant_id=$1 AND ilk_fatura >= DATE '2022-01-01'
      GROUP BY 1 ORDER BY 1`, [T])).rows;'''
NEW_Q = '''  const kohort = (await query(
    `SELECT extract(year from m.ilk_fatura)::int yil,
            CASE WHEN r.grup IN ('FILO TICARI','FILO TUKETICI','TOPTAN','KURUM','IHRACAT') THEN 'b2b'
                 WHEN r.grup='.PERAKENDE' THEN 'perakende'
                 WHEN r.grup='E-TICARET' THEN 'eticaret'
                 ELSE 'diger' END tip,
            count(*) kazanilan,
            count(*) FILTER (WHERE m.son_fatura >= CURRENT_DATE - INTERVAL '12 months') aktif
       FROM master_musteri m
       LEFT JOIN bi_musteri_risk r ON r.tenant_id::text=m.tenant_id::text AND r.muhatap_kodu=m.musteri_kodu
      WHERE m.tenant_id=$1 AND m.ilk_fatura >= DATE '2022-01-01'
      GROUP BY 1,2 ORDER BY 1`, [T])).rows;'''

OLD_MAP = '''    kohort: kohort.map(x => ({ yil: +x.yil, kazanilan: +x.kazanilan || 0, aktif: +x.aktif || 0,
                              pct: x.kazanilan ? Math.round(100 * x.aktif / x.kazanilan) : 0 })),'''
NEW_MAP = '''    kohort: kohort.map(x => ({ yil: +x.yil, tip: x.tip, kazanilan: +x.kazanilan || 0, aktif: +x.aktif || 0 })),'''

if "END tip," in src and "x.tip" in src:
    print("• zaten uygulanmış.")
else:
    for old,new,ad in [(OLD_Q,NEW_Q,"kohort sorgu"),(OLD_MAP,NEW_MAP,"kohort map")]:
        if old not in src:
            print("HATA: '%s' bulunamadı — DUR."%ad); sys.exit(1)
        src=src.replace(old,new,1)
    shutil.copy(SRC, SRC+".bak_kohtip"); open(SRC,"w",encoding="utf-8").write(src)
    open("/tmp/_kt.mjs","w",encoding="utf-8").write(src)
    r=subprocess.run(["node","--check","/tmp/_kt.mjs"],capture_output=True,text=True)
    if r.returncode!=0:
        shutil.copy(SRC+".bak_kohtip", SRC); print("HATA node --check:\n"+r.stderr); sys.exit(1)
    print("✓ kohort tip kırılımı eklendi + node --check geçti.")

if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD),exist_ok=True); shutil.copy(SHELLF, SHELLD); print("✓ shell güncellendi.")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
