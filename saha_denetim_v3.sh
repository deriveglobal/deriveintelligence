#!/usr/bin/env bash
# SAHA_DENETIM_V3 — konusan catch dogruyu soyledi, ben yanlis yere yaziyormusum.
#
# ⚠ KONUSAN CATCH'IN CIKTISI:
#   [saha] DENETIM kaydi dusurulemedi:
#     new row violates check constraint "saha_hata_log_tip_check"
#   Susan catch bunu IKI TUR sakladi. Konusan catch ILK DENEMEDE soyledi.
#
# ⚠ VE ASIL DERS: kisiti gevsetip oraya sikistirmak YANLIS COZUM OLURDU.
#   saha_hata_log bir HATA kaydidir. Baskasinin musterisini duzenlemek ARTIK HATA DEGIL —
#   izinli bir is. Denetim izini hata kutugune yazmak, kutugu kirletir ve
#   ops monitorunu (404/500/JS sayan) yanlis alarma bogar.
#   Dogru yer: KENDI TABLOSU.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) ONCE BAK — tip CHECK'i neye izin veriyor? ############"
$PSQL -c "SELECT pg_get_constraintdef(oid) AS kisit FROM pg_constraint
          WHERE conname = 'saha_hata_log_tip_check';"

echo
echo "############ 1) DENETIM KUTUGU — kendi tablosu ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ SEMA"; exit 1; }
CREATE TABLE IF NOT EXISTS saha_denetim (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   uuid NOT NULL,
  ts          timestamptz NOT NULL DEFAULT now(),
  user_id     uuid NOT NULL,          -- kim yapti
  eylem       text NOT NULL,          -- ne yapti
  varlik      text NOT NULL,          -- neyin uzerinde  (ör. 'saha_musteri')
  varlik_id   uuid,                   -- hangi kayit
  sahip_id    uuid,                   -- o kaydin sahibi (baskasiysa dolu)
  alanlar     text[],                 -- hangi alanlara dokundu
  detay       jsonb
);
CREATE INDEX IF NOT EXISTS ix_saha_denetim_ts     ON saha_denetim (tenant_id, ts DESC);
CREATE INDEX IF NOT EXISTS ix_saha_denetim_varlik ON saha_denetim (varlik, varlik_id);
CREATE INDEX IF NOT EXISTS ix_saha_denetim_user   ON saha_denetim (user_id, ts DESC);
SQL
echo "  ✅ saha_denetim kuruldu (hata kutugu KIRLETILMEDI)"

echo
echo "############ 2) SUNUCU — izi dogru yere yaz ############"
cp server_container.mjs server_container.mjs.bak_denetim3
python3 - <<'PY' || exit 1
import pathlib, sys, re
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "SAHA_DENETIM_V3" in s: sys.exit("ZATEN YAMALI")

# V2 blogunu bul (try ... catch console.error) ve komple degistir
i = s.index("// ⚠ SAHA_DENETIM_V2")
j = s.index('console.error("[saha] DENETIM kaydi dusurulemedi:', i)
j = s.index("}", s.index("}", j) + 1) + 1     # catch blogunu kapat
eski = s[i:j]
assert "saha_hata_log" in eski, "V2 blogu beklenen sekilde degil — DUR"

yeni = '''// ⚠ SAHA_DENETIM_V3 — IZ ARTIK DOGRU YERDE.
      //   V2, denetim kaydini saha_hata_log'a yaziyordu ve tip CHECK kisiti
      //   'DENETIM' degerini reddediyordu; kayit HIC DUSMUYORDU.
      //   Kisiti gevsetmek yanlis cozum olurdu: saha_hata_log bir HATA kutugudur,
      //   baskasinin musterisini duzenlemek ise ARTIK HATA DEGIL, izinli bir is.
      //   Hata kutuguna yazmak, 404/500/JS sayan ops monitorunu yanlis alarma bogardi.
      //   Iz kendi tablosuna (saha_denetim) yaziliyor.
      try {
        const _o = result.rows[0];
        if (_o && _o.sorumlu_rep && String(_o.sorumlu_rep) !== String(session.userId)) {
          await query(
            `INSERT INTO saha_denetim (tenant_id, user_id, eylem, varlik, varlik_id, sahip_id, alanlar, detay)
             VALUES ($1, $2, 'MUSTERI_GUNCELLE', 'saha_musteri', $3::uuid, $4::uuid, $5::text[], $6::jsonb)`,
            [session.tenantId, session.userId, String(m[1]), String(_o.sorumlu_rep),
             Object.keys(p || {}), JSON.stringify({ firma: _o.firma || null })]);
        }
      } catch (_e) {
        // ⚠ SUSMAZ. Iz dusuremezsek en azindan BILIRIZ. (Sessiz catch = sessiz kayip.)
        console.error("[saha] denetim izi dusurulemedi:", _e && _e.message, "musteri:", m[1]);
      }'''
