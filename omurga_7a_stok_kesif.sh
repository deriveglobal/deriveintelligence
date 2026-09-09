#!/usr/bin/env bash
# STOK KEŞİF — fonksiyon yazmadan ÖNCE kolonlar + hareket sınıfı + tarih aralığı (#100 donma?). SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_stok_hareket — TÜM kolonlar (giriş/çıkış miktar+tutar, sku, tarih, sınıf adları?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_stok_hareket' ORDER BY ordinal_position;"

hr "2. bi_stok_anlik — TÜM kolonlar (adet, sku/kalem, marka, grup_adi?)"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns
          WHERE table_name='bi_stok_anlik' ORDER BY ordinal_position;"

hr "3. ÖRNEK SATIR — bi_stok_hareket (gerçek değerlerle kolon adlarını gör)"
$PSQL -x -c "SELECT * FROM bi_stok_hareket WHERE tenant_id='$T'::uuid LIMIT 2;" 2>&1 | head -50

hr "4. ÖRNEK SATIR — bi_stok_anlik"
$PSQL -x -c "SELECT * FROM bi_stok_anlik WHERE tenant_id='$T'::uuid LIMIT 2;" 2>&1 | head -40

hr "5. HAREKET SINIFI / BELGE TÜRÜ — hangisi GİRİŞ hangisi ÇIKIŞ (reconstruction için)"
$PSQL -c "SELECT hareket_sinifi, count(*) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT belge_turu, count(*) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid GROUP BY 1 ORDER BY 2 DESC LIMIT 15;" 2>&1 | sed 's/^/  /'

hr "6. ⚠ HAREKET TARİH ARALIĞI — #100: akış 12 Haziran'da mı donmuş? (reconstruction'ı etkiler)"
$PSQL -c "SELECT min(tarih)::text ilk, max(tarih)::text son, count(*) FROM bi_stok_hareket WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
echo "  ⚠ 'tarih' kolonu yoksa yukarıda hata çıkar — §1'den doğru tarih kolonu adını alırım."

hr "7. MALİYET KÜPLERİ — bi_maliyet_sku / bi_maliyet_ay var mı (hazır ağırlıklı ort)?"
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_name IN ('bi_maliyet_sku','bi_maliyet_ay');"
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='bi_maliyet_sku' ORDER BY ordinal_position;" 2>&1 | sed 's/^/  /'

hr "BITTI — kolonlar+sınıf+tarih görüldü. Sonra stok_degeri fonksiyonu + reconstruction yazılır."
