#!/usr/bin/env python3
# SCORE_ODEME_V1 — musteri skoru "Odeme" bilesenini (s_pay) OLCULEN bi_tahsilat'a baglar.
#   son12 aktifse son12, degilse tam gecmis; tahsilat kaydi YOKSA eski proxy (fallback).
#   3 ozdes skor sorgusunu (musteri-fiyat, musteri-skor, musteri-fiyat-liste) birlikte gunceller.
#   FIYAT DEGISMEZ (fiyat s_vol+s_risk kullanir). Regex + tam sayim (assert) korumali. Idempotent.
import sys, re

FP = sys.argv[1] if len(sys.argv) > 1 else "/opt/krb-assessment/server_container.mjs"
s = open(FP, encoding="utf-8").read()

if "tah AS (SELECT muhatap_kodu, gec_odeme_orani" in s:
    print("zaten yamali (SCORE_ODEME_V1), atlandi"); print("DONE."); raise SystemExit

def sub(pat, repl, need, tag, flags=0):
    global s
    s2, n = re.subn(pat, repl, s, flags=flags)
    assert n == need, "SAYIM YANLIS: " + tag + " beklenen=" + str(need) + " bulunan=" + str(n)
    s = s2
    print(f"  {tag}: {n} degisiklik")

# 1) tah CTE ekle (net AS satirindan hemen sonra) — 3 skor sorgusu
sub(r"(net AS \(SELECT musteri_kodu, net_pozisyon FROM bi_cari_bakiye WHERE tenant_id::text=\$1\),)",
    r"\1\n           tah AS (SELECT muhatap_kodu, gec_odeme_orani, ort_gecikme_gun, son12_adedi, son12_gec_orani, son12_gecikme_gun FROM bi_tahsilat WHERE tenant_id::text=$1),",
    3, "tah_cte")

# 2) base blogu: eff_gec/eff_gun/has_tah + tah join — 3 skor sorgusu
sub(r"COALESCE\(r\.kredi_limiti,0\) kredi, COALESCE\(n\.net_pozisyon, r\.hesap_bakiyesi, 0\) net_poz\s*\n\s*FROM cust c LEFT JOIN risk r ON r\.muhatap_kodu=c\.musteri_kodu LEFT JOIN net n ON n\.musteri_kodu=c\.musteri_kodu\),",
    "COALESCE(r.kredi_limiti,0) kredi, COALESCE(n.net_pozisyon, r.hesap_bakiyesi, 0) net_poz,\n"
    "               (t.muhatap_kodu IS NOT NULL) has_tah,\n"
    "               CASE WHEN COALESCE(t.son12_adedi,0)>0 THEN t.son12_gec_orani ELSE t.gec_odeme_orani END eff_gec,\n"
    "               CASE WHEN COALESCE(t.son12_adedi,0)>0 THEN t.son12_gecikme_gun ELSE t.ort_gecikme_gun END eff_gun\n"
    "             FROM cust c LEFT JOIN risk r ON r.muhatap_kodu=c.musteri_kodu LEFT JOIN net n ON n.musteri_kodu=c.musteri_kodu LEFT JOIN tah t ON t.muhatap_kodu=c.musteri_kodu),",
    3, "base_join")

# 3) s_pay: olculen (has_tah) ELSE eski proxy — 3 skor sorgusu
sub(r"\(0\.6\*\(1-LEAST\(COALESCE\(vade,0\),120\)/120\.0\)\s*\+0\.4\*\(CASE WHEN overdue<=0 THEN 1\.0 WHEN bakiye<=0 THEN 0\.3 ELSE GREATEST\(0,1-overdue/bakiye\) END\)\) s_pay,",
    "(CASE WHEN has_tah "
    "THEN 0.6*(1-LEAST(GREATEST(COALESCE(eff_gec,0),0),100)/100.0)+0.4*(1-LEAST(GREATEST(COALESCE(eff_gun,0),0),60)/60.0) "
    "ELSE 0.6*(1-LEAST(COALESCE(vade,0),120)/120.0)+0.4*(CASE WHEN overdue<=0 THEN 1.0 WHEN bakiye<=0 THEN 0.3 ELSE GREATEST(0,1-overdue/bakiye) END) "
    "END) s_pay,",
    3, "s_pay")

open(FP, "w", encoding="utf-8").write(s)
print("yamalandi: SCORE_ODEME_V1 (3 skor sorgusu, olculen odeme + fallback)")
print("DONE.")
