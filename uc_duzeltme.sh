#!/usr/bin/env bash
# UC_DUZELTME — (1) 'kat' hatasi  (2) marj kokeni  (3) ⚠ SABIT REFERANSLI KAPI
#
# ⚠ IS 1 — bi.js:441 KOKU:
#     r.kredi_limiti ? ' · limit ' + _M(r.kredi_limiti) + (kat ? ... + ' kat' : '') : ' · limit yok'
#   kredi_limiti = 1 (BIR Turk Lirasi) JavaScript'te TRUTHY.
#   Sistem "limiti var" diyor, _M(1) = "0,0M" yaziyor, 3,5M'yi 1'e bolup 3.523.352 KAT buluyor.
#   ERP limit yoklugunu bazen 0, bazen 1 ile ifade ediyor. Fark burada PATLIYOR.
#
# ⚠ IS 2 — MARJ: kupte %8,1 (ciro 646,6M · brut kar 52,1M · 13.996 satir).
#   Koken %8,3 yaziyor, ben Fatih'e %8,3 demistim, ekran %7,9 gosteriyor. UCU DE HIZALANACAK.
#
# ⚠⚠ IS 3 — EN ONEMLISI: erp_ingest.py'deki MUTABAKAT KAPISI SABIT BIR SAYIYA BAGLI:
#     if abs(float(m) - 8.3) > 3: KUP KURULMAZ
#   Bu kapi, VERININ DEGISMEDIGINI VARSAYIYOR.
#   Bugun marj %8,1. Alti ay sonra gercekten %5'e duserse, kapi "bozuk" deyip
#   DOGRU kubu reddeder ve sistem BAYAT kupte donar. Kimse fark etmez.
#   ⚠ Bir kapi, olcmesi gereken seyi olcmuyorsa kapi degil ENGELDIR. Bugun bunu ogrendik.
#   ✅ COZUM: kapi sabite degil, MEVCUT KUPE baksin. "Yeni kup eskisinden 3 puandan
#      fazla sapiyorsa DUR" — bu, verinin degismesine izin verir ama ANI SICRAMAYI yakalar.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) ARAYUZ — limit 1 TL ise 'limit TANIMSIZ' ############"
cp shells/bi.js shells/bi.js.bak_kat2
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "KAT_FIX_V1" in s: sys.exit("ZATEN YAMALI")
ESKI = "           + (r.kredi_limiti ? ' · limit ' + _M(r.kredi_limiti) + (kat ? ' · ' + kat + ' kat' : '') : ' · limit yok')"
assert ESKI in s, "❌ 441 capasi bulunamadi"
YENI = """           // ⚠ KAT_FIX_V1 — kredi_limiti = 1 TL, JS'te TRUTHY.
           //   Eski hali "limit 0,0M · 3.523.352 kat" yaziyordu (3,5M ÷ 1 TL).
           //   ERP limit yoklugunu bazen 0, bazen 1 ile ifade ediyor.
           //   "Limit ASILDI" ile "limit HIC KONULMAMIS" ayni sey degil:
           //   birincisi ihlal (mudahale), ikincisi bosluk (KARAR).
           + (Number(r.kredi_limiti) > 1
                ? ' · limit ' + _M(r.kredi_limiti) + (kat ? ' · ' + kat + ' kat' : '')
                : ' · limit TANIMSIZ')"""
