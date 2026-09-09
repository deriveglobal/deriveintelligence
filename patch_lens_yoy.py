#!/usr/bin/env python3
# MANAGER_PF_LENS_YOY — lensler ucuna geçen-yıl-aynı-dönem (ciro_gy) ekler: Müşteri tipi, Şube, Bölge.
# cd /opt/krb-assessment && python3 patch_lens_yoy.py && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment
import sys, subprocess, shutil, os
SRC="/opt/krb-assessment/server_container.mjs"
SHELLF="manager_portfoyum.html"; SHELLD="/opt/krb-assessment/shells/manager_portfoyum.html"
src=open(SRC,encoding="utf-8").read()

if "const DGY" in src:
    print("• YoY zaten uygulanmış.")
else:
    reps=[]

    # 1) DSTART'tan sonra DGY + GYEND ekle
    DSTART_DECL = '''  const DSTART = donem === "buay" ? "date_trunc('month',CURRENT_DATE)"
              : donem === "3ay"  ? "CURRENT_DATE - INTERVAL '3 months'"
              : donem === "6ay"  ? "CURRENT_DATE - INTERVAL '6 months'"
              : donem === "ytd"  ? "date_trunc('year',CURRENT_DATE)"
              :                    "CURRENT_DATE - INTERVAL '12 months'";'''
    DGY_ADD = DSTART_DECL + '''
  const DGY = donem === "buay" ? "date_trunc('month',CURRENT_DATE) - INTERVAL '1 year'"
            : donem === "3ay"  ? "CURRENT_DATE - INTERVAL '15 months'"
            : donem === "6ay"  ? "CURRENT_DATE - INTERVAL '18 months'"
            : donem === "ytd"  ? "date_trunc('year',CURRENT_DATE) - INTERVAL '1 year'"
            :                    "CURRENT_DATE - INTERVAL '24 months'";
  const GYEND = "CURRENT_DATE - INTERVAL '1 year'";'''
    reps.append((DSTART_DECL, DGY_ADD, "DGY decl"))

    # 2) ŞUBE
    OLD_SUBE = '''  const sube = (await query(
    `SELECT sube AS ad, count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} AND COALESCE(sube,'')<>''
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;'''
    NEW_SUBE = '''  const sube = (await query(
    `SELECT sube AS ad,
            count(DISTINCT musteri_kodu) FILTER (WHERE fatura_tarihi>=${DSTART}) musteri,
            round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=${DSTART}))::bigint ciro,
            round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=${DGY} AND fatura_tarihi<${GYEND}))::bigint ciro_gy
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DGY} AND COALESCE(sube,'')<>''
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;'''
    reps.append((OLD_SUBE, NEW_SUBE, "sube"))

    # 3) BÖLGE
    OLD_BOLGE = '''  const bolge = (await query(
    `SELECT sehir AS ad, count(DISTINCT musteri_kodu) musteri, round(sum(satir_tutar))::bigint ciro
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DSTART} AND COALESCE(sehir,'')<>''
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;'''
    NEW_BOLGE = '''  const bolge = (await query(
    `SELECT sehir AS ad,
            count(DISTINCT musteri_kodu) FILTER (WHERE fatura_tarihi>=${DSTART}) musteri,
            round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=${DSTART}))::bigint ciro,
            round(sum(satir_tutar) FILTER (WHERE fatura_tarihi>=${DGY} AND fatura_tarihi<${GYEND}))::bigint ciro_gy
       FROM bi_satis_faturalari WHERE tenant_id=$1 AND satir_tutar>0 AND fatura_tarihi>=${DGY} AND COALESCE(sehir,'')<>''
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST LIMIT 8`, [T])).rows;'''
    reps.append((OLD_BOLGE, NEW_BOLGE, "bolge"))

    # 4) MÜŞTERİ TİPİ
    OLD_MT = '''  const musteritipi = (await query(
    `SELECT r.grup AS ad, count(DISTINCT f.musteri_kodu) musteri, round(sum(f.satir_tutar))::bigint ciro
       FROM bi_satis_faturalari f
       JOIN bi_musteri_risk r ON r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu
      WHERE f.tenant_id=$1 AND f.satir_tutar>0 AND f.fatura_tarihi>=${DSTART}
        AND r.grup IN ('.PERAKENDE','FILO TICARI','FILO TUKETICI','TOPTAN','KURUM','E-TICARET','IHRACAT')
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST`, [T])).rows;'''
    NEW_MT = '''  const musteritipi = (await query(
    `SELECT r.grup AS ad,
            count(DISTINCT f.musteri_kodu) FILTER (WHERE f.fatura_tarihi>=${DSTART}) musteri,
            round(sum(f.satir_tutar) FILTER (WHERE f.fatura_tarihi>=${DSTART}))::bigint ciro,
            round(sum(f.satir_tutar) FILTER (WHERE f.fatura_tarihi>=${DGY} AND f.fatura_tarihi<${GYEND}))::bigint ciro_gy
       FROM bi_satis_faturalari f
       JOIN bi_musteri_risk r ON r.tenant_id::text=f.tenant_id::text AND r.muhatap_kodu=f.musteri_kodu
      WHERE f.tenant_id=$1 AND f.satir_tutar>0 AND f.fatura_tarihi>=${DGY}
        AND r.grup IN ('.PERAKENDE','FILO TICARI','FILO TUKETICI','TOPTAN','KURUM','E-TICARET','IHRACAT')
      GROUP BY 1 ORDER BY ciro DESC NULLS LAST`, [T])).rows;'''
    reps.append((OLD_MT, NEW_MT, "musteritipi"))

    # 5) response maps → ciro_gy ekle
    reps.append(('    sube:   sube.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),',
                 '    sube:   sube.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0, ciro_gy: +x.ciro_gy || 0 })),', "sube map"))
    reps.append(('    bolge:  bolge.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),',
                 '    bolge:  bolge.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0, ciro_gy: +x.ciro_gy || 0 })),', "bolge map"))
    reps.append(('    musteritipi: musteritipi.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0 })),',
                 '    musteritipi: musteritipi.map(x => ({ ad: x.ad, musteri: +x.musteri || 0, ciro: +x.ciro || 0, ciro_gy: +x.ciro_gy || 0 })),', "musteritipi map"))

    for old,new,ad in reps:
        if old not in src:
            print("HATA: '%s' bulunamadı — DUR."%ad); sys.exit(1)
        src=src.replace(old,new,1)

    shutil.copy(SRC, SRC+".bak_lensyoy"); open(SRC,"w",encoding="utf-8").write(src)
    open("/tmp/_yoy.mjs","w",encoding="utf-8").write(src)
    r=subprocess.run(["node","--check","/tmp/_yoy.mjs"],capture_output=True,text=True)
    if r.returncode!=0:
        shutil.copy(SRC+".bak_lensyoy", SRC); print("HATA node --check:\n"+r.stderr); sys.exit(1)
    print("✓ lens YoY (ciro_gy) eklendi + node --check geçti.")

if os.path.exists(SHELLF):
    os.makedirs(os.path.dirname(SHELLD),exist_ok=True); shutil.copy(SHELLF, SHELLD); print("✓ shell güncellendi.")
print("\nŞimdi: docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment")
