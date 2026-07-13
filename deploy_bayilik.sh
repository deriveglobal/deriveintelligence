#!/usr/bin/env bash
# BAYILIK_V1 — bayilik markasi (liste-tesvik) vs net alim markasi (son alis fiyati).
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) ON KOSUL: SEZON_V1 yamali mi? ############"
grep -q "SEZON_V1" server_container.mjs || { echo "❌ DUR: SEZON_V1 yok. Once deploy_sezon.sh"; exit 1; }
grep -q "SEZON_UI_V1" shells/saha.js     || { echo "❌ DUR: SEZON_UI_V1 yok."; exit 1; }
echo "  ✅ SEZON_V1 + SEZON_UI_V1 yerinde"

echo
echo "############ 1) SQL'i ONCE POSTGRES'E DOGRULAT ############"
echo "  ⚠ Gecen sefer gecerli JS + gecersiz SQL uygulamayi dusurmustu."
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT 1 FROM bi_fiyat_iskonto
 WHERE tenant_id='$TEN'::uuid AND upper(marka)=upper('LASSA') AND aktif=true LIMIT 1;" >/dev/null \
 && echo "  SQL_OK: _bayilikMi" || { echo "❌ SQL FAIL: _bayilikMi"; exit 1; }

$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT birim_fiyat_kdv_haric AS f, fatura_tarihi AS t, tedarikci_adi AS td,
       vade_gun AS vg, (CURRENT_DATE - fatura_tarihi)::int AS gun
  FROM bi_tedarikci_faturalari
 WHERE tenant_id='$TEN'::uuid AND kalem_kodu='X' AND birim_fiyat_kdv_haric > 0
 ORDER BY fatura_tarihi DESC LIMIT 1;" >/dev/null \
 && echo "  SQL_OK: _sonAlisFiyati" || { echo "❌ SQL FAIL: _sonAlisFiyati"; exit 1; }

echo
echo "############ 2) ⚠ RLS KONTROLU — uygulama tedarikci tablosunu OKUYABILIYOR mu? ############"
echo "   bi_tedarikci_faturalari FORCED RLS. app.current_tenant_id kurulmuyorsa"
echo "   sorgu 0 satir doner ve HATA VERMEZ -- sessizce 'alis yok' der."
grep -c "app.current_tenant_id" server_container.mjs | sed 's/^/   kodda app.current_tenant_id gecisi: /'
echo "   ^ 0 ise: mevcut agirlikli-alis sorgusu da calismiyordur. Kontrol:"
$PSQL -c "
SELECT count(*) AS tedarikci_faturasi_gorunur
  FROM bi_tedarikci_faturalari WHERE tenant_id='$TEN'::uuid;" 2>&1 | head -4

echo
echo "############ 3) YAMA: sunucu ############"
if grep -q "BAYILIK_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_bayilik
  python3 patch_bayilik.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_bayilik server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_bayilik server_container.mjs; exit 1; }
  echo "  NODE_OK"
  grep -q "^async function _bayilikMi" server_container.mjs && echo "  ✅ _bayilikMi sutun 0" || {
    echo "  ❌ closure icinde"; cp server_container.mjs.bak_bayilik server_container.mjs; exit 1; }
  grep -q "^async function _sonAlisFiyati" server_container.mjs && echo "  ✅ _sonAlisFiyati sutun 0" || {
    echo "  ❌ closure icinde"; cp server_container.mjs.bak_bayilik server_container.mjs; exit 1; }
fi

echo
echo "############ 4) YAMA: ekran ############"
if grep -q "BAYILIK_UI_V1" shells/saha.js; then echo "  ZATEN YAMALI"; else
  cp shells/saha.js shells/saha.js.bak_bayilik
  ONCE=$(wc -c < shells/saha.js)
  python3 patch_bayilik_ui.py shells/saha.js || {
    echo "❌ geri alindi"; cp shells/saha.js.bak_bayilik shells/saha.js; exit 1; }
  SONRA=$(wc -c < shells/saha.js)
  echo "  boyut: $ONCE -> $SONRA"
  [ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/saha.js.bak_bayilik shells/saha.js; exit 1; }
  node --check shells/saha.js || { echo "❌ NODE FAIL"; cp shells/saha.js.bak_bayilik shells/saha.js; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 5) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 6) DAVRANIS TESTI — bu yil satilan ciro NASIL fiyatlanacak? ############"
