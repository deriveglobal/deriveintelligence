#!/usr/bin/env bash
# STOK RECONCILE — §4 uyuşmazlığı kapsam/ikiye-sayım mı gerçek mi? Adil test. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. İKİYE-SAYIM DEDEKTÖRÜ — Σgiris/Σcikis her hareket_sinifi'nda (hangi sınıf stok oynatıyor?)"
$PSQL -c "SELECT hareket_sinifi,
                 round(sum(giris)) top_giris, round(sum(cikis)) top_cikis,
                 round(sum(giris)-sum(cikis)) net
          FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY abs(sum(giris)-sum(cikis)) DESC;"
echo "  ⚠ Hem MAL_GIRISI hem ALIS_FATURA büyük giris veriyorsa = alış ikiye sayılıyor (fiziksel + mali)."

hr "2. KAPSAM-EŞLEŞMELİ — sadece snapshot'taki kalemler, TÜM depo (transfer netlenir): net vs adet"
$PSQL -c "
WITH anlik AS (SELECT kalem_kodu, sum(adet) adet FROM bi_stok_anlik WHERE tenant_id='$T'::uuid GROUP BY 1),
     mov   AS (SELECT kalem_kodu, sum(giris)-sum(cikis) qty FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1)
SELECT round(sum(a.adet)) anlik_adet,
       round(sum(m.qty)) hareket_net_sadece_snapshot_kalemleri,
       count(*) kalem,
       count(*) FILTER (WHERE abs(COALESCE(m.qty,0)-a.adet) <= greatest(a.adet*0.05,1)) eslesen_5pct
  FROM anlik a LEFT JOIN mov m USING(kalem_kodu);"
echo "  ⚠ eslesen_5pct / kalem yüksekse reconstruction meşru; düşükse hareket stok defterini tutmuyor."

hr "3. FİZİKSEL-SINIF reconstruction — sadece stok oynatanları say (mali fatura sınıflarını dışla) test"
$PSQL -c "
WITH anlik AS (SELECT kalem_kodu, sum(adet) adet FROM bi_stok_anlik WHERE tenant_id='$T'::uuid GROUP BY 1),
     mov   AS (SELECT kalem_kodu, sum(giris)-sum(cikis) qty FROM bi_stok_hareket
                WHERE tenant_id='$T'::uuid
                  AND hareket_sinifi NOT IN ('ALIS_FATURA','SATIS_FATURA')   -- mali ikizleri dışla test
                GROUP BY 1)
SELECT round(sum(a.adet)) anlik_adet, round(sum(m.qty)) hareket_net_fiziksel,
       count(*) FILTER (WHERE abs(COALESCE(m.qty,0)-a.adet) <= greatest(a.adet*0.05,1)) eslesen_5pct,
       count(*) kalem
  FROM anlik a LEFT JOIN mov m USING(kalem_kodu);"
echo "  ⚠ Bu daha yakınsa ikiye-sayım kanıtı; fiziksel sınıf seti reconstruction anahtarı olur."

hr "4. ÖRNEK KALEM — bir SKU'nun snapshot adedi vs hareket dökümü (gözle gör)"
$PSQL -c "
WITH tek AS (SELECT kalem_kodu FROM bi_stok_anlik WHERE tenant_id='$T'::uuid AND adet>100 ORDER BY adet DESC LIMIT 1)
SELECT hareket_sinifi, round(sum(giris)) giris, round(sum(cikis)) cikis
  FROM bi_stok_hareket WHERE tenant_id='$T'::uuid AND kalem_kodu=(SELECT kalem_kodu FROM tek)
 GROUP BY 1 ORDER BY 1;"
$PSQL -c "WITH tek AS (SELECT kalem_kodu FROM bi_stok_anlik WHERE tenant_id='$T'::uuid AND adet>100 ORDER BY adet DESC LIMIT 1)
          SELECT kalem_kodu, sum(adet) snapshot_adet FROM bi_stok_anlik
          WHERE tenant_id='$T'::uuid AND kalem_kodu=(SELECT kalem_kodu FROM tek) GROUP BY 1;"

hr "BITTI — reconstruction viable mi kesin görülecek. Değilse stok = snapshot-only (bugün+ileri, geçmiş yok)."
