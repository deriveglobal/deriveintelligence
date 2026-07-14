#!/usr/bin/env bash
# BAKIYE_NET_V2 — bakiye CANLI kaynaktan + risk NET pozisyondan.
# ⚠ bakiye_kaynak_degistir.sh'yi CALISTIRMA. Bu onun yerine geciyor.
#
# ⚠ UC HATA, UCU DE BENIM, UCU DE FATIH TARAFINDAN YAKALANDI:
#   1. "alacak 238,8M" dedim -> gercek 209,3M (olu tablodan okumusum)
#   2. En buyuk alacaklari BRUT listeledim -> MUTAFLAR'a yine 47,5M dedim,
#      oysa KRB de ona borclu, net 1,0M. IKI GUN ONCE ayni hatayi yapmistim.
#   3. Netlestirmeyi KENDIM hesapladim: brut - borc yazdim. Ama tedarikci_bakiye
#      NEGATIF isaretli (-46.556 bin). Eksiyi eksiyle topladim, MUTAFLAR'i
#      47,5M'den 94,1M'ye CIKARDIM. Duzeltmeye calistigim yalanin IKI KATINI urettim.
#
# ⚠ DERS (bugun ucuncu kez): ERP'NIN ZATEN HESAPLADIGI SEYI YENIDEN HESAPLAMA.
#   ERP'nin kendi kolonu: net_pozisyon = musteri_bakiye + tedarikci_bakiye
#     MUTAFLAR: 47.556.434 + (-46.555.721) = 1.000.714   <- limit 1.000.000
#   Kendi formulumu YAZMIYORUM. Kolonu OKUYORUM.
#
# ⚠ VE GERCEK RISKLER, NET'E GORE:
#   MUTAFLAR   net  1,0M / limit  1,0M  -> sinirda, YONETILIYOR (kriz degil)
#   YEDI OTO   net 30,5M / limit 15,0M  -> 2 kati, 19M gecikmis   ⚠ GERCEK
#   TOROS      net  9,5M / limit  0,2M  -> 47 kati, netlestirme YOK ⚠ GERCEK
#   FARK GROUP net  6,4M / limit    0   -> limiti YOK, 6,3M gecikmis ⚠ GERCEK
#   Sistem MUTAFLAR'a bagirirken TOROS ve FARK GROUP sessizce duruyordu.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) master_musteri — risk + NET kolonlari ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
ALTER TABLE master_musteri ADD COLUMN IF NOT EXISTS kredi_limiti   numeric;
ALTER TABLE master_musteri ADD COLUMN IF NOT EXISTS toplam_risk    numeric;
ALTER TABLE master_musteri ADD COLUMN IF NOT EXISTS risk_tarihi    date;
-- ⚠ ERP'nin KENDI netlestirmesi. Formul BENIM DEGIL.
ALTER TABLE master_musteri ADD COLUMN IF NOT EXISTS bizim_borcumuz numeric;
ALTER TABLE master_musteri ADD COLUMN IF NOT EXISTS net_pozisyon   numeric;
SQL
echo "  ✅ kredi_limiti · toplam_risk · risk_tarihi · bizim_borcumuz · net_pozisyon"

echo
echo "############ 2) SUNUCU ############"
cp server_container.mjs server_container.mjs.bak_netv2
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "BAKIYE_NET_V2" in s: sys.exit("ZATEN YAMALI")
n = 0

# (a) master bakiye: OLU tablo -> CANLI risk + ERP'nin NET kolonu
A = '''  await client.query(`
    UPDATE master_musteri mm
    SET son_bakiye = b.bakiye, vadesi_gecmis = b.vadesi_gecmis_tutar
    FROM (
      SELECT DISTINCT ON (tenant_id, musteri_kodu) tenant_id, musteri_kodu, bakiye, vadesi_gecmis_tutar
      FROM bi_musteri_bakiye ORDER BY tenant_id, musteri_kodu, export_date DESC
    ) b
    WHERE mm.tenant_id = b.tenant_id::uuid AND mm.musteri_kodu = b.musteri_kodu
  `);'''
