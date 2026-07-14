#!/usr/bin/env bash
# SIFIR_SABIT_2 — ekranda HICBIR SABIT SAYI kalmayacak.
#
# ⚠⚠ EN KOTU BULGU: "Yillik sermaye yuku 203M" (bi.js:273 ve 402)
#   Bu, COPE ATTIGIMIZ "deger kaybediyorsun" tezinden kalma bir HAYALET.
#   GERCEK: 29,7M. Ekranda YEDI KATI bir sayi, ASISTAN PROMPTLARININ ICINDE.
#   Fatih Bilen asistana "sermaye yukumuz ne?" dese, 203M cevabini alirdi.
#
# ⚠ DIGER YALANLAR:
#   "Net isletme sermayesi 104M" (gercek 74,4M) · "DSO 116" (gercek 102)
#   "Stok 131 gun" · MUTAFLAR 47,6/46,6/1,0 (IKI yerde) · "SAP 282,4M, %5,1"
#   "Sailun -%40, Dayton +%48" · "TOROS 47 kati"
#
# ⚠ ILKE: ekrandaki her SAYI veriden gelir. Her CUMLE bir KURAL'dir.
#   Bir kereye mahsus yapilmis DOGRULAMALAR ("SAP ile %5,1 tutuyor") ekranda
#   KALICI olarak duramaz — onlarin yeri KOKEN panelidir, ekranin govdesi degil.
#   Ekran sadece BUGUN DOGRU OLANI gosterir. Gecmisin dogrusu gecmiste durur.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) AYAR TABLOSU — varsayimlar koda degil AYARA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_ayar (
  tenant_id            uuid PRIMARY KEY,
  -- ⚠ VARSAYIM. Olculmus bir gercek DEGIL. Ekranda "varsayim" diye ETIKETLENIR.
  sermaye_maliyeti_pct numeric NOT NULL DEFAULT 40,
  stok_hedef_gun       integer NOT NULL DEFAULT 90,
  aktif_musteri_gun    integer NOT NULL DEFAULT 90,
  uyuyan_musteri_gun   integer NOT NULL DEFAULT 365,
  guncelleyen          uuid,
  updated_at           timestamptz NOT NULL DEFAULT now()
);
INSERT INTO bi_ayar (tenant_id)
SELECT id FROM platform_tenants WHERE status='active'
ON CONFLICT (tenant_id) DO NOTHING;
SQL
$PSQL -c "SELECT * FROM bi_ayar;"

echo
echo "############ 2) SUNUCU — 0.40 sabiti ayardan okunacak ############"
cp server_container.mjs server_container.mjs.bak_sabit
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "SIFIR_SABIT_V1" in s: sys.exit("ZATEN YAMALI")
n = 0

# /api/bi/finans — ayar CTE ekle + 0.40 kaldir
A = '''          borc AS (
            SELECT COALESCE(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0)),0) AS tutar,
                   COALESCE(abs(min(tedarikci_bakiye)),0) AS en_buyuk,
                   (SELECT tedarikci_adi FROM bi_cari_bakiye
                     WHERE tenant_id=$1::uuid ORDER BY tedarikci_bakiye LIMIT 1) AS en_buyuk_ad
              FROM bi_cari_bakiye WHERE tenant_id=$1::uuid)
          SELECT s.deger AS stok, a.bakiye AS alacak, a.gecikmis, a.toplam_risk,
                 a.gecikmis_musteri, b.tutar AS borc, b.en_buyuk, b.en_buyuk_ad,
                 (s.deger + a.bakiye - b.tutar)              AS net_sermaye,
                 ROUND((s.deger + a.bakiye - b.tutar) * 0.40) AS yillik_yuk
            FROM stok s, alacak a, borc b`, [T]),'''
