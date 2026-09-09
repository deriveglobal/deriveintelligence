#!/usr/bin/env python3
# TAHSILAT_KIYAS_V1 — KRB kıyas: "Tahsilat" metriği -> GERÇEK DSO (ölçülen tahsilat süresi),
#   "Gecikme" metriği -> ölçülen ödeme davranışı (%geç + ort gün). Kaynak: bi_tahsilat (son12/tam).
#   SQL 2 sorguya da tah+kt CTE + kolon ekler (fazladan kolon iyileştirme'de zararsız); JS yalnız kıyas kartını değiştirir.
#   Tahsilat kaydı yoksa ESKİ gösterim (fallback). Literal + tam sayım (assert). Idempotent.
import sys

FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
s = open(FP, encoding="utf-8").read()

if "TAHSILAT_KIYAS_V1" in s or "kt AS (SELECT AVG(t.dso)" in s:
    print("zaten yamali (TAHSILAT_KIYAS_V1), atlandi"); print("DONE."); raise SystemExit

def rep(old, new, need, tag):
    global s
    c = s.count(old)
    assert c == need, "SAYIM YANLIS: " + tag + " beklenen=" + str(need) + " bulunan=" + str(c)
    s = s.replace(old, new)
    print(f"  {tag}: {need} degisiklik")

# --- SQL (2 sorgu: musteri-kiyas + iyilestirme-hedefleri) ---
# 1) kro'dan sonra tah + kt CTE
rep("      kro AS (SELECT SUM(overdue)/NULLIF(SUM(bakiye),0) krb_od FROM risk)\n",
    "      kro AS (SELECT SUM(overdue)/NULLIF(SUM(bakiye),0) krb_od FROM risk),\n"
    "      tah AS (SELECT muhatap_kodu, CASE WHEN COALESCE(son12_adedi,0)>0 THEN son12_suresi ELSE ort_tahsilat_suresi END dso, "
    "CASE WHEN COALESCE(son12_adedi,0)>0 THEN son12_gec_orani ELSE gec_odeme_orani END gecp, "
    "CASE WHEN COALESCE(son12_adedi,0)>0 THEN son12_gecikme_gun ELSE ort_gecikme_gun END gun FROM bi_tahsilat WHERE tenant_id::text=$1),\n"
    "      kt AS (SELECT AVG(t.dso) krb_dso, AVG(t.gecp) krb_gecp FROM tah t JOIN cust c ON c.musteri_kodu=t.muhatap_kodu)\n",
    2, "sql_tah_kt")

# 2) FROM ... CROSS JOIN kro  ->  + tah/kt join
rep("FROM cust c LEFT JOIN risk r ON r.muhatap_kodu=c.musteri_kodu CROSS JOIN kb CROSS JOIN kro",
    "FROM cust c LEFT JOIN risk r ON r.muhatap_kodu=c.musteri_kodu LEFT JOIN tah t2 ON t2.muhatap_kodu=c.musteri_kodu CROSS JOIN kb CROSS JOIN kro CROSS JOIN kt",
    2, "sql_from_join")

# 3) marj_drag kolonundan sonra ölçülen kolonlar
rep("        round(GREATEST(0, kb.krb_marj/100.0 - (c.ciro-c.maliyet)/NULLIF(c.ciro,0)) * c.ciro)::float8 marj_drag",
    "        round(GREATEST(0, kb.krb_marj/100.0 - (c.ciro-c.maliyet)/NULLIF(c.ciro,0)) * c.ciro)::float8 marj_drag,\n"
    "        round(t2.dso)::float8 dso, round(kt.krb_dso)::float8 krb_dso, round(t2.gecp,1)::float8 gecp, "
    "round(t2.gun)::float8 gecikme_gun, round(kt.krb_gecp,1)::float8 krb_gecp, (t2.muhatap_kodu IS NOT NULL) has_tah",
    2, "sql_columns")