$PSQL -c "
WITH s AS (
  SELECT s.marka, s.kalem_kodu, s.satir_tutar, s.kategori,
         EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                  WHERE i.tenant_id='$TEN'::uuid AND i.aktif
                    AND upper(i.marka)=upper(s.marka)) AS bayilik,
         EXISTS (SELECT 1 FROM bi_tedarikci_faturalari t
                  WHERE t.tenant_id='$TEN'::uuid AND t.kalem_kodu=s.kalem_kodu
                    AND t.birim_fiyat_kdv_haric > 0) AS alis_var
    FROM bi_satis_faturalari s
   WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
     AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)),
k AS (
  SELECT CASE
     WHEN NOT bayilik AND alis_var THEN '✅ NET ALIM — son alis fiyati (YENI: artik hesaplaniyor)'
     WHEN NOT bayilik AND NOT alis_var THEN '❌ NET ALIM ama hic alinmamis — bilinmiyor'
     WHEN bayilik AND (kategori ILIKE '%KIS%') THEN '✅ BAYILIK — kis tesviki VAR'
     ELSE '⚠ BAYILIK ama tesvik EKSIK (yaz/4mevsim/TBR yuklenmemis)'
   END AS durum, satir_tutar FROM s)
SELECT durum, count(*) AS satir,
       round(sum(satir_tutar)/1e6,1) AS ciro_MTL,
       round(100.0*sum(satir_tutar)/sum(sum(satir_tutar)) OVER (),1) AS ciro_pct
  FROM k GROUP BY 1 ORDER BY 3 DESC;"

echo
echo "############ 7) ⚠ KRB'YE SOYLENECEK — TEK EKSIK ############"
$PSQL -c "
SELECT s.marka,
       CASE WHEN s.kategori ILIKE '%4 MEVSIM%' THEN '4MEVSIM'
            WHEN s.kategori ILIKE '%KIS%' THEN 'KIS'
            WHEN s.kategori ILIKE '%YAZ%' THEN 'YAZ' ELSE 'TICARI/TBR' END AS eksik_sezon,
       count(*) AS satir, round(sum(s.satir_tutar)/1e6,2) AS ciro_MTL
  FROM bi_satis_faturalari s
 WHERE s.tenant_id='$TEN' AND s.grup_adi LIKE 'LASTIK%'
   AND s.fatura_tarihi >= date_trunc('year', CURRENT_DATE)
   AND EXISTS (SELECT 1 FROM bi_fiyat_iskonto i
                WHERE i.tenant_id='$TEN'::uuid AND i.aktif AND upper(i.marka)=upper(s.marka))
   AND s.kategori NOT ILIKE '%KIS%'
 GROUP BY 1,2 ORDER BY 4 DESC LIMIT 10;"
echo "  ^ SADECE bunlar eksik. Net alim markalari icin BIR SEY GEREKMIYOR."

git add -A && git commit -q -m "fix(teklif): BAYILIK_V1 — KRB sadece Brisa+Continental bayisi. Net alim markalarinda ikame maliyeti = son net alis fiyati (tesvik aranmaz). Bayilik markalarinda tesvik eksikse gercek bosluk olarak bildirilir. Ciro'nun %38,7'si icin marj artik hesaplanabiliyor." && echo "  COMMITTED"

echo
echo "✅ Geri alma:"
echo "   cp server_container.mjs.bak_bayilik server_container.mjs"
echo "   cp shells/saha.js.bak_bayilik shells/saha.js"
echo "   docker cp server_container.mjs krb-assessment:/app/server.mjs"
echo "   docker cp shells/saha.js krb-assessment:/app/shells/saha.js && docker restart krb-assessment"