assert A in s, "❌ finans SELECT bulunamadi"
B = '''          borc AS (
            SELECT COALESCE(abs(sum(tedarikci_bakiye) FILTER (WHERE tedarikci_bakiye<0)),0) AS tutar,
                   COALESCE(abs(min(tedarikci_bakiye)),0) AS en_buyuk,
                   (SELECT tedarikci_adi FROM bi_cari_bakiye
                     WHERE tenant_id=$1::uuid ORDER BY tedarikci_bakiye LIMIT 1) AS en_buyuk_ad
              FROM bi_cari_bakiye WHERE tenant_id=$1::uuid),
          -- ⚠ SIFIR_SABIT_V1 — %40 KODDA SABIT DEGIL. Bu bir VARSAYIM ve ayardan gelir.
          --   Ekranda "varsayim" diye etiketlenir. Olculmus bir gercek DEGIL.
          ay AS (SELECT COALESCE(max(sermaye_maliyeti_pct),40) AS pct FROM bi_ayar WHERE tenant_id=$1::uuid)
          SELECT s.deger AS stok, a.bakiye AS alacak, a.gecikmis, a.toplam_risk,
                 a.gecikmis_musteri, b.tutar AS borc, b.en_buyuk, b.en_buyuk_ad,
                 (s.deger + a.bakiye - b.tutar)                       AS net_sermaye,
                 ROUND((s.deger + a.bakiye - b.tutar) * ay.pct / 100) AS yillik_yuk,
                 ay.pct                                               AS sermaye_maliyeti_pct
            FROM stok s, alacak a, borc b, ay`, [T]),'''
s = s.replace(A, B, 1); n += 1

# /api/bi/ana — ayni
C = "                 ROUND((s.deger + a.risk - b.tutar) * 0.40)         AS sermaye_yuku"
assert C in s, "❌ ana sermaye_yuku bulunamadi"
D = """                 -- ⚠ SIFIR_SABIT_V1 — %40 VARSAYIM, ayardan gelir.
                 ROUND((s.deger + a.risk - b.tutar)
                       * (SELECT COALESCE(max(sermaye_maliyeti_pct),40) FROM bi_ayar WHERE tenant_id=$2::uuid) / 100)
                                                                    AS sermaye_yuku,
                 (SELECT COALESCE(max(sermaye_maliyeti_pct),40) FROM bi_ayar WHERE tenant_id=$2::uuid)
                                                                    AS sermaye_maliyeti_pct"""
s = s.replace(C, D, 1); n += 1
p.write_text(s, encoding="utf-8")
print(f"  ✅ {n} yer: %40 artik bi_ayar'dan")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_sabit server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ARAYUZ — sabit sayilarin TEMIZLIGI ############"
cp shells/bi.js shells/bi.js.bak_sabit
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "SIFIR_SABIT_V1" in s: sys.exit("ZATEN YAMALI")
n = 0
def rep(eski, yeni, ad):
    global s, n
    if eski not in s:
        print(f"  ⚠ ATLANDI (capa yok): {ad}")
        return
    s = s.replace(eski, yeni, 1); n += 1
    print(f"  ✅ {ad}")

# ── 203M HAYALETI (iki yerde) ────────────────────────────────────────────
rep("esc('Yıllık sermaye yükü 203M. Faaliyet kârımla kıyasla — değer yaratıyor muyuz?')",
    "esc('Yıllık sermaye yükü ' + _M(s.sermaye_yuku) + '. Faaliyet kârımla kıyasla — değer yaratıyor muyuz?')",
    "203M hayaleti #1 (satir 273)")
rep("esc('Sermaye yükü 203M, lastik brüt kârı ' + Math.round(brutToplam/1e6) + 'M. Bu farkı kapatmak için ne yapmalıyım? Stok mu, tahsilat mı, marj mı — ",
    "esc('Sermaye yükü ' + _M(yuk) + ', lastik brüt kârı ' + Math.round(brutToplam/1e6) + 'M. Bu farkı kapatmak için ne yapmalıyım? Stok mu, tahsilat mı, marj mı — ",
    "203M hayaleti #2 (satir 402)")

# ── NET SERMAYE / BRISA ──────────────────────────────────────────────────
rep("esc('Net işletme sermayesi 104M. Brisa 319M borcu Kasım-Şubat ödenecek. Bu nakdi nereden bulacağız?')",
    "esc('Net işletme sermayesi ' + _M(s.net_sermaye) + '. En büyük tedarikçi borcu ' + _M(s.en_buyuk_borc) + '. Bu nakdi nereden bulacağız?')",
    "net sermaye 104M + Brisa 319M")

