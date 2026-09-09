#!/usr/bin/env bash
# DENETIM_DOGRULA_2 — kendi 3 hatali sorgumu duzelt, yeniden olc. SADECE OKUR.
#   ⚠ Once KOLON ADLARINI information_schema'dan al, sonra olc. Ezberden yazmam.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. DSO EVREN FARKI — tenant_id TIRNAKLI (onceki hata: trailing junk)"
$PSQL -c "
SELECT round(sum(satir_tutar) FILTER (WHERE ebat IS NULL)/1e6,1)     AS elenen_ebatsiz_m,
       round(sum(satir_tutar) FILTER (WHERE ebat IS NOT NULL)/1e6,1) AS lastik_m,
       round(sum(satir_tutar)/1e6,1)                                 AS toplam_m,
       round(100.0*sum(satir_tutar) FILTER (WHERE ebat IS NULL)/nullif(sum(satir_tutar),0),1) AS elenen_pct
  FROM bi_satis_faturalari
 WHERE tenant_id = '$T'
   AND miktar > 0 AND fatura_tarihi >= CURRENT_DATE - 365;"
echo "    ⚠ ANLAM #1: elenen_pct ~%20 ise, payda lastikle daralir, DSO ~21 gun sisik."

hr "2. master_musteri — GERCEK KOLON ADLARI (once bak, sonra olc)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='master_musteri' AND
          (column_name ILIKE '%bakiye%' OR column_name ILIKE '%borc%' OR column_name ILIKE '%pozisyon%'
           OR column_name ILIKE '%net%' OR column_name ILIKE '%risk%')
          ORDER BY ordinal_position;"

hr "2b. net_pozisyon kirliligi — kolon adlari yukaridan, simdi olc"
# ⚠ Kolon adlarini yukaridaki ciktidan DOGRULAYIP asagidaki sorguyu ona gore okumaliyim.
#   Guvenli genel olcum: hangi kolonlar varsa toplamlarini goster.
$PSQL -c "
SELECT
  round(sum(COALESCE(son_bakiye,0))/1e6,1)      AS son_bakiye_m,
  round(sum(COALESCE(net_pozisyon,0))/1e6,1)    AS net_pozisyon_m
  FROM master_musteri WHERE tenant_id = '$T';" 2>&1 | sed 's/^/    /'
echo "    (kolon hatasi verirse yukaridaki 2. adimdan gercek adi alip tekrar bakacagiz)"
echo "--- toplam tedarikci borcu (kiyas icin) ---"
$PSQL -c "SELECT round(abs(sum(tedarikci_bakiye))/1e6,1) AS ted_borc_m
          FROM bi_cari_bakiye WHERE tedarikci_bakiye < 0;"

hr "3. krb_audit_logs — var mi, kac kayit, ne yaziyor?"
$PSQL -c "SELECT to_regclass('public.krb_audit_logs') AS tablo_var_mi;"
$PSQL -c "SELECT count(*) AS kayit, min(created_at)::date AS ilk, max(created_at)::date AS son
          FROM krb_audit_logs;" 2>&1 | sed 's/^/    /'
echo "--- hangi action'lar (KRB is eylemi var mi)? ---"
$PSQL -c "SELECT action, count(*) FROM krb_audit_logs GROUP BY 1 ORDER BY 2 DESC LIMIT 15;" 2>&1 | sed 's/^/    /'

hr "4. TEKLIF — CHECK ile veri celisiyor mu? (ONAYLANDI CHECK'te yok gibiydi)"
$PSQL -c "
SELECT conname, pg_get_constraintdef(oid) AS taniM
  FROM pg_constraint
 WHERE conrelid = 'saha_teklif'::regclass AND contype='c'
   AND pg_get_constraintdef(oid) ILIKE '%durum%';" 2>&1 | sed 's/^/    /'
echo "--- gercek durum degerleri (CHECK'e uyuyor mu?) ---"
$PSQL -c "SELECT durum, count(*) FROM saha_teklif GROUP BY 1;"

hr "BITTI — bu uc olcum kanitlaninca kuyruk saglam zeminde"
