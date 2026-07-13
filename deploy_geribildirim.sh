#!/usr/bin/env bash
# GERIBILDIRIM_V1 — CANLI UYGULAMA. Her sayi bir konusma baslangici.
#
# ⚠ SU ANKI MANTIK TEK YONLU: sistem gosterir, kullanici bakar.
#   Fatih Bilen bir sayiya bakip "bu yanlis" ya da "beni ilgilendirmiyor"
#   dediginde, o dusunce HICBIR YERE GITMIYOR. Ertesi gun ayni sayi ayni yerde.
#
# ✅ HER RAKAM, HER KART, HER SATIR KONUSULABILIR OLACAK.
#   Dort tur geri bildirim, dort farkli yere gider:
#
#   'yanlis'   -> VERI SAGLIGI odasina duser. Bugun 10 hatayi ben buldum;
#                 yarin Fatih Bilen bulacak ve sistem DUYACAK.
#   'onemli'   -> puanlama AGIRLIGINI degistirir (yukari)
#   'onemsiz'  -> puanlama agirligini degistirir (asagi)
#   'sabitle'  -> puani ne olursa olsun ana sayfada KALIR
#   'yorum'    -> ajan okur. "Mutaflar ipotek Agustos'ta" -> Agustos'ta HATIRLATILIR
#
# ⚠ SISTEM DE GERI KONUSUR (bi_sistem_sorusu):
#   "Sevk gecikmelerini 3 kez onemsiz isaretlediniz. Turu kapatalim mi?"
#   "Mutaflar'i susturdunuz ama kredi limiti hala 1M. Gercek limit nedir?"
#   Son soru KRITIK: sistem sadece ogrenmiyor, VERIYI DUZELTMEYE calisiyor.
#
# ⚠ OGRENILEN PROFIL GORUNUR OLACAK. "Sistem sizin hakkinizda ne ogrendi?"
#   Yanlissa duzeltilebilmeli. KARA KUTU OLMAYACAK.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
-- ═══ HER SEYE BAGLANABILEN GERI BILDIRIM ═══
CREATE TABLE IF NOT EXISTS bi_geri_bildirim (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  zaman      timestamptz NOT NULL DEFAULT now(),
  kullanici  text NOT NULL,
  -- ⚠ HEDEF: neye dair? 'sinyal:kredi:MUTAFLAR' | 'metrik:nakit_dongusu'
  --          'oda:sezon' | 'satir:bi_on_siparis:<id>'
  hedef      text NOT NULL,
  hedef_tur  text NOT NULL,       -- sinyal | metrik | oda | satir | ekran
  tur        text NOT NULL,       -- yanlis | onemli | onemsiz | sabitle | yorum | soru
  metin      text,
  -- ⚠ BAGLAM: o an ekranda ne vardi? Sayi neydi? Uc ay sonra anlamli olsun.
  baglam     jsonb,
  islendi    boolean NOT NULL DEFAULT false,
  sonuc      text
);
CREATE INDEX IF NOT EXISTS idx_gb ON bi_geri_bildirim (tenant_id, kullanici, zaman DESC);
CREATE INDEX IF NOT EXISTS idx_gb_islenmemis ON bi_geri_bildirim (tenant_id) WHERE NOT islendi;

-- ═══ OGRENILEN PROFIL — puanlamayi KISISELLESTIRIR ═══
CREATE TABLE IF NOT EXISTS bi_kullanici_profil (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL,
  kullanici  text NOT NULL,
  -- ⚠ AGIRLIK: sinyal turune gore carpan. 1,0 = notr. 0,3 = ilgilenmiyor. 2,0 = cok onemli.
  sinyal_turu text NOT NULL,
  agirlik    numeric(4,2) NOT NULL DEFAULT 1.00,
  -- ⚠ NEDEN bu agirlik? Kara kutu olmayacak.
  gerekce    text,
  kanit_sayisi int NOT NULL DEFAULT 0,
  guncelleme timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, kullanici, sinyal_turu)
);

-- ═══ SISTEMIN GERI SORDUGU SORULAR ═══
CREATE TABLE IF NOT EXISTS bi_sistem_sorusu (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id  uuid NOT NULL,
  olusma     timestamptz NOT NULL DEFAULT now(),
  kullanici  text,
  anahtar    text NOT NULL,
  soru       text NOT NULL,
  -- ⚠ NEDEN soruyorum? Kanit gorunsun.
  kanit      text,
  secenekler jsonb,
  cevap      text,
  cevap_zamani timestamptz,
  durum      text NOT NULL DEFAULT 'acik',
  UNIQUE (tenant_id, anahtar)
);