# ── %40 ETIKETI -> VARSAYIM ──────────────────────────────────────────────
rep("+   '<div style=\"font-size:12px;color:var(--tx-2)\">%40 / yıl · net üzerinden</div>'",
    "+   '<div style=\"font-size:12px;color:var(--tx-2)\">%' + (s.sermaye_maliyeti_pct || 40) + ' / yıl · net üzerinden · <span class=\"d-sari\">⚠ varsayım</span></div>'",
    "%40 -> ayardan + 'varsayim' etiketi")

# ── STOK 131 / DSO 116 / 26,9 ────────────────────────────────────────────
rep("esc('Stok 131 günden 90 güne inerse ne kadar sermaye serbest kalır? Hangi ürünler?')",
    "esc('Stok ' + (s.stok_gun || '—') + ' günden hedefe inerse ne kadar sermaye serbest kalır? Hangi ürünler?')",
    "stok 131 gun")
rep("esc('Gerçek DSO 116 gün. Neden tahsilat tablosu 26,9 gösteriyor? Gecikmiş alacağı müşteri bazında sırala.')",
    "esc('Tahsilat süresi ' + (s.dso_gun || '—') + ' gün. Gecikmiş alacağı müşteri bazında sırala — kim, ne kadar, kaç gündür?')",
    "DSO 116 + 26,9")
rep("+ 'Tahsilat süresi ödemeyenleri de içerir. Sistemin daha önce gösterdiği 26,9 gün yalnızca ödeyenleri ölçüyordu.</div>';",
    "+ 'Tahsilat süresi ödemeyenleri de içerir. Sadece ödeyenleri ölçen bir tablo, tahsilatı olduğundan hızlı gösterir.</div>';",
    "26,9 gun (kural haline geldi)")

# ── SAP DOGRULAMASI (bir kereye mahsus olcum -> ekranda yeri yok) ────────
rep("+ '<span class=\"d-yesil\">✅ Maliyet tabanı doğrulandı</span> <span style=\"color:var(--tx-3)\">— SAP’ın kendi stok değeri (282,4M), bağımsız hesabımızla (268,5M) %5,1 içinde tutuyor.</span><br>'",
    "+ '<span class=\"d-yesil\">✅ Maliyet tabanı doğrulandı</span> <span style=\"color:var(--tx-3)\">— stok değeri, tedarikçi faturasındaki fiilen ödenen fiyatla hesaplanır. Doğrulama tarihçesi için sayıya tıkla.</span><br>'",
    "SAP 282,4M / 268,5M / %5,1")
rep("+ '<span class=\"d-sari\">⚠ Marka kırılımı yok</span> <span style=\"color:var(--tx-3)\">— ERP’nin hareketli ortalaması alış faturasından markadan markaya sapıyor (Sailun −%40, Dayton +%48). Toplamda götürüyor, marka bazında güvenilmez.</span>'",
    "+ '<span class=\"d-sari\">⚠ Marka kırılımı yok</span> <span style=\"color:var(--tx-3)\">— ERP’nin hareketli ortalaması alış faturasından markadan markaya sapıyor. Toplamda götürüyor, marka bazında güvenilmez.</span>'",
    "Sailun -%40 / Dayton +%48")
rep("+ 'Sapma markadan markaya değişiyor: Sailun −%40, Dayton +%48, Continental %1.<br>'",
    "+ 'Sapma markadan markaya değişiyor — bu yüzden marka bazında marj gösterilmez.<br>'",
    "Sailun/Dayton/Continental sapmasi")
rep("+ 'açılış stoğu + alışlar − SMM = kapanış stoğu. Kapanış biliniyor (268,5M).</div>';",
    "+ 'açılış stoğu + alışlar − SMM = kapanış stoğu. Kapanış biliniyor.</div>';",
    "kapanis 268,5M")
rep("esc('Stok denkliğiyle SMM’yi doğrula: açılış stoğu + alışlar − SMM = kapanış stoğu (268,5M). ERP maliyeti mi doğru, alış faturası mı?')",
    "esc('Stok denkliğiyle SMM’yi doğrula: açılış stoğu + alışlar − SMM = kapanış stoğu. ERP maliyeti mi doğru, alış faturası mı?')",
    "SMM prompt 268,5M")

# ── MUTAFLAR (IKI YERDE) -> KURAL ────────────────────────────────────────
rep("+ 'MUTAFLAR brüt 47,6M görünüyor; KRB’nin ona borcu 46,6M — <span class=\"d-yesil\">net 1,0M, tam limitte.</span> Yönetilen mahsuplaşma.</div>';",
    "+ 'Karşılıklı alım yapan müşterilerde <span class=\"d-yesil\">net pozisyon</span> gösterilir; brüt alacağa bakmak yanlış alarm üretir.</div>';",
    "MUTAFLAR cumlesi #1 (Bugun)")
