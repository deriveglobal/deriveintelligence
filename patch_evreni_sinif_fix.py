#!/usr/bin/env python3
# EVRENI_SINIF_FIX — musteri-evreni siniflamasini verify_umbrella.sql blok D ile BIREBIR yap.
#  Sorun: cust sorgusu f.miktar>0 filtreliyor + sinifi JS'te (psr>=ciro/2) yeniden hesapliyordu
#         -> ticari satirlar dusuyor, buyuk hesaplar yanlis TUK'a gidiyordu (nakit 35.8/14.1 yanlis).
#  Duzeltme: f.satir_tutar>0 (blok D ile ayni) + sinifi SQL'de hesapla (PSR-filter >= nonPSR-filter).
# Idempotent (EVRENI_SINIF_FIX varsa cikar).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "EVRENI_SINIF_FIX" in s:
    print("[skip] EVRENI_SINIF_FIX zaten var"); sys.exit(0)

OLD_CUST = '''      const cust = (await query("SELECT f.musteri_kodu kod, sum(f.satir_tutar)::float8 ciro, (sum(f.satir_tutar)-sum(f.miktar*a.birim_maliyet))::float8 kar, COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)='PSR'),0)::float8 psr FROM bi_satis_faturalari f JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date WHERE f.tenant_id::text=$1 AND " + fWin + " AND f.miktar>0 GROUP BY 1", params)).rows;'''
NEW_CUST = '''      const cust = (await query("SELECT f.musteri_kodu kod, sum(f.satir_tutar)::float8 ciro, (sum(f.satir_tutar)-sum(f.miktar*a.birim_maliyet))::float8 kar, CASE WHEN COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)='PSR'),0) >= COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)<>'PSR'),0) THEN 'TUK' ELSE 'TIC' END sinif FROM bi_satis_faturalari f JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date WHERE f.tenant_id::text=$1 AND " + fWin + " AND f.satir_tutar>0 GROUP BY 1", params)).rows; /* EVRENI_SINIF_FIX */'''

OLD_JS = '        const sinif = (c.psr || 0) >= (c.ciro || 0) / 2 ? "TUK" : "TIC";'
NEW_JS = '        const sinif = c.sinif;'

assert OLD_CUST in s, "HATA: cust sorgu satiri bulunamadi (musteri-evreni deploy edilmis mi?)"
assert OLD_JS in s, "HATA: JS sinif satiri bulunamadi"
s = s.replace(OLD_CUST, NEW_CUST, 1).replace(OLD_JS, NEW_JS, 1)
open(F, "w", encoding="utf-8").write(s)
print("[ok] EVRENI_SINIF_FIX uygulandi — siniflama artik blok D ile birebir (satir_tutar>0 + SQL sinif)")
