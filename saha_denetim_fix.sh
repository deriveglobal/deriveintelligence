#!/usr/bin/env bash
# SAHA_DENETIM_FIX — iki hatami kapatiyorum.
#
# ⚠ HATA 1 — TEST OTURUMU ACIK KALDI.
#   psql -tAc ciktisina "INSERT 0 1" karisti, $SID bozuk uuid oldu, UPDATE patladi.
#   Iptal sonrasi istek 401 degil 200 dondu: Eftal'in kimligiyle actigim oturum HALA CANLI.
#   10 dakikada kendiliginden olur — ama BIRAKMAM. Simdi kapatiyorum.
#
# ⚠ HATA 2 — DENETIM KAYDI DUSMEDI (0 satir).
#   Kapiyi kaldirdim, yerine koydugum IZ calismiyor. Yani su an baskasinin musterisini
#   kim degistirdi, HIC BILINMIYOR.
#   Sebep: INSERT'te  'PUT /api/saha/musteriler/'||$3  ifadesinde $3'un tipi belirsiz
#   ("could not determine data type of parameter $3") -> sorgu patladi ->
#   ve BENIM yazdigim  catch (_e) { /* denetim kaydi asla isi bloklamaz */ }
#   hatayi SESSIZCE YUTTU.
#   ⚠ Sessiz yutmayi duzeltirken sessiz yutan kod yazmisim. Ayni hastalik.
#   Cozum: $3::text cast + catch ARTIK SUSMUYOR (console.error).
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ⚠ ACIK KALAN TEST OTURUMUNU KAPAT ############"
$PSQL -c "
UPDATE user_sessions SET revoked_at = now()
 WHERE revoked_at IS NULL
   AND metadata->>'amac' = 'SAHA_FIX_V1 dogrulama';
"
echo "  --- geride acik test oturumu kaldi mi? ---"
$PSQL -c "SELECT id, user_id, revoked_at, expires_at FROM user_sessions
          WHERE metadata->>'amac' = 'SAHA_FIX_V1 dogrulama';"

echo
echo "############ 2) DENETIM KAYDINI ONAR ############"
cp server_container.mjs server_container.mjs.bak_denetim
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "SAHA_DENETIM_V2" in s: sys.exit("ZATEN YAMALI")

ESKI = '''      // ⚠ SAHA_FIX_V1 — kapi kalkti, KAYIT kaldi. Baskasinin musterisi degistiyse iz birakir.
      try {
        const _o = result.rows[0];
        if (_o && _o.sorumlu_rep && String(_o.sorumlu_rep) !== String(session.userId)) {
          await query(
            `INSERT INTO saha_hata_log (tenant_id, user_id, tip, view_adi, endpoint, hata_mesaji, extra)
             VALUES ($1,$2,'DENETIM','musteri','PUT /api/saha/musteriler/'||$3,
                     'Baskasina atanmis musteri duzenlendi', $4::jsonb)`,
            [session.tenantId, session.userId, m[1],
             JSON.stringify({ sahip: _o.sorumlu_rep, alanlar: Object.keys(p || {}) })]);
        }
      } catch (_e) { /* denetim kaydi asla isi bloklamaz */ }'''
assert ESKI in s, "denetim blogu bulunamadi — dosya degismis, DUR"

YENI = '''      // ⚠ SAHA_DENETIM_V2 — ONCEKI HALI CALISMIYORDU VE SUSUYORDU.
      //   'PUT /api/saha/musteriler/'||$3  ifadesinde $3'un tipi belirsizdi
      //   ("could not determine data type of parameter $3") -> sorgu patliyordu ->
      //   ve catch bloğu hatayi SESSIZCE YUTUYORDU. Kapiyi kaldirdik ama IZ TUTMUYORDUK:
      //   baskasinin musterisini kimin degistirdigi HIC KAYDEDILMIYORDU.
      //   ⚠ Sessiz veri kaybini duzeltirken sessiz veri kaybi yazmisim. Iki duzeltme:
      //     (1) $3::text — tip artik acik.
      //     (2) catch ARTIK SUSMUYOR. Denetim kaydi isi bloklamaz ama SESSIZ de dusmez.
      try {
        const _o = result.rows[0];
        if (_o && _o.sorumlu_rep && String(_o.sorumlu_rep) !== String(session.userId)) {
          await query(
            `INSERT INTO saha_hata_log (tenant_id, user_id, tip, view_adi, endpoint, hata_mesaji, extra)
             VALUES ($1, $2, 'DENETIM', 'musteri',
                     'PUT /api/saha/musteriler/' || $3::text,
                     'Baskasina atanmis musteri duzenlendi',
                     $4::jsonb)`,
            [session.tenantId, session.userId, String(m[1]),
             JSON.stringify({ sahip: String(_o.sorumlu_rep), alanlar: Object.keys(p || {}) })]);
        }
      } catch (_e) {
        console.error("[saha] DENETIM kaydi dusurulemedi:", _e && _e.message, "musteri:", m[1]);
      }'''
