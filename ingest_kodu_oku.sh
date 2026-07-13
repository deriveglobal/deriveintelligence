#!/usr/bin/env bash
# Salt okuma. Ingest kodunu GORMEK istiyorum -- bir daha tahmin etmeyecegim.
# Merak: sayilari DOGRU okuyor (DB ortalama 5.85), tarihi YANLIS.
# Nasil? Nerede? Onu gorelim.
S=/opt/krb-assessment/server_container.mjs

echo "############ 1) Excel okuyucu (XLSX.read) — cellDates var mi? ############"
sed -n '9005,9030p' $S
echo "  ^ cellDates:true YOKSA tarihler seri sayi/metin olarak gelir."

echo
echo "############ 2) SAYI ayristirici — /10000 NEREDE? ############"
grep -n "10000\|10_000\|1e4\|parseFloat\|Number(\|replace(/\." $S \
  | sed -n '1,40p'

echo
echo "############ 3) SATIS ingest fonksiyonu (asil yer) ############"
grep -n "satis_faturalari\|INSERT INTO bi_satis" $S | head
echo "  -- INSERT'in etrafindaki 60 satir --"
L=$(grep -n "INSERT INTO bi_satis_faturalari" $S | head -1 | cut -d: -f1)
[ -n "$L" ] && sed -n "$((L-45)),$((L+20))p" $S

echo
echo "############ 4) Kolon eslestirme (Excel basligi -> DB kolonu) ############"
grep -n "Kayıt Tarihi\|Vade Tarihi\|Belge Numarası\|Muhatap Kodu\|Miktar\|Birim Fiyat" $S | head -20

echo
echo "############ 5) Diger ingest'ler nerede? ############"
grep -n "bi_tedarikci_faturalari\|bi_odeme_gecmisi\|bi_stok_durumu\|bi_stok_hareketleri\|bi_musteri_bakiye" $S \
  | grep -i "insert\|copy" | head

echo
echo "############ 6) bi_musteri_bakiye'ye 399 satir NEREDEN geldi? ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT export_date, count(*) FROM bi_musteri_bakiye GROUP BY 1 ORDER BY 1;"
echo "  ^ 'account balance' dosyasi 403 satir. Cok yakin. Ayni kaynak olabilir."
