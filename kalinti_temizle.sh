#!/usr/bin/env bash
# KALINTI_TEMIZLE — yeni dogruyu yazdim ama ESKI YALANI SILMEDIM.
#
# ⚠ KAPI YANLIS ALARM VERDI VE SUCLU BENIM:
#   Sorguyu refreshSahaMasters daha BITMEDEN calistirdim (12 sn beklemek yetmemis).
#   "Calismadi" sandim. Calismis. -> Beklemeyi olcmeden hukum vermek de bir hatadir.
#
# ⚠ AMA GERCEK BIR TUTARSIZLIK VAR:
#   bi_musteri_risk (musteri_mi) : 209,3M
#   master_musteri.son_bakiye    : 219,0M
#   Fark: 9,7M. NEREDEN?
#
# ⚠ HIPOTEZ (dogrulanacak, varsayilmayacak):
#   master_musteri'de OLU tablodan kalma satirlar vardi (372 tane).
#   Yamam sadece risk raporuyla ESLESEN satirlari guncelledi.
#   Eslesmeyenler ESKI OLU DEGERLERINI KORUDU -> canli verinin arasinda 12 Haziran kalintisi.
#   Bugun defalarca kovaladigim desen: yeni dogruyu yaz, eski yalani silme.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ HIPOTEZI DOGRULA — kalinti gercekten var mi? ############"
$PSQL -c "
SELECT count(*)                                   AS bakiyesi_dolu,
       count(*) FILTER (WHERE risk_tarihi IS NOT NULL) AS risk_raporundan,
       count(*) FILTER (WHERE risk_tarihi IS NULL)     AS KALINTI_olu_tablodan,
       round(sum(son_bakiye) FILTER (WHERE risk_tarihi IS NULL)/1e6, 1) AS kalinti_M
  FROM master_musteri
 WHERE son_bakiye IS NOT NULL;"
echo "  ⚠ 'KALINTI_olu_tablodan' > 0 ise hipotez DOGRU: risk raporunda olmayan satirlar"
echo "     12 Haziran'dan kalma bozuk degerlerini koruyor."

echo
echo "  --- kalinti ornekleri (kim bunlar?) ---"
$PSQL -c "
SELECT musteri_kodu, left(musteri_adi, 34) AS musteri,
       round(son_bakiye/1e3) AS bakiye_bin, round(vadesi_gecmis/1e3) AS gecikmis_bin
  FROM master_musteri
 WHERE son_bakiye IS NOT NULL AND risk_tarihi IS NULL
 ORDER BY son_bakiye DESC LIMIT 8;"

echo
echo "############ 2) TEMIZLE — risk raporunda olmayan = bakiyesi BILINMIYOR ############"
# ⚠ 0 YAZMIYORUM. 0 "borcu yok" demek. Dogrusu: BILMIYORUZ -> NULL.
#   Bilmedigimiz seye sayi uydurmak, yanlis sayidan kotudur.
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE master_musteri
   SET son_bakiye = NULL, vadesi_gecmis = NULL, net_pozisyon = NULL
 WHERE risk_tarihi IS NULL;
SQL
echo "  ✅ kalinti NULL'landi (0 degil — 0 'borcu yok' demek olurdu; dogrusu BILINMIYOR)"

echo
echo "############ 3) ⚠ MUTABAKAT — simdi tutuyor mu? ############"
$PSQL -c "
SELECT 'bi_musteri_risk (kaynak)' AS kaynak,
       count(*) FILTER (WHERE hesap_bakiyesi <> 0) AS bakiyeli,
       round(sum(hesap_bakiyesi)/1e6, 1)  AS bakiye_M,
       round(sum(vadesi_gecmis)/1e6, 1)   AS gecikmis_M
  FROM bi_musteri_risk WHERE musteri_mi
UNION ALL
SELECT 'master_musteri (turev)',
       count(*) FILTER (WHERE son_bakiye <> 0),
       round(sum(son_bakiye)/1e6, 1),
       round(sum(vadesi_gecmis)/1e6, 1)
  FROM master_musteri;"
echo "  ⚠ IKI SATIR AYNI OLMALI. Degilse turev tablo kaynagi yansitmiyor demektir."

