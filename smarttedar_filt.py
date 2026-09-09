#!/usr/bin/env python3
# TEDARFILT_V1 — musteri tarafi motorlardan (skor, fiyat, kiyas, iyilestirme-hedefleri) BUYUK tedarikci/
# ithal entitelerini (grup=TEDARİKÇİ VE 12-ay lastik cirosu > 5M) haric tut. Sadece SAILUN TURKEY (46.9M)
# + SAILUN GROUP HANGKONG (19.7M) yakalanir; kucuk (grup TEDAR ama gercek musteri: DERELİ, DCM vb.) KORUNUR.
# Hayalet "musteri" kartlari + sahte drag hedefleri temizlenir. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "TEDARFILT_V1" in s:
    print("tedarfilt: already present, skip"); print("DONE."); raise SystemExit

# Ortak haric-tutma alt sorgusu ($1 = tenant, her iki CTE'de de mevcut)
def excl(mk):
    return (" AND " + mk + " NOT IN (SELECT f2.musteri_kodu FROM bi_satis_faturalari f2 "
            "WHERE f2.tenant_id::text=$1 AND f2.grup_adi LIKE 'LASTIK%' "
            "AND f2.fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months') "
            "AND f2.musteri_kodu IN (SELECT muhatap_kodu FROM bi_musteri_risk WHERE tenant_id::text=$1 AND grup ILIKE '%TEDAR%') "
            "GROUP BY f2.musteri_kodu HAVING SUM(f2.satir_tutar) > 5000000) /* TEDARFILT_V1 */")

# (1) Skor CTE (SMARTPRICE_V1 musteri-fiyat + SMARTPRICE_V2 musteri-skor + musteri-fiyat-liste): 3 kopya
OLD_S = ("             WHERE tenant_id::text=$1 AND grup_adi LIKE 'LASTIK%' AND miktar>0\n"
         "               AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months')\n"
         "             GROUP BY musteri_kodu)")
NEW_S = ("             WHERE tenant_id::text=$1 AND grup_adi LIKE 'LASTIK%' AND miktar>0\n"
         "               AND fatura_tarihi >= (CURRENT_DATE - INTERVAL '12 months')\n"
         "              " + excl("musteri_kodu") + "\n"
         "             GROUP BY musteri_kodu)")
cnt_s = s.count(OLD_S)
assert cnt_s >= 1, "skor CTE WHERE bulunamadi"
s = s.replace(OLD_S, NEW_S)

# (2) Kiyas CTE (SMARTKIYAS_V1 musteri-kiyas + iyilestirme-hedefleri): 2 kopya
OLD_K = ("        WHERE f.tenant_id::text=$1 AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0\n"
         "          AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'\n"
         "        GROUP BY f.musteri_kodu)")
NEW_K = ("        WHERE f.tenant_id::text=$1 AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0\n"
         "          AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'\n"
         "         " + excl("f.musteri_kodu") + "\n"
         "        GROUP BY f.musteri_kodu)")
cnt_k = s.count(OLD_K)
assert cnt_k >= 1, "kiyas CTE WHERE bulunamadi"
s = s.replace(OLD_K, NEW_K)

write(FP, s)
print("tedarfilt: skor CTE x%d, kiyas CTE x%d filtrelendi" % (cnt_s, cnt_k))
print("marker count:", s.count("TEDARFILT_V1"))
print("DONE.")
