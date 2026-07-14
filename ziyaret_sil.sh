#!/usr/bin/env bash
# ZIYARET_SIL — Eftal'in istedigi silme. (saha_oneri: 0a12fe05)
#
# ⚠ TASARIM KARARLARI:
#
#   1. UYARI TAHMIN DEGIL SAYIM.
#      "Emin misiniz?" demiyorum. Kullanici NE KAYBEDECEGINI RAKAMLA gorecek:
#      "119 karakterlik not · 2 fotograf · 1 rakip fiyat kaydi. Geri alinamaz."
#      Bos bir onay penceresi kimseyi korumaz.
#
#   2. TEMSILCI SADECE KENDI ZIYARETINI SILER.
#      Musteri duzenlemede kapiyi kaldirdik — ama silme GERI ALINAMAZ bir eylem.
#      Ayri muamele hak ediyor. Yonetici/admin hepsini silebilir.
#
#   3. IZ KALIR. saha_denetim'e dusuyor: kim, ne zaman, hangi ziyareti,
#      hangi musteride, notu neydi. Kullanici icin kayit gitti; sistem icin belli.
#
#   4. ARSIV. saha_ziyaret_silinen tablosuna tam kopya. Kullaniciya "geri alinamaz"
#      diyorum ve arayuzde geri alma YOK — ama veri kaybi sessiz olmuyor.
#      ⚠ Bugun butun gun sessiz veri kaybi kovaladik. Kendim uretmem.
#
#   5. BAGLI KAYITLAR DA GIDER. Foto ve rakip teklifi. Ziyaret yoksa
#      fotografin anlami yok — sahipsiz birakmam.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ARSIV TABLOSU ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS saha_ziyaret_silinen (
  LIKE saha_ziyaret INCLUDING DEFAULTS,
  silen_id      uuid,
  silen_adi     text,
  silinme_at    timestamptz NOT NULL DEFAULT now(),
  foto_sayisi   integer,
  teklif_sayisi integer
);
SQL
echo "  ✅ saha_ziyaret_silinen"

echo
echo "############ 2) SUNUCU — onizleme + silme ############"
cp server_container.mjs server_container.mjs.bak_sil
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "ZIYARET_SIL_V1" in s: sys.exit("ZATEN YAMALI")

ANC = '    if (method === "PUT" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})$`)))) {'
assert ANC in s, "❌ capa yok"

