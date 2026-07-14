#!/usr/bin/env bash
# ASISTAN_BEYNI_TEMIZLE — sabit sayiyi ASISTANIN BEYNINE ben yazmisim.
#
# ⚠ BULGU (server_container.mjs:25621, asistanin SISTEM PROMPTU):
#     "MUTAFLAR: alacak 47,5M ama bizim borcumuz 46,5M, NET 1,0M (limiti 1,0M)."
#   Bunu oraya BAKIYE_NET_V2 yamasinda BEN KOYDUM. Bugun. Birkac saat once.
#
# ⚠ ASISTAN BU METNI HER SORUDA OKUYOR.
#   MUTAFLAR yarin borcunu kapatsa, asistan HALA "47,5M ama net 1,0M" diyecek
#   ve kullanici bunu VERIDEN GELMIS sanacak.
#   Ekrandaki sabit sayilari temizlerken, AYNI SABIT SAYILARI beyne yazmisim.
#
# ⚠ Fatih Bilen "gelir konusunda yalan soyledi" demisti. Mekanizma TAM BUYDU:
#   asistan, promptuna gomulu eski bir sayiyi okuyup HESAPLAMIS GIBI soyluyor.
#
# ✅ ILKE: prompta ORNEK degil KURAL yazilir.
#   Ornek eskir. Kural eskimez. Sayiyi asistan SORGUYLA bulsun.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) ONCE — prompttaki sabit sayilar ############"
awk 'NR>=25606 && NR<=25640 { printf "%5d| %s\n", NR, $0 }' server_container.mjs

echo
echo "############ 2) TEMIZLE — ornek CIKAR, kural KALSIN ############"
cp server_container.mjs server_container.mjs.bak_beyin
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "BEYIN_TEMIZ_V1" in s: sys.exit("ZATEN YAMALI")

ESKI = """    '    ⚠⚠ RISK SORULURSA NET_POZISYON KULLAN, BRUT DEGIL. Bir musteri ayni zamanda\\n' +
    '    tedarikci olabilir. MUTAFLAR: alacak 47,5M ama bizim borcumuz 46,5M, NET 1,0M\\n' +
    '    (limiti 1,0M). Brut bakip \\'limitin 47 kati\\' demek YANLIS ALARM olur.\\n' +"""
assert ESKI in s, "❌ MUTAFLAR ornegi bulunamadi"

YENI = """    '    ⚠⚠ BEYIN_TEMIZ_V1 — RISK SORULURSA net_pozisyon KULLAN, brut DEGIL.\\n' +
    '    Bir musteri ayni zamanda tedarikci olabilir; ona olan borcumuz alacagimizdan\\n' +
    '    dusulur. Brut alacagi kredi limitiyle kiyaslamak YANLIS ALARM uretir.\\n' +
    '    ⚠ ORNEK VERME, SORGU CALISTIR: rakami her zaman veritabanindan oku.\\n' +
    '    (Bu prompta bir ornek musteri ve rakamlari yazilmisti; musteri borcunu\\n' +
    '     kapatinca prompt YALAN SOYLEMEYE devam ediyordu. Kaldirildi.)\\n' +"""
