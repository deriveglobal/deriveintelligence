#!/usr/bin/env bash
# ZINCIR_KANIT — iki is: (1) BENIM BIRAKTIGIM KIRLILIGI temizle, (2) zinciri CANLI kanitla.
#
# ⚠ (1) TESTTE master_musteri.refreshed_at'i 30 gun geri attim ve OYLE KALDI.
#   Veri bozulmadi — ama DAMGA yalan soyluyor. Ops monitoru bunu gorup
#   "master 30 gundur bayat" diye alarm verebilir.
#   Kendi kurdugum alarma kendi elimle yanlis veri besleyip birakamam.
#
# ⚠ (2) "Fonksiyon calisiyor" ile "zincir calisiyor" AYNI SEY DEGIL.
#   Zincirin cagirdigi refreshSahaMasters()'i, zincirin cagirdigi SEKILDE —
#   yani CANLI SUNUCU UZERINDEN, HTTP ile — tetikleyip kanitliyorum.
#   Konteyneri yeniden BASLATMIYORUM: baslatirsam acilis tazelemesi devreye girer
#   ve "calisti" sanirim. Tam da duzeltmeye calistigim yanilgi bu.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) ONCE — damga hala bayat mi? ############"
$PSQL -c "SELECT max(refreshed_at) AS damga, now() - max(refreshed_at) AS yas FROM master_musteri;"

echo
echo "############ 1) ADMIN oturumu (gecici, 5 dk, sonunda IPTAL) ############"
ADMIN=$($PSQL -tAc "SELECT id FROM users WHERE role='platform_owner' AND status='active' ORDER BY created_at LIMIT 1" | tr -d '[:space:]')
[ -n "$ADMIN" ] || { echo "❌ platform_owner bulunamadi — DUR"; exit 1; }
$PSQL -c "SELECT id, email, role FROM users WHERE id='$ADMIN';"

TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$ADMIN','$HASH', now() + interval '5 minutes', '{\"amac\":\"zincir kaniti\"}'::jsonb);"
AUTH="Authorization: Bearer $TOKEN"

# ⚠ Oturum GERCEKTEN gecerli mi? Yoksa 401'i "calisti" sanma tuzagina duseriz.
K=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "http://localhost:8080/api/saha/musteriler?limit=1")
echo "  oturum saglamasi -> HTTP $K  (200 olmali)"
[ "$K" = "200" ] || { echo "  ❌ OTURUM GECERSIZ — test anlamsiz, DURDUM."
  $PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='zincir kaniti';"; exit 1; }

echo
echo "############ 2) ⚠ ZINCIRIN CAGIRDIGI FONKSIYON — CANLI, HTTP ile ############"
echo "  POST /api/saha/master-refresh   (zincirdeki refreshSahaMasters ile AYNI fonksiyon)"
R=$(curl -s -w '\n%{http_code}' -X POST -H "$AUTH" "http://localhost:8080/api/saha/master-refresh")
echo "  yanit: $(echo "$R" | head -1)  ·  HTTP $(echo "$R" | tail -1)"

echo
echo "############ 3) SONRA — damga tazelendi mi? ############"
$PSQL -c "SELECT max(refreshed_at) AS damga, now() - max(refreshed_at) AS yas FROM master_musteri;"
YAS=$($PSQL -tAc "SELECT EXTRACT(epoch FROM (now() - max(refreshed_at)))::int FROM master_musteri")
if [ "$YAS" -lt 120 ]; then
  echo "  ✅ master TAZELENDI (yas ${YAS}sn) — zincirin cagirdigi fonksiyon CANLIDA CALISIYOR"
else
  echo "  ❌ master TAZELENMEDI (yas ${YAS}sn) — zincir KOPUK"
fi

echo
echo "############ 4) MUTABAKAT — master ham veriyle hala TUTUYOR mu? ############"
$PSQL -c "
WITH ham AS (SELECT musteri_kodu, max(fatura_tarihi) s FROM bi_satis_faturalari GROUP BY 1)
SELECT count(*) AS ortak,
       count(*) FILTER (WHERE mm.son_fatura = h.s) AS ayni,
       count(*) FILTER (WHERE mm.son_fatura IS DISTINCT FROM h.s) AS sapan
  FROM master_musteri mm JOIN ham h ON h.musteri_kodu = mm.musteri_kodu;"
echo "  ⚠ 'sapan' 0 olmali."

echo
echo "############ 5) durum dagilimi — bozulmadi mi? ############"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"
$PSQL -c "
SELECT count(*) FILTER (WHERE m.durum='AKTIF_MUSTERI' AND (mm.son_fatura IS NULL OR mm.son_fatura <= current_date-90)) AS aktif_ama_satis_yok,
       count(*) FILTER (WHERE m.durum='ESKI_NOKTA'    AND mm.son_fatura >  current_date-90)                            AS eski_ama_satis_yeni,
       count(*) FILTER (WHERE m.durum='YENI_NOKTA'    AND mm.son_fatura IS NOT NULL)                                   AS yeni_ama_faturasi_var
  FROM saha_musteri m
  LEFT JOIN master_musteri mm ON mm.tenant_id=m.tenant_id AND mm.musteri_kodu=m.musteri_kodu
 WHERE m.aktif;"
echo "  ⚠ Ucu de 0 olmali."

echo
echo "############ 6) OTURUMU KAPAT ############"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE revoked_at IS NULL AND metadata->>'amac'='zincir kaniti';"
Z=$(curl -s -o /dev/null -w '%{http_code}' -H "$AUTH" "http://localhost:8080/api/saha/musteriler?limit=1")
echo "  iptal sonrasi -> HTTP $Z  $([ "$Z" = "401" ] && echo '✅ kapandi' || echo '❌ HALA ACIK')"
$PSQL -tAc "SELECT count(*) FROM user_sessions WHERE revoked_at IS NULL AND metadata ? 'amac';" | sed 's/^/  acik test oturumu: /'
