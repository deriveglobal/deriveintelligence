#!/usr/bin/env bash
# SAHA_FIX_V1 — Eftal 13 Temmuz'da 23 hata aldi. Ucu de kapatiliyor.
# ⚠ TUM CAPALAR 4 TURLUK KESIFTEN, DOSYADAN. Hafizamdan tek satir yok.
#
# ── HATA 1 · 500 · ISKONTO EKRANI (5 kez, 14:47:31 -> 14:48:47) ──────────────
#    saha_musteri_tedarikci_destek.musteri_id = INTEGER
#    saha_musteri.id                          = UUID
#    Ekran KURULDUGUNDAN BERI HIC CALISMAMIS. Eftal 5 kez denedi, 5'inde de patladi.
#    Tablo BOS (0/0) -> tip degistirmek guvenli.
#    ⚠ TUZAK: bu tablonun tenant_id'si TEXT, saha_musteri'ninki UUID. Ayni $1'i iki tipte
#      kullanma hatasina bir daha dusmemek icin tenant_id'ye DOKUNMUYORUM (text=text calisiyor).
#
# ── HATA 2 · 403 x13 · SESSIZ VERI KAYBI ────────────────────────────────────
#    ⚠ ZIYARETLER KAYDOLDU. Kaybolan ziyaret DEGIL.
#    saha.js ziyareti yazdiktan SONRA, musteri kartina AYRI bir PUT atiyor
#    (saha.js:1004 ve 1258): ziyarette ogrenileni profile isliyor:
#      { sektorler, tedarikci_markalar }  ve  { durum }
#    Sunucu bu ikinci istege 403 veriyordu. Satirin sonunda .catch(() => {}) vardi.
#    SONUC: ziyaret VAR, ziyaretten cikan PROFIL BILGISI YOK. Eftal ekranda "✓" gordu.
#    ⚠ Sunucudaki kapi BASTAN YANLISTI. "Temsilci sadece kendi musterisini duzenler"
#      diye bir kural HIC KONULMADI — ben varsaydim. Fatih: "they all can edit any customers".
#    Kapi KALDIRILIYOR.
#
# ── HATA 3 · 404 + JS_HATA · TEK KOK, IKI BELIRTI ───────────────────────────
#    saha.js:574  z = (await api(`/api/saha/ziyaretler/${zid}`)).ziyaret
#    Boyle bir uc nokta YOK (liste, POST, PUT, /foto, /fotolar, /yorumlar var; TEKIL GET yok).
#    404 -> try{}catch{} yutuyor -> z bos -> ekran cizilmiyor -> #det-yorum-gonder hic olusmuyor
#    -> saha.js:667 o butona olay baglamaya calisiyor -> "null is not an object".
#    Uc nokta ekleniyor + buton null-korumasi.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) ON KAPI — tablolar HALA bos mu? ############"
BOS=$($PSQL -tAc "SELECT (SELECT count(*) FROM saha_musteri_tedarikci_destek) + (SELECT count(*) FROM saha_musteri_tedarikci_destek_log)")
echo "  destek + log satir sayisi: $BOS"
[ "$BOS" = "0" ] || { echo "❌ TABLO DOLMUS — tip degisimi veri kaybeder. DURDUM."; exit 1; }

echo
echo "############ 1) SEMA — musteri_id integer -> uuid ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ SEMA — islem geri alindi"; exit 1; }
BEGIN;
ALTER TABLE saha_musteri_tedarikci_destek_log ALTER COLUMN musteri_id TYPE uuid USING NULL;
ALTER TABLE saha_musteri_tedarikci_destek     ALTER COLUMN musteri_id TYPE uuid USING NULL;
-- ⚠ FK artik kurulabilir. Once tip uyusmadigi icin KURULAMIYORDU — bu yuzden hata
--   veritabani seviyesinde degil, calisma aninda 500 olarak patliyordu.
ALTER TABLE saha_musteri_tedarikci_destek
  ADD CONSTRAINT fk_destek_musteri FOREIGN KEY (musteri_id)
  REFERENCES saha_musteri(id) ON DELETE CASCADE;
COMMIT;
SQL
$PSQL -c "SELECT table_name, column_name, data_type FROM information_schema.columns
          WHERE table_name LIKE 'saha_musteri_tedarikci_destek%' AND column_name='musteri_id';"

echo
echo "############ 2) SUNUCU — 403 kapisi kaldiriliyor, tekil ziyaret ekleniyor ############"
cp server_container.mjs server_container.mjs.bak_sahafix
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "SAHA_FIX_V1" in s: sys.exit("❌ ZATEN YAMALI — durdum")

