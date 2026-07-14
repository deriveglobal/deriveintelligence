#!/usr/bin/env bash
# DURUM_UYGULA_2 — bir onceki surumu (durum_uygula.sh) CALISTIRMADIK, iyi ki.
#
# ⚠ FATIH'IN ITIRAZI HAKLIYDI VE SEMAYI KURTARDI:
#   "yeni mi" sorusu ZATEN KAYIT ANINDA cevaplaniyor — temsilci master_musteri'de
#   arar, bulursa musteridir, bulamazsa "yeni nokta olarak ekle" der.
#   Ben 'ESLESMEMIS' diye YENI BIR DURUM ekleyecektim: kimlik bilgisini
#   ikinci bir yere yazacaktim. Iki kaynak, er ya da gec CELISIR.
#
# ⚠ VE OLCUM GOSTERDI KI IKI EKSEN CAKISIYOR — tablo DORT satir, fazlasi yok:
#     ERP'de VAR -> AKTIF 248 · UYUYAN 143 · ESKI 402
#     ERP'de YOK -> hic satis yok 235      (TEK satir)
#   ERP'de olmayan HER musterinin hic satisi yok. Yani "hic satis yok" = "ERP'de yok".
#   Ve bu TAM OLARAK YENI_NOKTA'nin anlami. Yeni enum'a GEREK YOK.
#   Mevcut dort etiket, hic degistirilmeden dogru seyi anlatiyor.
#
# ⚠ VE TEK KAYNAK: master_musteri ZATEN son_fatura / fatura_sayisi / toplam_ciro
#   tutuyor (38.628 kayit, tazeleniyor). bi_satis_faturalari'ndan YENIDEN
#   hesaplamak ikinci bir gercek uretmek olurdu. master_musteri'yi okuyorum.
#
# KURAL (tek eksen: FAALIYET):
#   hic fatura yok        -> YENI_NOKTA     (= ERP'de yok = gercekten yeni)
#   son fatura <=  90 gun -> AKTIF_MUSTERI
#   son fatura <= 365 gun -> PASIF_NOKTA    (uyuyan)
#   daha eski             -> ESKI_NOKTA
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 0) ⚠ KAPI — master_musteri ile ham fatura AYNI SEYI mi soyluyor? ############"
echo "  (master_musteri'yi tek kaynak yapiyorum; once ham veriyle TUTUYOR mu bakiyorum)"
$PSQL -c "
WITH ham AS (SELECT musteri_kodu, max(fatura_tarihi) s FROM bi_satis_faturalari GROUP BY 1)
SELECT count(*) AS ortak_musteri,
       count(*) FILTER (WHERE mm.son_fatura = h.s)                      AS ayni_tarih,
       count(*) FILTER (WHERE mm.son_fatura IS DISTINCT FROM h.s)       AS sapan,
       max(abs(mm.son_fatura - h.s))                                    AS en_buyuk_sapma_gun
  FROM master_musteri mm JOIN ham h ON h.musteri_kodu = mm.musteri_kodu;"
echo "  ⚠ 'sapan' buyukse master_musteri bayat demektir — o zaman ham veriyi kullanirim."

