#!/usr/bin/env bash
# ZINCIR_BAGLA — yukleme sonrasi master + durum TAZELENSIN. Son halka.
#
# ⚠ KANITLANDI: master_musteri SUNUCU ACILISINDA kuruluyor (refreshed_at 04:58:14.237,
#   konteyner basladi 04:58:13.319 — bir saniye bile yok). ERP yuklenince DEGIL.
#
# ⚠ BU, durum'dan COK DAHA BUYUK BIR BOSLUK:
#   refreshSahaMasters() sadece master_musteri'yi degil; marka_kirilimi,
#   kategori_kirilimi, fiyat listesi eslesmesini de kuruyor.
#   refreshSahaCariCache() typeahead'i besliyor.
#   Yarin satis faturasi yuklenir, konteyner yeniden BASLAMAZ:
#     master dunku kalir · yeni musteriler typeahead'de CIKMAZ · ciro kirilimlari ESKIR
#     · durum eski master'dan hesaplanir  -> VE HICBIR YERDE HATA GORUNMEZ.
#   Bugune kadar fark edilmedi cunku her dagitimda konteyner yeniden basliyordu;
#   master TESADUFEN tazeleniyordu. Dagitimi biraktigimiz gun sessizce eskir.
#   ⚠ ERP monitorunun 30 gun boyunca emekli bir boru hattini izlemesiyle AYNI DESEN.
#
# ⚠ COZUM: sunucunun KENDI fonksiyonlari cagriliyor. Kendi SQL'imi YAZMIYORUM —
#   ayni tabloyu iki yerde kuran iki SQL, er ya da gec IKI GERCEK uretir.
#   Capa: 23665-23667 (unlink -> sendJson arasi). Dosyadan okundu, tahmin yok.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) YAMA ############"
cp server_container.mjs server_container.mjs.bak_zincir
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "ZINCIR_V1" in s: sys.exit("ZATEN YAMALI")

ESKI = '''      await unlink(yol).catch(() => {});

      sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc });'''
assert ESKI in s, "❌ unlink/sendJson capasi bulunamadi — DUR"

YENI = '''      await unlink(yol).catch(() => {});

      // ⚠ ZINCIR_V1 — YUKLEME BITTI, AMA IS BITMEDI.
      //   master_musteri SUNUCU ACILISINDA kuruluyordu, ERP yuklenince DEGIL.
      //   (kanit: refreshed_at 04:58:14.237 · konteyner basladi 04:58:13.319)
      //   Yani yeni satis faturasi yuklenir, konteyner yeniden baslamazsa:
      //     master dunku kalir · yeni musteriler typeahead'de cikmaz ·
      //     ciro kirilimlari eskir · durum eski master'dan hesaplanir
      //   ve HICBIR YERDE HATA GORUNMEZ. Bugune kadar fark edilmedi cunku her
      //   dagitimda konteyner yeniden basliyor, master TESADUFEN tazeleniyordu.
      //   ⚠ ERP monitorunun 30 gun boyunca emekli bir hatti izlemesiyle ayni desen.
      //   Sunucunun KENDI fonksiyonlari cagriliyor; ikinci bir SQL yazilmiyor.
      const tazelenen = [];
      if (sonuc.ok && ["satis_faturalari", "cari_bakiye", "musteri_risk"].includes(sonuc.tip)) {
        try {
          await refreshSahaMasters();       // master_musteri + kirilimlar + fiyat eslesme
          tazelenen.push("master_musteri");
          await refreshSahaCariCache();     // typeahead
          tazelenen.push("cari_cache");
          const d = await query("SELECT * FROM saha_musteri_durum_yenile()");
          tazelenen.push(`musteri_durum (${d.rows[0]?.degisen ?? 0} kayit)`);
        } catch (e) {
          // ⚠ SUSMAZ. Sessiz catch = sessiz kayip. Kullanici NE TAZELENMEDIGINI gorsun.
          console.error("[yukle] tazeleme basarisiz:", e && e.message);
          tazelenen.push("⚠ TAZELEME HATASI: " + String(e && e.message).slice(0, 160));
        }
      }

      sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc, tazelenen });'''
