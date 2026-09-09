#!/usr/bin/env bash
# METRIK 2 — TEDARIKCI BORCU. Sablon: fonksiyon + canli + capraz-kontrol + SINIR. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_cari_bakiye — YAPI (tedarikci_bakiye nasil? isaret?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_cari_bakiye' ORDER BY ordinal_position;"
echo "  --- ornek 3 satir ---"
$PSQL -c "SELECT * FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid LIMIT 3;" 2>&1 | sed 's/^/  /'

hr "2. FONKSIYON (canli) — toplam tedarikci borcu = SUM(abs(negatif bakiye))"
$PSQL -c "
SELECT round(sum(abs(tedarikci_bakiye)) FILTER (WHERE tedarikci_bakiye<0)/1e6,1) AS borc_m,
       round(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye>0)/1e6,1)      AS bizim_alacak_m,
       count(*) FILTER (WHERE tedarikci_bakiye<0) AS borclu_oldugumuz,
       count(*) AS toplam_cari
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;"
echo "  ⚠ tedarikci_bakiye NEGATIF = biz borçluyuz (isaret tuzagi — daha once yanildik)."

hr "3. YOGUNLASMA — kime ne kadar? (Brisa?)"
$PSQL -c "
SELECT COALESCE(cari_adi, cari_kodu, '(?)') AS tedarikci,
       round(abs(tedarikci_bakiye)/1e6,1) AS borc_m
  FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND tedarikci_bakiye<0
 ORDER BY abs(tedarikci_bakiye) DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "4. ⚠ KAPSAM — tedarikciler LASTIK markasi mi? (lastik-only bolunebilir mi)"
echo "  ⚠ Suppliers Brisa/Bridgestone/Lassa/Michelin ise: dogal lastik. Servis tedarikcisi varsa karisik."
echo "  (yukaridaki liste zaten gosteriyor — lastik markasi mi bak)"

hr "5. ⚠ CAPRAZ-KONTROL kaynagi — alis − odeme ile tutar mi? odeme tablosu var mi?"
echo "  --- tedarikci odeme/tahsilat tablosu var mi? ---"
$PSQL -c "SELECT table_name FROM information_schema.tables
          WHERE table_schema='public' AND (table_name ILIKE '%tedarik%odeme%' OR table_name ILIKE '%tedarik%tahsil%' OR table_name ILIKE '%alis%odeme%');" 2>&1 | sed 's/^/  /'
echo "  --- toplam alis (bi_tedarikci_faturalari) — borçla kiyas icin ---"
$PSQL -c "SELECT round(sum(birim_fiyat_kdv_haric*miktar)/1e6,1) AS alis_net_m, count(*) FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ Alacak gibi: borc = alislar − odemeler. Odeme tablosu yoksa ERP'nin kendi rakami capraz-kontrol."

hr "6. ⚠ ERP KENDI net_pozisyon'u — #119 baglantisi (yeniden hesaplama tuzagi)"
echo "  ⚠ DSO'da ders: ERP net_pozisyon'u zaten hesapliyor; tedarikci_bakiye NEGATIF."
echo "     master_musteri.bizim_borcumuz bu koku cekiyordu (kirli, #119). Metrik onu DEGIL, bi_cari_bakiye'yi okumali."

hr "BITTI — yapi+capraz-kontrol netlesince tedarikci borcu tanimini yazarim"
