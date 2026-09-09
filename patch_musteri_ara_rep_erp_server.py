#!/usr/bin/env python3
# MUSTERI_ARA_REP_ERP_V1 (server) — Yildiray 04.08: "Sirayhan Hafriyat SAP'ta var ama aktivite
#   girmek icin bulamiyorum". Kok-neden: GET /api/saha/musteri-ara rep'lere ERP carilerini HIC
#   dondurmuyordu (`const cari = isRep ? { rows: [] } : ...`, MUSTERI_ARA_REP_SCOPE_V1). Rep yalniz
#   kendine atali saha musterilerini goruyordu; yalniz ERP'de olan (saha'ya girilmemis) cariyi
#   bulamiyor → aktivite giremiyor. Sirayhan ERP'de var (M4134926), saha'da yok, Yildiray = rep.
#   Fatih karari: ERP carileri rep aramasina ACILSIN (rep 'ERP cariyi sahaya ekle' ile koda bagli
#   ekleyip aktivite girer). Fix: isRep guard'ini kaldir — master_musteri sorgusu rep icin de calissin.
#   SAHA sonuclari yine sorumlu_rep ile scoped kalir; yalniz ERP arama tenant genelinde acilir.
#   Idempotent (marker: MUSTERI_ARA_REP_ERP_V1).
import sys

path = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
with open(path, "r", encoding="utf-8") as f:
    src = f.read()
orig = src
MARK = "MUSTERI_ARA_REP_ERP_V1"

if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

old = "      const cari = isRep ? { rows: [] } : await query(`"
new = "      const cari = /* " + MARK + " — rep de ERP (SAP) carileri arayabilir */ await query(`"
if old not in src:
    print("HATA: 'const cari = isRep ...' anchor bulunamadi"); sys.exit(1)
src = src.replace(old, new, 1)
print("[+] isRep ERP kisiti kaldirildi (rep de ERP carileri gorur)")

if src == orig:
    print("[=] Degisiklik yok")
else:
    with open(path, "w", encoding="utf-8") as f:
        f.write(src)
    print("[ok] yazildi:", path)
