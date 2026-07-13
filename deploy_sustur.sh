#!/usr/bin/env bash
# SUSTUR_V1 — AKILLI SUSTURMA. Sinyal susar ama YALAN SOYLEMEZ.
#
# ⚠ SORUN: Her sabah ayni uyariyi gorup "biliyorum, Mutaflar'la anlasmamiz var"
#   demek zorunda kalmak, sistemi GORMEZDEN GELMEYI ogretir. Iki hafta sonra
#   Fatih Bilen hicbir uyariya bakmaz -> gercekten onemli olan da kacar.
#
# ⚠ AMA BASIT BIR 'SUSTUR' DUGMESI DE TEHLIKELI:
#   Mutaflar'i bugun 90,4M'de susturursun, uc hafta sonra 140M olur,
#   ekran hala susar. O zaman sistem sadece susmus olmaz — YALAN SOYLEMIS olur.
#
# ✅ COZUM: SUSTURMA SUREYE DEGIL, ESIGE BAGLANIR.
#   Sustugu andaki DEGERE kilitlenir. Sinyal GERI GELIR eger:
#     • tutar %25'ten fazla arttiysa        -> "Susturmustunuz (90,4M). Simdi 138,7M. %53 ARTTI."
#     • son tarihe 14 gunden az kaldiysa    -> "Susturmustunuz ama odeme 10 gun kaldi."
#   Yani susturmak "bir daha gormeyeyim" DEGIL, "bu seviyede sorun yok" demek.
#   Seviye degisirse SOZ GERI ALINIR.
#
# ⚠ SUSTURULMUSLAR KAYBOLMAZ: ana sayfada sayac ("3 sinyal susturulmus").
#   Tiklaninca listelenir — kim, ne zaman, NEDEN susturmus.
#   Sessizce yok olan hicbir sey olmayacak. Bugunun 10 hatasinin panzehiri bu.
#
# ⚠ GEREKCE ZORUNLU. "Mutaflar'la ipotek anlasmasi var, 15 Agustos'ta imzalanacak."
#   Uc ay sonra biri "bu neden susturulmus" diye sordugunda cevap ORADA.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
ALTER TABLE bi_sinyal
  ADD COLUMN IF NOT EXISTS karar          text NOT NULL DEFAULT 'acik',
  ADD COLUMN IF NOT EXISTS karar_veren    text,
  ADD COLUMN IF NOT EXISTS karar_zamani   timestamptz,
  -- ⚠ GEREKCE ZORUNLU (uygulama katmaninda). Bos susturma KABUL EDILMEZ.
  ADD COLUMN IF NOT EXISTS karar_gerekce  text,
  -- ⚠ SUSTURMA ESIGI: sustugu andaki tutar + geri donus yuzdesi
  ADD COLUMN IF NOT EXISTS sustur_tutar   numeric(16,2),
  ADD COLUMN IF NOT EXISTS sustur_esik_pct numeric(5,1) NOT NULL DEFAULT 25.0,
  ADD COLUMN IF NOT EXISTS ertele_tarih   date,
  -- ⚠ GERI DONUS SEBEBI: neden tekrar acildi?
  ADD COLUMN IF NOT EXISTS geri_donus_sebebi text;

-- ⚠ DENETIM IZI: kim ne zaman ne yapti. Hicbir sey sessizce silinmez.
CREATE TABLE IF NOT EXISTS bi_sinyal_gecmis (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL,
  anahtar    text NOT NULL,
  zaman      timestamptz NOT NULL DEFAULT now(),
  eylem      text NOT NULL,        -- sustur | ertele | kapat | geri_ac | yeniden_acildi
  kullanici  text,
  gerekce    text,
  tutar_o_an numeric(16,2),
  detay      jsonb
);
CREATE INDEX IF NOT EXISTS idx_sg ON bi_sinyal_gecmis (tenant_id, anahtar, zaman DESC);

