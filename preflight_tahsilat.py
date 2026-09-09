#!/usr/bin/env python3
# TAHSILAT SUNUCU ON-UCUS (read-only). DB'ye YAZMAZ. Yamali motorun oku()'su ile dosyayi isler,
#   uretilecek cari satirlarini + sistem toplamlarini gosterir. Konteyner icinde:
#   docker exec -u root krb-assessment python3 /tmp/preflight_tahsilat.py /tmp/t.xlsx
import sys
sys.path.insert(0, "/app"); sys.path.insert(0, "/opt/krb-assessment"); sys.path.insert(0, ".")
import erp_ingest as eng
def fm(x): return format(round(x), ",").replace(",", ".")
F = sys.argv[1]
tip, satir, istat = eng.oku(F)
assert tip == "tahsilat", "TIP YANLIS: " + str(tip)
kap = eng.kapilari_kos(tip, satir)
dusen = [g for g in kap if not g["gecti"]]
mus = [r for r in satir if r["musteri_mi"]]
rec = [r for r in satir if r["son12_adedi"] > 0]
tot = sum(r["toplam_tahsilat"] for r in satir)
wsure = sum(r["ort_tahsilat_suresi"] * r["toplam_tahsilat"] for r in satir)
late = sum(r["gec_odeme_orani"] / 100 * r["toplam_tahsilat"] for r in satir)
print("== TAHSILAT ON-UCUS (DB'ye yazilmadi) ==")
print("tip:", tip, "| cari:", len(satir), "| musteri_mi:", len(mus), "| son12 aktif:", len(rec))
print("kapilar:", [(g["kapi"], "GECTI" if g["gecti"] else "DUSTU") for g in kap])
print("DUSEN KAPI:", len(dusen), "->", "YUKLEME REDDEDILIR" if dusen else "yukleme gecer")
print("toplam tahsilat:", fm(tot))
print("sistem tutar-agirlikli ort suresi:", round(wsure / tot, 1), "gun")
print("sistem gec-oran (tutar):", round(100 * late / tot, 1), "%")
print("mukerrer(dogal_anahtar):", eng.mukerrer_bul(tip, satir)[0])
for r in satir:
    if "ROTA" in r["muhatap_adi"].upper():
        print("ROTA: adet", r["tahsilat_adedi"], "sure", r["ort_tahsilat_suresi"], "gec%", r["gec_odeme_orani"],
              "son12[ad=%s,gec%%=%s]" % (r["son12_adedi"], r["son12_gec_orani"]), "son", r["son_tahsilat_tarihi"]); break
print("\nBEKLENEN (yerel dry-run): cari 38.605, musteri_mi 38.422, son12 aktif ~11.718,")
print("  toplam 5.069.717.128, sure 30,1 gun, gec-oran 52,5%. Eslesiyorsa GO.")
