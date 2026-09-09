#!/usr/bin/env python3
# MANAGER_PF_MUSTERITIPI — "sektör (satis_kanali karışık)" lensini "Müşteri tipi (bi_musteri_risk.grup)" ile değiştirir.
# lensler sorgusu + lens-liste drill + shell. cd /opt/krb-assessment && python3 patch_musteritipi_fix.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SRC="/opt/krb-assessment/server_container.mjs"
SHELLF="manager_portfoyum.html"; SHELLD="/opt/krb-assessment/shells/manager_portfoyum.html"
src=open(SRC,encoding="utf-8").read()

OLD_SEKTOR = '''  const sektor = (await query(
    `SELECT CASE WHEN satis_kanali='TBR SATIŞ' THEN 'Uzun yol (TBR)'
                 WHEN satis_kanali='OTR SATIŞ' THEN 'İnşaat/Maden (OTR)'
                 WHEN satis_kanali LIKE '%FİLO%' THEN 'Filo'
                 WHEN satis_kanali LIKE 'MAĞAZA%' OR satis_kanali LIKE 'LASTİK SERVİS%' OR satis_kanali='TÜKETİCİ ÜRÜNLER SATIŞ' OR satis_kanali LIKE 'E-TİCARET%' THEN 'Binek/Tüketici'
                 ELSE 'Diğer' END AS ad,
            count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART}
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST`, [T])).rows;'''

NEW_SEKTOR = '''  const musteritipi = (await query(
    `SELECT r.grup AS ad, count(DISTINCT f.musteri_kodu) musteri, round(sum(f.satir_tutar))::bigint ciro
       FROM bi_satis_faturalari f
       JOIN bi_musteri_risk r ON r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu
      WHERE f.tenant_id=$1 AND f.satir_tutar>0 AND f.fatura_tarihi>=${DSTART}
        AND r.grup IN ('.PERAKENDE','FILO TICARI','FILO TUKETICI','TOPTAN','KURUM','E-TICARET','IHRACAT')
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST`, [T])).rows;'''

OLD_KEY = "    sektor: sektor.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),"
NEW_KEY = "    musteritipi: musteritipi.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),"

LL_ANCHOR = '''        ORDER BY ciro_12 DESC NULLS LAST LIMIT 200`, [T, ref])).rows;
  } else if (tip) {'''
LL_NEW = '''        ORDER BY ciro_12 DESC NULLS LAST LIMIT 200`, [T, ref])).rows;
  } else if (tip === "musteritipi" && ref) {
    rows = (await query(
      `SELECT mm.musteri_adi AS firma, mm.sehir AS il, t.musteri_kodu, round(t.ciro)::bigint AS ciro_12
         FROM (SELECT f.musteri_kodu, sum(f.satir_tutar) AS ciro FROM bi_satis_faturalari f
                JOIN bi_musteri_risk r ON r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu
                WHERE f.tenant_id=$1 AND f.satir_tutar>0 AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months' AND r.grup=$2
                GROUP BY 1 ORDER BY 2 DESC LIMIT 200) t
         LEFT JOIN master_musteri mm ON mm.tenant_id=$1 AND mm.musteri_kodu=t.musteri_kodu
        ORDER BY ciro_12 DESC NULLS LAST`, [T, ref])).rows;
  } else if (tip) {'''

if "const musteritipi" in src:
    print("• zaten uygulanmış.")
else:
    for old,new,ad in [(OLD_SEKTOR,NEW_SEKTOR,"lensler sorgu"),(OLD_KEY,NEW_KEY,"lensler key"),(LL_ANCHOR,LL_NEW,"lens-liste drill")]:
        if old not in src:
            print("HATA: '%s' bulunamadı — DUR."%ad); sys.exit(1)
        src=src.replace(old,new,1)
    shutil.copy(SRC, SRC+".bak_mtipi"); open(SRC,"w",encoding="utf-8").write(src)
    open("/tmp/_mt.mjs","w",encoding="utf-8").write(src)
    r=subprocess.run(["node","--check","/tmp/_mt.mjs"],capture_output=True,text=True)
    if r.returncode!=0:
        shutil.copy(SRC+".bak_mtipi", SRC); print("HATA node --check:\n"+r.stderr); sys.exit(1)
    print("✓ sektör → müşteri tipi (lensler + lens-liste) + node --check geçti.")

if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD),exist_ok=True); shutil.copy(SHELLF, SHELLD); print("✓ shell güncellendi.")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