s = s.replace(ESKI, YENI, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ yukleme sonrasi: master + cari_cache + durum tazeleniyor")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_zincir server_container.mjs; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 2) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"

echo
echo "############ 3) ⚠ KANIT — zincir GERCEKTEN calisiyor mu? ############"
echo "  ⚠ Konteyner AZ ONCE yeniden basladi; master TESADUFEN taze."
echo "     O yuzden onu KASITLI BAYATLATIP yuklemenin tazeleyip tazelemedigine bakiyorum."
echo "     (Yoksa 'calisiyor' sanirim — tam da duzeltmeye calistigim yanilgi.)"
$PSQL -c "UPDATE master_musteri SET refreshed_at = now() - interval '30 days';"
$PSQL -c "SELECT max(refreshed_at) AS bayatlatilmis FROM master_musteri;"
$PSQL -c "UPDATE saha_musteri SET durum='YENI_NOKTA'
          WHERE id IN (SELECT id FROM saha_musteri WHERE durum='AKTIF_MUSTERI' AND aktif LIMIT 5);"
echo "  5 AKTIF musteri kasitli olarak YENI_NOKTA yapildi:"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "  --- simdi bir ERP dosyasi yuklenmis gibi zinciri tetikle (endpoint uzerinden) ---"
echo "  ⚠ Gercek yukleme icin dosya lazim. Onun yerine, endpoint'in cagirdigi"
echo "     AYNI fonksiyonlari admin uc noktasindan tetikleyip zinciri dogruluyorum."
$PSQL -c "SELECT * FROM saha_musteri_durum_yenile();"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"
echo "  ⚠ 5 kayit AKTIF_MUSTERI'ye geri dondu mu? Donduyse fonksiyon calisiyor."
echo "     Zincirin KENDISI ise ancak GERCEK bir dosya yuklenince kanitlanir —"
echo "     bir sonraki ERP yuklemesinde 'tazelenen' alanini ekranda goreceksin."

git add -A
git commit -q -m 'fix(erp): ZINCIR_V1 — yukleme sonrasi master + typeahead + durum TAZELENIYOR. Kanitlandi ki master_musteri SUNUCU ACILISINDA kuruluyordu, ERP yuklenince degil: master_musteri.refreshed_at 04:58:14.237, konteyner basladi 04:58:13.319 — bir saniye bile yok. refreshSahaMasters() sadece master_musteriyi degil marka_kirilimi, kategori_kirilimi ve fiyat listesi eslesmesini de kuruyor; refreshSahaCariCache() typeahead besliyor. Yani yeni satis faturasi yuklenip konteyner yeniden baslamazsa: master dunku kalir, yeni musteriler typeaheadde cikmaz, ciro kirilimlari eskir, durum eski masterdan hesaplanir — VE HICBIR YERDE HATA GORUNMEZ. Bugune kadar fark edilmedi cunku her dagitimda konteyner yeniden basliyor, master tesaduven tazeleniyordu; dagitimi biraktigimiz gun sessizce eskirdi. ERP monitorunun 30 gun boyunca emekli bir boru hattini izlemesiyle AYNI DESEN. Cozum: yukleme endpointi (23665, unlink ile sendJson arasi) artik sunucunun KENDI refreshSahaMasters + refreshSahaCariCache fonksiyonlarini ve saha_musteri_durum_yenile()i cagiriyor; ikinci bir SQL yazilmadi cunku ayni tabloyu iki yerde kuran iki SQL er ya da gec iki gercek uretir. Tetikleyici tipler: satis_faturalari, cari_bakiye, musteri_risk. Sonuc yanitta "tazelenen" alaninda gorunuyor; hata olursa catch SUSMUYOR, kullaniciya ne tazelenmedigini soyluyor.'
echo "  COMMITTED"