s = s.replace(ESKI, YENI, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ $3::text cast + catch artik susmuyor")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_denetim server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 3) ⚠ DENETIM GERCEKTEN DUSUYOR MU? — kanit ############"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"
MID="ecb0a4ee-d8f8-43c7-a9f3-ccf905413baf"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
# ⚠ SID'i temiz al — gecen sefer "INSERT 0 1" karismisti
SID=$($PSQL -tAc "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
      VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"DENETIM dogrulama\"}'::jsonb)
      RETURNING id;" | tr -d '[:space:]' | head -c 36)
echo "  oturum: [$SID]"

ONCE=$($PSQL -tAc "SELECT count(*) FROM saha_hata_log WHERE tip='DENETIM'")
ESKI=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
K=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d "{\"durum\":\"$ESKI\"}" "http://localhost:8080/api/saha/musteriler/$MID")
SONRA=$($PSQL -tAc "SELECT count(*) FROM saha_hata_log WHERE tip='DENETIM'")
echo "  PUT (baskasinin musterisi, ayni deger) -> HTTP $K"
echo "  DENETIM kaydi: $ONCE -> $SONRA"
[ "$SONRA" -gt "$ONCE" ] && echo "  ✅ IZ DUSTU" || echo "  ❌ IZ HALA DUSMUYOR — konteyner logu:"
[ "$SONRA" -gt "$ONCE" ] || docker logs --since 30s krb-assessment 2>&1 | grep -i "DENETIM" | head -3
$PSQL -x -c "SELECT to_char(ts,'HH24:MI:SS') saat, tip, endpoint, hata_mesaji, extra
             FROM saha_hata_log WHERE tip='DENETIM' ORDER BY ts DESC LIMIT 1;"

echo
echo "############ 4) OTURUMU KAPAT — bu sefer DOGRULAYARAK ############"
$PSQL -c "UPDATE user_sessions SET revoked_at=now()
          WHERE revoked_at IS NULL AND metadata->>'amac' IN ('DENETIM dogrulama','SAHA_FIX_V1 dogrulama');"
R=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "http://localhost:8080/api/saha/ziyaretler")
echo "  iptal sonrasi -> HTTP $R   $([ "$R" = "401" ] && echo '✅ oturum gercekten kapandi' || echo '❌ HALA ACIK')"
echo "  --- acik kalan test oturumu: ---"
$PSQL -tAc "SELECT count(*) FROM user_sessions WHERE revoked_at IS NULL
            AND metadata->>'amac' LIKE '%dogrulama%';" | sed 's/^/      adet: /'

git add -A
git commit -q -m 'fix(saha): SAHA_DENETIM_V2 — kendi yazdigim sessiz yutmayi kapatiyorum. SAHA_FIX_V1 de PUT /api/saha/musteriler icindeki sahiplik kapisini kaldirmis, yerine denetim kaydi koymustum: baskasina atanmis musteri degistirilirse saha_hata_log a DENETIM satiri dussun diye. Canli test gosterdi ki O KAYIT HIC DUSMUYOR (0 satir). Sebep: INSERT icindeki "PUT /api/saha/musteriler/"||$3 ifadesinde $3un tipi belirsiz kaliyor (could not determine data type of parameter $3), sorgu patliyor, ve benim yazdigim catch (_e) {} blogu hatayi SESSIZCE YUTUYORDU. Yani sahiplik kapisini kaldirdik ama izi tutmuyorduk: baskasinin musterisini kimin degistirdigi hic kaydedilmiyordu. Ayni hastalik: sessiz veri kaybini duzeltirken sessiz veri kaybi yazmisim (saha.js:1004teki .catch(()=>{}) ile birebir ayni desen). Iki duzeltme: (1) $3::text ile tip acik hale getirildi, (2) catch artik SUSMUYOR — console.error basiyor; denetim kaydi isi bloklamaz ama sessizce de dusmez. Ayrica: dogrulama testinde actigim gecici oturum psql -tAc ciktisina INSERT 0 1 karistigi icin iptal edilememis ve acik kalmisti; kapatildi ve kapandigi 401 ile dogrulandi.'
echo "  COMMITTED"