# --- JS (yalnız musteri-kiyas kartı) ---
# 4) destructuring + olculen degiskenler
rep("        const overdue = n(x.overdue), odPct = n(x.od_pct), krbOd = n(x.krb_od_pct), buyume = n(x.buyume);\n",
    "        const overdue = n(x.overdue), odPct = n(x.od_pct), krbOd = n(x.krb_od_pct), buyume = n(x.buyume);\n"
    "        const dso = n(x.dso), krbDso = n(x.krb_dso), gecp = n(x.gecp), gecikmeGun = n(x.gecikme_gun), krbGecp = n(x.krb_gecp), hasTah = x.has_tah === true; /* TAHSILAT_KIYAS_V1 */\n",
    1, "js_vars")

# 5) "Tahsilat" metrigi -> GERCEK DSO
rep('''        // tahsilat (vade dusuk=iyi)
        { const kotu = vade != null && krbVade != null && vade > krbVade * 1.15;
          M.push({ anahtar: "tahsilat", ad: "Tahsilat", deger: vade != null ? vade + " gün" : "—", krb: krbVade != null ? krbVade + " gün" : "—",
            durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Vadeyi kısalt / peşin teşvik et" : null }); }''',
    '''        // tahsilat -> GERCEK DSO (olculen tahsilat suresi) TAHSILAT_KIYAS_V1
        { const useDso = hasTah && dso != null; const val = useDso ? dso : vade, krbVal = useDso ? krbDso : krbVade;
          const kotu = val != null && krbVal != null && val > krbVal * 1.15;
          M.push({ anahtar: "tahsilat", ad: useDso ? "Tahsilat (DSO)" : "Tahsilat", deger: val != null ? Math.round(val) + " gün" : "—", krb: krbVal != null ? Math.round(krbVal) + " gün" : "—",
            durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Vadeyi kısalt / peşin teşvik et" : null }); }''',
    1, "js_tahsilat_dso")

# 6) "Gecikme" metrigi -> OLCULEN odeme davranisi
rep('''        // gecikme (dusuk=iyi)
        { const _ciro = n(x.ciro) || 0; const odCiro = (_ciro > 0 && overdue != null) ? overdue / _ciro * 100 : null; /* SMARTKIYAS_V2 */
          const kotu = overdue != null && _ciro > 0 && overdue > _ciro * 0.10 && overdue > 50000;
          M.push({ anahtar: "gecikme", ad: "Gecikme", deger: overdue != null ? Math.round(overdue).toLocaleString("tr-TR") + " ₺" + (odCiro != null ? " · cironun %" + Math.round(odCiro) + "'i" : "") : "—",
            krb: "sağlıklı < %10", durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Tahsilat planı / kredi limitini gözden geçir" : null }); }''',
    '''        // gecikme -> OLCULEN odeme davranisi (%gec + ort gun) TAHSILAT_KIYAS_V1
        { if (hasTah && gecp != null) {
            const kotu = gecp > 55 || (gecikmeGun != null && gecikmeGun > 15);
            M.push({ anahtar: "gecikme", ad: "Ödeme davranışı", deger: "%" + Math.round(gecp) + " geç" + (gecikmeGun != null ? " · ort " + Math.round(gecikmeGun) + " gün" : ""),
              krb: "KRB %" + (krbGecp != null ? Math.round(krbGecp) : "—") + " geç", durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Tahsilat planı / peşin teşvik / limit gözden geçir" : null });
          } else {
            const _ciro = n(x.ciro) || 0; const odCiro = (_ciro > 0 && overdue != null) ? overdue / _ciro * 100 : null;
            const kotu = overdue != null && _ciro > 0 && overdue > _ciro * 0.10 && overdue > 50000;
            M.push({ anahtar: "gecikme", ad: "Gecikme", deger: overdue != null ? Math.round(overdue).toLocaleString("tr-TR") + " ₺" + (odCiro != null ? " · cironun %" + Math.round(odCiro) + "'i" : "") : "—",
              krb: "sağlıklı < %10", durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Tahsilat planı / kredi limitini gözden geçir" : null }); } }''',
    1, "js_gecikme_olculen")

open(FP, "w", encoding="utf-8").write(s)
print("yamalandi: TAHSILAT_KIYAS_V1 (gercek DSO + olculen gecikme)")
print("DONE.")
