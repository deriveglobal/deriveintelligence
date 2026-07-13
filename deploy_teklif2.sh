#!/usr/bin/env bash
# TEKLIF_V2_FIX (agirlikli satis fiyati) + TEKLIF_UI_V2 (ekran) — birlikte.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SUNUCU: agirlikli SATIS FIYATI eksikti ############"
if grep -q "agirlikli_satis_fiyati" server_container.mjs; then echo "  ZATEN VAR"; else
  cp server_container.mjs server_container.mjs.bak_tfix
  python3 patch_teklif_fix.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_tfix server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL — geri alindi"; cp server_container.mjs.bak_tfix server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 2) SQL'i POSTGRES'E DOGRULAT ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN SELECT ROUND(SUM(miktar*(vade_tarihi-fatura_tarihi))/NULLIF(SUM(miktar),0)) AS ag_satis_vade,
       ROUND(SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0)) AS ag_satis_fiyat
  FROM bi_satis_faturalari sv
 WHERE sv.tenant_id='$TEN'::text AND sv.kalem_kodu='LTC-11283'
   AND sv.birim_fiyat > 0 AND sv.vade_tarihi IS NOT NULL
   AND sv.fatura_tarihi >= date_trunc('year', CURRENT_DATE);" >/dev/null \
  && echo "  SQL_OK" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_tfix server_container.mjs; exit 1; }

echo
echo "############ 3) EKRAN: saha.js ############"
cp shells/saha.js shells/saha.js.bak_teklifui
ONCE=$(wc -c < shells/saha.js)
if grep -q "TEKLIF_UI_V2" shells/saha.js; then echo "  ZATEN YAMALI"; else
  python3 patch_teklif_ui.py shells/saha.js || {
    echo "❌ geri alindi"; cp shells/saha.js.bak_teklifui shells/saha.js; exit 1; }
  SONRA=$(wc -c < shells/saha.js)
  echo "  boyut: $ONCE -> $SONRA"
  [ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp shells/saha.js.bak_teklifui shells/saha.js; exit 1; }
  node --check shells/saha.js || { echo "❌ NODE FAIL"; cp shells/saha.js.bak_teklifui shells/saha.js; exit 1; }
  echo "  NODE_OK"
  # ⚠ closure tuzagi: fonksiyonlar SUTUN 0'da olmali
  for F in _vadeHTML _kendiSatisHTML _vadeMaliyetHTML _teklifAnalizHTML; do
    grep -q "^function $F" shells/saha.js && echo "  ✅ $F sutun 0" || {
      echo "  ❌ $F SUTUN 0'DA DEGIL"; cp shells/saha.js.bak_teklifui shells/saha.js; exit 1; }
  done
  [ -f dispatch_guard.py ] && { python3 dispatch_guard.py shells/saha.js >/dev/null 2>&1 && echo "  DISPATCH_OK" || echo "  (dispatch guard atlandi)"; }
fi

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker cp shells/saha.js krb-assessment:/app/shells/saha.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7

echo
echo "############ 5) DOGRULAMA ############"
curl -s -o /dev/null -w "  GET /              -> HTTP %{http_code}\n" http://localhost:8080/
curl -s -o /tmp/_s.js -w "  GET shells/saha.js -> HTTP %{http_code} (%{size_download} B)\n" http://localhost:8080/shells/saha.js
grep -c "_kendiSatisHTML" /tmp/_s.js | xargs echo "  _kendiSatisHTML servis ediliyor:"

echo
echo "############ 6) CANLI — onaylayan ARTIK BUNU gorecek ############"
$PSQL -x -c "
SELECT t.marka || ' ' || t.ebat AS urun,
       oz.mn AS min_TL, oz.med AS medyan_TL, oz.mx AS max_TL,
       oz.ucuz AS en_ucuza_ALAN, oz.pahali AS en_pahaliya_ALAN,
       al.f AS agirlikli_ALIS_fiyati, al.v AS alis_vadesi_gun,
       sv.f AS agirlikli_SATIS_fiyati, sv.v AS satis_vadesi_gun,
       CASE WHEN al.f>0 AND sv.f>0
            THEN ROUND((sv.f-al.f)/sv.f*100,1) END AS gerceklesen_marj_pct
  FROM saha_teklif t
  LEFT JOIN LATERAL (SELECT ROUND(MIN(birim_fiyat)) mn,
      ROUND(percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat)::numeric) med,
      ROUND(MAX(birim_fiyat)) mx,
      (array_agg(musteri_adi ORDER BY birim_fiyat ASC))[1] ucuz,
      (array_agg(musteri_adi ORDER BY birim_fiyat DESC))[1] pahali
    FROM bi_satis_faturalari sf WHERE sf.tenant_id=t.tenant_id::text AND sf.ebat=t.ebat
      AND upper(sf.marka)=upper(t.marka) AND sf.birim_fiyat>0
      AND sf.fatura_tarihi >= date_trunc('year',CURRENT_DATE)) oz ON true
  LEFT JOIN LATERAL (SELECT ROUND(SUM(miktar*birim_fiyat_kdv_haric)/NULLIF(SUM(miktar),0)) f,
      ROUND(SUM(miktar*vade_gun)/NULLIF(SUM(miktar),0)) v
    FROM bi_tedarikci_faturalari tf WHERE tf.tenant_id=t.tenant_id AND tf.kalem_kodu=t.kalem_kodu
      AND tf.vade_gun IS NOT NULL AND tf.fatura_tarihi >= date_trunc('year',CURRENT_DATE)) al ON true
  LEFT JOIN LATERAL (SELECT ROUND(SUM(miktar*birim_fiyat)/NULLIF(SUM(miktar),0)) f,
      ROUND(SUM(miktar*(vade_tarihi-fatura_tarihi))/NULLIF(SUM(miktar),0)) v
    FROM bi_satis_faturalari sv2 WHERE sv2.tenant_id=t.tenant_id::text AND sv2.kalem_kodu=t.kalem_kodu
      AND sv2.birim_fiyat>0 AND sv2.vade_tarihi IS NOT NULL
      AND sv2.fatura_tarihi >= date_trunc('year',CURRENT_DATE)) sv ON true
 WHERE t.tenant_id='$TEN'::uuid AND t.kalem_kodu IS NOT NULL
 ORDER BY t.created_at DESC LIMIT 2;"

git add -A && git commit -q -m "fix(teklif): agirlikli SATIS FIYATI eksikti (Fatih tespit etti) + TEKLIF_UI_V2 ekran" && echo "  COMMITTED"
echo
echo "✅ Geri alma: cp server_container.mjs.bak_tfix server_container.mjs; cp shells/saha.js.bak_teklifui shells/saha.js"
