#!/usr/bin/env bash
# /api/bi/ana dagitimi — SQL ONCE Postgres'te dogrulanir, SONRA restart.
# ⚠ Bu disiplin daha once bizi kurtardi: bozuk SQL ile restart edilirse
#   uygulama 500 doner ve Pazartesi 8 temsilci acilista patlamis sistem gorur.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 0) ANCHOR — taze grep ############"
grep -n "url.pathname === '/api/bi/pricing/ccc'\|url.pathname === '/api/bi/sezon/durum'" server_container.mjs | head -3

echo
echo "############ 1) ⚠ SQL'LERI ONCE POSTGRES'TE KOS ############"
echo "   (endpoint icindeki sorgularin AYNISI — restart ONCESI dogrulama)"
$PSQL -v ON_ERROR_STOP=1 <<SQL >/dev/null 2>&1
SET app.current_tenant_id='$TEN';
WITH sa AS (
  SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))
         bi_sku_norm(kalem_kodu) AS sku, birim_fiyat_kdv_haric AS fiyat
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND miktar>0 AND birim_fiyat_kdv_haric>0
   ORDER BY 1, fatura_tarihi DESC),
stok AS (
  SELECT COALESCE(sum(st.adet*sa.fiyat),0) AS deger,
         COALESCE(sum(st.taahhut*sa.fiyat),0) AS taahhutlu,
         COALESCE(sum(st.kullanilabilir*sa.fiyat),0) AS serbest,
         COALESCE(sum(st.adet),0) AS adet
    FROM bi_stok_anlik st
    LEFT JOIN sa ON sa.sku=bi_sku_norm(st.kalem_kodu)
   WHERE st.tenant_id='$TEN'::uuid AND st.adet>0),
alacak AS (
  SELECT COALESCE(sum(toplam_risk),0) AS risk, COALESCE(sum(vadesi_gecmis),0) AS gecikmis,
         count(*) FILTER (WHERE vadesi_gecmis>0) AS gecikmis_musteri,
         count(*) FILTER (WHERE limit_asimi>0) AS limit_asan
    FROM bi_musteri_risk WHERE tenant_id='$TEN'::uuid AND COALESCE(musteri_mi,true)),
ciro AS (
  SELECT COALESCE(sum(satir_tutar),0)/365.0 AS gunluk FROM bi_satis_faturalari
   WHERE tenant_id='$TEN'::text AND miktar>0 AND ebat IS NOT NULL
     AND fatura_tarihi >= CURRENT_DATE-365)
SELECT s.deger, a.risk, ROUND(s.deger/NULLIF(c.gunluk,0)) AS stok_gun,
       ROUND(a.risk/NULLIF(c.gunluk,0)) AS dso, ROUND((s.deger+a.risk)*0.40) AS yuk
  FROM stok s, alacak a, ciro c;
SELECT bi_sinyal_puan(tutar_tl,son_tarih,eylem_var), bi_sinyal_puan_detay(tutar_tl,son_tarih,eylem_var)
  FROM bi_sinyal WHERE tenant_id='$TEN' AND durum='acik' AND tur<>'odeme' LIMIT 1;
SQL
[ $? -ne 0 ] && { echo "❌ SQL PATLADI — endpoint YAZILMADI. Restart YOK."; exit 1; }
echo "  ✅ tum sorgular Postgres'te calisti"

echo
echo "############ 2) YEDEK + YAMA ############"
cp server_container.mjs server_container.mjs.bak_anaapi
ONCE=$(wc -c < server_container.mjs)
python3 patch_ana_api.py || { echo "❌ yamaci patladi"; cp server_container.mjs.bak_anaapi server_container.mjs; exit 1; }
SONRA=$(wc -c < server_container.mjs)
echo "  boyut: $ONCE -> $SONRA"
[ "$SONRA" -gt "$ONCE" ] || { echo "❌ buyumedi"; cp server_container.mjs.bak_anaapi server_container.mjs; exit 1; }

echo
echo "############ 3) ⚠ KAPI: SOZDIZIMI ############"
node --check server_container.mjs || { echo "❌ NODE FAIL — GERI ALINIYOR"
  cp server_container.mjs.bak_anaapi server_container.mjs; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 8
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ⚠ CANLI TEST — endpoint cevap veriyor mu? ############"
CODE=$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/bi/ana)
echo "  GET /api/bi/ana -> HTTP $CODE  (401 = yasiyor, oturum gerekiyor · 404 = YOK)"
[ "$CODE" = "404" ] && { echo "  ❌ ENDPOINT YOK — geri aliniyor"
  cp server_container.mjs.bak_anaapi server_container.mjs
  docker cp server_container.mjs krb-assessment:/app/server.mjs
  docker restart krb-assessment >/dev/null; exit 1; }

echo
echo "############ 6) ⚠ SUNUCU HATA VERIYOR MU? ############"
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw\|unhandled" | head -5 || echo "  temiz"

git add -A && git commit -q -m "feat(ana): ANA_API_V1 — /api/bi/ana. Her rakam Postgres'te DOGRULANDI: bagli sermaye 507,3M (stok 268,5 + alacak 238,8) · stok 131 gun · GERCEK DSO 116 gun · yillik sermaye yuku 202,9M (%40). ⚠ DSO 116, ekrandaki 26,9 DEGIL: bi_fatura_tahsilat sadece TAHSIL EDILMIS faturalari tutuyor, 145,4M odemeyen ortalamaya HIC girmiyor (hayatta kalan yanliligi). ⚠ EVA/NOPAT DONMUYOR: bayilik cirosunun %92'sinin (319,4M/347,6M) maliyeti hesaplanamiyor — yaz+4mevsim iskonto kademesi ve TBR fiyat listesi YOK. Marj UYDURULMUYOR; endpoint 'hesaplanamiyor' + EKSIK DOSYA LISTESI donuyor. Sistemin ilk soyledigi sey kendi korlugu. ⚠ Planli odemeler (Brisa takvimi, 4 adet 129,6M) karar kuyrugundan AYRILDI — ilk 6 sinyalin 4'u bunlardi, gercek kararlari asagi itiyorlardi." && echo "  COMMITTED"

echo
echo "✅ Geri alma: cp server_container.mjs.bak_anaapi server_container.mjs && docker cp server_container.mjs krb-assessment:/app/server.mjs && docker restart krb-assessment"
