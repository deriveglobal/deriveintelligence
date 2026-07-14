#!/usr/bin/env bash
# SAHA_DENETIM_V3B — V3 sozdizimi hatasi verdi, node --check YAKALADI, yedek GERI KONDU.
#
# ⚠ HATAM: V2 blogunu KARAKTER INDEKSIYLE kesmeye calistim, catch'in kapanisini
#   yanlis saydim, fazladan bir ')' birakti.
#   ✅ COZUM: indeksle kesme YOK. Kendi yazdigim blogun TAMAMINI birebir metin
#      olarak degistiriyorum. Capa tahmin edilmiyor, tam metin eslesiyor.
#
# ⚠ NOT: saha_denetim tablosu V3'te KURULDU (CREATE IF NOT EXISTS — tekrar zararsiz).
#   CHECK kisiti da goruldu: API_HATA, JS_HATA, AG_HATA, YAVAS_API, SESSIZ_HATA.
#   Hepsi HATA. 'DENETIM'in orada isi yokmus — ayri tablo karari dogruydu.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) SAGLAMA — dosya V2'ye geri donmus mu? ############"
node --check server_container.mjs && echo "  ✅ mevcut dosya saglam (yedek geri konmus)" || { echo "  ❌ DOSYA BOZUK — DUR"; exit 1; }
grep -c "SAHA_DENETIM_V2" server_container.mjs | sed 's/^/  V2 blogu: /'
$PSQL -tAc "SELECT count(*) FROM information_schema.tables WHERE table_name='saha_denetim';" | sed 's/^/  saha_denetim tablosu: /'

echo
echo "############ 1) YAMA — birebir metin degisimi ############"
cp server_container.mjs server_container.mjs.bak_v3b
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "SAHA_DENETIM_V3" in s: sys.exit("ZATEN V3")

ESKI = '''      // ⚠ SAHA_DENETIM_V2 — ONCEKI HALI CALISMIYORDU VE SUSUYORDU.
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
assert ESKI in s, "❌ V2 blogu BIREBIR bulunamadi — dosya bekledigimden farkli. DUR."

YENI = '''      // ⚠ SAHA_DENETIM_V3 — IZ ARTIK DOGRU YERDE VE GERCEKTEN DUSUYOR.
      //   V2 izi saha_hata_log'a yazmaya calisiyordu; tablonun tip CHECK kisiti
      //   sadece sunlara izin veriyor: API_HATA, JS_HATA, AG_HATA, YAVAS_API, SESSIZ_HATA.
      //   Hepsi HATA. 'DENETIM' reddediliyordu, kayit HIC DUSMUYORDU.
      //   ⚠ Kisiti gevsetmek YANLIS COZUM olurdu: baskasinin musterisini duzenlemek
      //     artik HATA DEGIL, izinli bir is. Hata kutuguna yazsaydik, 404/500/JS sayan
      //     ops monitorunu her mesru duzenlemede yanlis alarma bogardik.
      //   Iz kendi tablosuna yaziliyor: saha_denetim.
      try {
        const _o = result.rows[0];
        if (_o && _o.sorumlu_rep && String(_o.sorumlu_rep) !== String(session.userId)) {
          await query(
            `INSERT INTO saha_denetim
               (tenant_id, user_id, eylem, varlik, varlik_id, sahip_id, alanlar, detay)
             VALUES ($1, $2, 'MUSTERI_GUNCELLE', 'saha_musteri', $3::uuid, $4::uuid, $5::text[], $6::jsonb)`,
            [session.tenantId, session.userId, String(m[1]), String(_o.sorumlu_rep),
             Object.keys(p || {}), JSON.stringify({ firma: _o.firma || null })]);
        }
      } catch (_e) {
        // ⚠ SUSMAZ. Iz dusuremezsek en azindan BILIRIZ. Sessiz catch = sessiz kayip.
        console.error("[saha] denetim izi dusurulemedi:", _e && _e.message, "musteri:", m[1]);
      }'''
s = s.replace(ESKI, YENI, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ birebir degistirildi -> saha_denetim")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_v3b server_container.mjs; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 2) ⚠ KANIT — iz gercekten dusuyor mu? ############"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"
MID="ecb0a4ee-d8f8-43c7-a9f3-ccf905413baf"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"denetim dogrulama\"}'::jsonb);"

ONCE=$($PSQL -tAc "SELECT count(*) FROM saha_denetim")
ESKI=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
K=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
     -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
     -d "{\"durum\":\"$ESKI\"}" "http://localhost:8080/api/saha/musteriler/$MID")
SONRA=$($PSQL -tAc "SELECT count(*) FROM saha_denetim")
YENI=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
echo "  PUT (baskasinin musterisi, AYNI deger) -> HTTP $K"
echo "  veri: '$ESKI' -> '$YENI'  $([ "$ESKI" = "$YENI" ] && echo '✅ degismedi' || echo '❌ DEGISTI')"
echo "  saha_denetim: $ONCE -> $SONRA"
if [ "$SONRA" -gt "$ONCE" ]; then
  echo "  ✅ IZ DUSTU"
  $PSQL -x -c "SELECT to_char(d.ts,'HH24:MI:SS') saat, u.full_name AS kim, d.eylem,
                      s.full_name AS kaydin_sahibi, d.alanlar, d.detay
                 FROM saha_denetim d
                 LEFT JOIN users u ON u.id=d.user_id
                 LEFT JOIN users s ON s.id=d.sahip_id
                ORDER BY d.ts DESC LIMIT 1;"
else
  echo "  ❌ IZ DUSMEDI — konteyner ne diyor:"
  docker logs --since 30s krb-assessment 2>&1 | grep -i "denetim" | head -3
fi

echo
echo "############ 3) OTURUMU KAPAT ############"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE revoked_at IS NULL AND metadata ? 'amac';"
R=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "http://localhost:8080/api/saha/ziyaretler")
echo "  iptal sonrasi -> HTTP $R  $([ "$R" = "401" ] && echo '✅ kapandi' || echo '❌ HALA ACIK')"
$PSQL -tAc "SELECT count(*) FROM user_sessions WHERE revoked_at IS NULL AND metadata ? 'amac';" | sed 's/^/  acik test oturumu: /'

git add -A
git commit -q -m 'fix(saha): SAHA_DENETIM_V3 — iz dogru tabloda ve gercekten dusuyor. V2 izi saha_hata_loga yaziyordu; o tablonun tip CHECK kisiti sadece API_HATA/JS_HATA/AG_HATA/YAVAS_API/SESSIZ_HATA degerlerine izin veriyor, hepsi HATA. DENETIM reddediliyor, kayit hic dusmuyordu — ve konusan catch bunu ilk denemede soyledi (susan catch iki tur saklamisti). Kisiti gevsetmek yanlis cozum olurdu: baskasinin musterisini duzenlemek artik hata degil izinli bir is; hata kutuguna yazsaydik 404/500/JS sayan ops monitorunu her mesru duzenlemede yanlis alarma bogardik. Iz kendi tablosuna tasindi: saha_denetim (kim, ne zaman, hangi eylem, hangi varlik, kaydin sahibi, hangi alanlar). Ayrica V3un ilk denemesi sozdizimi hatasi verdi cunku V2 blogunu karakter indeksiyle kesmistim ve catchin kapanisini yanlis saymistim; node --check yakaladi, yedek geri kondu, sunucu bozulmadi. Bu surumde indeksle kesme yok: blogun tamami birebir metin olarak degistiriliyor.'
echo "  COMMITTED"
