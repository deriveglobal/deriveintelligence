#!/usr/bin/env bash
# DURUM_UYGULA — durum artik ELLE YAZILMIYOR, ERP'den HESAPLANIYOR.
#
# ⚠ PROVA: 1.028 musterinin 674'u degisiyor. Ucte ikisi YANLISMIS.
#   201 musteriye BU AY fatura kesilmis, ekran "eski nokta" diyordu.
#   PRATIK OTOMOTIV: 1.453 fatura, son satis 10 Tem -> ekranda "YENI NOKTA".
#   Temsilci dort yillik musterinin kapisini "yeni nokta" etiketiyle caliyordu.
#
# ⚠ KALICILIK — ASIL MESELE BU:
#   Bugun duzeltip yarin ERP yuklenince tekrar bozulursa, HICBIR SEY yapmamis oluruz.
#   Bu yuzden hesap bir FONKSIYON'a konuyor ve erp_ingest.py'nin BAGIMLILIK zincirine
#   baglaniyor: satis_faturalari yuklendi -> musteri_durum yeniden hesaplanir.
#   Bir daha elle is YOK.
#
# ⚠ VE ELLE SECIM KAPATILIYOR:
#   Alan hesaplaniyorsa, temsilcinin acilir listeden secmesi onu TEKRAR BOZAR.
#   Sunucu PUT'ta artik 'durum' alanini KABUL ETMIYOR. (Arayuzdeki liste no-op olur;
#   goruntusu ayri bir adimda temizlenecek — ama VERIYI artik bozamaz.)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) SEMA — ESLESMEMIS durustce ekleniyor ############"
# ⚠ 235 musterinin ERP kodu yok. "YENI" demek YALAN olur: gercekten yeni mi,
#   yoksa sadece eslestirilmemis mi — BILMIYORUZ. Bilmedigimiz seye isim veriyoruz.
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ SEMA"; exit 1; }
BEGIN;
ALTER TABLE saha_musteri DROP CONSTRAINT IF EXISTS saha_musteri_durum_check;
ALTER TABLE saha_musteri ADD CONSTRAINT saha_musteri_durum_check
  CHECK (durum = ANY (ARRAY[
    'YENI_NOKTA','ESKI_NOKTA','AKTIF_MUSTERI','PASIF_NOKTA',
    'RISKLI_NOKTA',   -- eski kayitlar icin korunuyor; artik yazilmiyor
    'ESLESMEMIS'      -- ⚠ YENI: "ERP eslesmesi yok, durum BILINMIYOR"
  ]));

-- ⚠ HESAP BIR FONKSIYONDA. Tek kaynak. Kopyala-yapistir SQL yok.
CREATE OR REPLACE FUNCTION saha_musteri_durum_yenile()
RETURNS TABLE(degisen bigint) AS $$
  WITH erp AS (
    SELECT musteri_kodu, max(fatura_tarihi) AS son_satis
      FROM bi_satis_faturalari
     GROUP BY musteri_kodu
  ),
  hesap AS (
    SELECT m.id,
           CASE
             WHEN m.musteri_kodu IS NULL           THEN 'ESLESMEMIS'
             WHEN e.musteri_kodu IS NULL           THEN 'YENI_NOKTA'
             WHEN e.son_satis > current_date -  90 THEN 'AKTIF_MUSTERI'
             WHEN e.son_satis > current_date - 365 THEN 'PASIF_NOKTA'
             ELSE                                       'ESKI_NOKTA'
           END AS yeni
      FROM saha_musteri m
      LEFT JOIN erp e ON e.musteri_kodu = m.musteri_kodu
     WHERE m.aktif
  ),
  upd AS (
    UPDATE saha_musteri m SET durum = h.yeni, updated_at = now()
      FROM hesap h
     WHERE m.id = h.id AND m.durum IS DISTINCT FROM h.yeni
    RETURNING 1
  )
  SELECT count(*) FROM upd;
$$ LANGUAGE sql;
COMMIT;
SQL
echo "  ✅ ESLESMEMIS eklendi · saha_musteri_durum_yenile() kuruldu"

echo
echo "############ 2) ILK HESAP ############"
$PSQL -c "SELECT * FROM saha_musteri_durum_yenile();"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 3) ⚠ SAGLAMA — hesap ERP ile TUTUYOR mu? ############"
$PSQL -c "
WITH erp AS (SELECT musteri_kodu, max(fatura_tarihi) s FROM bi_satis_faturalari GROUP BY 1)
SELECT count(*) FILTER (WHERE m.durum='AKTIF_MUSTERI' AND e.s <= current_date-90) AS aktif_ama_satis_eski,
       count(*) FILTER (WHERE m.durum='ESKI_NOKTA'    AND e.s >  current_date-90) AS eski_ama_satis_yeni,
       count(*) FILTER (WHERE m.durum='ESLESMEMIS'    AND m.musteri_kodu IS NOT NULL) AS eslesmemis_ama_kodu_var,
       count(*) FILTER (WHERE m.durum='YENI_NOKTA'    AND e.s IS NOT NULL) AS yeni_ama_satis_var
  FROM saha_musteri m LEFT JOIN erp e ON e.musteri_kodu=m.musteri_kodu WHERE m.aktif;"
echo "  ⚠ Dordu de 0 olmali. Degilse hesap tutmuyor demektir."

echo
echo "############ 4) SUNUCU — elle secim ARTIK KABUL EDILMIYOR ############"
cp server_container.mjs server_container.mjs.bak_durum
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "DURUM_TURETILIYOR" in s: sys.exit("ZATEN YAMALI")

