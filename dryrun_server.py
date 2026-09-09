#!/usr/bin/env python3
# ALACAK_YASLANDIRMA — SUNUCU ÖN-UÇUŞ (read-only). DB'ye YAZMAZ. Yamalı erp_ingest.oku() ile
# dosyayı işler, üretilecek cari satırlarını ve toplamları gösterir. Cutover ÖNCESİ çalıştır,
# sayıların doğrulanmış dry-run ile aynı olduğunu teyit et. Sunucuda /opt/krb-assessment içinde:
#   docker exec -i krb-assessment sh -c "cat > /tmp/dr.py && cat > /tmp/f.xlsx" ... (ya da dosyayı /tmp'e koy)
#   python3 dryrun_server.py /tmp/f.xlsx
import sys
sys.path.insert(0, "/opt/krb-assessment")
sys.path.insert(0, ".")
import erp_ingest as eng   # yamalı motor
def fm(x): return format(round(x), ",").replace(",", ".")
F = sys.argv[1]
tip, satir, istat = eng.oku(F)
assert tip == "alacak_yaslandirma", "TİP YANLIŞ: " + str(tip)
kap = eng.kapilari_kos(tip, satir)
dusen = [g for g in kap if not g["gecti"]]
mus = [r for r in satir if r["musteri_mi"]]
alacak = sum(max(r["hesap_bakiyesi"], 0) for r in mus)
gec = sum(r["vadesi_gecmis"] for r in mus)
print("== ÖN-UÇUŞ (DB'ye yazılmadı) ==")
print("tip:", tip, "| cari:", len(satir), "| musteri_mi:", len(mus))
print("kapılar:", [(g["kapi"], "GEÇTİ" if g["gecti"] else "DÜŞTÜ") for g in kap])
print("DÜŞEN KAPI:", len(dusen), "->", "YÜKLEME REDDEDİLİR" if dusen else "yükleme geçer")
print("alacak:", fm(alacak), "| gecikmiş(FIFO):", fm(gec), "| kredi limiti:", fm(sum(r["kredi_limiti"] for r in mus)))
print("mükerrer(dogal_anahtar):", eng.mukerrer_bul(tip, satir)[0])
for r in satir:
    if "ROTA" in r["muhatap_adi"].upper():
        print("ROTA: bakiye", fm(r["hesap_bakiyesi"]), "limit", fm(r["kredi_limiti"]), "vadesi", fm(r["vadesi_gecmis"])); break
print("\nBEKLENEN (24 Tem doğrulama): cari~1383, musteri_mi~1336, alacak~233,9M, gecikmiş~92,2M, ROTA bakiye 1.509.181 vadesi 0")
print("→ Sayılar eşleşiyorsa GO. Eşleşmiyorsa DUR, dosyayı/again incele.")