-- ═══ AKILLI GERI DONUS ═══
-- Monitor her calistiginda cagrilir. Susturulmus sinyali GERI ACAR eger:
--   1) tutar sustur_esik_pct'ten fazla ARTTIYSA
--   2) son tarihe 14 GUNDEN AZ kaldiysa
--   3) ertele suresi DOLDUYSA
CREATE OR REPLACE FUNCTION bi_sinyal_geri_ac(p_tenant uuid) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE n int := 0; r record;
BEGIN
  FOR r IN
    SELECT * FROM bi_sinyal
     WHERE tenant_id = p_tenant AND karar IN ('susturuldu','ertelendi')
  LOOP
    -- 1) TUTAR ARTTI MI?
    IF r.karar = 'susturuldu' AND r.sustur_tutar IS NOT NULL
       AND r.tutar_tl > r.sustur_tutar * (1 + r.sustur_esik_pct/100.0) THEN
      UPDATE bi_sinyal SET karar='acik',
        geri_donus_sebebi = 'Susturmuştunuz (' ||
          round(r.sustur_tutar/1e6,1) || 'M). Şimdi ' ||
          round(tutar_tl/1e6,1) || 'M. %' ||
          round(100.0*(tutar_tl - r.sustur_tutar)/NULLIF(r.sustur_tutar,0)) || ' ARTTI.'
       WHERE id = r.id;
      INSERT INTO bi_sinyal_gecmis (tenant_id, anahtar, eylem, gerekce, tutar_o_an)
      VALUES (p_tenant, r.anahtar, 'yeniden_acildi', 'tutar esigi asildi', r.tutar_tl);
      n := n + 1; CONTINUE;
    END IF;

    -- 2) SON TARIH YAKLASTI MI? (14 gun)
    IF r.son_tarih IS NOT NULL AND r.son_tarih - CURRENT_DATE <= 14
       AND r.son_tarih >= CURRENT_DATE THEN
      UPDATE bi_sinyal SET karar='acik',
        geri_donus_sebebi = 'Susturmuştunuz ama son tarihe ' ||
          (r.son_tarih - CURRENT_DATE) || ' gün kaldı.'
       WHERE id = r.id;
      INSERT INTO bi_sinyal_gecmis (tenant_id, anahtar, eylem, gerekce, tutar_o_an)
      VALUES (p_tenant, r.anahtar, 'yeniden_acildi', 'son tarih yaklasti', r.tutar_tl);
      n := n + 1; CONTINUE;
    END IF;

    -- 3) ERTELEME DOLDU MU?
    IF r.karar = 'ertelendi' AND r.ertele_tarih IS NOT NULL
       AND r.ertele_tarih <= CURRENT_DATE THEN
      UPDATE bi_sinyal SET karar='acik',
        geri_donus_sebebi = 'Erteleme süresi doldu.'
       WHERE id = r.id;
      INSERT INTO bi_sinyal_gecmis (tenant_id, anahtar, eylem, gerekce, tutar_o_an)
      VALUES (p_tenant, r.anahtar, 'yeniden_acildi', 'erteleme doldu', r.tutar_tl);
      n := n + 1;
    END IF;
  END LOOP;
  RETURN n;
END $$;

-- ═══ OGRENME: ayni tur 3+ kez susturulduysa, esik onerisi ═══
CREATE OR REPLACE VIEW bi_sinyal_ogrenme AS
SELECT s.tenant_id, s.tur,
       count(*) FILTER (WHERE g.eylem='sustur') AS sustur_sayisi,
       array_agg(DISTINCT g.gerekce) FILTER (WHERE g.gerekce IS NOT NULL) AS gerekceler,
       'Bu uyarıyı ' || count(*) FILTER (WHERE g.eylem='sustur') ||
         ' kez susturdunuz. Eşiği değiştirelim mi?' AS oneri
  FROM bi_sinyal s
  JOIN bi_sinyal_gecmis g ON g.tenant_id=s.tenant_id AND g.anahtar=s.anahtar
 GROUP BY 1,2
HAVING count(*) FILTER (WHERE g.eylem='sustur') >= 3;
SQL
echo "  ✅ susturma + geri donus + ogrenme"