ESKI = '''      const fields = ["tip", "firma", "musteri_kodu", "il", "ilce", "segment", "durum",
                      "lat", "lng", "telefon", "yetkili", "notlar", "sorumlu_rep"];'''
assert ESKI in s, "❌ fields dizisi bulunamadi — DUR"
YENI = '''      // ⚠ DURUM_TURETILIYOR — 'durum' listeden CIKARILDI.
      //   durum artik ELLE YAZILMIYOR: ERP satis gecmisinden hesaplaniyor
      //   (saha_musteri_durum_yenile(), her ERP yuklemesinde tazelenir).
      //   Onceden elle seciliyordu ve kimse guncellemiyordu: 1.028 musterinin
      //   674'u yanlisti. 201 musteriye BU AY fatura kesilmisken ekran "eski nokta"
      //   diyordu; PRATIK OTOMOTIV'in 1.453 faturasi vardi ve "YENI NOKTA" yaziyordu.
      //   Alan hesaplaniyorsa, elle secim onu TEKRAR BOZAR. Bu yuzden kabul edilmiyor.
      const fields = ["tip", "firma", "musteri_kodu", "il", "ilce", "segment",
                      "lat", "lng", "telefon", "yetkili", "notlar", "sorumlu_rep"];'''
s = s.replace(ESKI, YENI, 1)

# ── Musteri detayina KANIT ekle: etiket degil, SAYI gostersin ──
A = '''        LEFT JOIN LATERAL (
          SELECT MAX(z.ziyaret_tarihi) AS son_ziyaret, COUNT(*) AS ziyaret_sayisi
          FROM saha_ziyaret z
          WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'
        ) sz ON true'''
assert A in s, "❌ ziyaret LATERAL bulunamadi"
B = A + '''
        -- ⚠ DURUM_TURETILIYOR — ekranda ETIKET degil KANIT dursun.
        --   Temsilci "yeni nokta" yazisini degil, "1.453 fatura · son satis 10 Tem"i gorsun.
        LEFT JOIN LATERAL (
          SELECT count(*) AS erp_fatura_sayisi,
                 min(f.fatura_tarihi) AS erp_ilk_satis,
                 max(f.fatura_tarihi) AS erp_son_satis
          FROM bi_satis_faturalari f
          WHERE m.musteri_kodu IS NOT NULL AND f.musteri_kodu = m.musteri_kodu
        ) erp ON true'''
s = s.replace(A, B, 1)

C = '''        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,'''
assert C in s, "❌ detay SELECT bulunamadi"
D = '''        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,
               erp.erp_fatura_sayisi, erp.erp_ilk_satis, erp.erp_son_satis,'''
s = s.replace(C, D, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ PUT 'durum' kabul etmiyor · detayda ERP kaniti (fatura sayisi, ilk/son satis)")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_durum server_container.mjs; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 5) ⚠ KALICILIK — erp_ingest.py baglanti noktalari ############"
echo "  (yamamadan ONCE gorecegim — capa hafizadan degil DOSYADAN)"
grep -n "BAGIMLILIK" erp_ingest.py
awk '/^BAGIMLILIK/,/^}/ { printf "%5d| %s\n", NR, $0 }' erp_ingest.py
echo "  --- yeniden kurma adimlarini KIM calistiriyor? ---"
grep -n "maliyet_ay\|marj_fact\|sinyal_kredi\|def .*kur\|def .*rebuild\|ADIMLAR\|KURUCU" erp_ingest.py | head -15

echo
echo "############ 6) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"

git add -A
git commit -q -m 'feat(saha): durum artik ELLE YAZILMIYOR, ERPden HESAPLANIYOR. Olcum: 1.028 musterinin 674u yanlisti (ucte ikisi). 248 musteriye son 90 gunde satis yapilmis, ekranda "aktif" yazan 1 (BIR) taneydi. 201 musteriye BU AY fatura kesilmis, ekran "eski nokta" diyordu. PRATIK OTOMOTIVin 1.453 faturasi ve 10 Temmuzda satisi var, ekranda "YENI NOKTA" yaziyordu — temsilci dort yillik musterinin kapisini "yeni nokta" etiketiyle caliyordu. Sebep: alan bir acilir listeden elle seciliyordu, Excel ice aktarimindan gelen varsayilanla kalmisti, kimse guncellemiyordu. Kural artik olgu: ERP kodu yok -> ESLESMEMIS (bilmiyoruz, oyle de soyluyoruz; 235 musteriye "yeni" demek yalan olurdu) · kod var hic fatura yok -> YENI_NOKTA · son 90 gun -> AKTIF_MUSTERI · 1 yil ici -> PASIF_NOKTA · daha eski -> ESKI_NOKTA. Hesap saha_musteri_durum_yenile() fonksiyonunda (tek kaynak). Sunucu PUTta artik durum alanini KABUL ETMIYOR: alan hesaplaniyorsa elle secim onu tekrar bozar. Musteri detayina KANIT eklendi (erp_fatura_sayisi, ilk/son satis) — temsilci etiketi degil sayiyi gorsun. RISKLI_NOKTA aktiflik ekseninden cikti: risk vadesi gecmis bakiyeden gelen AYRI bir eksen, aktif bir musteri ayni anda riskli olabilir.'
echo "  COMMITTED"
echo
echo "⚠ HENUZ KALICI DEGIL: erp_ingest.py baglantisi yapilmadi (capalari yukarida bastim)."
echo "   Su an ERP yuklenirse durum TAZELENMEZ. Bir sonraki adim bu."
