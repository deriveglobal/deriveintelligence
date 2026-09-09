#!/usr/bin/env bash
# OMURGA 47 — ÖĞRENME halkası (DB): genel ogren_sor() + cevap-oku yardımcı + test. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ogren_sor() — genel soru üretici (honest-null'da çağrılır) + ogren_bilinen() (hatırla)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- Sistem bir şeyi açıklayamayınca kullanıcıya sorar (idempotent: aynı anahtar tekrar sormaz)
CREATE OR REPLACE FUNCTION ogren_sor(p_tenant uuid, p_kullanici text, p_anahtar text, p_soru text, p_kanit text, p_secenekler jsonb)
RETURNS uuid AS $$
DECLARE v_id uuid; v_cevap text;
BEGIN
  -- zaten cevaplanmışsa tekrar sorma (hatırla)
  SELECT id, cevap INTO v_id, v_cevap FROM bi_sistem_sorusu WHERE tenant_id=p_tenant AND anahtar=p_anahtar;
  IF v_id IS NOT NULL THEN RETURN v_id; END IF;
  INSERT INTO bi_sistem_sorusu (tenant_id, kullanici, anahtar, soru, kanit, secenekler, durum)
  VALUES (p_tenant, p_kullanici, p_anahtar, p_soru, p_kanit, p_secenekler, 'acik')
  ON CONFLICT (tenant_id, anahtar) DO NOTHING RETURNING id INTO v_id;
  IF v_id IS NULL THEN SELECT id INTO v_id FROM bi_sistem_sorusu WHERE tenant_id=p_tenant AND anahtar=p_anahtar; END IF;
  RETURN v_id;
END; $$ LANGUAGE plpgsql;

-- Bir desen için öğrenilmiş (cevaplanmış) açıklama var mı — sebep-araştırıcı önce buna bakar
CREATE OR REPLACE FUNCTION ogren_bilinen(p_tenant uuid, p_anahtar text)
RETURNS text AS $$
  SELECT cevap FROM bi_sistem_sorusu WHERE tenant_id=p_tenant AND anahtar=p_anahtar AND durum='cevaplandi' AND cevap IS NOT NULL LIMIT 1;
$$ LANGUAGE sql STABLE;
SQL
echo "  ✅ ogren_sor + ogren_bilinen"

hr "2. TEST — bir honest-null sorusu üret (CONTINENTAL örnek)"
$PSQL -c "SELECT ogren_sor('$T'::uuid,'Fatih Bilen','marj-ek-baglam:CONTINENTAL',
  'CONTINENTAL marjı %14→%2 düştü; köprü maliyet+mix diyor ama ek bir sebep biliyor musun? (fiyat baskısı, tedarikçi, kampanya)',
  'köprü: maliyet -3,3M · mix -3,0M · fiyat +2,4M (atomdan)',
  '[\"Rakip fiyat baskısı zorladı\",\"Tedarikçi maliyeti fırladı\",\"Bilinçli düşük-marj hacim büyüttük\",\"Başka (yazacağım)\"]'::jsonb) AS soru_id;" 2>&1 | sed 's/^/  /'

hr "3. AÇIK SORULAR (endpoint bunu döndürecek)"
$PSQL -c "SELECT anahtar, left(soru,70) soru, secenekler, durum FROM bi_sistem_sorusu WHERE tenant_id='$T'::uuid AND durum='acik';" 2>&1 | sed 's/^/  /'

hr "4. HATIRLA testi — cevaplanmadıkça bilinen yok"
$PSQL -c "SELECT COALESCE(ogren_bilinen('$T'::uuid,'marj-ek-baglam:CONTINENTAL'),'(henüz cevap yok)') AS bilinen;" 2>&1 | sed 's/^/  /'

hr "BITTI — sor + hatırla DB'de. Sonra endpoint (gör/cevapla) + araştırıcı honest-null hook."
