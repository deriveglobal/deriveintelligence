#!/usr/bin/env bash
# GORUNUM_KESIF — 62 sorguyu tek tek yazmak yerine OLU TABLOLARI GORUNUME cevirecegim.
#
# ✅ NEDEN: ayni isim, ayni kolon adlari — ama arkasinda CANLI veri.
#   62 sorgunun HICBIRINE dokunmadan hepsi dogru veriyi okur.
#   bi_stok_durumu.toplam_deger artik 10 kat siskin bir kolon degil,
#   tedarikci faturasindan hesaplanan GERCEK deger olur.
#   Ve olu tablolar GERCEKTEN olur — bir daha kimse yanlislikla yazamaz.
#
# ⚠ ENGEL: sunucu ACILISTA bu tablolar icin CREATE TABLE + CREATE INDEX calistiriyor.
#   Gorunum varken CREATE INDEX PATLAR. Once o satirlari GORECEGIM. Tahmin yok.
#
# ⚠ VE KONTROL: bu tablolara YAZAN bir sey var mi? (varsa gorunum kiramaz)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ACILIS SEMASI — CREATE TABLE / INDEX satirlari ############"
awk 'NR>=20060 && NR<=20190 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 2) ⚠ BU TABLOLARA YAZAN VAR MI? (INSERT/UPDATE/DELETE/COPY) ############"
for T in bi_stok_durumu bi_stok_hareketleri bi_musteri_bakiye bi_odeme_gecmisi; do
  echo "  ══ $T ══"
  grep -rn "INSERT INTO $T\|UPDATE $T\|DELETE FROM $T\|COPY $T\|TRUNCATE $T" \
    --include=*.mjs --include=*.py --include=*.sql . 2>/dev/null \
    | grep -v "srv_broken\|\.bak_\|_yedek" | head -5
  echo "    (yukaridaki bos ise: kimse YAZMIYOR -> gorunume cevirmek GUVENLI)"
done

echo
echo "############ 3) ERP MOTORU bu tablolari yukluyor mu? ############"
grep -n "bi_stok_durumu\|bi_stok_hareketleri\|bi_musteri_bakiye\|bi_odeme_gecmisi" erp_ingest.py | head

echo
echo "############ 4) bi_sku_norm — gorunumde kullanacagim, VAR MI? ############"
$PSQL -c "SELECT proname, pg_get_function_result(oid) FROM pg_proc WHERE proname LIKE 'bi_sku%';"

echo
echo "############ 5) KOLON HARITASI — gorunum icin (varsaymadan) ############"
echo "  --- bi_stok_durumu (OLU) kolonlari: sorgular BUNLARI bekliyor ---"
$PSQL -c "SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_stok_durumu';"
echo "  --- bi_stok_anlik (CANLI) kolonlari: bunlardan uretecegim ---"
$PSQL -c "SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_stok_anlik';"
echo
echo "  --- bi_stok_hareketleri (OLU) ---"
$PSQL -c "SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_stok_hareketleri';"
echo "  --- bi_stok_hareket (CANLI) ---"
$PSQL -c "SELECT string_agg(column_name, ', ' ORDER BY ordinal_position) FROM information_schema.columns WHERE table_name='bi_stok_hareket';"