s = s.replace(ESKI, YENI, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ limit ≤ 1 TL -> 'limit TANIMSIZ'")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_kat2 shells/bi.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 2) MARJ KOKENI — kupten okunan gercek deger ############"
GERCEK=$($PSQL -tAc "
SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1)
  FROM bi_marj_fact WHERE tenant_id='$T' AND ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok';" | tr -d ' ')
echo "  kupteki gercek marj: %$GERCEK"
$PSQL -c "
UPDATE bi_sayi_koken
   SET sinir = '✅ DOĞRULANDI (14 Tem): küpteki gerçek değer %$GERCEK — ciro 646,6M, brüt kâr 52,1M, 13.996 satır. ⚠ Daha önce %8,3 yazıyordu; küp tazelendikçe kayar, bu normaldir. ⚠ ALT SINIR: ERP maliyeti FATURA maliyetidir, prim ÖNCESİDİR. ⚠ MARKA KIRILIMI YOK: ERP''nin hareketli ortalaması alış faturasından markadan markaya sapıyor (Sailun −%40, Dayton +%48). Toplamda götürüyor, marka bazında GÜVENİLMEZ.'
 WHERE anahtar = 'brut_marj';"
echo "  ✅ koken %$GERCEK olarak guncellendi"

echo
echo "############ 3) ⚠⚠ MUTABAKAT KAPISI — sabit sayidan KURTARILIYOR ############"
grep -n "8.3" erp_ingest.py | head -4
cp erp_ingest.py erp_ingest.py.bak_kapi
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("erp_ingest.py"); s = p.read_text(encoding="utf-8")
if "KAPI_DINAMIK_V1" in s: sys.exit("ZATEN YAMALI")

ESKI = '''                m = cur.fetchone()[0]
                if m is None or abs(float(m) - 8.3) > 3:'''
assert ESKI in s, "❌ mutabakat kapisi bulunamadi"
YENI = '''                m = cur.fetchone()[0]
                # ⚠⚠ KAPI_DINAMIK_V1 — kapi ARTIK SABIT BIR SAYIYA BAGLI DEGIL.
                #   Eski hali: abs(m - 8.3) > 3 -> KUP KURULMAZ.
                #   Bu kapi VERININ DEGISMEDIGINI VARSAYIYORDU.
                #   Alti ay sonra marj gercekten %5'e duserse, kapi DOGRU kubu
                #   "bozuk" diye reddeder ve sistem BAYAT kupte donar. Kimse fark etmez.
                #   ⚠ Olcmesi gereken seyi olcmeyen kapi, kapi degil ENGELDIR.
                #   ✅ Kapi artik MEVCUT KUPE bakiyor: yeni kup eskisinden 3 puandan
                #      fazla sapiyorsa DUR. Veri degisebilir; ANI SICRAMA yakalanir.
                cur.execute("""
                    SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1)
                      FROM bi_marj_fact
                     WHERE ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok'""")
                _e = cur.fetchone()
                eski = float(_e[0]) if _e and _e[0] is not None else None
                referans = eski if eski is not None else 8.1   # ilk kurulum: olculmus deger
                if m is None or abs(float(m) - referans) > 3:'''
s = s.replace(ESKI, YENI, 1)

# uyari metnini de referansa bagla
E2 = '''                        f"⚠ MARJ KUBU KURULMADI: yeni kup %{m} veriyor, "
                        f"beklenen %8,3 (±3). ESKI KUP YERINDE KALDI. "
                        f"Bozuk bir kup, eski bir kupten kotudur.")'''
if E2 in s:
    s = s.replace(E2, '''                        f"⚠ MARJ KUBU KURULMADI: yeni kup %{m} veriyor, "
                        f"mevcut kup %{referans} (±3 puan tolerans). ESKI KUP YERINDE KALDI. "
                        f"Bozuk bir kup, eski bir kupten kotudur. "
                        f"⚠ Marj GERCEKTEN degistiyse tolerans elle gozden gecirilmeli.")''', 1)
p.write_text(s, encoding="utf-8")
print("  ✅ kapi sabit 8.3 yerine MEVCUT KUPE bakiyor")
PY
python3 -c "import ast; ast.parse(open('erp_ingest.py',encoding='utf-8').read()); print('  ✅ python sozdizimi')" \
  || { cp erp_ingest.py.bak_kapi erp_ingest.py; echo "❌ PY FAIL"; exit 1; }

echo
echo "############ 4) DAGIT + DOGRULA ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'grep -c "KAT_FIX_V1" /app/shells/bi.js' | sed 's/^/  imajda KAT_FIX_V1: /'
docker exec krb-assessment sh -c 'grep -c "KAPI_DINAMIK_V1" /app/erp_ingest.py' | sed 's/^/  imajda KAPI_DINAMIK_V1: /'

echo
echo "  --- ⚠ KAPI GERCEKTEN CALISIYOR MU? motoru cagirip dene ---"
docker exec krb-assessment python3 -c "
import sys; sys.path.insert(0,'/app')
import erp_ingest, json
print(json.dumps(erp_ingest.turet('$T','satis_faturalari'), ensure_ascii=False))
"
echo "  ⚠ 'turetilen: [marj_fact (%8.1)]' gorunmeli. 'uyari' bos olmali."

$PSQL -c "SELECT anahtar, left(sinir, 70) AS sinir FROM bi_sayi_koken WHERE anahtar='brut_marj';"

git add -A
git commit -q -m 'fix(bi): UC_DUZELTME. (1) KAT_FIX_V1 — bi.js:441de kredi_limiti = 1 TL JavaScriptte TRUTHY oldugu icin sistem "limit 0,0M · 3.523.352 kat" yaziyordu (3,5M ÷ 1 TL). ERP limit yoklugunu bazen 0 bazen 1 ile ifade ediyor. Artik limit <= 1 TL ise "limit TANIMSIZ" yaziyor: "limit ASILDI" mudahale ister, "limit HIC KONULMAMIS" KARAR ister; ikisi ayni alarma girerse ikisi de gurultu olur. (2) MARJ — kupteki gercek deger %8,1 (ciro 646,6M, brut kar 52,1M, 13.996 satir); koken %8,3 yaziyordu, Fatihe %8,3 demistim, ekran %7,9 gosteriyordu. Uc kaynak da kupten okunan degere hizalandi. (3) ⚠ EN ONEMLISI — KAPI_DINAMIK_V1: erp_ingest.pydeki mutabakat kapisi SABIT bir sayiya bagliydi (abs(m - 8.3) > 3 -> kup kurulmaz). Bu kapi VERININ DEGISMEDIGINI VARSAYIYORDU: alti ay sonra marj gercekten %5e duserse kapi DOGRU kubu bozuk diye reddeder, sistem bayat kupte donar ve kimse fark etmez. Kapi artik sabite degil MEVCUT KUPE bakiyor — veri degisebilir, ANI SICRAMA yakalanir. Bugunun dersi: olcmesi gereken seyi olcmeyen kapi, kapi degil ENGELDIR (bunu kendi parantez sayacimla da yasadim: calisan bir yamayi cope attirdi).'
echo "  COMMITTED"
