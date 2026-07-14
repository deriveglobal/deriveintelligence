#!/usr/bin/env bash
# UC_ARIZA_DUZELT — Eftal'in ve Huseyin'in bugun yasadigi uc ariza.
#
# ⚠ 1) PIYASA EKRANI — UC BUTONUN UCU DE OLU.
#      'g' fonksiyonu saha.js'de BES ayri fonksiyonun ICINDE yerel tanimli
#      (799, 961, 1230, 1908, 3328). Ama rakipFiyatModal (5383), dosyaYukleModal (5415)
#      ve piyasaNotuModal (5429) onu KENDI KAPSAMLARINDA BULAMIYOR.
#      "Rakip Fiyat" · "Dosya Yukle" · "Piyasa Notu" — ucu de kaydete basinca patliyor.
#      Eftal 10:17 ve 10:23'te 16 kez denedi. Ekran aciliyor, buton calisiyor, KAYDET OLUYOR.
#
# ⚠ 2) MUKERRER ZIYARET — SUNUCUDA HICBIR KORUMA YOK.
#      POST /api/saha/ziyaretler (28619) dogrudan INSERT yapiyor.
#      Ve GET /api/saha/ziyaretler her cagrida foto sayisi icin TUM TABLOYU grupluyor (28594).
#      ZINCIR: yavas liste -> kullanici "olmadi" saniyor -> tekrar basiyor -> koruma yok -> IKI KAYIT.
#      HARUN BOZBAG: 1,16 sn arayla. UZUNLAR (Huseyin, bugun): 33 sn — ve o saatlerde YAVAS_API.
#      ⚠ Eftal "silme butonu" istedi. Hakli — ama silme SEBEBI DURDURMAZ.
#
# ⚠⚠ 3) VE EFTAL'IN BUGUNKU 400 HATASI BENIM YUZUMDEN.
#      'durum'u sunucunun PUT'ta kabul ettigi listeden CIKARDIM (artik ERP'den hesaplaniyor).
#      Ama ARAYUZ HALA GONDERIYOR (saha.js:1001 ve 1257).
#      Sunucu: govdede durum'dan baska bir sey yok -> "Guncellenecek alan yok" -> 400.
#      Sessiz 403'u duzelttim, yerine GORUNUR 400 koydum. Ilerleme ama HATA.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) ARAYUZ — uc duzeltme ############"
cp shells/saha.js shells/saha.js.bak_ucariza
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/saha.js"); s = p.read_text(encoding="utf-8")
if "UC_ARIZA_V1" in s: sys.exit("ZATEN YAMALI")
n = 0
def rep(eski, yeni, ad):
    global s, n
    if eski not in s:
        print(f"  ⚠ CAPA YOK: {ad}"); return False
    s = s.replace(eski, yeni, 1); n += 1
    print(f"  ✅ {ad}"); return True

# ── (a) PIYASA: 'g' uc modalde de tanimli olsun ─────────────────────────
rep('''function rakipFiyatModal(onSave) {
  modal(`''',
'''function rakipFiyatModal(onSave) {
  // ⚠ UC_ARIZA_V1 — 'g' bu kapsamda TANIMLI DEGILDI.
  //   Eftal 14 Tem 10:17 ve 10:23'te 16 kez denedi: "Can't find variable: g".
  //   Piyasa ekraninin UC BUTONU DA bu yuzden oluydu.
  const g = id => document.getElementById(id)?.value.trim() || "";
  modal(`''',
"piyasa: rakipFiyatModal -> g tanimlandi")

rep('''function dosyaYukleModal(onSave) {
  modal(`''',
'''function dosyaYukleModal(onSave) {
  // ⚠ UC_ARIZA_V1 — 'g' bu kapsamda da yoktu.
  const g = id => document.getElementById(id)?.value.trim() || "";
  modal(`''',
"piyasa: dosyaYukleModal -> g tanimlandi")

rep('''function piyasaNotuModal(onSave) {
  modal(`''',
'''function piyasaNotuModal(onSave) {
  // ⚠ UC_ARIZA_V1 — 'g' bu kapsamda da yoktu.
  const g = id => document.getElementById(id)?.value.trim() || "";
  modal(`''',
"piyasa: piyasaNotuModal -> g tanimlandi")

# ── (b) DURUM artik gonderilmiyor (400'un sebebi) ───────────────────────
rep('''      const durumSecim = document.getElementById("zf-durum")?.value;
      if (durumSecim) {
        await api(`/api/saha/musteriler/${mus.id}`, {
          method: "PUT", body: JSON.stringify({ durum: durumSecim })
        }).catch(() => {});
      }''',
'''      // ⚠ UC_ARIZA_V1 — 'durum' ARTIK GONDERILMIYOR.
      //   durum ERP satis gecmisinden HESAPLANIYOR (saha_musteri_durum_yenile).
      //   Sunucu PUT'ta kabul etmiyor; arayuz yine de gonderdigi icin
      //   Eftal bugun 11:28 ve 11:54'te "Guncellenecek alan yok" (400) aldi.
      //   Sessiz 403'u duzeltirken gorunur 400 uretmisim. Kaynak: BU ISTEK.''',
"durum PUT #1 (zf-durum) kaldirildi")