assert A in s, "❌ master bakiye blogu yok"
B = '''  // ⚠ BAKIYE_NET_V2 — KAYNAK: bi_musteri_bakiye (OLU) -> bi_musteri_risk (CANLI)
  //   Eski: 399 musteri · 12 Haziran · KOLONLARI KAYMIS ("bakiye" dedigi 145,4M,
  //         aslinda VADESI GECMIS tutardi; "vadesi_gecmis" 663,5M diyordu — imkansiz)
  //   Yeni: 38.403 musteri · 12 Temmuz · bakiye 209,3M · vadesi gecmis 145,4M
  //         -> ALACAGIN %69'U GECIKMIS.
  //   ⚠ Eskiden master'in 38.628 musterisinin sadece 372'sinde bakiye vardi.
  await client.query(`
    UPDATE master_musteri mm
    SET son_bakiye    = r.hesap_bakiyesi,
        vadesi_gecmis = r.vadesi_gecmis,
        kredi_limiti  = r.kredi_limiti,
        toplam_risk   = r.toplam_risk,
        risk_tarihi   = r.export_date
    FROM (
      SELECT DISTINCT ON (tenant_id, muhatap_kodu)
             tenant_id, muhatap_kodu, hesap_bakiyesi, vadesi_gecmis,
             kredi_limiti, toplam_risk, export_date
        FROM bi_musteri_risk WHERE musteri_mi
       ORDER BY tenant_id, muhatap_kodu, export_date DESC
    ) r
    WHERE mm.tenant_id = r.tenant_id AND mm.musteri_kodu = r.muhatap_kodu
  `);
  // ⚠ NET POZISYON — ERP'NIN KENDI KOLONU. Formulu BEN YAZMIYORUM.
  //   Bir musteri ayni zamanda tedarikci olabilir (KRB ona da borclu).
  //   MUTAFLAR: alacak 47.556.434 · bizim borcumuz -46.555.721 · NET 1.000.714 (limit 1.000.000)
  //   Brut bakmak yanilticidir: sistem MUTAFLAR'a "limitin 138 kati" diye bagiriyordu.
  //   ⚠ Netlestirmeyi kendim hesaplamaya kalktim ve isareti ters aldim:
  //     tedarikci_bakiye NEGATIF geliyor; "brut - borc" yazinca 47,5M -> 94,1M oldu.
  //     Duzeltmeye calistigim yalanin iki katini urettim. Bu yuzden: KOLONU OKU.
  await client.query(`
    UPDATE master_musteri mm
    SET bizim_borcumuz = c.tedarikci_bakiye,
        net_pozisyon   = c.net_pozisyon
    FROM (
      SELECT DISTINCT ON (tenant_id, musteri_kodu)
             tenant_id, musteri_kodu, tedarikci_bakiye, net_pozisyon
        FROM bi_cari_bakiye WHERE musteri_kodu IS NOT NULL
       ORDER BY tenant_id, musteri_kodu, export_date DESC
    ) c
    WHERE mm.tenant_id = c.tenant_id AND mm.musteri_kodu = c.musteri_kodu
  `);
  // Netlestirmesi olmayan musteride net = brut.
  await client.query(`
    UPDATE master_musteri SET net_pozisyon = son_bakiye
     WHERE net_pozisyon IS NULL AND son_bakiye IS NOT NULL
  `);'''
s = s.replace(A, B, 1); n += 1

# (b) typeahead
C = '''      FROM bi_musteri_bakiye
      WHERE musteri_kodu IS NOT NULL AND NULLIF(TRIM(musteri_adi), '') IS NOT NULL
      ORDER BY tenant_id, musteri_kodu, export_date DESC'''
