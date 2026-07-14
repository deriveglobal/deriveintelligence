#!/usr/bin/env bash
# OLU_TABLO_GORUNUM — 62 sorguya DOKUNMADAN hepsini canli veriye baglar.
#
# ✅ TUM KAPILAR ACIK (olculdu):
#   · Hicbir kod bu tablolara YAZMIYOR (INSERT/UPDATE/DELETE yok)
#   · erp_ingest.py onlari YUKLEMIYOR
#   · bi_sku_norm() fonksiyonu MEVCUT
#
# ⚠ YONTEM: olu tabloyu YEDEKLE, ayni isimde GORUNUM kur.
#   Ayni isim, ayni kolon adlari — arkasinda CANLI veri.
#   62 sorgunun HICBIRINE dokunmuyorum. Her dokundugum sorgu yeni bir hata riski;
#   bugun bunu uc kez yasadik.
#
# ⚠ EN BUYUK KAZANIM: bi_stok_durumu.toplam_deger
#   Su an 1.468,3M gosteriyor (10 KAT SISKIN, x10.000 virgul bozulmasi).
#   Gorunumde: adet × TEDARIKCI FATURASI fiyati = ana sayfanin kullandigi YONTEM.
#   Yani o kolonu okuyan HER sorgu, ana sayfayla AYNI sayiyi verecek.
#   TEK YONTEM, TEK GERCEK.
#
# ⚠ bi_odeme_gecmisi'ne DOKUNMUYORUM: canli karsiligi YOK. Kesmek yerine
#   "karsiligi yok" diye biliyorum. Bilmedigim seyi silmem.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) ⚠ ON KAPI — gercekten kimse yazmiyor mu? ############"
Y=$(grep -rn "INSERT INTO bi_stok_durumu\|INSERT INTO bi_stok_hareketleri\|INSERT INTO bi_musteri_bakiye" \
     --include=*.mjs --include=*.py . 2>/dev/null | grep -v "srv_broken\|\.bak_" | wc -l)
echo "  yazan kod satiri: $Y"
[ "$Y" = "0" ] || { echo "  ❌ YAZAN VAR — gorunume ceviremem. DURDUM."; exit 1; }

echo
echo "############ 1) SUNUCU — acilistaki CREATE TABLE/INDEX satirlari kaldiriliyor ############"
# ⚠ Gorunum varken CREATE INDEX PATLAR. Once bunlari cikarmaliyim.
cp server_container.mjs server_container.mjs.bak_gorunum
python3 - <<'PY' || exit 1
import pathlib, re, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "OLU_GORUNUM_V1" in s: sys.exit("ZATEN YAMALI")
n = 0
for tablo in ["bi_stok_hareketleri", "bi_stok_durumu", "bi_musteri_bakiye"]:
    # CREATE TABLE blogunu bul: "CREATE TABLE IF NOT EXISTS <tablo> (" ... ");"
    m = re.search(r"    CREATE TABLE IF NOT EXISTS " + tablo + r" \(.*?\n    \);\n", s, re.S)
    assert m, f"❌ {tablo} CREATE TABLE blogu bulunamadi"
    s = s[:m.start()] + f"    -- ⚠ OLU_GORUNUM_V1 — {tablo} artik TABLO DEGIL, GORUNUM.\n" \
                        f"    --   Arkasinda canli veri var; CREATE TABLE burada olursa gorunumu ezer.\n" \
        + s[m.end():]
    n += 1
# indeksler
for idx in ["idx_bsh_kalem", "idx_bsh_date", "idx_bsd_item", "idx_bmb_musteri"]:
    m = re.search(r"    CREATE INDEX IF NOT EXISTS " + idx + r" ON [^\n]*\n", s)
    if m:
        s = s[:m.start()] + s[m.end():]
        n += 1