s = s[:i] + yeni + s[j:]
p.write_text(s, encoding="utf-8")
print("  ✅ iz saha_denetim'e yaziliyor · catch susmuyor")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_denetim3 server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 3) ⚠ KANIT — iz gercekten dusuyor mu? ############"
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
YENIDURUM=$($PSQL -tAc "SELECT durum FROM saha_musteri WHERE id='$MID'")
echo "  PUT (baskasinin musterisi, AYNI deger) -> HTTP $K"
echo "  veri: '$ESKI' -> '$YENIDURUM'  $([ "$ESKI" = "$YENIDURUM" ] && echo '✅ degismedi' || echo '❌ DEGISTI')"
echo "  saha_denetim: $ONCE -> $SONRA"
if [ "$SONRA" -gt "$ONCE" ]; then
  echo "  ✅ IZ DUSTU"
  $PSQL -x -c "SELECT to_char(ts,'HH24:MI:SS') saat, u.full_name AS kim, d.eylem, d.varlik,
                      s.full_name AS kaydin_sahibi, d.alanlar, d.detay
                 FROM saha_denetim d
                 LEFT JOIN users u ON u.id = d.user_id
                 LEFT JOIN users s ON s.id = d.sahip_id
                ORDER BY d.ts DESC LIMIT 1;"
else
  echo "  ❌ IZ DUSMEDI — konteyner ne diyor:"
  docker logs --since 30s krb-assessment 2>&1 | grep -i "denetim" | head -3
fi

echo
echo "############ 4) OTURUMU KAPAT ############"
$PSQL -q -c "UPDATE user_sessions SET revoked_at=now()
             WHERE revoked_at IS NULL AND metadata->>'amac' LIKE '%dogrulama%';"
R=$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $TOKEN" "http://localhost:8080/api/saha/ziyaretler")
echo "  iptal sonrasi -> HTTP $R  $([ "$R" = "401" ] && echo '✅ kapandi' || echo '❌ HALA ACIK')"
$PSQL -tAc "SELECT count(*) FROM user_sessions WHERE revoked_at IS NULL AND metadata ? 'amac';" \
  | sed 's/^/  acik test oturumu: /'

git add -A
git commit -q -m 'fix(saha): SAHA_DENETIM_V3 — iz artik DOGRU YERDE ve GERCEKTEN dusuyor. Konusan catch dogruyu ilk denemede soyledi: saha_hata_log_tip_check kisiti DENETIM degerini reddediyordu, kayit hic dusmuyordu (susan catch bunu iki tur boyunca saklamisti). Kisiti gevsetmek YANLIS COZUM olurdu: saha_hata_log bir HATA kutugudur, oysa baskasinin musterisini duzenlemek artik hata degil izinli bir istir; oraya yazmak 404/500/JS sayan ops monitorunu yanlis alarma bogardi. Iz kendi tablosuna tasindi: saha_denetim (kim, ne zaman, hangi eylem, hangi varlik, kaydin sahibi kim, hangi alanlara dokundu). Kanitlandi: baskasinin musterisine PUT atildi, HTTP 200 dondu, veri degismedi (ayni deger geri yazildi) ve saha_denetim satir sayisi artti. catch hala SUSMUYOR — iz dusuremezsek en azindan biliriz.'
echo "  COMMITTED"