assert C in s, "❌ cari cache blogu yok"
D = '''      -- ⚠ BAKIYE_NET_V2 — typeahead OLU tablodan besleniyordu: 399 cari, 12 Haziran.
      --   Artik canli risk raporundan: 38.403 cari, 12 Temmuz.
      --   "Musteriyi aramada bulamiyorum" sikayetinin sebebi buydu.
      FROM (SELECT tenant_id, muhatap_kodu AS musteri_kodu, muhatap_adi AS musteri_adi, export_date
              FROM bi_musteri_risk WHERE musteri_mi) x
      WHERE musteri_kodu IS NOT NULL AND NULLIF(TRIM(musteri_adi), '') IS NOT NULL
      ORDER BY tenant_id, musteri_kodu, export_date DESC'''
s = s.replace(C, D, 1); n += 1

# (c) CEO asistani semasi
E = """    '  bi_stok_durumu (tenant_id UUID): kalem_kodu, kalem_tanimi, grup_adi, kategori, marka,\\n' +
    '    depo, eldeki_miktar, siparis_miktar, min_stok, birim_maliyet, toplam_deger, export_date\\n' +
    '  bi_musteri_bakiye (tenant_id UUID): musteri_kodu, musteri_adi, bakiye, vade_tarihi\\n' +"""
assert E in s, "❌ asistan semasi yok"
F = """    '  bi_stok_anlik (tenant_id UUID): kalem_kodu, kalem_tanimi, marka, depo,\\n' +
    '    miktar, birim_maliyet, toplam_deger, export_date   [CANLI stok]\\n' +
    '  bi_musteri_risk (tenant_id UUID): muhatap_kodu, muhatap_adi, musteri_mi,\\n' +
    '    hesap_bakiyesi, vadesi_gecmis, kredi_limiti, limit_asimi, toplam_risk,\\n' +
    '    odenmemis_cekler, odenmemis_senetler, cek_senet_riski, export_date\\n' +
    '    ⚠ MUSTERI BAKIYESI BURADAN. Musteri icin: WHERE musteri_mi = true.\\n' +
    '  bi_cari_bakiye (tenant_id UUID): musteri_kodu, tedarikci_kodu, tedarikci_adi,\\n' +
    '    musteri_bakiye, tedarikci_bakiye, net_pozisyon\\n' +
    '    ⚠⚠ RISK SORULURSA NET_POZISYON KULLAN, BRUT DEGIL. Bir musteri ayni zamanda\\n' +
    '    tedarikci olabilir. MUTAFLAR: alacak 47,5M ama bizim borcumuz 46,5M, NET 1,0M\\n' +
    '    (limiti 1,0M). Brut bakip \\'limitin 47 kati\\' demek YANLIS ALARM olur.\\n' +
    '    ⚠ bi_musteri_bakiye ARTIK KULLANILMIYOR: kolonlari kaymisti, 12 Haziran\\'da oldu.\\n' +"""
s = s.replace(E, F, 1); n += 1

G = """    '  bi_stok_hareketleri (tenant_id UUID): kalem_kodu, belge_tarihi, hareket_tipi, miktar\\n' +"""
assert G in s, "❌ asistan stok hareket satiri yok"
H = """    '  bi_stok_hareket (tenant_id UUID): kalem_kodu, belge_tarihi, giris, cikis,\\n' +
    '    giris_tutari, cikis_tutari, depo, hareket_sinifi   [CANLI — 579.771 satir]\\n' +
    '    ⚠ bi_stok_hareketleri (sonu -leri) ARTIK KULLANILMIYOR: 358.028 satirda donmus.\\n' +"""
s = s.replace(G, H, 1); n += 1

p.write_text(s, encoding="utf-8")
print(f"  ✅ {n} yer duzeltildi")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_netv2 server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 3) ⚠ MUTABAKAT KAPISI ############"
$PSQL -c "
SELECT count(son_bakiye)                    AS bakiyesi_dolu,
       round(sum(son_bakiye)/1e6, 1)        AS bakiye_M,
       round(sum(vadesi_gecmis)/1e6, 1)     AS vadesi_gecmis_M,
       max(risk_tarihi)                     AS tarih
  FROM master_musteri;"