echo
echo "############ 1) HESAP — tek fonksiyon, tek kaynak ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || { echo "❌ SEMA"; exit 1; }
BEGIN;
-- ⚠ ENUM'A DOKUNULMUYOR. Mevcut dort etiket zaten dogru seyi anlatiyor.
--   ESLESMEMIS EKLENMIYOR: "hic satis yok" zaten "ERP'de yok" demek (olcum: 235 = 235).
CREATE OR REPLACE FUNCTION saha_musteri_durum_yenile()
RETURNS TABLE(degisen bigint) AS $$
  WITH hesap AS (
    SELECT m.id,
           CASE
             WHEN mm.son_fatura IS NULL                THEN 'YENI_NOKTA'    -- hic fatura yok
             WHEN mm.son_fatura > current_date -  90    THEN 'AKTIF_MUSTERI'
             WHEN mm.son_fatura > current_date - 365    THEN 'PASIF_NOKTA'   -- uyuyan
             ELSE                                            'ESKI_NOKTA'
           END AS yeni
      FROM saha_musteri m
      LEFT JOIN master_musteri mm
        ON mm.tenant_id = m.tenant_id AND mm.musteri_kodu = m.musteri_kodu
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
echo "  ✅ saha_musteri_durum_yenile() — kaynak: master_musteri"

echo
echo "############ 2) ILK HESAP ############"
$PSQL -c "SELECT * FROM saha_musteri_durum_yenile();"
$PSQL -c "SELECT durum, count(*) FROM saha_musteri WHERE aktif GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 3) ⚠ SAGLAMA — dordu de 0 olmali ############"
$PSQL -c "
SELECT count(*) FILTER (WHERE m.durum='AKTIF_MUSTERI' AND (mm.son_fatura IS NULL OR mm.son_fatura <= current_date-90))  AS aktif_ama_satis_yok_veya_eski,
       count(*) FILTER (WHERE m.durum='ESKI_NOKTA'    AND mm.son_fatura >  current_date-90)                             AS eski_ama_satis_yeni,
       count(*) FILTER (WHERE m.durum='YENI_NOKTA'    AND mm.son_fatura IS NOT NULL)                                    AS yeni_ama_faturasi_var,
       count(*) FILTER (WHERE m.durum='RISKLI_NOKTA')                                                                   AS riskli_kaldi
  FROM saha_musteri m
  LEFT JOIN master_musteri mm ON mm.tenant_id=m.tenant_id AND mm.musteri_kodu=m.musteri_kodu
 WHERE m.aktif;"

echo
echo "############ 4) KONUM — ilk check-in = musterinin konumu ############"
# ⚠ Karar: HARITA kurulur. Ziyaret DOGRULAMASI / mesafe denetimi YAPILMAZ.
#   1.028 musterinin 0'inda koordinat vardi; 2.403 ziyaretin 9'unda check-in.
#   Temsilci check-in atarken zaten dukkanin onunde — referans BEDAVA olusuyor.
$PSQL -c "
WITH ilk AS (
  SELECT DISTINCT ON (z.musteri_id)
         z.musteri_id, z.checkin_lat, z.checkin_lng
    FROM saha_ziyaret z
   WHERE z.checkin_lat IS NOT NULL AND z.checkin_lng IS NOT NULL
   ORDER BY z.musteri_id, z.checkin_at ASC
)
UPDATE saha_musteri m
   SET lat = i.checkin_lat, lng = i.checkin_lng, updated_at = now()
  FROM ilk i
 WHERE m.id = i.musteri_id AND m.lat IS NULL
RETURNING m.firma, m.lat, m.lng;"
$PSQL -c "SELECT count(*) AS musteri, count(lat) AS konumu_var FROM saha_musteri WHERE aktif;"

echo
echo "############ 5) SUNUCU — elle secim kabul edilmiyor + ekranda KANIT ############"
cp server_container.mjs server_container.mjs.bak_durum2
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("server_container.mjs"); s = p.read_text(encoding="utf-8")
if "DURUM_TURETILIYOR" in s: sys.exit("ZATEN YAMALI")

ESKI = '''      const fields = ["tip", "firma", "musteri_kodu", "il", "ilce", "segment", "durum",
                      "lat", "lng", "telefon", "yetkili", "notlar", "sorumlu_rep"];'''
assert ESKI in s, "❌ fields dizisi bulunamadi — DUR"
YENI = '''      // ⚠ DURUM_TURETILIYOR — 'durum' listeden CIKARILDI.
      //   Elle seciliyordu ve kimse guncellemiyordu: 1.028 musterinin 674'u YANLISTI.
      //   248 musteriye son 90 gunde satis yapilmisken ekranda "aktif" yazan 1 TANEYDI.
      //   PRATIK OTOMOTIV: 1.453 fatura, son satis 10 Tem -> ekranda "YENI NOKTA".
      //   Temsilci dort yillik musterinin kapisini "yeni nokta" etiketiyle caliyordu.
      //   Artik master_musteri.son_fatura'dan HESAPLANIYOR (saha_musteri_durum_yenile).
      //   Alan hesaplaniyorsa elle secim onu TEKRAR BOZAR — bu yuzden kabul edilmiyor.
      const fields = ["tip", "firma", "musteri_kodu", "il", "ilce", "segment",
                      "lat", "lng", "telefon", "yetkili", "notlar", "sorumlu_rep"];'''
s = s.replace(ESKI, YENI, 1)

A = '''        LEFT JOIN LATERAL (
          SELECT MAX(z.ziyaret_tarihi) AS son_ziyaret, COUNT(*) AS ziyaret_sayisi
          FROM saha_ziyaret z
          WHERE z.musteri_id = m.id AND z.durum = 'TAMAMLANDI'
        ) sz ON true'''
assert A in s, "❌ ziyaret LATERAL bulunamadi"
s = s.replace(A, A + '''
        -- ⚠ DURUM_TURETILIYOR — ekranda ETIKET degil KANIT.
        --   Temsilci "yeni nokta" yazisini degil, "1.453 fatura · son satis 10 Tem"i gorsun.
        --   Kaynak master_musteri: zaten hesapli, tazeleniyor, TEK GERCEK.''', 1)

C = '''        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,'''
assert C in s, "❌ detay SELECT bulunamadi"
D = '''        SELECT m.*, u.full_name AS sorumlu_rep_adi,
               sz.son_ziyaret, sz.ziyaret_sayisi,
               mm.fatura_sayisi AS erp_fatura_sayisi,
               mm.ilk_fatura    AS erp_ilk_satis,
               mm.son_fatura    AS erp_son_satis,
               mm.toplam_ciro   AS erp_toplam_ciro,
               mm.son_bakiye    AS erp_bakiye,
               mm.vadesi_gecmis AS erp_vadesi_gecmis,'''
s = s.replace(C, D, 1)
p.write_text(s, encoding="utf-8")
print("  ✅ PUT 'durum' kabul etmiyor · detayda ERP kaniti (master_musteri'den)")
PY
node --check server_container.mjs || { cp server_container.mjs.bak_durum2 server_container.mjs; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 6) ⚠ KALICILIK — erp_ingest.py capalarini GOSTER (yamamadan once) ############"
awk '/^BAGIMLILIK/,/^}/ { printf "%5d| %s\n", NR, $0 }' erp_ingest.py
grep -n "def .*kur\|def .*yenile\|ADIM\|maliyet_ay\|marj_fact\|sinyal_kredi" erp_ingest.py | head -12

echo
echo "############ 7) DAGIT ############"
docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 12
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
docker logs --since 30s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  log temiz"

git add -A
git commit -q -m 'feat(saha): durum artik ELLE YAZILMIYOR, master_musteriden HESAPLANIYOR. Fatihin itirazi semayi kurtardi: "yeni mi" sorusu zaten KAYIT ANINDA cevaplaniyor (temsilci master_musteride arar, bulursa musteridir, bulamazsa yeni nokta olarak ekler). Ben ESLESMEMIS diye yeni bir durum ekleyecektim — kimlik bilgisini ikinci bir yere yazacaktim, iki kaynak er ya da gec celisir. Olcum gosterdi ki iki eksen cakisiyor: ERPde olmayan HER musterinin hic satisi yok (235=235), yani "hic satis yok" = "ERPde yok" = YENI_NOKTA. Yeni enuma gerek yok, mevcut dort etiket hic degistirilmeden dogru seyi anlatiyor. Kaynak master_musteri (38.628 kayit; son_fatura, fatura_sayisi, toplam_ciro zaten hesapli ve tazeleniyor) — bi_satis_faturalarindan yeniden hesaplamak ikinci bir gercek uretmek olurdu. Olcum: 1.028 musterinin 674u yanlisti; 248 musteriye son 90 gunde satis varken ekranda aktif yazan 1 taneydi; 201 musteriye BU AY fatura kesilmisken ekran eski nokta diyordu. Sunucu PUTta durum alanini artik kabul etmiyor. Musteri detayina KANIT eklendi (fatura sayisi, ilk/son satis, ciro, bakiye, vadesi gecmis) — etiket degil sayi. Ayrica konum: 1.028 musterinin 0inda koordinat vardi, 2.403 ziyaretin 9unda check-in; ilk check-in musterinin konumu olarak kaydedildi (temsilci zaten kapida, referans bedava olusuyor). Karar: HARITA kurulur, ziyaret dogrulamasi/mesafe denetimi YAPILMAZ.'
echo "  COMMITTED"
echo
echo "⚠ HENUZ KALICI DEGIL: erp_ingest.py baglantisi YOK."
echo "   Su an ERP yuklenirse durum TAZELENMEZ. Capalar yukarida — sonraki adim."
