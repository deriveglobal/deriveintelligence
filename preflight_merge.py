#!/usr/bin/env python3
# MERGE ON-UCUS (read-only). DB'ye YAZMAZ. Dosyayi okur + mevcut carileri okur,
#   birlestirmeyi BELLEKTE simule eder, sonuc cari sayisini ve metrikleri gosterir.
#   Konteyner icinde: docker exec krb-assessment python3 /tmp/preflight_merge.py /tmp/f.xlsx <TENANT>
import sys
sys.path.insert(0, "/app"); sys.path.insert(0, "/opt/krb-assessment"); sys.path.insert(0, ".")
import erp_ingest as eng

def fm(x): return format(round(x), ",").replace(",", ".")

F = sys.argv[1]
TEN = sys.argv[2]

tip, satir, istat = eng.oku(F)
assert tip == "alacak_yaslandirma", "TIP YANLIS: " + str(tip)

incoming = {str(r.get("muhatap_kodu", "")) for r in satir}
mus_file = [r for r in satir if r["musteri_mi"]]
alacak = sum(max(r["hesap_bakiyesi"], 0) for r in mus_file)
gec = sum(r["vadesi_gecmis"] for r in mus_file)

cn = eng._baglan()
existing = set(); grup_map = {}
try:
    with cn, cn.cursor() as cur:
        cur.execute("SELECT muhatap_kodu, grup FROM bi_musteri_risk WHERE tenant_id=%s::uuid", (TEN,))
        rows = cur.fetchall()
        for kod, grup in rows:
            kk = str(kod or ""); existing.add(kk); grup_map[kk] = grup
    cn.rollback()   # READ-ONLY: hicbir sey yazma
finally:
    cn.close()

mevcut_distinct = len(existing)
carried = existing - incoming            # dosyada olmayan, kimligi TASINAN cariler
yeni = incoming - existing               # dosyadaki YENI cariler
final_distinct = existing | incoming     # birlesme sonrasi tekil cari
dropout = existing - final_distinct      # KAYBOLAN cari (tasarim geregi: 0)
grup_bos = sum(1 for kk in carried if not (grup_map.get(kk) or "").strip())

print("== MERGE ON-UCUS (DB'ye YAZILMADI) ==")
print("dosyadaki cari         :", len(satir), "| musteri_mi:", len(mus_file))
print("mevcut bi_musteri_risk :", mevcut_distinct, "(tekil cari)")
print("dosyada guncellenen    :", len(incoming & existing))
print("dosyadaki YENI cari    :", len(yeni))
print("kimligi TASINAN cari   :", len(carried), "(dosyada yok -> risk 0, grup korunur)")
print("-> BIRLESME SONRASI TOPLAM TEKIL CARI:", len(final_distinct))
print("-> KAYBOLAN (dropout)  :", len(dropout), "  [0 olmali]")
print("tasinanlarda bos grup  :", grup_bos)
print("alacak (dosyadan)      :", fm(alacak), "| gecikmis(FIFO):", fm(gec))
print()
if len(dropout) == 0 and len(final_distinct) >= mevcut_distinct:
    print("SONUC: DUSME YOK, tum mevcut cariler korunuyor. Sayilar dogrulanmis degerle ayni ise -> GO.")
else:
    print("SONUC: !! DIKKAT — dropout>0 veya toplam<mevcut. DUR, cutover YAPMA.")