s = s.replace(ESKI, YENI, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ MUTAFLAR ornegi kaldirildi — kural kaldi")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_beyin server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ⚠ ASISTAN PROMPTUNUN TAMAMINDA SABIT SAYI TARAMASI ############"
echo "  (buildDeptSystemPrompt + DB_SCHEMA + deptExtra — HER SORUDA okunuyor)"
python3 - <<'PY'
import re, pathlib
lines = pathlib.Path("server_container.mjs").read_text(encoding="utf-8").split("\n")
bas = next(i for i,l in enumerate(lines) if "function buildDeptSystemPrompt" in l)
son = bas + 220
sayi = re.compile(r"\d+[.,]\d+\s*M\b|\b\d{2,3},\d\b|%\s?\d+[,.]?\d*|\b\d{3,}\s*(gün|adet|müşteri)")
bulunan = 0
for i in range(bas, min(son, len(lines))):
    l = lines[i]
    if l.strip().startswith("//"): continue
    m = sayi.findall(l)
    if m and not re.search(r"slice\(|substring|length|LIMIT|\$\d", l):
        print(f"  {i+1:5d}| {l.strip()[:110]}")
        bulunan += 1
print(f"\n  {'⚠ ' + str(bulunan) + ' satirda sabit sayi VAR' if bulunan else '✅ prompt TEMIZ — sabit sayi yok'}")
PY

echo
echo "############ 4) KOKEN SINIR METINLERI — sayidan arindir ############"
# ⚠ SINIR bir KURAL olmali, bir OLCUM degil.
#   "Bekleyen siparis dahil degildir" -> KALICI DOGRU
#   "209,3M'dir"                      -> BIR AYLIK OMRU VAR
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_sayi_koken SET sinir =
'⚠ İŞLETME SERMAYESİ İÇİN BU KULLANILIR — toplam_risk DEĞİL. Fark: toplam_risk''e çek/senet riski ve bekleyen sipariş de dahildir. Bekleyen sipariş henüz PARA DEĞİLDİR.
⚠ Eski bi_musteri_bakiye tablosu müşterilerin çok küçük bir kısmını içeriyordu ve KOLONLARI KAYMIŞTI: "bakiye" dediği aslında vadesi geçmiş tutardı. O tablo artık kullanılmıyor.'
WHERE anahtar='alacak_bakiye';

UPDATE bi_sayi_koken SET sinir =
'⚠ Bu bir oran değil, bir DURUM: alacağın büyük bölümü zaten vadesini geçirmiş.
⚠ Tedarikçi ödeme takvimi yaklaşırken bu tutarın ne kadarının tahsil edilebileceği ayrıca hesaplanmalı — sistem bunu HENÜZ hesaplamıyor.'
WHERE anahtar='vadesi_gecmis';

UPDATE bi_sayi_koken SET sinir =
'⚠ "Limit AŞILDI" ile "limit HİÇ KONULMAMIŞ" aynı şey değil. Birincisi bir İHLAL — müdahale ister. İkincisi bir BOŞLUK — karar ister.
⚠ ERP''de limit tanımsızlığı bazen 0, bazen 1 TL olarak duruyor. Sistem 1 TL''yi limit saymaz.'
WHERE anahtar='limitsiz_alacak';

UPDATE bi_sayi_koken SET sinir =
'⚠ Bu takvim ELLE GİRİLDİ (13 Tem). ERP''den türetilmiyor.
⚠ Brisa taksitleri değişirse bu ekran GÜNCELLENMEZ ve yanlış gösterir. Değişiklik olursa haber verilmeli.
⚠ Ödeme tarihinde beklenen TAHSİLAT tanımlı değil: çıkış belli, giriş belli değil.'
WHERE anahtar='brisa_takvim';

UPDATE bi_sayi_koken SET sinir =
'⚠ Sermaye maliyeti bir VARSAYIMDIR — ölçülmüş bir gerçek değil. Ayarlardan değiştirilebilir.
⚠ Bu sayı 13 Tem''e kadar YANLIŞTI: tedarikçi borcu hiç sayılmıyordu ve "değer kaybediyorsun" tezi kurulmuştu; ikisi de yanlıştı.
⚠ 14 Tem''de ikinci düzeltme: alacak bacağı toplam_risk yerine hesap_bakiyesi oldu — bekleyen sipariş henüz para değil.'
WHERE anahtar='net_sermaye';

UPDATE bi_sayi_koken SET sinir =
'⚠ ALT SINIR: ERP maliyeti FATURA maliyetidir, tedarikçi primi ÖNCESİDİR. Prim dahil edilirse efektif marj daha yüksektir.
⚠ MARKA BAZINDA GÜVENİLMEZ: ERP''nin hareketli ortalama maliyeti alış faturasından markadan markaya sapıyor. Toplamda tutuyor, marka kırılımında tutmuyor — bu yüzden marka bazlı marj GÖSTERİLMEZ.
⚠ Küp her ERP yüklemesinde yeniden kurulur; mutabakat kapısı, yeni küp mevcut küpten 3 puandan fazla saparsa kurulumu DURDURUR.'
WHERE anahtar='brut_marj';
SQL
echo "  ✅ 6 koken SINIR metni sayidan arindirildi — artik KURAL, olcum degil"

docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
SELECT anahtar,
       (length(sinir) - length(regexp_replace(sinir, '[0-9]', '', 'g'))) AS rakam_adedi
  FROM bi_sayi_koken ORDER BY 2 DESC;"
echo "  ⚠ Kalan rakamlar sadece TARIH olmali (13 Tem, 14 Tem) — onlar gecmise ait, degismez."

echo
echo "############ 5) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'grep -c "BEYIN_TEMIZ_V1" /app/server.mjs' | sed 's/^/  imajda BEYIN_TEMIZ_V1: /'

git add -A
git commit -q -m 'fix(brain): BEYIN_TEMIZ_V1 — sabit sayiyi ASISTANIN BEYNINE BEN yazmisim. server_container.mjs:25621, asistanin sistem promptu: "MUTAFLAR: alacak 47,5M ama bizim borcumuz 46,5M, NET 1,0M (limiti 1,0M)." Bunu BAKIYE_NET_V2 yamasinda bugun, birkac saat once ben koydum. Asistan bu metni HER SORUDA okuyor: MUTAFLAR yarin borcunu kapatsa asistan hala "47,5M ama net 1,0M" diyecek ve kullanici bunu VERIDEN GELMIS sanacak. Ekrandaki sabit sayilari temizlerken ayni sabit sayilari beyne yazmisim. Fatih Bilen 11 Temmuzda asistani "gelir konusunda yalan soyledi" diyerek birakmisti — mekanizma tam buydu: asistan promptuna gomulu eski bir sayiyi okuyup HESAPLAMIS GIBI soyluyor. Ornek kaldirildi, kural birakildi: "risk sorulursa net_pozisyon kullan; bir musteri ayni zamanda tedarikci olabilir; ORNEK VERME, SORGU CALISTIR — rakami her zaman veritabanindan oku." Ayrica 6 koken SINIR metni sayidan arindirildi: SINIR bir KURAL olmali, bir OLCUM degil. "Bekleyen siparis dahil degildir" kalici dogrudur; "209,3Mdir" bir aylik omru vardir.'
echo "  COMMITTED"
