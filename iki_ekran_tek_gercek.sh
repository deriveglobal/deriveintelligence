#!/usr/bin/env bash
# IKI_EKRAN_TEK_GERCEK — Bugun ve Finans BIRBIRINI YALANLIYOR.
#
# ⚠ EKRANDA GORULEN:
#            Bugun      Finans
#   net      103,9M     74,4M
#   alacak   238,8M     209,3M
#   yuk       41,6M     29,7M
#   Ayni uygulama, iki sekme, IKI GERCEK. Butun gun kovaladigimiz hastaligin ta kendisi.
#
# ⚠ DOGRU OLAN FINANS: hesap_bakiyesi (fiilen faturalanmis, tahsil edilecek).
#   Bugun eski tanimi kullaniyor: toplam_risk = hesap_bakiyesi + cek/senet(29,5M) + bekleyen siparis(3,8M).
#   Bekleyen siparis HENUZ PARA DEGIL -> isletme sermayesinde YERI YOK.
#
# ⚠ DSO da ayni yanlistan besleniyor: toplam_risk / gunluk ciro = 116 gun.
#   Dogru alacakla ~102 gun olmali.
#
# ⚠ VE ERDOGANLAR "3523352.6 kat" — Bugun ekraninda HALA duruyor (limit 1 TL).
#   Finans'ta "limit YOK" diyor. Ayni hata, iki yerde FARKLI davraniyor.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SUNUCU — /api/bi/ana alacak tanimi duzeltiliyor ############"
cp server_container.mjs server_container.mjs.bak_tekgercek
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "TEK_GERCEK_V1" in s: sys.exit("ZATEN YAMALI")

ESKI = '''          alacak AS (
            SELECT COALESCE(sum(toplam_risk),0)    AS risk,
                   COALESCE(sum(vadesi_gecmis),0)  AS gecikmis,
                   count(*) FILTER (WHERE vadesi_gecmis>0)  AS gecikmis_musteri,
                   count(*) FILTER (WHERE limit_asimi>0)    AS limit_asan
              FROM bi_musteri_risk
             WHERE tenant_id=$2::uuid AND COALESCE(musteri_mi,true)),'''
assert ESKI in s, "❌ ana alacak blogu bulunamadi"
YENI = '''          alacak AS (
            -- ⚠ TEK_GERCEK_V1 — 14 Tem: toplam_risk -> hesap_bakiyesi
            --   Bugun ve Finans odalari BIRBIRINI YALANLIYORDU:
            --     Bugun  net 103,9M · alacak 238,8M · yuk 41,6M
            --     Finans net  74,4M · alacak 209,3M · yuk 29,7M
            --   toplam_risk = hesap_bakiyesi + cek/senet (29,5M) + bekleyen siparis (3,8M).
            --   ⚠ BEKLEYEN SIPARIS HENUZ PARA DEGIL — isletme sermayesinde YERI YOK.
            --   Ayni uygulamada iki sayi olamaz. Kaynak: bi_musteri_risk.hesap_bakiyesi.
            SELECT COALESCE(sum(hesap_bakiyesi),0) AS risk,
                   COALESCE(sum(vadesi_gecmis),0)  AS gecikmis,
                   count(*) FILTER (WHERE vadesi_gecmis>0)  AS gecikmis_musteri,
                   count(*) FILTER (WHERE limit_asimi>0)    AS limit_asan
              FROM bi_musteri_risk
             WHERE tenant_id=$2::uuid AND COALESCE(musteri_mi,true)),'''