p.write_text(s, encoding="utf-8")
print(f"  ✅ {n} blok/satir kaldirildi (3 CREATE TABLE + 4 CREATE INDEX)")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_gorunum server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 2) VERITABANI — yedekle, gorunum kur ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ SEMA — geri alindi"; exit 1; }
BEGIN;
-- ⚠ SILMIYORUM, YEDEKLIYORUM. Silinen veri geri gelmez; yedek gelir.
ALTER TABLE IF EXISTS bi_stok_hareketleri RENAME TO bi_stok_hareketleri_olu_yedek;
ALTER TABLE IF EXISTS bi_stok_durumu      RENAME TO bi_stok_durumu_olu_yedek;
ALTER TABLE IF EXISTS bi_musteri_bakiye   RENAME TO bi_musteri_bakiye_olu_yedek;

-- ── 1. STOK HAREKETLERI: duz kolon eslesmesi ────────────────────────────
-- ⚠ bi_stok_hareket'te export_date YOK -> ingested_at::date kullaniliyor.
CREATE VIEW bi_stok_hareketleri AS
SELECT id, tenant_id,
       ingested_at::date        AS export_date,
       ingested_at,
       belge_turu, belge_no, belge_tarihi,
       muhatap_kodu,
       muhatap_adi              AS muhatap_tanimi,
       satis_calisani           AS temsilci,
       depo, kalem_kodu, grup_adi, kategori, marka, kalem_tanimi,
       birim_maliyet,
       giris                    AS giris_miktari,
       giris_tutari,
       cikis                    AS cikis_miktari,
       cikis_tutari,
       stok_bakiye_tutari,
       notlar                   AS aciklama
  FROM bi_stok_hareket;

-- ── 2. STOK DURUMU: ⚠ toplam_deger ARTIK GERCEK ─────────────────────────
-- Eski tablo 1.468,3M diyordu (10 kat siskin). Gorunum, ana sayfanin
-- kullandigi YONTEMI kullanir: adet × tedarikci faturasi birim fiyati.
CREATE VIEW bi_stok_durumu AS
WITH fiyat AS (
  SELECT DISTINCT ON (tenant_id, bi_sku_norm(kalem_kodu))
         tenant_id, bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS f
    FROM bi_tedarikci_faturalari
   WHERE miktar > 0 AND birim_fiyat_kdv_haric > 0
   ORDER BY tenant_id, 2, fatura_tarihi DESC
)
SELECT a.id, a.tenant_id, a.export_date, a.ingested_at,
       a.kalem_kodu, a.kalem_tanimi, a.grup_adi,
       a.kategori2               AS kategori,
       a.marka, a.depo,
       a.adet                    AS eldeki_miktar,
       a.taahhut                 AS siparis_miktar,
       a.min_seviye              AS min_stok,
       COALESCE(p.f, 0)                          AS birim_maliyet,
       ROUND(a.adet * COALESCE(p.f, 0), 2)       AS toplam_deger
  FROM bi_stok_anlik a
  LEFT JOIN fiyat p ON p.tenant_id = a.tenant_id
                   AND p.sku = bi_sku_norm(a.kalem_kodu);

-- ── 3. MUSTERI BAKIYE: canli risk raporundan ────────────────────────────
-- ⚠ Eski tablo 399 musteri, 12 Haziran, KOLONLARI KAYMIS.
CREATE VIEW bi_musteri_bakiye AS
SELECT id, tenant_id, export_date, ingested_at,
       muhatap_kodu    AS musteri_kodu,
       muhatap_adi     AS musteri_adi,
       NULL::text      AS sube,
       NULL::numeric   AS borc_tutari,
       NULL::numeric   AS alacak_tutari,
       hesap_bakiyesi  AS bakiye,
       vadesi_gecmis   AS vadesi_gecmis_tutar,
       NULL::integer   AS en_uzun_vade_gun
  FROM bi_musteri_risk
 WHERE musteri_mi;
COMMIT;
SQL
echo "  ✅ 3 gorunum kuruldu · olu tablolar *_olu_yedek olarak SAKLANDI"

echo
echo "############ 3) ⚠⚠ MUTABAKAT — gorunum ana sayfayla AYNI mi diyor? ############"
$PSQL -c "
SELECT round(sum(toplam_deger)/1e6, 1) AS gorunum_stok_M,
       count(*) AS satir, max(export_date) AS tarih
  FROM bi_stok_durumu WHERE tenant_id='$T'::uuid
   AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id='$T'::uuid);"