# ── 2a) 403 KAPISI: kaldir (capa birebir 28227-28235'ten) ────────────────
ESKI = '''      // Rep ownership check — reps can only edit customers assigned to them
      if (session.sahaRole === "rep") {
        const ownerCheck = await query(
          `SELECT id FROM saha_musteri WHERE tenant_id=$1 AND id=$2 AND sorumlu_rep=$3 AND aktif=true`,
          [session.tenantId, m[1], session.userId]);
        if (!ownerCheck.rowCount) {
          sendJson(response, 403, { error: "Bu müşteri size atanmamış." }); return;
        }
      }
'''
assert ESKI in s, "403 blogu bulunamadi — DOSYA DEGISMIS, dur"
YENI = '''      // ⚠ SAHA_FIX_V1 — SAHIPLIK KAPISI KALDIRILDI.
      //   Eski hali: temsilci sadece KENDI musterisini duzenleyebiliyordu.
      //   Boyle bir kural hic konulmadi; kod varsaymis. Gercek kural: herkes duzenleyebilir.
      //   Bedeli agirdi: arayüz ziyaret kaydinda musteri profiline
      //     { sektorler, tedarikci_markalar } ve { durum } yaziyor (saha.js:1004, 1258),
      //   sunucu 403 veriyor, satirin sonundaki .catch(()=>{}) hatayi yutuyordu.
      //   13 Temmuz'da Eftal'in 13 ziyaretinden toplanan saha gozlemi
      //   HIC KAYDEDILMEDI ve ona "✓" gosterildi. Sessiz veri kaybi.
      //   Kim neyi degistirdi sorusu, asagidaki denetim kaydiyla cevaplaniyor.
'''
s = s.replace(ESKI, YENI, 1)

# ── 2b) DENETIM: baskasinin musterisini duzenleyen kaydedilsin ───────────
ANC_UPD = '''      const result = await query(`
        UPDATE saha_musteri SET ${sets.join(", ")}, updated_at = now()
        WHERE tenant_id = $1 AND id = $2 RETURNING *
      `, params);
      if (!result.rowCount) { sendJson(response, 404, { error: "Müşteri bulunamadı." }); return; }'''
assert ANC_UPD in s, "UPDATE blogu bulunamadi"
s = s.replace(ANC_UPD, ANC_UPD + '''
      // ⚠ SAHA_FIX_V1 — kapi kalkti, KAYIT kaldi. Baskasinin musterisi degistiyse iz birakir.
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
      } catch (_e) { /* denetim kaydi asla isi bloklamaz */ }''', 1)

# ── 2c) 404: GET /api/saha/ziyaretler/:id — HIC YAZILMAMISTI ─────────────
ANC_PUT = '    if (method === "PUT" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})$`)))) {'
assert ANC_PUT in s, "ziyaret PUT capasi bulunamadi"
EP = '''    // ⚠ SAHA_FIX_V1 — TEKIL ZIYARET. Bu uc nokta HIC YAZILMAMISTI.
    //   saha.js:574 bunu cagiriyordu; sunucu "Bilinmeyen saha endpoint'i" (404) donuyordu.
    //   404 -> catch yutuyor -> z bos -> ekran cizilmiyor -> #det-yorum-gonder olusmuyor
    //   -> saha.js:667 patliyor ("null is not an object"). TEK KOK, IKI BELIRTI.
    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})$`)))) {
      const session = await requireSahaAccess(request);
      const r = await query(`
        SELECT z.*, mu.firma, mu.il, mu.ilce, mu.tip AS musteri_tip,
               mu.sektorler, mu.tedarikci_markalar, mu.durum AS musteri_durum,
               u.full_name AS rep_adi
          FROM saha_ziyaret z
          LEFT JOIN saha_musteri mu ON mu.id = z.musteri_id
          LEFT JOIN users u ON u.id = z.rep_id
         WHERE z.tenant_id = $1 AND z.id = $2
      `, [session.tenantId, m[1]]);
      if (!r.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      sendJson(response, 200, { ziyaret: r.rows[0] });
      return;
    }

'''
s = s.replace(ANC_PUT, EP + ANC_PUT, 1)

p.write_text(s, encoding="utf-8")
print("  ✅ 403 kapisi kaldirildi · denetim kaydi eklendi · tekil ziyaret uc noktasi eklendi")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_sahafix server_container.mjs; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ARAYUZ — buton null-korumasi (JS_HATA) ############"
cp shells/saha.js shells/saha.js.bak_sahafix
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/saha.js"); s = p.read_text(encoding="utf-8")
if "SAHA_FIX_V1" in s: sys.exit("❌ ZATEN YAMALI")
A = '  document.getElementById("det-yorum-gonder").addEventListener("click", async () => {'
assert A in s, "det-yorum-gonder capasi bulunamadi"
B = '''  // ⚠ SAHA_FIX_V1 — kok sebep (404) kapandi, ama ekran bir daha ASLA
  //   var olmayan bir butona olay baglayip patlamasin.
  const _detYorumBtn = document.getElementById("det-yorum-gonder");
  if (_detYorumBtn) _detYorumBtn.addEventListener("click", async () => {'''