rep('''      // Update nokta durumu (tuketici)
      const durumSecim = tuketici ? document.getElementById("pt-durum")?.value : null;
      if (durumSecim && z.musteri_id) {
        await api(`/api/saha/musteriler/${z.musteri_id}`, { method: "PUT", body: JSON.stringify({ durum: durumSecim }) }).catch(() => {});
      }''',
'''      // ⚠ UC_ARIZA_V1 — 'durum' ARTIK GONDERILMIYOR (ERP'den hesaplaniyor).''',
"durum PUT #2 (pt-durum) kaldirildi")

# ── (c) KAYDET butonu: cift tiklamaya kilit ─────────────────────────────
# ziyaret kaydet butonunu bul (zf formu)
import re
m = re.search(r'(document\.getElementById\("zf-kaydet"\)\.addEventListener\("click", async \(\) => \{)', s)
if m:
    s = s.replace(m.group(1), m.group(1) + '''
    // ⚠ UC_ARIZA_V1 — CIFT TIKLAMA KILIDI.
    //   Yavas kaydet -> kullanici "olmadi" saniyor -> tekrar basiyor -> IKI KAYIT.
    //   Sistemde 35 mukerrer grup, 37 fazladan kayit var.
    const _kb = document.getElementById("zf-kaydet");
    if (_kb.disabled) return;
    _kb.disabled = true; _kb.textContent = "Kaydediliyor…";
    const _serbest = () => { _kb.disabled = false; _kb.textContent = "Kaydet"; };''', 1)
    n += 1
    print("  ✅ zf-kaydet: cift tiklama kilidi")
else:
    print("  ⚠ zf-kaydet butonu bulunamadi — sunucu tarafi korumasi YETERLI olacak")

p.write_text(s, encoding="utf-8")
print(f"\n  TOPLAM {n} duzeltme")
PY
node --check shells/saha.js || { cp shells/saha.js.bak_ucariza shells/saha.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 2) SUNUCU — mukerrer kayit KORUMASI (asil cozum) ############"
cp server_container.mjs server_container.mjs.bak_ucariza
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "MUKERRER_V1" in s: sys.exit("ZATEN YAMALI")

A = '''      const tamamla = p.tamamla === true;
      const result = await query(`
        INSERT INTO saha_ziyaret (tenant_id, musteri_id, rep_id, tip, durum,'''
assert A in s, "❌ POST ziyaret capasi yok"
B = '''      const tamamla = p.tamamla === true;
      // ⚠⚠ MUKERRER_V1 — AYNI KAYDI IKI KEZ YAZMA.
      //   Sistemde 35 mukerrer grup, 37 fazladan kayit vardi.
      //   HARUN BOZBAG: 1,16 saniye arayla iki kayit (cift tiklama).
      //   UZUNLAR (Huseyin): 33 saniye — ve o saatlerde YAVAS_API uyarilari.
      //   ZINCIR: yavas kaydet -> kullanici "olmadi" saniyor -> tekrar basiyor -> IKI KAYIT.
      //   ⚠ Eftal "silme butonu" istedi. Hakli — ama silme SEBEBI DURDURMAZ.
      //   Ayni rep + ayni musteri + ayni gun, son 3 dakika icinde kayit varsa:
      //   YENI KAYIT ACMA, MEVCUDU DONDUR. Kullanici icin fark yok; veri temiz kalir.
      const _tarih = tamamla ? (p.ziyaret_tarihi || new Date().toISOString().slice(0, 10)) : null;
      if (tamamla) {
        const _var = await query(`
          SELECT * FROM saha_ziyaret
           WHERE tenant_id=$1 AND musteri_id=$2 AND rep_id=$3
             AND ziyaret_tarihi=$4 AND durum='TAMAMLANDI'
             AND created_at > now() - interval '3 minutes'
           ORDER BY created_at DESC LIMIT 1`,
          [session.tenantId, p.musteri_id, session.userId, _tarih]);
        if (_var.rowCount) {
          console.warn("[saha] mukerrer ziyaret engellendi:", session.userId, p.musteri_id, _tarih);
          sendJson(response, 200, { ziyaret: _var.rows[0], asistan: null, mukerrer_engellendi: true });
          return;
        }
      }
      const result = await query(`
        INSERT INTO saha_ziyaret (tenant_id, musteri_id, rep_id, tip, durum,'''
s = s.replace(A, B, 1)

# ⚠ Bos PUT -> 400 yerine ANLAMLI yanit
C = '''      if (!sets.length) { sendJson(response, 400, { error: "Güncellenecek alan yok." }); return; }'''
assert C in s, "❌ bos PUT capasi yok"
D = '''      // ⚠ MUKERRER_V1 — 'durum' artik hesaplaniyor; sadece durum gonderildiyse
      //   bu bir HATA DEGIL. Eftal bugun bu yuzden iki kez 400 aldi.
      if (!sets.length) {
        if (Object.prototype.hasOwnProperty.call(p, "durum")) {
          sendJson(response, 200, { ok: true, not: "Nokta durumu artık ERP satış geçmişinden otomatik hesaplanıyor; elle güncellenmiyor." });
          return;
        }
        sendJson(response, 400, { error: "Güncellenecek alan yok." }); return;
      }'''