rep("+ '<b>MUTAFLAR bu listede yok</b> — brüt 47,6M ama bizim ona borcumuz 46,6M, net 1,0M, tam limitinde.</div>';",
    "+ 'Bize de borcu olan müşteriler <b>net pozisyonlarıyla</b> değerlendirilir; brüt alacağı limitle kıyaslamak yanlış alarm üretir.</div>';",
    "MUTAFLAR cumlesi #2 (Finans)")
rep("esc('Net risk sıralamasını aç. YEDİ OTO 30,5M limitin 2 katı, TOROS 9,5M limitin 47 katı. Bunlarda ne yapmalıyım?')",
    "esc('Net risk sıralamasını aç. Limitini aşan ve limiti hiç tanımlanmamış müşterileri ayrı ayrı listele — her biri için ne yapmalıyım?')",
    "YEDI OTO / TOROS sabit sayilari")

p.write_text(s, encoding="utf-8")
print(f"\n  TOPLAM {n} sabit sayi temizlendi")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_sabit shells/bi.js; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) BRISA — kaynagi EKRANDA yaz ############"
# ⚠ deploy_sinyal.sh'de ELLE yazilmis tarihler. Ureten mantik YOK.
#   Brisa taksiti degistirirse EKRAN YALAN SOYLER. Kaynagi gorunur yapiyorum.
$PSQL -c "
UPDATE bi_sinyal
   SET ozet = ozet || ' · ⚠ elle girildi (13 Tem) — Brisa takvimi değişirse güncellenmeli'
 WHERE tur='odeme' AND ozet NOT LIKE '%elle girildi%';"
$PSQL -c "SELECT son_tarih, left(ozet, 80) FROM bi_sinyal WHERE tur='odeme' ORDER BY son_tarih;"

echo
echo "############ 5) DAGIT + DOGRULA ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo "  --- ⚠ EKRANDA HALA SABIT SAYI VAR MI? ---"
grep -c "203M\|104M\|116 gün\|131 gün\|282,4M\|268,5M\|47,6M\|46,6M\|Sailun −%40" shells/bi.js | sed 's/^/      kalan: /'
echo "      (0 olmali)"

git add -A
git commit -q -m 'refactor(bi): SIFIR_SABIT_V1 — ekranda HICBIR SABIT SAYI kalmadi. En kotu bulgu: "Yillik sermaye yuku 203M" iki yerde asistan promptunun icinde duruyordu — cope attigimiz "deger kaybediyorsun" tezinden kalma bir hayalet; gercek 29,7M, yani YEDI KATI bir yalan. Fatih Bilen asistana sermaye yukunu sorsa 203M cevabini alirdi. Temizlenenler: net sermaye 104M (gercek 74,4M), DSO 116 (gercek 102), stok 131 gun, MUTAFLAR 47,6/46,6/1,0 (IKI ayri yerde sabitti), SAP 282,4M / bizim 268,5M / %5,1 dogrulamasi, Sailun -%40 / Dayton +%48, TOROS 47 kati, tahsilat 26,9 gun. Hepsi ya veriden gelen degiskene baglandi ya da CUMLE KURALA cevrildi ("MUTAFLAR brut 47,6M" yerine "karsilikli alim yapan musterilerde net pozisyon gosterilir"). Bir kereye mahsus yapilmis DOGRULAMALAR ekranin govdesinden cikarildi: onlarin yeri koken panelidir. Ekran sadece BUGUN DOGRU OLANI gosterir. %40 sermaye maliyeti koddan cikip bi_ayar tablosuna tasindi ve ekranda "⚠ varsayim" diye etiketlendi — olculmus bir gercek degil. Brisa odeme takvimi deploy_sinyal.sh icinde ELLE yazilmis tarihlerden geliyor; ureten mantik yok, bu yuzden ozetine "⚠ elle girildi (13 Tem) — Brisa takvimi degisirse guncellenmeli" eklendi: sistem neyi bildigini degil NEREDEN BILDIGINI soylemeli.'
echo "  COMMITTED"
