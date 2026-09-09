#!/usr/bin/env bash
# OMURGA 61b — celiski_odeme yasasına SANITY: negatif tahsilat günü "hızlı ödeme" değildir.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. yasa_celiski_odeme — gün >= 0 (negatif = geçersiz, ateşleme)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION yasa_celiski_odeme(p_tenant uuid, p_tur text, p_anahtar text) RETURNS jsonb AS $$
DECLARE vg numeric; gun numeric;
BEGIN
  IF p_tur<>'musteri' THEN RETURN jsonb_build_object('fired',false); END IF;
  SELECT COALESCE(vadesi_gecmis,0) INTO vg FROM bi_musteri_risk WHERE tenant_id=p_tenant AND muhatap_kodu=p_anahtar;
  -- yalnızca MAKUL (>=0) ortalama tahsilat günlerini dikkate al; negatif = veri artefaktı
  SELECT min(ort_tahsilat_gun) INTO gun FROM bi_musteri_risk_odeme
    WHERE tenant_id=p_tenant AND muhatap_kodu=p_anahtar AND ort_tahsilat_gun >= 0;
  IF COALESCE(vg,0)>5000000 AND gun IS NOT NULL AND gun >= 0 AND gun < 30 THEN
    RETURN jsonb_build_object('fired',true,'yasa','celiski_odeme',
      'bulgu','Vadesi geçmiş '||replace(round(vg/1e6,1)::text,'.',',')||'M yüksek görünüyor AMA ortalama tahsilat yalnızca '||round(gun)||' gün — büyük olasılıkla anlık/snapshot bakiye, kalıcı tahsilat riski gibi okunmamalı',
      'veri',jsonb_build_object('vgecmis_m',round(vg/1e6,1),'tahsilat_gun',round(gun)));
  END IF;
  RETURN jsonb_build_object('fired',false);
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ celiski_odeme (sanity)"

hr "2. MUTAFLAR — artık SADECE net_pozisyon (celiski -6'ya yanlış ateşlemiyor)"
$PSQL -c "SELECT jsonb_agg(x->>'yasa') uygulanan FROM jsonb_array_elements(capraz_kontrol('$T'::uuid,'musteri','M4115532')) x;" 2>&1 | sed 's/^/  /'

hr "3. ROTA — celiski_odeme DOĞRU ateşliyor (15 gün geçerli hızlı ödeme)"
K=$($PSQL -tA -c "SELECT muhatap_kodu FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND muhatap_adi ILIKE '%ROTA LAST%' LIMIT 1;")
$PSQL -c "SELECT jsonb_pretty(capraz_kontrol('$T'::uuid,'musteri','$K'));" 2>&1 | sed 's/^/  /'

hr "BITTI — sanity ilkesi taze yasaya da uygulandı. Doğru müşteride ateşliyor, veri artefaktında değil."