-- ═══ KISISELLESTIRILMIS PUAN ═══
-- ⚠ Puanlama artik EVRENSEL degil, KULLANICIYA GORE.
--   Ama gorunur: ekranda "sizin agirliginiz: 0,4 (3 kez onemsiz isaretlediniz)" yazacak.
CREATE OR REPLACE FUNCTION bi_sinyal_puan_kisisel(
  p_tenant uuid, p_kullanici text, p_tur text,
  p_tutar numeric, p_son_tarih date, p_eylem boolean
) RETURNS numeric LANGUAGE sql STABLE AS $$
  SELECT ROUND(
    bi_sinyal_puan(p_tutar, p_son_tarih, p_eylem)
    * COALESCE((SELECT agirlik FROM bi_kullanici_profil
                 WHERE tenant_id=p_tenant AND kullanici=p_kullanici
                   AND sinyal_turu=p_tur), 1.00)
  , 1)
$$;

-- ═══ OGRENME MOTORU — geri bildirimlerden agirlik turet ═══
CREATE OR REPLACE FUNCTION bi_profil_ogren(p_tenant uuid, p_kullanici text) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE n int := 0; r record;
BEGIN
  FOR r IN
    SELECT s.tur,
           count(*) FILTER (WHERE g.tur='onemli')  AS onemli,
           count(*) FILTER (WHERE g.tur='onemsiz') AS onemsiz,
           count(*) FILTER (WHERE g.tur='sabitle') AS sabitle
      FROM bi_geri_bildirim g
      JOIN bi_sinyal s ON s.tenant_id=g.tenant_id
                      AND ('sinyal:'||s.anahtar) = g.hedef
     WHERE g.tenant_id=p_tenant AND g.kullanici=p_kullanici
     GROUP BY s.tur
  LOOP
    -- ⚠ AGIRLIK: her 'onemli' +0,25 · her 'onemsiz' -0,25 · sabitle +0,5
    --   Taban 1,0. Alt sinir 0,2 (hic gostermemek DEGIL — sadece asagi cek).
    --   ⚠ SIFIR YAPMIYORUZ: kullanici onemsiz dese bile 90M'lik bir risk
    --     tamamen kaybolmamali. Sistem korletilemez.
    INSERT INTO bi_kullanici_profil (tenant_id, kullanici, sinyal_turu, agirlik, gerekce, kanit_sayisi)
    VALUES (p_tenant, p_kullanici, r.tur,
            GREATEST(0.20, LEAST(2.50,
              1.00 + 0.25*r.onemli - 0.25*r.onemsiz + 0.50*r.sabitle)),
            r.onemli || ' kez önemli · ' || r.onemsiz || ' kez önemsiz · ' ||
              r.sabitle || ' kez sabitle',
            r.onemli + r.onemsiz + r.sabitle)
    ON CONFLICT (tenant_id, kullanici, sinyal_turu) DO UPDATE SET
      agirlik = EXCLUDED.agirlik, gerekce = EXCLUDED.gerekce,
      kanit_sayisi = EXCLUDED.kanit_sayisi, guncelleme = now();
    n := n + 1;
  END LOOP;
  RETURN n;
END $$;

-- ═══ SISTEM SORU URETIR ═══
CREATE OR REPLACE FUNCTION bi_soru_uret(p_tenant uuid, p_kullanici text) RETURNS int
LANGUAGE plpgsql AS $$
DECLARE n int := 0;
BEGIN
  -- S1: Ayni tur 3+ kez onemsiz -> "kapatalim mi?"
  INSERT INTO bi_sistem_sorusu (tenant_id, kullanici, anahtar, soru, kanit, secenekler)
  SELECT p_tenant, p_kullanici, 'onemsiz:'||p.sinyal_turu,
         '"' || p.sinyal_turu || '" uyarılarını sürekli önemsiz işaretliyorsunuz. Ne yapalım?',
         p.gerekce || ' → ağırlık şu an ' || p.agirlik,
         '["Eşiği yükselt", "Bu türü tamamen kapat", "Böyle kalsın"]'::jsonb
    FROM bi_kullanici_profil p
   WHERE p.tenant_id=p_tenant AND p.kullanici=p_kullanici
     AND p.agirlik <= 0.5 AND p.kanit_sayisi >= 3
  ON CONFLICT (tenant_id, anahtar) DO NOTHING;
  GET DIAGNOSTICS n = ROW_COUNT;

  -- ⚠ S2: SUSTURDU AMA VERI HALA YANLIS -> sistem VERIYI DUZELTMEYE calisiyor
  INSERT INTO bi_sistem_sorusu (tenant_id, kullanici, anahtar, soru, kanit, secenekler)
  SELECT p_tenant, p_kullanici, 'veri:'||s.anahtar,
         replace(split_part(s.anahtar,':',2),'_',' ') ||
           ' uyarısını susturdunuz ama kredi limiti hâlâ ' ||
           round((s.detay->>'limit')::numeric/1e6,1) || 'M görünüyor. Gerçek limit nedir?',
         'Sistemdeki limit yanlışsa, bu uyarı her sezon tekrar çıkacak.',
         '["Limiti güncelleyeceğim", "Teminat var, limit önemsiz", "Limit doğru"]'::jsonb
    FROM bi_sinyal s
   WHERE s.tenant_id=p_tenant AND s.karar='susturuldu' AND s.tur='kredi_asimi'
     AND (s.detay->>'limit')::numeric < (s.detay->>'risk')::numeric / 10
  ON CONFLICT (tenant_id, anahtar) DO NOTHING;

  RETURN n;
