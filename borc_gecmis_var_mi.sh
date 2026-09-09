#!/usr/bin/env bash
# "Geçmiş borç kurulamaz" iddiamı ÇİFT KONTROL: ödeme feed'i / cari hareket / snapshot geçmişi var mı? SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_cari_bakiye — KAÇ farklı export_date var? (birden fazlaysa snapshot GEÇMİŞİ var!)"
$PSQL -c "SELECT count(DISTINCT export_date) farkli_gun, min(export_date)::text ilk, max(export_date)::text son
          FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid;"
$PSQL -c "SELECT export_date::text, count(*) FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 1 DESC LIMIT 10;" 2>&1 | sed 's/^/  /'
echo "  ⚠ Tek gün ise geçmiş yok; birden fazla gün varsa o günler için borç GÖRÜLEBİLİR."

hr "2. bi_tedarikci_faturalari — ödeme/kapanış tarihi kolonu VAR MI? (tahsilat gibi)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_tedarikci_faturalari'
            AND (column_name ~* 'odem|tahsil|kapan|vade|son_|tarih|bakiye') ORDER BY column_name;"

hr "3. TÜM tablolar — ödeme/tediye/cari-hareket benzeri tablo var mı? (kaçırmış olabilirim)"
$PSQL -c "SELECT table_name FROM information_schema.tables
          WHERE table_schema='public'
            AND (table_name ~* 'odem|tediye|payment|cari_har|cari_hesap|muhase|ekstre|hesap_har|tedarikci')
          ORDER BY 1;"

hr "4. bi_fatura_tahsilat — tedarikçi tarafını da içeriyor mu, yoksa sadece müşteri mi?"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='bi_fatura_tahsilat' ORDER BY ordinal_position;"

hr "5. Snapshot geçmişi — bi_musteri_risk / bi_stok_anlik da tek gün mü (pozisyon tabloları geneli)?"
$PSQL -c "SELECT 'musteri_risk' t, count(DISTINCT export_date) gun FROM bi_musteri_risk WHERE tenant_id='$T'::uuid
          UNION ALL SELECT 'stok_anlik', count(DISTINCT export_date) FROM bi_stok_anlik WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'

hr "BITTI — iddiam doğru mu (geçmiş borç yok) yoksa bir yol var mı, veri söyleyecek."
