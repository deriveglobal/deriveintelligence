#!/usr/bin/env bash
# OMURGA 58 — YASA KATMANI: bi_yasa (kanunlar defteri) + capraz_kontrol (runner) + 2 genel yasa.
# "Korelasyonu bir kez yaz, her yerde uygula." Yamayı yasaya çeviriyoruz.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_yasa — kanunlar defteri (veri olarak korelasyon kuralları)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_yasa (
  kod text PRIMARY KEY,
  ad text,
  tur text,                     -- net / sanity / decompose / tip / temporal
  kapsam text[],                -- hangi özneler: musteri, marka, tedarikci, stok
  aciklama text,                -- genel ilke (insan-okur)
  durum text DEFAULT 'taslak',  -- taslak / onayli / kapali
  kaynak text DEFAULT 'sistem', -- sistem / kullanici (öğrenilen)
  guven text DEFAULT 'taslak',
  created_at timestamptz DEFAULT now()
);
SQL
echo "  ✅ bi_yasa"

hr "2. YASA fonksiyonları (yasa_<kod>(tenant, tur, anahtar) → jsonb{fired,bulgu,veri})"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- YASA 1: NET POZİSYON — alacak, karşı borçla netleştirilmeden risk sayılmaz
CREATE OR REPLACE FUNCTION yasa_net_pozisyon(p_tenant uuid, p_tur text, p_anahtar text) RETURNS jsonb AS $$
DECLARE onlar numeric; biz numeric; net numeric; vg numeric;
BEGIN
  IF p_tur NOT IN ('musteri','tedarikci') THEN RETURN jsonb_build_object('fired',false); END IF;
  SELECT COALESCE(musteri_bakiye,0), COALESCE(CASE WHEN tedarikci_bakiye<0 THEN -tedarikci_bakiye ELSE 0 END,0)
    INTO onlar, biz FROM bi_cari_bakiye WHERE tenant_id=p_tenant AND (musteri_kodu=p_anahtar OR tedarikci_kodu=p_anahtar) LIMIT 1;
  onlar:=COALESCE(onlar,0); biz:=COALESCE(biz,0); net:=onlar-biz;
  SELECT COALESCE(vadesi_gecmis,0) INTO vg FROM bi_musteri_risk WHERE tenant_id=p_tenant AND muhatap_kodu=p_anahtar;
  vg:=COALESCE(vg,0);
  IF biz > 1000000 AND vg > 1000000 THEN
    RETURN jsonb_build_object('fired',true,'yasa','net_pozisyon',
      'bulgu','Vadesi geçmiş '||replace(round(vg/1e6,1)::text,'.',',')||' milyon TL görünüyor, ANCAK bu firmaya biz de '||replace(round(biz/1e6,1)::text,'.',',')||' milyon TL borçluyuz; net pozisyon yaklaşık '||replace(round(net/1e6,1)::text,'.',',')||' milyon TL — tek taraflı okuma yanıltıcı, önce mutabakat/takas',
      'veri',jsonb_build_object('onlar_bize_m',round(onlar/1e6,1),'biz_onlara_m',round(biz/1e6,1),'net_m',round(net/1e6,1)));
  END IF;
  RETURN jsonb_build_object('fired',false);
END; $$ LANGUAGE plpgsql;

-- YASA 2: VERİ MAKULİYETİ — bir rakam referansa göre imkânsızsa iddia edilmez, işaretlenir
CREATE OR REPLACE FUNCTION yasa_veri_makul(p_tenant uuid, p_tur text, p_anahtar text) RETURNS jsonb AS $$
DECLARE vg numeric; c21 numeric; cs numeric; yillik numeric; m0 date:=date_trunc('month',CURRENT_DATE)::date;
BEGIN
  IF p_tur <> 'musteri' THEN RETURN jsonb_build_object('fired',false); END IF;
  SELECT COALESCE(vadesi_gecmis,0), COALESCE(ciro_2021,0) INTO vg, c21 FROM bi_musteri_risk WHERE tenant_id=p_tenant AND muhatap_kodu=p_anahtar;
  SELECT COALESCE(sum(satir_tutar),0)*2 INTO cs FROM bi_satis_faturalari
    WHERE tenant_id::text=p_tenant::text AND musteri_kodu=p_anahtar AND fatura_tarihi>=m0-interval '6 month' AND fatura_tarihi<m0;
  yillik := GREATEST(COALESCE(cs,0), COALESCE(c21,0));
  IF COALESCE(vg,0) > 1000000 AND yillik > 0 AND vg > yillik*1.5 THEN
    RETURN jsonb_build_object('fired',true,'yasa','veri_makul',
      'bulgu','Vadesi geçmiş bakiye ('||replace(round(vg/1e6,1)::text,'.',',')||'M) bu müşterinin yıllık cirosundan (~'||replace(round(yillik/1e6,1)::text,'.',',')||'M) büyük — rakam veri hatası olabilir, muhasebeyle teyit edilmeli',
      'veri',jsonb_build_object('vgecmis_m',round(vg/1e6,1),'yillik_m',round(yillik/1e6,1)));
  END IF;
  RETURN jsonb_build_object('fired',false);
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ yasa_net_pozisyon + yasa_veri_makul"