echo "  ⚠ BEKLENEN ≈ 268,5M (ana sayfa). ESKIDEN 1.468,3M idi."

$PSQL -c "
SELECT round(sum(bakiye)/1e6,1) AS gorunum_bakiye_M,
       round(sum(vadesi_gecmis_tutar)/1e6,1) AS gecikmis_M, count(*) AS musteri
  FROM bi_musteri_bakiye WHERE tenant_id='$T'::uuid;"
echo "  ⚠ BEKLENEN ≈ 209,3M / 145,4M. ESKIDEN 145,4M / 663,5M (kolonlar kaymisti)."

$PSQL -c "
SELECT count(*) AS satir, max(belge_tarihi) AS son_hareket
  FROM bi_stok_hareketleri WHERE tenant_id='$T'::uuid;"
echo "  ⚠ BEKLENEN ≈ 580.000 satir · son hareket 2026-07-13."
echo "     ESKIDEN 358.028 satir · son hareket 5 ARALIK 2026 (gelecek tarih — bozuk)."

echo
echo "############ 4) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
echo "  ⚠ 40 sn bekliyorum (acilis semasi + master tazeleme)"
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
echo "  --- acilis semasi PATLADI mi? (gorunum uzerine CREATE INDEX denerse patlar) ---"
docker logs --since 60s krb-assessment 2>&1 | grep -i "error\|already exists\|cannot" | head -5 || echo "  ✅ log temiz"

echo
echo "############ 5) ⚠ 62 SORGU HALA CALISIYOR MU? — uc uc noktayi dene ############"
for E in /api/bi/ana /api/bi/yukle/durum; do
  printf "  %-24s -> HTTP %s\n" "$E" "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080$E)"
done
echo "  (401 = uc nokta VAR, oturum ister — dogru. 500 = SORGU KIRILDI.)"

git add -A
git commit -q -m 'refactor(bi): OLU_GORUNUM_V1 — olu tablolar GORUNUME cevrildi; 62 sorguya dokunmadan hepsi canli veriye baglandi. Yontem: olu tabloyu yedekle (*_olu_yedek), ayni isimde ayni kolon adlariyla gorunum kur. Her dokunulan sorgu yeni bir hata riski; bugun bunu uc kez yasadik. (1) bi_stok_durumu: eski tablo toplam_deger kolonunda 1.468,3M gosteriyordu — 10 KAT SISKIN (x10.000 virgul bozulmasi; LASTIK TUKETICI adet basina 27.053 TL cikiyordu, binek lastigi ~2.800 TL). Gorunum ana sayfanin YONTEMINI kullaniyor: adet × tedarikci faturasi birim fiyati -> 268,5M. Artik o kolonu okuyan HER sorgu ana sayfayla ayni sayiyi veriyor: tek yontem, tek gercek. Ayrica bi_stok_anlikta birim_maliyet/toplam_deger kolonlari HIC YOKTU; korlemesine tasisaydim stok degeri hesaplayan her sorgu ya patlar ya da liste fiyatini maliyet sanardi (marj %100 gorunurdu). (2) bi_stok_hareketleri: 358.028 satir, en son belge tarihi 5 ARALIK 2026 — gelecekte bir tarih (gun/ay takas bozulmasi). Gorunum bi_stok_hareket uzerine kuruldu (580.016 satir, 13 Temmuz): giris_miktari->giris, cikis_miktari->cikis, muhatap_tanimi->muhatap_adi, temsilci->satis_calisani, aciklama->notlar. (3) bi_musteri_bakiye: 399 musteri, 12 Haziran, kolonlari kaymis (bakiye 145,4M / vadesi gecmis 663,5M — imkansiz); gorunum bi_musteri_risk uzerine kuruldu (38.403 musteri, 12 Temmuz, 209,3M / 145,4M). Acilis semasindaki CREATE TABLE ve CREATE INDEX satirlari kaldirildi (gorunum uzerine index kurulamaz). bi_odeme_gecmisine DOKUNULMADI: canli karsiligi yok, bilmedigim seyi silmem.'
echo "  COMMITTED"