END $$;
SQL
echo "  ✅ geri bildirim + profil + ogrenme + sistem sorulari"

echo
echo "############ 2) TEST — Fatih Bilen 3 kez 'sevk gecikmesi onemsiz' desin ############"
$PSQL -c "
INSERT INTO bi_geri_bildirim (tenant_id, kullanici, hedef, hedef_tur, tur, metin, baglam)
SELECT '$TEN', 'Fatih Bilen', 'sinyal:'||anahtar, 'sinyal', 'onemsiz',
       'Sevk zaten Ağustos-Eylül''de gelir, her yıl böyle.',
       jsonb_build_object('tutar', tutar_tl, 'puan', bi_sinyal_puan(tutar_tl,son_tarih,eylem_var))
  FROM bi_sinyal WHERE tenant_id='$TEN' AND tur='sevk_gecikme' AND durum='acik' LIMIT 3;
SELECT bi_profil_ogren('$TEN'::uuid, 'Fatih Bilen') AS ogrenilen_tur;"

echo
echo "   -- ⚠ OGRENILEN PROFIL (gorunur, kara kutu degil) --"
$PSQL -c "
SELECT sinyal_turu, agirlik, gerekce, kanit_sayisi
  FROM bi_kullanici_profil WHERE tenant_id='$TEN' AND kullanici='Fatih Bilen';"

echo
echo "############ 3) ⚠⚠ KISISELLESTIRILMIS SIRALAMA — ne degisti? ############"
$PSQL -c "
SELECT left(baslik,42) AS baslik,
       bi_sinyal_puan(tutar_tl, son_tarih, eylem_var) AS EVRENSEL,
       bi_sinyal_puan_kisisel('$TEN'::uuid,'Fatih Bilen',tur,tutar_tl,son_tarih,eylem_var) AS FATIH_BILEN,
       COALESCE((SELECT agirlik FROM bi_kullanici_profil p
                  WHERE p.tenant_id='$TEN' AND p.kullanici='Fatih Bilen'
                    AND p.sinyal_turu=s.tur),1.0) AS agirlik
  FROM bi_sinyal s WHERE tenant_id='$TEN' AND karar='acik'
 ORDER BY 3 DESC LIMIT 8;"
echo "  ^ Sevk gecikmeleri ASAGI indi (agirlik 0,25). Kredi/odeme YERINDE."
echo "     ⚠ SIFIRLANMADI — 0,20 alt sinir var. Kullanici 'onemsiz' dese bile"
echo "        90M'lik bir risk tamamen kaybolmamali. SISTEM KORLETILEMEZ."

echo
echo "############ 4) ⚠ SISTEM GERI SORUYOR ############"
$PSQL -c "SELECT bi_soru_uret('$TEN'::uuid, 'Fatih Bilen') AS uretilen_soru;"
$PSQL -c "
SELECT left(soru, 62) AS soru, left(kanit, 40) AS kanit, secenekler
  FROM bi_sistem_sorusu WHERE tenant_id='$TEN' AND durum='acik';"
echo "  ^ Sistem sadece OGRENMIYOR — VERIYI DUZELTMEYE calisiyor."

echo
echo "############ 5) TEMIZLIK ############"
$PSQL -c "
DELETE FROM bi_geri_bildirim WHERE tenant_id='$TEN';
DELETE FROM bi_kullanici_profil WHERE tenant_id='$TEN';
DELETE FROM bi_sistem_sorusu WHERE tenant_id='$TEN';
SELECT 'test verisi temizlendi' AS durum;"

git add -A && git commit -q -m "feat(canli): GERIBILDIRIM_V1 — her sayi konusulabilir. bi_geri_bildirim (yanlis/onemli/onemsiz/sabitle/yorum, baglamiyla) + bi_kullanici_profil (ogrenilen agirliklar, GORUNUR — kara kutu degil) + bi_sinyal_puan_kisisel (puanlama artik kullaniciya gore) + bi_sistem_sorusu (sistem GERI SORAR: 'sevk gecikmelerini 3 kez onemsiz dediniz, turu kapatalim mi?' ve 'Mutaflar'i susturdunuz ama limit hala 1M, gercek limit nedir?'). ⚠ Agirlik alt siniri 0,20 — kullanici 'onemsiz' dese bile 90M'lik risk kaybolmaz. SISTEM KORLETILEMEZ." && echo "  COMMITTED"
