#!/usr/bin/env bash
# METRIK 3E — ayrisma ITHAL/YERLI ile ortusuyor mu? marka marka + tedarikci ulke. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. MARKA MARKA — son alis vs maliyet_ay orani (ithal 2x, yerli 1x bekleniyor)"
$PSQL -c "
WITH son_alis AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric f FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid AND birim_fiyat_kdv_haric>0 ORDER BY kalem_kodu, fatura_tarihi DESC),
may AS (SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_maliyet f FROM bi_maliyet_ay WHERE tenant_id='$T'::uuid AND birim_maliyet>0 ORDER BY kalem_kodu, ay DESC)
SELECT COALESCE(s.marka,'(bos)') marka,
       round(sum(s.adet)) adet,
       round(sum(s.adet*sa.f)/1e6,1) son_alis_m,
       round(sum(s.adet*may.f)/1e6,1) maliyet_ay_m,
       round(sum(s.adet*may.f)/nullif(sum(s.adet*sa.f),0),2) oran
  FROM bi_stok_anlik s JOIN son_alis sa ON sa.kalem_kodu=s.kalem_kodu JOIN may ON may.kalem_kodu=s.kalem_kodu
 WHERE s.tenant_id='$T'::uuid GROUP BY 1 ORDER BY 3 DESC NULLS LAST LIMIT 20;"
echo "  ⚠ oran ~2 olan markalar ITHAL (Sailun/Atrezzo, Windforce...), ~1 olanlar YERLI (Brisa/Lassa/Petlas)?"

hr "2. TEDARIKCI ULKE — ithal tedarikciler (yurtdisi isimli) hangileri?"
$PSQL -c "
SELECT DISTINCT left(tedarikci_adi,40) tedarikci
  FROM bi_tedarikci_faturalari WHERE tenant_id='$T'::uuid
   AND tedarikci_adi ~* 'hangkong|hong kong|group|co\.|gmbh|s\.r\.l|import|ithalat|ltd\.$|china|deutschland'
 ORDER BY 1 LIMIT 20;"
echo "  ⚠ Bu tedarikcilerin faturasi CIPLAK (gumruk haric) — landed cost ayrica."

hr "3. ⚠ landed cost / gumruk KAYITLI mi? (kolon/tablo var mi)"
$PSQL -c "SELECT table_name, column_name FROM information_schema.columns
          WHERE column_name ~* 'gumruk|damping|landed|navlun|ithalat|maliyet' AND table_name ~* 'tedarik|maliyet|stok'
          ORDER BY 1,2;" 2>&1 | sed 's/^/  /'
echo "  ⚠ Yoksa: landed cost YOK; kupun 1451'i nereden geliyor? (kup insasi incelenmeli)"

hr "BITTI — ithal/yerli ortusuyorsa teori kanit; landed cost kaynagi belirlenmeli"