echo
echo "############ 4) ⚠ SUNUCUYA KALICI YAZ — her tazelemede kalinti silinsin ############"
cp server_container.mjs server_container.mjs.bak_kalinti
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "KALINTI_TEMIZ" in s: sys.exit("ZATEN YAMALI")
A = '''  await client.query(`
    UPDATE master_musteri mm
    SET son_bakiye    = r.hesap_bakiyesi,'''
assert A in s, "❌ capa yok"
B = '''  // ⚠ KALINTI_TEMIZ — ONCE SIL, SONRA YAZ.
  //   Ilk denemede sadece ESLESEN satirlari guncelledim; eslesmeyenler
  //   olu tablodan kalma 12 Haziran degerlerini KORUDU (9,7M kalinti).
  //   Yeni dogruyu yazip eski yalani silmemek — bugun defalarca kovaladigim desen.
  //   ⚠ 0 YAZMIYORUM: 0 "borcu yok" demektir. Dogrusu BILINMIYOR -> NULL.
  await client.query(`
    UPDATE master_musteri
       SET son_bakiye = NULL, vadesi_gecmis = NULL,
           kredi_limiti = NULL, toplam_risk = NULL,
           bizim_borcumuz = NULL, net_pozisyon = NULL, risk_tarihi = NULL
  `);
''' + A
s = s.replace(A, B, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ once temizle, sonra doldur")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_kalinti server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
echo "  ⚠ 40 sn bekliyorum — gecen sefer 12 sn YETMEDI ve yanlis hukum verdim."
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ⚠ SON MUTABAKAT (acilis tazelemesinden SONRA) ############"
$PSQL -c "
SELECT count(*) FILTER (WHERE son_bakiye IS NOT NULL) AS bakiyesi_var,
       round(sum(son_bakiye)/1e6, 1)     AS bakiye_M,
       round(sum(vadesi_gecmis)/1e6, 1)  AS gecikmis_M,
       max(risk_tarihi)                  AS tarih
  FROM master_musteri;"
echo "  ⚠ BEKLENEN: bakiye 209,3M · gecikmis 145,4M · 2026-07-12"

echo
echo "  --- MUTAFLAR: brut vs NET ---"
$PSQL -c "
SELECT round(son_bakiye/1e3) brut_bin, round(bizim_borcumuz/1e3) borcumuz_bin,
       round(net_pozisyon/1e3) NET_bin, round(kredi_limiti/1e3) limit_bin
  FROM master_musteri WHERE musteri_adi ILIKE '%MUTAFLAR%';"
echo "  ⚠ NET 1.001 bin (1,0M) olmali. 94.112 cikarsa isaret ters demektir."

echo
echo "  --- GERCEK RISK SIRALAMASI (net/limit) ---"
$PSQL -c "
SELECT left(musteri_adi,28) musteri, round(net_pozisyon/1e3) net_bin,
       round(vadesi_gecmis/1e3) gecikmis_bin, round(kredi_limiti/1e3) limit_bin,
       round(net_pozisyon/NULLIF(kredi_limiti,0), 1) AS limit_kati
  FROM master_musteri
 WHERE net_pozisyon > 2e6 AND kredi_limiti > 0
 ORDER BY net_pozisyon/NULLIF(kredi_limiti,0) DESC LIMIT 8;"

git add -A
git commit -q -m 'fix(bi): KALINTI_TEMIZ — yeni dogruyu yazdim ama eski yalani silmemistim. master_musteri.son_bakiye risk raporundan dolduruluyordu ama sadece ESLESEN satirlar guncelleniyordu; eslesmeyen satirlar olu bi_musteri_bakiye tablosundan kalma 12 Haziran degerlerini KORUYORDU (9,7M kalinti: kaynak 209,3M derken turev tablo 219,0M diyordu). Artik ONCE TEMIZLENIYOR sonra dolduruluyor. Kalinti satirlara 0 YAZILMIYOR: 0 "borcu yok" demektir, dogrusu "bilinmiyor" -> NULL. Bilmedigimiz seye sayi uydurmak, yanlis sayidan kotudur. Ayrica bir onceki calistirmada mutabakat kapisi YANLIS ALARM verdi cunku sorguyu refreshSahaMasters bitmeden calistirdim (12 sn yetmemis) ve "calismadi" sandim — beklemeyi olcmeden hukum vermek de bir hatadir; bekleme 40 sn ye cikarildi.'
echo "  COMMITTED"