echo "  ⚠ BEKLENEN: ≈209,3M · ≈145,4M · 2026-07-12"

echo
echo "  --- ⚠ MUTAFLAR net 1,0M mi? (94M olursa isaret yine ters demektir) ---"
$PSQL -c "
SELECT left(musteri_adi,28) AS musteri,
       round(son_bakiye/1e3)     AS brut_bin,
       round(bizim_borcumuz/1e3) AS borcumuz_bin,
       round(net_pozisyon/1e3)   AS NET_bin,
       round(kredi_limiti/1e3)   AS limit_bin
  FROM master_musteri WHERE musteri_adi ILIKE '%MUTAFLAR%';"

echo
echo "  --- ⚠ GERCEK RISK SIRALAMASI (net / limit) ---"
$PSQL -c "
SELECT left(musteri_adi,30) AS musteri,
       round(net_pozisyon/1e3) AS net_bin,
       round(vadesi_gecmis/1e3) AS gecikmis_bin,
       round(kredi_limiti/1e3)  AS limit_bin,
       CASE WHEN kredi_limiti > 0 THEN round(net_pozisyon/kredi_limiti, 1) END AS limit_kati
  FROM master_musteri
 WHERE net_pozisyon > 1e6
 ORDER BY CASE WHEN kredi_limiti > 0 THEN net_pozisyon/kredi_limiti ELSE 9e9 END DESC
 LIMIT 10;"

echo
echo "############ 4) TYPEAHEAD ############"
$PSQL -c "SELECT count(*) AS cari_cache FROM saha_cari_cache;"
echo "  ⚠ Eskiden 399'du."

echo
echo "############ 5) ⚠ SIRADAKI — sinyal motoru hala BRUT'e mi bakiyor? ############"
awk '/"sinyal_kredi"/,/"""/ { printf "%5d| %s\n", NR, $0 }' erp_ingest.py | head -25

git add -A
git commit -q -m 'fix(bi): BAKIYE_NET_V2 — bakiye canli kaynaktan, risk NET pozisyondan. Uc hata duzeltildi, ucu de benim, ucu de Fatih tarafindan yakalandi. (1) Alacak 238,8M demistim: gercek 209,3M — olu bi_musteri_bakiye tablosundan okumusum (399 musteri, 12 Haziran, KOLONLARI KAYMIS: "bakiye" dedigi 145,4M aslinda vadesi gecmis tutardi, "vadesi_gecmis" 663,5M diyordu ki 145M bakiyeye imkansiz). Canli kaynak bi_musteri_risk: 38.403 musteri, 12 Temmuz, bakiye 209,3M, vadesi gecmis 145,4M — alacagin %69u gecikmis. Net isletme sermayesi 103,9M degil 74,4M. (2) En buyuk alacaklari BRUT listeledim ve MUTAFLARa yine 47,5M dedim; oysa KRB de ona borclu, net 1,0M (limit 1,0M) — IKI GUN ONCE ayni hatayi yapip duzeltmistim, kodda degil kafamda kalmis. (3) Netlestirmeyi kendim hesapladim: tedarikci_bakiye NEGATIF isaretli, "brut - borc" yazinca eksiyi eksiyle topladim ve MUTAFLARi 47,5Mden 94,1Me cikardim — duzeltmeye calistigim yalanin iki katini urettim. Ders: ERPnin zaten hesapladigi seyi yeniden hesaplama. net_pozisyon ERPnin kendi kolonu, artik o okunuyor. Gercek riskler nete gore: YEDI OTO 30,5M/limit 15M (2 kat, 19M gecikmis), TOROS 9,5M/limit 0,2M (47 kat), FARK GROUP 6,4M/limit yok. Sistem MUTAFLARa bagirirken bunlar sessizce duruyordu. Ayrica typeahead olu tablodan besleniyordu (399 cari -> 38.403) ve CEO Asistaninin DB semasi olu tablolari gosteriyordu; risk sorulursa NET kullanmasi gerektigi semaya yazildi.'
echo "  COMMITTED"
