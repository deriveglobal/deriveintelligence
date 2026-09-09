#!/usr/bin/env bash
# DSO KEŞİF — fonksiyon yazmadan ÖNCE kolon adları + tipler + desen doğrula. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_musteri_risk — hesap_bakiyesi + musteri_mi GERÇEKTEN var mı? tenant_id tipi?"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_musteri_risk' AND column_name IN ('hesap_bakiyesi','musteri_mi','tenant_id','muhatap_kodu')
          ORDER BY column_name;"

hr "2. bi_fatura_tahsilat — reconstruction kolonları (fatura_no, musteri_kodu, son_tahsilat) + tenant_id tipi?"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_fatura_tahsilat' AND column_name IN ('fatura_no','musteri_kodu','son_tahsilat','tenant_id')
          ORDER BY column_name;"

hr "3. bi_satis_faturalari — DSO payda kolonları + tenant_id tipi?"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_satis_faturalari' AND column_name IN ('odeme_kosulu','satir_tutar','fatura_tarihi','fatura_no','musteri_kodu','tenant_id')
          ORDER BY column_name;"

hr "4. KREDİ DESENİ — odeme_kosulu 'vade|çek|mukabili|mahsuben' gerçek değerleri yakalıyor mu?"
$PSQL -c "SELECT CASE WHEN odeme_kosulu ~* 'vade|çek|mukabili|mahsuben' THEN 'KREDİLİ' ELSE 'peşin/diğer' END sinif,
                 count(*), round(sum(satir_tutar)/1e6,1) tutar_m
          FROM bi_satis_faturalari WHERE tenant_id='$T' AND fatura_tarihi >= CURRENT_DATE - 365
          GROUP BY 1 ORDER BY 2 DESC;"
echo "  --- hangi odeme_kosulu KREDİLİ sayıldı (kontrol) ---"
$PSQL -c "SELECT odeme_kosulu, count(*) FROM bi_satis_faturalari
          WHERE tenant_id='$T' AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben'
          GROUP BY 1 ORDER BY 2 DESC LIMIT 12;" 2>&1 | sed 's/^/  /'

hr "5. BUGÜNKÜ DSO BİLEŞENLERİ — alacak (gerçek) ÷ günlük kredili → ~83 mi?"
$PSQL -c "
WITH a AS (SELECT sum(hesap_bakiyesi) alacak FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true)=true),
     k AS (SELECT sum(satir_tutar)/365 gunluk FROM bi_satis_faturalari
            WHERE tenant_id='$T' AND fatura_tarihi >= CURRENT_DATE-365 AND odeme_kosulu ~* 'vade|çek|mukabili|mahsuben')
SELECT round(a.alacak/1e6,1) alacak_m, round(k.gunluk/1e6,2) gunluk_kredili_m,
       round(a.alacak/k.gunluk) dso_gun FROM a,k;"
echo "  ⚠ dso_gun ~83 civarıysa fonksiyon tanımı sağlam."

hr "6. RECONSTRUCTION SAPMASI — alacak_recon(bugün) vs alacak_gerçek: hâlâ ~%7 mi?"
RECON=$($PSQL -tAc "
  SELECT round(sum(s.satir_tutar)/1e6,1) FROM bi_satis_faturalari s
   LEFT JOIN (SELECT DISTINCT fatura_no,musteri_kodu,son_tahsilat FROM bi_fatura_tahsilat WHERE tenant_id='$T'::uuid) t
     ON t.fatura_no=s.fatura_no AND t.musteri_kodu=s.musteri_kodu
   WHERE s.tenant_id='$T' AND s.fatura_tarihi<=CURRENT_DATE
     AND (t.fatura_no IS NULL OR t.son_tahsilat>CURRENT_DATE)" | tr -d '[:space:]')
GERCEK=$($PSQL -tAc "SELECT round(sum(hesap_bakiyesi)/1e6,1) FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true)=true" | tr -d '[:space:]')
echo "  reconstruction: ~${RECON}M · gerçek (bi_musteri_risk): ~${GERCEK}M"
echo "  ⚠ Fark ~%7 ise: geçmiş backfill 'yaklasik' güvenle meşru; bugün+ileri 'snapshot' kesin."

hr "BITTI — kolonlar doğrulandı, desen tutuyor mu görüldü. Sonra fonksiyon+backfill yazılır."