hr "3. capraz_kontrol — RUNNER: her uygulanabilir yasayı özneye uygular (tireless breadth)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION capraz_kontrol(p_tenant uuid, p_tur text, p_anahtar text) RETURNS jsonb AS $$
DECLARE r record; res jsonb; out jsonb := '[]'::jsonb;
BEGIN
  FOR r IN SELECT kod FROM bi_yasa WHERE durum IN ('onayli','taslak') AND p_tur = ANY(kapsam) ORDER BY kod LOOP
    BEGIN
      EXECUTE format('SELECT %I($1,$2,$3)', 'yasa_'||r.kod) INTO res USING p_tenant, p_tur, p_anahtar;
      IF res IS NOT NULL AND (res->>'fired')::boolean THEN out := out || jsonb_build_array(res); END IF;
    EXCEPTION WHEN OTHERS THEN
      -- yasa hatası tüm zinciri kırmaz AMA sessizce yutulmaz — görünür işaret
      out := out || jsonb_build_array(jsonb_build_object('fired',true,'yasa',r.kod,'hata',true,'bulgu','⚠ yasa çalışmadı: '||SQLERRM));
    END;
  END LOOP;
  RETURN out;
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ capraz_kontrol (runner)"

hr "4. YASALARI kaydet (Fatih öğretti → onaylı)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
INSERT INTO bi_yasa(kod,ad,tur,kapsam,aciklama,durum,kaynak,guven) VALUES
('net_pozisyon','Net pozisyon','net',ARRAY['musteri','tedarikci'],
  'Herhangi bir risk/bakiye rakamı, karşı taraftaki borç/alacakla NETLEŞTİRİLMEDEN risk sayılmaz. Karşılıklı ticaret varsa gerçek risk nettir.','onayli','kullanici','onayli'),
('veri_makul','Veri makuliyeti','sanity',ARRAY['musteri'],
  'Bir rakam bir referansa göre imkânsız görünüyorsa (ör. vadesi geçmiş > yıllık ciro) körü körüne iddia edilmez, ŞÜPHE olarak işaretlenir ve teyit istenir.','onayli','sistem','onayli')
ON CONFLICT (kod) DO UPDATE SET ad=EXCLUDED.ad, tur=EXCLUDED.tur, kapsam=EXCLUDED.kapsam, aciklama=EXCLUDED.aciklama, durum=EXCLUDED.durum, kaynak=EXCLUDED.kaynak, guven=EXCLUDED.guven;
SQL
$PSQL -c "SELECT kod, tur, kapsam, durum, kaynak FROM bi_yasa ORDER BY kod;" 2>&1 | sed 's/^/  /'

hr "5. KANIT — capraz_kontrol MUTAFLAR'a hangi yasaları uyguladı (net YASADAN gelmeli, yamadan değil)"
$PSQL -c "SELECT jsonb_pretty(capraz_kontrol('$T'::uuid,'musteri','M4115532'));" 2>&1 | sed 's/^/  /'

hr "6. KARŞILAŞTIRMA — net-even OLMAYAN bir müşteride ne diyor (ROTA — bize borç var mı)"
$PSQL -c "SELECT muhatap_kodu FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND muhatap_adi ILIKE '%ROTA LAST%' LIMIT 1;" 2>&1 | sed 's/^/  /'
K=$(docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tA -c "SELECT muhatap_kodu FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND muhatap_adi ILIKE '%ROTA LAST%' LIMIT 1;")
$PSQL -c "SELECT jsonb_pretty(capraz_kontrol('$T'::uuid,'musteri','$K'));" 2>&1 | sed 's/^/  /'

hr "BITTI — yasa=data, runner=uygulama. Yeni korelasyon = 1 yasa satırı (+fonksiyon), her yerde çalışır."