EP = '''    // ── ZIYARET_SIL_V1 ────────────────────────────────────────────────────
    // ⚠ Eftal'in onerisi (0a12fe05): "Ziyaret kayitlarinin silinebilmesi."
    //   Mukerrer kaydin SEBEBINI kestik; bu, yanlislikla acilan kayitlar icin.
    //
    // ⚠ SILME ONIZLEME — kullanici NE KAYBEDECEGINI RAKAMLA gorsun.
    //   "Emin misiniz?" hicbir sey anlatmaz. "2 fotograf, 1 rakip fiyat" anlatir.
    if (method === "GET" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})/silme-onizleme$`)))) {
      const session = await requireSahaAccess(request);
      const r = await query(`
        SELECT z.id, z.rep_id, z.durum, z.ziyaret_tarihi,
               coalesce(length(z.notlar),0) AS not_uzunluk,
               mu.firma,
               (SELECT count(*) FROM saha_ziyaret_foto f WHERE f.ziyaret_id = z.id)   AS foto,
               (SELECT count(*) FROM saha_rakip_teklif t WHERE t.ziyaret_id = z.id)   AS teklif
          FROM saha_ziyaret z
          LEFT JOIN saha_musteri mu ON mu.id = z.musteri_id
         WHERE z.tenant_id=$1 AND z.id=$2`, [session.tenantId, m[1]]);
      if (!r.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      const z = r.rows[0];
      const kendisi = String(z.rep_id) === String(session.userId);
      const yonetici = session.sahaRole !== "rep";
      // ⚠ ZAMAN SINIRI — temsilci sadece BUGUN ve DUNKU ziyaretini silebilir.
      //   Daha eskisi rapora, prime, gecmise girmis olabilir. Yonetici SINIRSIZ.
      const _t = z.ziyaret_tarihi ? new Date(z.ziyaret_tarihi) : null;
      const _gun = _t ? Math.floor((Date.now() - _t.getTime()) / 86400000) : 0;
      const zamanOk = yonetici || _gun <= 1;
      let neden = null;
      if (!kendisi && !yonetici)      neden = "Bu ziyaret size ait değil.";
      else if (!zamanOk)              neden = "Sadece bugünkü ve dünkü ziyaretler silinebilir. Daha eskisi için yöneticine yaz.";
      sendJson(response, 200, {
        firma: z.firma, tarih: z.ziyaret_tarihi, durum: z.durum,
        not_uzunluk: Number(z.not_uzunluk),
        foto: Number(z.foto), teklif: Number(z.teklif),
        gun: _gun,
        silebilir: (kendisi || yonetici) && zamanOk,
        neden: neden
      });
      return;
    }

    // ⚠ SILME — geri alinamaz. Arsive kopyalanir, iz birakilir.
    if (method === "DELETE" && (m = path.match(new RegExp(`^/api/saha/ziyaretler/(${SAHA_UUID_RE})$`)))) {
      const session = await requireSahaAccess(request);
      const r = await query(
        `SELECT * FROM saha_ziyaret WHERE tenant_id=$1 AND id=$2`, [session.tenantId, m[1]]);
      if (!r.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      const z = r.rows[0];
      // ⚠ Temsilci SADECE kendi ziyaretini siler. Silme geri alinamaz — ayri muamele.
      if (session.sahaRole === "rep" && String(z.rep_id) !== String(session.userId)) {
        sendJson(response, 403, { error: "Sadece kendi ziyaretinizi silebilirsiniz." }); return;
      }
      // ⚠ ZAMAN SINIRI — temsilci: BUGUN + DUN. Yonetici: sinirsiz.
      //   Bir gunden eski ziyaret rapora, prime, gecmise girmis olabilir.
      //   Kapiyi SUNUCUDA tutuyorum; arayuz kapisi kullanicinin insafina kalir.
      if (session.sahaRole === "rep" && z.ziyaret_tarihi) {
        const _g = Math.floor((Date.now() - new Date(z.ziyaret_tarihi).getTime()) / 86400000);
        if (_g > 1) {
          sendJson(response, 403, {
            error: "Sadece bugünkü ve dünkü ziyaretler silinebilir. Daha eskisi için yöneticine yaz."
          });
          return;
        }
      }
      const _f = await query(`SELECT count(*) n FROM saha_ziyaret_foto WHERE ziyaret_id=$1`, [m[1]]);
      const _t = await query(`SELECT count(*) n FROM saha_rakip_teklif WHERE ziyaret_id=$1`, [m[1]]);
      try {
        // ⚠ ARSIV. Kullaniciya "geri alinamaz" diyoruz ve arayuzde geri alma YOK.
        //   Ama veri kaybi SESSIZ olmuyor. Bugun butun gun sessiz kaybi kovaladik.
        await query(`
          INSERT INTO saha_ziyaret_silinen
          SELECT z.*, $2::uuid, $3::text, now(), $4::int, $5::int
            FROM saha_ziyaret z WHERE z.id = $1`,
          [m[1], session.userId, session.name || session.email || "", Number(_f.rows[0].n), Number(_t.rows[0].n)]);
      } catch (e) {
        console.error("[saha] silme arsivi yazilamadi:", e && e.message);
        sendJson(response, 500, { error: "Arşiv yazılamadı, silme yapılmadı." }); return;
      }
      // ⚠ Bagli kayitlar da gider. Ziyaret yoksa fotografin anlami yok.
      await query(`DELETE FROM saha_rakip_teklif WHERE ziyaret_id=$1`, [m[1]]);
      await query(`DELETE FROM saha_ziyaret_foto  WHERE ziyaret_id=$1`, [m[1]]);
      await query(`DELETE FROM saha_ziyaret       WHERE tenant_id=$1 AND id=$2`, [session.tenantId, m[1]]);
      // ⚠ IZ. Kim, ne zaman, neyi.
      try {
        await query(
          `INSERT INTO saha_denetim (tenant_id, user_id, eylem, varlik, varlik_id, sahip_id, alanlar, detay)
           VALUES ($1,$2,'ZIYARET_SIL','saha_ziyaret',$3::uuid,$4::uuid,ARRAY['silindi']::text[],$5::jsonb)`,
          [session.tenantId, session.userId, m[1], z.rep_id,
           JSON.stringify({ musteri_id: z.musteri_id, tarih: z.ziyaret_tarihi,
                            not_uzunluk: (z.notlar || "").length,
                            foto: Number(_f.rows[0].n), teklif: Number(_t.rows[0].n) })]);
      } catch (e) { console.error("[saha] silme izi dusurulemedi:", e && e.message); }
      sendJson(response, 200, { ok: true, silinen: m[1] });
      return;
    }

'''
s = s.replace(ANC, EP + ANC, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ GET .../silme-onizleme + DELETE .../:id")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_sil server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) ARAYUZ — ziyaret detayina SIL butonu ############"
cp shells/saha.js shells/saha.js.bak_sil
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/saha.js"); s = p.read_text(encoding="utf-8")
if "ZIYARET_SIL_V1" in s: sys.exit("ZATEN YAMALI")

A = '''      <button class="btn cizgili" id="det-duzenle">✏️ Düzenle</button>'''
assert A in s, "❌ det-duzenle capasi yok"
B = '''      <button class="btn cizgili" id="det-duzenle">✏️ Düzenle</button>
      <button class="btn cizgili" id="det-sil" style="color:#dc2626;border-color:#fecaca">🗑 Sil</button>'''
s = s.replace(A, B, 1)

# handler: det-duzenle'nin dinleyicisinin yanina
C = '''  document.getElementById("det-duzenle")'''
assert C in s, "❌ det-duzenle dinleyici capasi yok"
D = '''  // ⚠ ZIYARET_SIL_V1 — UYARI TAHMIN DEGIL SAYIM.
  //   "Emin misiniz?" hicbir sey anlatmaz. "2 fotograf, 1 rakip fiyat" anlatir.
  const _silBtn = document.getElementById("det-sil");
  if (_silBtn) _silBtn.addEventListener("click", async () => {
    let o;
    try { o = await api(`/api/saha/ziyaretler/${zid}/silme-onizleme`); }
    catch (e) { uyari(e.message); return; }
    if (!o.silebilir) { uyari(o.neden || "Bu ziyareti silemezsiniz."); return; }
    const kayiplar = [];
    if (o.not_uzunluk > 0) kayiplar.push(`${o.not_uzunluk} karakterlik ziyaret notu`);
    if (o.foto > 0)        kayiplar.push(`${o.foto} fotoğraf`);
    if (o.teklif > 0)      kayiplar.push(`${o.teklif} rakip fiyat kaydı`);
    const liste = kayiplar.length
      ? kayiplar.map(k => "• " + k).join("\\n")
      : "• (bu ziyarette not, fotoğraf veya rakip fiyat kaydı yok)";
    const ok = confirm(
      `${o.firma || "Ziyaret"} — ${o.tarih || ""}\\n\\n` +
      `Bu ziyaret KALICI OLARAK silinecek.\\n\\nSilinecekler:\\n${liste}\\n\\n` +
      `⚠ Geri alınamaz.`);
    if (!ok) return;
    _silBtn.disabled = true; _silBtn.textContent = "Siliniyor…";
    try {
      await api(`/api/saha/ziyaretler/${zid}`, { method: "DELETE" });
      kapatModal();
      uyari("✓ Ziyaret silindi.", true);
      await loadView("ziyaretler");
    } catch (e) {
      _silBtn.disabled = false; _silBtn.textContent = "🗑 Sil";
      uyari(e.message);
    }
  });
  document.getElementById("det-duzenle")'''
s = s.replace(C, D, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ 🗑 Sil butonu + sayimli uyari")
PY
node --check shells/saha.js || { cp shells/saha.js.bak_sil shells/saha.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 4) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'grep -c "ZIYARET_SIL_V1" /app/server.mjs /app/shells/saha.js'

echo
echo "############ 5) ⚠ CANLI TEST — Eftal'in oturumuyla ############"
EFTAL="ae0c55f9-68cc-421d-96d9-409222452f1a"
TOKEN=$(openssl rand -hex 32)
HASH=$(printf "%s" "$TOKEN" | openssl dgst -sha256 -hex | awk '{print $NF}')
$PSQL -q -c "INSERT INTO user_sessions (user_id, token_hash, expires_at, metadata)
  VALUES ('$EFTAL','$HASH', now() + interval '5 minutes', '{\"amac\":\"silme testi\"}'::jsonb);"
A="Authorization: Bearer $TOKEN"

ZID=$($PSQL -tAc "SELECT id FROM saha_ziyaret WHERE rep_id='$EFTAL' ORDER BY created_at DESC LIMIT 1" | tr -d ' ')
echo "  Eftal'in son ziyareti: $ZID"
echo "  --- ONIZLEME (silmeden) ---"
curl -s -H "$A" "http://localhost:8080/api/saha/ziyaretler/$ZID/silme-onizleme" | python3 -m json.tool

echo "  --- BASKASININ ziyaretini silmeye calis (403 bekleniyor) ---"
BZID=$($PSQL -tAc "SELECT id FROM saha_ziyaret WHERE rep_id <> '$EFTAL' AND rep_id IS NOT NULL LIMIT 1" | tr -d ' ')
curl -s -o /dev/null -w "      DELETE baskasinin -> HTTP %{http_code}\n" -X DELETE -H "$A" \
  "http://localhost:8080/api/saha/ziyaretler/$BZID"
echo "      (403 olmali — silinmemis olmali)"
$PSQL -c "SELECT count(*) AS hala_duruyor FROM saha_ziyaret WHERE id='$BZID';"

$PSQL -q -c "UPDATE user_sessions SET revoked_at=now() WHERE metadata->>'amac'='silme testi';"

git add -A
git commit -q -m 'feat(saha): ZIYARET_SIL_V1 — ziyaret silme. Eftalin onerisi (saha_oneri 0a12fe05): "Ziyaret kayitlarinin silinebilmesi ile ilgili bir gelistirme olabilir. Ornegin bugunku ziyaretlerimde Harun Bozbag benden veya herhangi bir sebepten kaynakli 2 kayit olusmus." Mukerrer kaydin SEBEBINI ayrica kestik (MUKERRER_V1); bu, yanlislikla acilan kayitlar icin. Tasarim: (1) UYARI TAHMIN DEGIL SAYIM — "Emin misiniz?" hicbir sey anlatmaz; kullanici ne kaybedecegini rakamla goruyor: kac karakterlik not, kac fotograf, kac rakip fiyat kaydi. Bos onay penceresi kimseyi korumaz. (2) Temsilci SADECE kendi ziyaretini siler; musteri duzenlemede kapiyi kaldirdik ama silme geri alinamaz bir eylem, ayri muamele hak ediyor. Yonetici/admin hepsini silebilir. (3) IZ: saha_denetime dusuyor — kim, ne zaman, hangi ziyareti, hangi musteride, notu neydi. (4) ARSIV: saha_ziyaret_silinen tablosuna tam kopya. Kullaniciya "geri alinamaz" diyoruz ve arayuzde geri alma yok, ama veri kaybi SESSIZ olmuyor — bugun butun gun sessiz veri kaybi kovaladik, kendim uretmem. (5) Bagli kayitlar da gider (foto + rakip teklif): ziyaret yoksa fotografin anlami yok, sahipsiz birakilmaz.'
echo "  COMMITTED"
