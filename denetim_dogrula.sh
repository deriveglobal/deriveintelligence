#!/usr/bin/env bash
# DENETIM_DOGRULA — 5 denetimin "olctum" iddialarini TEK read-only gecisle teyit et.
#   Hicbir sey degistirmez. Her bulgunun yaninda: iddia / gercek / karar.
#   ⚠ Denetimler paralel oturumdan geldi; sayilarini KORLEMESINE almiyorum.
#   ⚠ Ayrica: aksam duzeltmeleri (yama_sabit_sayilar, koken_guncelle) CANLIDA mi?
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SRC="server_container.mjs"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "A. 'TEK GERCEGIN IKI ADI' — en cok tekrar eden aile"

echo "--- A1) TEKLIF durum dagilimi (rapor 'KAZANILDI' sayiyor, akis ne yaziyor?) ---"
$PSQL -c "SELECT durum, count(*) FROM saha_teklif GROUP BY 1 ORDER BY 2 DESC;"
echo "    ⚠ FIYAT/SAHA R2: KAZANILDI hic var mi? yoksa rapor kazanmayi hep 0 sayar."
echo "--- rapor/teklif kodu hangi enum'u sayiyor? ---"
grep -nE "KAZANILDI|ONAYLANDI" "$SRC" | grep -iE "rapor|kazan|durum *=" | head -12 | sed 's/^/    /'

echo
echo "--- A2) MUSTERI durum dagilimi (RISKLI_NOKTA fonksiyonda yok — var mi? ESKI_NOKTA rapora giriyor mu?) ---"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"
echo "--- rapor/ozet 'pasif/riskli'yi nasil sayiyor? (ESKI_NOKTA dahil mi?) ---"
grep -nE "PASIF_NOKTA|RISKLI_NOKTA|ESKI_NOKTA" "$SRC" | head -15 | sed 's/^/    /'
echo "--- durum'u yazan KOD YOLLARI kac tane? (fonksiyon + baska) ---"
grep -nE "RISKLI_NOKTA" "$SRC" | grep -iE "set|update|=|insert" | head | sed 's/^/    /'

echo
echo "--- A3) PARA BIRIMI etiket bolunmesi TL vs TRY ---"
$PSQL -c "SELECT para_birimi, count(*) FROM bi_fiyat_listesi_kalemler GROUP BY 1 ORDER BY 2 DESC;"
echo "    ⚠ FIYAT #1: iki etiket varsa, tek etiket filtreleyen sorgu otekini kacirir."

hr "B. DSO — uc kaynak + 21 gun siskinlik"
echo "--- B1) DSO uc kaynagi hangi tablolardan? ---"
grep -noE "FROM (bi_fatura_tahsilat|bi_odeme_gecmisi|bi_musteri_risk)" "$SRC" | sort | uniq -c | sed 's/^/    /'
echo "--- B2) DSO evren farki: ebat NULL ile elenen ciro ---"
$PSQL -c "
SELECT round(sum(satir_tutar) FILTER (WHERE ebat IS NULL)/1e6,1) AS elenen_m,
       round(sum(satir_tutar) FILTER (WHERE ebat IS NOT NULL)/1e6,1) AS lastik_m,
       round(sum(satir_tutar)/1e6,1) AS toplam_m
  FROM bi_satis_faturalari
 WHERE tenant_id=$T::text AND miktar>0 AND fatura_tarihi>=CURRENT_DATE-365;"
echo "    ⚠ ANLAM #1: pay TUM alacak, payda SADECE lastik -> DSO ~21 gun sisik."

hr "C. tenant_id TEXT tuzagi"
$PSQL -c "SELECT data_type, count(*) FROM information_schema.columns
          WHERE column_name='tenant_id' AND table_name NOT LIKE '%yedek%' GROUP BY 1;"
echo "--- TEXT olan saha_* tablolari (join'de patlar) ---"
$PSQL -c "SELECT table_name FROM information_schema.columns
          WHERE column_name='tenant_id' AND data_type='text' AND table_name LIKE 'saha_%';"
echo "    ⚠ SAHA #4: saha_musteri_tedarikci_destek TEXT bekleniyor."

hr "D. export_date yazili olmayan sozlesme"
for t in bi_musteri_risk bi_stok_anlik bi_cari_bakiye; do
  ref=$(grep -oE "FROM $t\b|JOIN $t\b" "$SRC" | wc -l | tr -d ' ')
  flt=$(grep -oE "$t[^;]{0,400}export_date" "$SRC" | wc -l | tr -d ' ')
  echo "    $t: ~$ref referans, kabaca $flt export_date filtreli"
done
echo "    ⚠ DENETIM #1: DELETE FROM garantisi motorun, sorgunun degil."

hr "E. Sessiz catch — 8 kritik hala bos mu?"
bosCatch=$(grep -cE "catch\s*(\([a-z_]*\))?\s*\{\s*\}" "$SRC")
echo "    tamamen bos catch sayisi: $bosCatch"
echo "--- kritik satirlar hala bos mu? (28715 civari ziyaret sinyali, 26314 teklif log, 21811 audit) ---"
for ln in 21811 21821 26314 26320 28715; do
  printf "    %s: " "$ln"; sed -n "${ln}p" "$SRC" | sed 's/^ *//' | cut -c1-90
done