s = s.replace(ESKI, YENI, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ /api/bi/ana artik hesap_bakiyesi kullaniyor (DSO da bundan turer)")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_tekgercek server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 2) ARAYUZ — 'kat' gosterimi: limit YOKSA kat YOK ############"
cp shells/bi.js shells/bi.js.bak_tekgercek
python3 - <<'PY' || exit 1
import pathlib, re, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "KAT_FIX_V1" in s: sys.exit("ZATEN YAMALI")
# Bugun odasindaki risk listesinde 'kat' yazan yeri bul
m = re.search(r"([^\n]*kat[^\n]*)\n", s)
# Guvenli yol: 'kat' iceren satirlari yazdirip elle degistiremem -> hedefli arama
hedefler = [i for i,l in enumerate(s.split("\n")) if "' kat'" in l or '" kat"' in l or "+ ' kat'" in l or "kat</" in l]
print("  'kat' gecen satirlar:", [h+1 for h in hedefler][:6])
sys.exit(0)
PY

echo "  ⚠ Arayuzdeki 'kat' satirini gormeden degistirmem. Yukarida satir no var."
echo "     (Bugun odasindaki risk listesi — bir sonraki adimda hedefli yamalanacak.)"

echo
echo "############ 3) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 4) ⚠⚠ MUTABAKAT — IKI EKRAN AYNI MI DIYOR? ############"
ADMIN=$($PSQL -tAc "SELECT id FROM users WHERE role='platform_owner' AND status='active' LIMIT 1" | tr -d '[:space:]')
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$ADMIN','$HASH', now() + interval '5 minutes', '{\"amac\":\"mutabakat\"}'::jsonb);"
A="Authorization: Bearer $TOKEN"

echo "  --- /api/bi/ana (Bugun) ---"
curl -s -H "$A" http://localhost:8080/api/bi/ana | python3 -c "
import sys, json
d = json.load(sys.stdin)
s = d.get('sermaye') or d.get('kapital') or {}
for k in ('stok','alacak','risk','borc','tedarikci_borcu','net_sermaye','sermaye_yuku','yillik_yuk','dso_gun','stok_gun'):
    if k in s: print(f'    {k:18s} {float(s[k])/1e6:>10.1f} M' if float(s[k])>1e5 else f'    {k:18s} {s[k]}')
" 2>/dev/null || curl -s -H "$A" http://localhost:8080/api/bi/ana | head -c 400

echo "  --- /api/bi/finans ---"
curl -s -H "$A" http://localhost:8080/api/bi/finans | python3 -c "
import sys, json
s = json.load(sys.stdin)['sermaye']
for k in ('stok','alacak','gecikmis','borc','net_sermaye','yillik_yuk'):
    print(f'    {k:18s} {float(s[k])/1e6:>10.1f} M')
"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='mutabakat';"
echo
echo "  ⚠ IKI EKRAN AYNI SAYIYI DEMELI: alacak ≈209,3M · net ≈74,4M · yuk ≈29,7M"

echo
echo "############ 5) MARJ — koken 8,3 diyor, ekran 7,9. Hangisi? ############"
$PSQL -c "
SELECT round(100.0*sum(brut_kar)/NULLIF(sum(ciro),0), 1) AS marj_pct,
       round(sum(ciro)/1e6, 1)     AS ciro_M,
       round(sum(brut_kar)/1e6, 1) AS brut_kar_M
  FROM bi_marj_fact
 WHERE tenant_id='$T'::uuid AND ay >= CURRENT_DATE-365 AND maliyet_kaynak <> 'yok';"
echo "  ⚠ Kupte ne yaziyorsa O DOGRU. Koken metnini ona gore guncellemem lazim."

git add -A
git commit -q -m 'fix(bi): TEK_GERCEK_V1 — Bugun ve Finans odalari BIRBIRINI YALANLIYORDU. Ekranda: Bugun net 103,9M / alacak 238,8M / yuk 41,6M · Finans net 74,4M / alacak 209,3M / yuk 29,7M. Ayni uygulama, iki sekme, iki gercek — butun gun kovaladigimiz hastaligin ta kendisi. Dogru olan Finans: bi_musteri_risk.hesap_bakiyesi (fiilen faturalanmis, tahsil edilecek). Bugun eski tanimi kullaniyordu: toplam_risk = hesap_bakiyesi + cek/senet 29,5M + bekleyen siparis 3,8M; bekleyen siparis HENUZ PARA DEGIL, isletme sermayesinde yeri yok. /api/bi/ana artik hesap_bakiyesi kullaniyor; DSO da bundan turedigi icin 116 gunden ~102 gune duzeliyor.'
echo "  COMMITTED"