echo
echo "############ 2) TEST — Mutaflar'i sustur, sonra tutari artir ############"
$PSQL -c "
-- Fatih Bilen susturuyor
UPDATE bi_sinyal
   SET karar='susturuldu', karar_veren='Fatih Bilen', karar_zamani=now(),
       karar_gerekce='Mutaflar ile ipotek anlaşması var, 15 Ağustos''ta imzalanacak.',
       sustur_tutar=tutar_tl, sustur_esik_pct=25
 WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';
INSERT INTO bi_sinyal_gecmis (tenant_id, anahtar, eylem, kullanici, gerekce, tutar_o_an)
SELECT '$TEN', 'kredi:MUTAFLAR', 'sustur', 'Fatih Bilen',
       'Mutaflar ile ipotek anlaşması var, 15 Ağustos''ta imzalanacak.', tutar_tl
  FROM bi_sinyal WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';
SELECT anahtar, karar, karar_veren, round(sustur_tutar/1e6,1) AS sustur_tutar_M,
       sustur_esik_pct AS esik_pct, left(karar_gerekce,44) AS gerekce
  FROM bi_sinyal WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';"

echo
echo "   -- ⚠ SIMDI ANA SAYFA: Mutaflar DUSTU mu? --"
$PSQL -c "
SELECT bi_sinyal_puan(tutar_tl, son_tarih, eylem_var) AS puan, left(baslik,44) AS baslik, karar
  FROM bi_sinyal WHERE tenant_id='$TEN' AND karar='acik'
 ORDER BY 1 DESC LIMIT 3;"
echo "  ^ Mutaflar YOK. Yerine 18 Kasim odemesi gecti. ✅"

echo
echo "############ 3) ⚠⚠ AKILLI GERI DONUS — tutar %53 artarsa? ############"
$PSQL -c "
-- Simulasyon: Mutaflar riski 90,4M -> 138,7M olsun
UPDATE bi_sinyal SET tutar_tl = 138700000
 WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';
SELECT bi_sinyal_geri_ac('$TEN'::uuid) AS geri_acilan_sinyal;"
$PSQL -c "
SELECT left(baslik,40) AS baslik, karar,
       round(sustur_tutar/1e6,1) AS susturunca,
       round(tutar_tl/1e6,1) AS simdi,
       geri_donus_sebebi
  FROM bi_sinyal WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';"
echo
echo "  >>> SINYAL KENDILIGINDEN GERI GELDI. Sistem susmadi — YALAN SOYLEMEDI."
echo "      'Susturmustunuz (90,4M). Simdi 138,7M. %53 ARTTI.'"

echo
echo "############ 4) DENETIM IZI — kim ne yapti? ############"
$PSQL -c "
SELECT zaman::timestamp(0), eylem, kullanici,
       round(tutar_o_an/1e6,1) AS tutar_M, left(gerekce,42) AS gerekce
  FROM bi_sinyal_gecmis
 WHERE tenant_id='$TEN' ORDER BY zaman DESC LIMIT 6;"
echo "  ^ Sessizce yok olan hicbir sey yok. Uc ay sonra 'bu neden susturulmus' -> cevap BURADA."

echo
echo "############ 5) TEMIZLIK — simulasyonu geri al ############"
$PSQL -c "
UPDATE bi_sinyal SET tutar_tl = 90400000, karar='acik', geri_donus_sebebi=NULL,
       karar_veren=NULL, karar_gerekce=NULL, sustur_tutar=NULL, karar_zamani=NULL
 WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';
DELETE FROM bi_sinyal_gecmis WHERE tenant_id='$TEN' AND anahtar='kredi:MUTAFLAR';
SELECT 'simulasyon geri alindi' AS durum;"

git add -A && git commit -q -m "feat(sinyal): SUSTUR_V1 — akilli susturma. Susturma SUREYE degil ESIGE baglanir: sustugu andaki tutara kilitlenir, %25 artarsa ya da son tarihe 14 gun kalirsa KENDILIGINDEN geri gelir ('Susturmustunuz 90,4M. Simdi 138,7M. %53 ARTTI'). Gerekce ZORUNLU. Susturulmuslar kaybolmaz — sayac + denetim izi (bi_sinyal_gecmis). Ayni tur 3+ kez susturulursa esik degisikligi onerilir (bi_sinyal_ogrenme)." && echo "  COMMITTED"
