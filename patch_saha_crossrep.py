#!/usr/bin/env python3
# saha_fix_4 (omurga_78, ②) — cross-rep sizinti: musteri "son ziyaret"/"ziyaret sayisi" REP icin
# kendi ziyaretine gore hesaplanir (ziyaret listesi zaten rep-scoped; kart onunla tutarli olur).
# Rep raporu (Eftal): baska repin (Huseyin) ziyareti "benim son ziyaretim" gorunuyordu; iceri girince kayit yoktu.
# Yonetici/GM tum ziyaretleri gormeye devam eder. SADECE sunucu; saha.js degismez.
# Yedekli + node --check + geri-alinabilir. Sunucuda calisir.
import shutil, subprocess, sys
S = "/opt/krb-assessment/server_container.mjs"
srv = open(S, encoding="utf-8").read()

E = []
# 1) LISTE: szRep setup
E.append((
'''      const params = [session.tenantId];
      let sql = `
        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,''',
'''      const params = [session.tenantId];
      // CROSS_REP_V1 — rep icin "son ziyaret" KENDI ziyaretine gore (ziyaret listesi de rep-scoped).
      //   Onceden LATERAL tum replerin ziyaretini sayiyordu -> baska repin ziyareti "son ziyaretim" gorunuyordu.
      let szRep = "";
      if (session.sahaRole === "rep") { params.push(session.userId); szRep = ` AND z.rep_id = $${params.length}`; }
      let sql = `
        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,'''))
# 2) LISTE: LATERAL
E.append((
'''          WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'
        ) sz ON true
        -- ⚠ DURUM_TURETILIYOR''',
'''          WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'${szRep}
        ) sz ON true
        -- ⚠ DURUM_TURETILIYOR'''))
# 3) DETAY: setup
E.append((
'''      const result = await query(`
        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,
               COALESCE(m.vergi_no, mm.vergi_no) AS kimlik_vergi_no,
               COALESCE(m.tc_no, mm.tc_no) AS kimlik_tc_no,''',
'''      const _dp = [session.tenantId, m[1]];
      let _szRep = "";
      if (session.sahaRole === "rep") { _dp.push(session.userId); _szRep = ` AND z.rep_id = $${_dp.length}`; }
      const result = await query(`
        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,
               COALESCE(m.vergi_no, mm.vergi_no) AS kimlik_vergi_no,
               COALESCE(m.tc_no, mm.tc_no) AS kimlik_tc_no,'''))
# 4) DETAY: LATERAL + params
E.append((
'''          WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'
        ) sz ON true
        WHERE m.tenant_id = $1 AND m.id = $2 AND m.aktif = true
      `, [session.tenantId, m[1]]);''',
'''          WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'${_szRep}
        ) sz ON true
        WHERE m.tenant_id = $1 AND m.id = $2 AND m.aktif = true
      `, _dp);'''))

if 'CROSS_REP_V1' in srv:
    sys.exit("ZATEN VAR: saha_fix_4 uygulanmis gibi.")
for i, (o, n) in enumerate(E, 1):
    if o not in srv:
        sys.exit("HATA: %d. blok bulunamadi (elle bak)." % i)
    if srv.count(o) != 1:
        sys.exit("UYARI: %d. blok %d kez — belirsiz." % (i, srv.count(o)))
    srv = srv.replace(o, n, 1)

shutil.copy2(S, S + ".crossrep.bak")
open(S, "w", encoding="utf-8").write(srv)
try:
    chk = subprocess.run(["node", "--check", S], capture_output=True, text=True)
    if chk.returncode != 0:
        shutil.copy2(S + ".crossrep.bak", S)
        sys.exit("HATA: node --check GECMEDI -> GERI ALINDI\n" + chk.stderr)
    print("OK: node --check GECTI")
except FileNotFoundError:
    print("UYARI: node yok, --check atlandi (yedek .crossrep.bak)")
print("OK: cross-rep 'son ziyaret' rep-scoped. SADECE server — build yeterli (saha.js degismedi).")