hr "F. Denetim gunlugu — bos mu, kurgu mu?"
$PSQL -c "SELECT count(*) AS krb_audit_kayit, max(created_at)::date AS son FROM krb_audit_logs;" 2>/dev/null || echo "    (krb_audit_logs yok?)"
echo "--- kurgu tablolar koda referansli mi? ---"
for t in security_audit_log security_events audit_events login_attempt_log ip_blocks; do
  n=$(grep -c "$t" "$SRC"); echo "    $t: kodda $n referans"
done
echo "--- saha_denetim ne kaydediyor? ---"
$PSQL -c "SELECT eylem, count(*) FROM saha_denetim GROUP BY 1 ORDER BY 2 DESC;" 2>/dev/null

hr "G. PROMPT SABITLERI — aksam yamasi (yama_sabit_sayilar) CANLIDA mi?"
echo "--- sokulmus olmasi gereken string'ler hala VAR mi? (varsa yama uygulanmamis) ---"
for s in "DSO ~59-87" "CCC < 30" "DPO (~68-84)" "121,76 M TL" "38.604 muhatap" "USD ~₺46"; do
  n=$(grep -cF "$s" "$SRC"); echo "    \"$s\": $n kez (0 = sokulmus)"
done
echo "--- %7,1 + adet:32000 zinciri (DENETIM #3 — AYRI is, yama bunu kapsamiyordu) ---"
grep -nE "7\.1|%7,1|adet: *(25000|32000|40000)" "$SRC" | head | sed 's/^/    /'

hr "H. KOKEN tablosu — koken_guncelle CANLIDA mi? iddia rakami kaldi mi?"
$PSQL -c "
SELECT anahtar,
       (kaynak ~ '[0-9]{2,}[.,][0-9]|[0-9]+ ?M') AS kaynakta_rakam,
       (sinir  ~ '[0-9]{2,}[.,][0-9]|[0-9]+ ?M') AS sinirda_rakam
  FROM bi_sayi_koken
 WHERE anahtar <> 'brisa_takvim'
 ORDER BY 1;" 2>/dev/null || echo "    (bi_sayi_koken yok?)"

hr "I. master_musteri.net_pozisyon kirli mi? (risk listesi bunun ustunde)"
$PSQL -c "
SELECT round(sum(son_bakiye)/1e6,1) AS son_bakiye_m,
       round(sum(bizim_borcumuz)/1e6,1) AS bizim_borc_m,
       round(sum(net_pozisyon)/1e6,1) AS net_m
  FROM master_musteri WHERE tenant_id=$T::uuid;" 2>/dev/null
echo "    ⚠ ANLAM #2: bizim_borcumuz ~ toplam tedarikci borcu ise, borc musteriye cekilmis (kirli)."

hr "J. segment yazicisi 13 Tem'de durdu mu? (rakip)"
$PSQL -c "
SELECT scraped_at::date AS gun,
       count(*) FILTER (WHERE segment IS NULL OR segment='') AS bos,
       count(*) FILTER (WHERE segment<>'') AS dolu
  FROM bi_rakip_fiyat GROUP BY 1 ORDER BY 1 DESC LIMIT 6;" 2>/dev/null

hr "K. OLU/KULLANILMAYAN ozellikler — canli test gereken bosluklar"
$PSQL -c "
SELECT 'saha_iskonto_talep' t, count(*) FROM saha_iskonto_talep
UNION ALL SELECT 'saha_konusma', count(*) FROM saha_konusma
UNION ALL SELECT 'saha_konusma_mesaj', count(*) FROM saha_konusma_mesaj
UNION ALL SELECT 'bi_tedarikci_kampanya', count(*) FROM bi_tedarikci_kampanya
UNION ALL SELECT 'bi_rakip_izle', count(*) FROM bi_rakip_izle
UNION ALL SELECT 'bi_rakip_fiyat_alarm', count(*) FROM bi_rakip_fiyat_alarm
UNION ALL SELECT 'bi_rakip_izle_taban_bos', count(*) FROM bi_rakip_izle WHERE son_min_fiyat IS NULL;" 2>/dev/null

hr "L. RLS kapali tablo sayisi"
$PSQL -c "SELECT count(*) FILTER(WHERE relrowsecurity) AS acik,
                 count(*) FILTER(WHERE NOT relrowsecurity) AS kapali
          FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname='public' AND c.relkind='r';"

hr "M. Dagitim — build context sismesi"
echo "    .dockerignore var mi: $([ -f .dockerignore ] && echo VAR || echo YOK)"
echo "    kok dizindeki buyuk ham dosyalar (>10MB):"
find . -maxdepth 1 -type f -size +10M -exec ls -lh {} \; 2>/dev/null | awk '{print "      "$5"  "$9}'

hr "N. Kucuk mayinlar"
echo "--- goruldu-hepsi: tid tanimsiz mi? (satir ~20981) ---"
grep -nE "goruldu-hepsi" "$SRC" | head | sed 's/^/    /'
echo "--- /api/rakip/ayar cift tanimli mi? ---"
grep -nE "/api/rakip/ayar" "$SRC" | head | sed 's/^/    /'

hr "BITTI"
echo "Bu ciktiyi oldugu gibi yapistir. Hicbir sayiyi hafizamdan yazmayacagim; kuyrugu buradan kuracagiz."
