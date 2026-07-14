#!/usr/bin/env bash
# NEDEN_CALISMADI — mutabakat kapisi DUSTU. Iyi ki koydum.
#
# ⚠ BELIRTI:
#   master_musteri hala 145,4M / 663,5M diyor · risk_tarihi BOS · MUTAFLAR 50,2M (olu tablonun rakami)
#   Ama typeahead CALISTI (399 -> 38.628). Demek refreshSahaCariCache kostu.
#   O halde refreshSahaMasters ya PATLADI ya da eslesme TUTMADI. Ikisi cok farkli seyler.
#
# ⚠ "Calisti herhalde" DEMIYORUM. Sadece OKUYOR.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) KOD GERCEKTEN KONTEYNERDE MI? ############"
R=$(md5sum server_container.mjs | cut -c1-32)
C=$(docker exec krb-assessment md5sum /app/server.mjs | cut -c1-32)
[ "$R" = "$C" ] && echo "  ✅ repo = konteyner" || echo "  ❌ SAPMA — konteyner ESKI kodu calistiriyor"
docker exec krb-assessment sh -c 'grep -c "BAKIYE_NET_V2" /app/server.mjs' | sed 's/^/  konteynerde BAKIYE_NET_V2: /'

echo
echo "############ 2) ⚠ SUNUCU ACILISTA PATLADI MI? ############"
docker logs krb-assessment 2>&1 | grep -i "saha schema\|master_musteri\|error" | head -10

echo
echo "############ 3) ⚠ ESLESME TUTUYOR MU? — kod tipleri ############"
$PSQL -c "
SELECT 'master_musteri' t, column_name, data_type FROM information_schema.columns
 WHERE table_name='master_musteri' AND column_name IN ('tenant_id','musteri_kodu')
UNION ALL
SELECT 'bi_musteri_risk', column_name, data_type FROM information_schema.columns
 WHERE table_name='bi_musteri_risk' AND column_name IN ('tenant_id','muhatap_kodu')
ORDER BY 1,2;"

echo
echo "############ 4) ⚠⚠ ASIL SORU — KODLAR AYNI FORMATTA MI? ############"
echo "  --- master_musteri.musteri_kodu ornekleri ---"
$PSQL -c "SELECT musteri_kodu, left(musteri_adi,30) FROM master_musteri LIMIT 5;"
echo "  --- bi_musteri_risk.muhatap_kodu ornekleri ---"
$PSQL -c "SELECT muhatap_kodu, left(muhatap_adi,30), musteri_mi FROM bi_musteri_risk WHERE musteri_mi LIMIT 5;"

echo "  --- KAC TANESI ESLESIYOR? ---"
$PSQL -c "
SELECT (SELECT count(*) FROM master_musteri)                            AS master,
       (SELECT count(*) FROM bi_musteri_risk WHERE musteri_mi)          AS risk,
       (SELECT count(*) FROM master_musteri mm
          JOIN bi_musteri_risk r ON r.tenant_id = mm.tenant_id
                                AND r.muhatap_kodu = mm.musteri_kodu
                                AND r.musteri_mi)                       AS eslesen;"
echo "  ⚠ 'eslesen' 0 ise: kod formatlari FARKLI. Yama dogru, ANAHTAR yanlis."

echo
echo "############ 5) MUTAFLAR — iki tabloda kodu ne? ############"
$PSQL -c "SELECT 'master' k, musteri_kodu AS kod, round(son_bakiye) FROM master_musteri WHERE musteri_adi ILIKE '%MUTAFLAR%'
UNION ALL
SELECT 'risk', muhatap_kodu, round(hesap_bakiyesi) FROM bi_musteri_risk WHERE muhatap_adi ILIKE '%MUTAFLAR%' AND musteri_mi
UNION ALL
SELECT 'cari_bakiye', musteri_kodu, round(net_pozisyon) FROM bi_cari_bakiye WHERE tedarikci_adi ILIKE '%MUTAFLAR%';"
echo "  ⚠ Kodlar farkliysa mesele burada. Ayni ise UPDATE hic calismamis demektir."

echo
echo "############ 6) refreshSahaMasters'i ELLE tetikle, HATAYI GOR ############"
ADMIN=$($PSQL -tAc "SELECT id FROM users WHERE role='platform_owner' AND status='active' LIMIT 1" | tr -d '[:space:]')
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$ADMIN','$HASH', now() + interval '3 minutes', '{\"amac\":\"master teshis\"}'::jsonb);"
echo "  POST /api/saha/master-refresh :"
curl -s -w '\n  HTTP %{http_code}\n' -X POST -H "Authorization: Bearer $TOKEN" \
  http://localhost:8080/api/saha/master-refresh | sed 's/^/  /'
echo "  --- konteyner logu (son 30sn) ---"
docker logs --since 30s krb-assessment 2>&1 | tail -8
echo "  --- master simdi ne diyor? ---"
$PSQL -c "SELECT count(son_bakiye) dolu, round(sum(son_bakiye)/1e6,1) bakiye_M, max(risk_tarihi) tarih FROM master_musteri;"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='master teshis';"
