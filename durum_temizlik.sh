#!/usr/bin/env bash
# DURUM_TEMIZLIK — durum_uygula.sh CALISMIS (ben "calistirma" demeden once).
#
# ⚠ KANIT: sunucu "ZATEN YAMALI" dedi ve ilk hesapta 674 degil 235 kayit degisti.
#   674'u o script duzeltmis; bugunku 235 ise onun ekledigi ESLESMEMIS etiketlerinin
#   YENI_NOKTA'ya donmesi. Sonuc zararsiz — ama semada KALINTI birakti:
#     (a) CHECK kisitinda artik kullanilmayan 'ESLESMEMIS'
#     (b) sunucudaki ERP-kanit LATERAL'i bi_satis_faturalari'ni tariyor,
#         oysa master_musteri ZATEN hesapli ve HAM VERIYLE BIREBIR AYNI
#         (38.627/38.627, sapma 0 gun — kapida olculdu).
#
# ⚠ VE ASIL EKSIK: KALICILIK.
#   Su an ERP yuklenirse durum TAZELENMEZ. Bugun duzeltip yarin bozulmasi,
#   hic duzeltmemekten kotudur — cunku dogru sanirsin.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) KALINTI (a) — ESLESMEMIS kisittan cikiyor ############"
KALAN=$($PSQL -tAc "SELECT count(*) FROM saha_musteri WHERE durum='ESLESMEMIS'")
echo "  ESLESMEMIS satiri: $KALAN"
[ "$KALAN" = "0" ] || { echo "  ❌ HALA VAR — kisiti daraltamam, DURDUM."; exit 1; }
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
BEGIN;
ALTER TABLE saha_musteri DROP CONSTRAINT IF EXISTS saha_musteri_durum_check;
ALTER TABLE saha_musteri ADD CONSTRAINT saha_musteri_durum_check
  CHECK (durum = ANY (ARRAY[
    'YENI_NOKTA',     -- hic fatura yok (= ERP'de yok = gercekten yeni)
    'AKTIF_MUSTERI',  -- son 90 gun
    'PASIF_NOKTA',    -- uyuyan (1 yil ici)
    'ESKI_NOKTA',     -- 1 yildan eski
    'RISKLI_NOKTA'    -- eski kayitlar icin korunuyor; ARTIK YAZILMIYOR (risk ayri eksen)
  ]));
COMMIT;
SQL
$PSQL -c "SELECT pg_get_constraintdef(oid) FROM pg_constraint WHERE conname='saha_musteri_durum_check';"

echo
echo "############ 2) KALINTI (b) — kanit master_musteri'den okunsun ############"
echo "  --- sunucuda su an hangi kaynak? ---"
grep -n "erp_fatura_sayisi\|erp_son_satis" server_container.mjs | head -5
cp server_container.mjs server_container.mjs.bak_temizlik
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "KANIT_MASTER" in s: sys.exit("  (zaten master_musteri'den okuyor)")

ESKI = '''        LEFT JOIN LATERAL (
          SELECT count(*) AS erp_fatura_sayisi,
                 min(f.fatura_tarihi) AS erp_ilk_satis,
                 max(f.fatura_tarihi) AS erp_son_satis
          FROM bi_satis_faturalari f
          WHERE m.musteri_kodu IS NOT NULL AND f.musteri_kodu = m.musteri_kodu
        ) erp ON true'''
if ESKI not in s:
    print("  ⚠ eski LATERAL bulunamadi — dokunmuyorum, elle bakilacak")
    sys.exit(0)
YENI = '''        -- ⚠ KANIT_MASTER — kaynak bi_satis_faturalari degil, master_musteri.
        --   Ikisi BIREBIR AYNI (38.627/38.627, sapma 0 gun — olculdu), ama master zaten
        --   hesapli: her istekte fatura tablosunu taramaya gerek yok. Ve TEK GERCEK olur.
        --   Ustelik ciro/bakiye/vadesi_gecmis de buradan gelir.
        LEFT JOIN master_musteri mm2
          ON mm2.tenant_id = m.tenant_id AND mm2.musteri_kodu = m.musteri_kodu'''
s = s.replace(ESKI, YENI, 1)

# SELECT tarafini master'a cevir
import re
ESKI_SEL = '''               erp.erp_fatura_sayisi, erp.erp_ilk_satis, erp.erp_son_satis,'''
if ESKI_SEL in s:
    s = s.replace(ESKI_SEL, '''               mm2.fatura_sayisi AS erp_fatura_sayisi,
               mm2.ilk_fatura    AS erp_ilk_satis,
               mm2.son_fatura    AS erp_son_satis,
               mm2.toplam_ciro   AS erp_toplam_ciro,
               mm2.son_bakiye    AS erp_bakiye,
               mm2.vadesi_gecmis AS erp_vadesi_gecmis,''', 1)
p.write_text(s, encoding="utf-8")
print("  ✅ kanit master_musteri'den (+ciro, bakiye, vadesi gecmis)")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_temizlik server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ⚠ KALICILIK — erp_ingest.py capalari (HAFIZADAN DEGIL) ############"
awk '/^BAGIMLILIK/,/^}/ { printf "%5d| %s\n", NR, $0 }' erp_ingest.py
echo "  --- yeniden kurma adimlarini KIM calistiriyor? ---"
grep -n "BAGIMLILIK\|def kur\|def yeniden\|maliyet_ay\|marj_fact\|sinyal_kredi\|MUTABAKAT" erp_ingest.py | head -20

echo
echo "############ 4) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"

echo
echo "############ 5) SON DURUM ############"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"
$PSQL -c "SELECT count(*) AS musteri, count(lat) AS haritada FROM saha_musteri WHERE aktif;"

git add -A
git commit -q -m 'chore(saha): durum kalintilari temizlendi + kanit tek kaynaga baglandi. durum_uygula.sh (geri cektigim surum) calismis; ESLESMEMIS etiketi CHECK kisitinda kalinti birakmisti — 0 satir kaldigi dogrulandi ve kisit daraltildi. Dort etiket: YENI_NOKTA (hic fatura yok = ERPde yok = gercekten yeni), AKTIF_MUSTERI (son 90 gun), PASIF_NOKTA (uyuyan), ESKI_NOKTA (1 yildan eski). RISKLI_NOKTA eski kayitlar icin korunuyor ama artik yazilmiyor: risk vadesi gecmis bakiyeden gelen AYRI bir eksen. Musteri detayindaki ERP kaniti bi_satis_faturalari LATERAL taramasindan master_musteri lookupuna cevrildi: ikisi birebir ayni (38.627/38.627, sapma 0 gun, kapida olculdu) ama master zaten hesapli ve ciro/bakiye/vadesi_gecmis de veriyor — her istekte fatura tablosunu taramaya gerek yok, ve TEK GERCEK olur.'
echo "  COMMITTED"
echo
echo "⚠ HALA KALICI DEGIL — erp_ingest baglantisi yok. Capalar (3) numarali bolumde."