s = s.replace(C, D, 1)

# ⚠ YAVAS LISTE — foto alt sorgusu her cagrida TUM TABLOYU grupluyor
E = '''        LEFT JOIN (SELECT ziyaret_id, COUNT(*) AS foto_sayisi FROM saha_ziyaret_foto GROUP BY ziyaret_id) fot ON fot.ziyaret_id = z.id'''
if E in s:
    s = s.replace(E, '''        -- ⚠ MUKERRER_V1 — eski hali TUM foto tablosunu grupluyordu (her cagrida).
        --   Yavaslik mukerrer kayit URETIYORDU: kullanici "olmadi" sanip tekrar basiyordu.
        LEFT JOIN LATERAL (
          SELECT count(*) AS foto_sayisi FROM saha_ziyaret_foto f WHERE f.ziyaret_id = z.id
        ) fot ON true''', 1)
    print("  ✅ yavas foto alt sorgusu -> LATERAL")

p.write_text(s, encoding="utf-8")
print("  ✅ mukerrer koruma · bos PUT anlamli yanit")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_ucariza server_container.mjs; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker exec krb-assessment sh -c 'grep -c "UC_ARIZA_V1" /app/shells/saha.js' | sed 's/^/  imajda UC_ARIZA_V1: /'
docker exec krb-assessment sh -c 'grep -c "MUKERRER_V1" /app/server.mjs' | sed 's/^/  imajda MUKERRER_V1: /'

echo
echo "############ 4) ⚠ MEVCUT 37 MUKERRER — SILMIYORUM, GOSTERIYORUM ############"
$PSQL -c "
WITH grup AS (
  SELECT rep_id, musteri_id, ziyaret_tarihi, count(*) AS adet,
         array_agg(id ORDER BY created_at) AS ids,
         array_agg(coalesce(length(notlar),0) ORDER BY created_at) AS not_uzunluk
    FROM saha_ziyaret
   GROUP BY 1,2,3 HAVING count(*) > 1
)
SELECT m.firma, coalesce(u.full_name,'(import)') AS rep, g.ziyaret_tarihi, g.adet, g.not_uzunluk
  FROM grup g
  JOIN saha_musteri m ON m.id = g.musteri_id
  LEFT JOIN users u ON u.id = g.rep_id
 ORDER BY g.ziyaret_tarihi DESC LIMIT 12;"
echo "  ⚠ SILME KURALI ONERISI: her grupta NOTU EN UZUN olan kalir, otekiler silinir."
echo "     (Ayni notlarsa: ILK olusan kalir.)"
echo "  ⚠ Silmeden ONCE onayini istiyorum. Veri silmek geri alinamaz."

git add -A
git commit -q -m 'fix(saha): UC_ARIZA_V1 + MUKERRER_V1 — Eftal ve Huseyinin bugun yasadigi uc ariza. (1) PIYASA EKRANI: g fonksiyonu saha.jsde bes ayri fonksiyonun icinde yerel tanimliydi ama rakipFiyatModal, dosyaYukleModal ve piyasaNotuModal onu kendi kapsamlarinda bulamiyordu — "Rakip Fiyat", "Dosya Yukle" ve "Piyasa Notu" butonlarinin UCU DE kaydete basinca patliyordu ("Cant find variable: g"). Eftal 14 Tem 10:17 ve 10:23te 16 kez denedi. Uc modalde de g tanimlandi. (2) MUKERRER ZIYARET: POST /api/saha/ziyaretlerde hicbir koruma yoktu; sistemde 35 mukerrer grup, 37 fazladan kayit birikmisti. Sebep zinciri: GET /api/saha/ziyaretler her cagrida tum foto tablosunu grupluyordu (yavas) -> kullanici "olmadi" sanip tekrar basiyordu -> koruma yok -> iki kayit. HARUN BOZBAG 1,16 saniye arayla, UZUNLAR (Huseyin) 33 saniye arayla ve tam o saatlerde YAVAS_API uyarilari. Eftal "silme butonu" istedi — hakli, ama silme SEBEBI DURDURMAZ. Uc katmanli cozum: sunucuda ayni rep+musteri+gun son 3 dakikada kayit varsa yeni kayit acilmiyor mevcut donduruluyor, foto alt sorgusu LATERALe cevrildi (yavaslik kesildi), arayuzde kaydet butonu ilk tiklamada kilitleniyor. (3) ⚠ VE EFTALIN BUGUNKU 400 HATASI BENIM YUZUMDENDI: durumu sunucunun PUT kabul listesinden cikarmistim (artik ERPden hesaplaniyor) ama arayuz hala gonderiyordu, sunucu "Guncellenecek alan yok" deyip 400 veriyordu. Sessiz 403u duzeltirken gorunur 400 uretmisim. Arayuz artik gondermiyor; sunucu sadece durum gelirse 400 degil aciklamali 200 donuyor.'
echo "  COMMITTED"