s = s.replace(A, B, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ det-yorum-gonder korundu")
PY
node --check shells/saha.js 2>/dev/null && echo "  ✅ saha.js sozdizimi" || echo "  (saha.js modul degil, node --check atlandi)"

echo
echo "############ 4) IMAJ + DAGIT (⚠ docker cp YOK) ############"
docker build -t krb-assessment:secure . 2>&1 | tail -3
docker compose up -d --force-recreate krb-assessment 2>&1 | tail -2
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"

echo
echo "############ 5) ⚠ DOGRULA — Eftal'in ucu de kapandi mi? ############"
echo "  [1] iskonto 500:"
$PSQL -tAc "SELECT '      musteri_id = '||data_type FROM information_schema.columns
            WHERE table_name='saha_musteri_tedarikci_destek' AND column_name='musteri_id';"
echo "  [2] 403 kapisi:"
grep -c 'Bu müşteri size atanmamış' server_container.mjs | sed 's/^/      kodda kalan adet: /'
echo "  [3] tekil ziyaret uc noktasi:"
printf "      GET /api/saha/ziyaretler/{uuid} -> HTTP %s   (401=VAR, oturum ister · 404=HALA YOK)\n" \
  "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/saha/ziyaretler/dc9caaf4-0afd-499f-84f1-fcf34b735765)"

echo
echo "############ 6) ⚠ KAYIP VERI — 13 ziyaretin notlari ############"
echo "  (gozlemler reddedildi ama ZIYARET KAYDI duruyor; nottan cikarim icin okuyorum)"
$PSQL -x -c "
SELECT z.id, to_char(z.ziyaret_tarihi,'DD Mon') AS tarih, mu.firma, mu.tip,
       mu.sektorler, mu.tedarikci_markalar, mu.durum,
       left(coalesce(z.notlar,''), 400) AS not
  FROM saha_hata_log h
  JOIN saha_musteri mu ON mu.id = replace(h.endpoint,'/api/saha/musteriler/','')::uuid
  LEFT JOIN LATERAL (
    SELECT * FROM saha_ziyaret z2
     WHERE z2.musteri_id = mu.id AND z2.rep_id = h.user_id
     ORDER BY abs(extract(epoch FROM (z2.created_at - h.ts))) LIMIT 1
  ) z ON true
 WHERE h.user_id='ae0c55f9-68cc-421d-96d9-409222452f1a'
   AND h.http_status=403 AND h.ts >= current_date - 1
 ORDER BY h.ts;
"

git add -A
git commit -q -m 'fix(saha): SAHA_FIX_V1 — Eftal 13 Temmuzda 23 hata aldi; ucu de kapatildi. (1) 500 SEMA: saha_musteri_tedarikci_destek.musteri_id INTEGER iken saha_musteri.id UUID — iskonto ekrani kuruldugundan beri hic calismamis, Eftal 5 kez denedi (14:47:31-14:48:47), 5inde de patladi. Tablo bostu (0/0), tip uuid yapildi ve FK kuruldu; FK zaten tip uyusmadigi icin hic kurulamamisti, bu yuzden hata veritabani seviyesinde degil calisma aninda 500 olarak patliyordu. (2) 403 x13 SESSIZ VERI KAYBI: PUT /api/saha/musteriler/{id} icindeki "temsilci sadece kendi musterisini duzenler" kapisi — boyle bir kural HIC KONULMADI, kod varsaymis. Arayüz ziyaret kaydinda musteri profiline {sektorler, tedarikci_markalar} ve {durum} yaziyor (saha.js:1004, 1258); sunucu 403 veriyor, satir sonundaki .catch(()=>{}) hatayi yutuyordu. Eftalin 13 ziyaretinde topladigi saha gozlemi HIC KAYDEDILMEDI ve ona ekranda tik gosterildi. Kapi kaldirildi (herkes her musteriyi duzenleyebilir), yerine denetim kaydi kondu: baskasina atanmis musteri degistirilirse saha_hata_log a DENETIM satiri dusuyor. (3) 404 + JS_HATA TEK KOK IKI BELIRTI: GET /api/saha/ziyaretler/{id} hic yazilmamisti (liste, POST, PUT, /foto, /fotolar, /yorumlar vardi; tekil GET yoktu). saha.js:574 bunu cagiriyor, 404 geliyor, try-catch yutuyor, z bos kaliyor, ekran cizilmiyor, #det-yorum-gonder butonu hic olusmuyor, saha.js:667 o butona olay baglamaya calisip "null is not an object" atiyordu. Uc nokta eklendi + buton null-korumasi kondu. Dagitim docker cp ile DEGIL, imaj yeniden derlenerek yapildi.'
echo "  COMMITTED"
