#!/usr/bin/env bash
# DENETIM_111B2 — para_birimi KALICI kapi: yazim-yolundan bagimsiz trigger.
#   ⚠ INSERT noktasi dinamik/parametreli — tek satiri kovalamak yerine DB kapisi.
#   BEFORE INSERT/UPDATE: TL/₺/TRL -> TRY. Hangi yol olursa olsun normalize eder.
#   Deploy gerektirmez (DB objesi).
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"

echo "############ 1) TRIGGER FONKSIYONU + TRIGGER ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION norm_para_birimi() RETURNS trigger AS $$
BEGIN
  -- ⚠ Tek gercek tek ad: Turk lirasi = TRY. TL/₺/TRL hepsi TRY'ye iner.
  IF upper(trim(coalesce(NEW.para_birimi,''))) IN ('TL','₺','TL.','TRL','TRY.') THEN
    NEW.para_birimi := 'TRY';
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_norm_para_birimi ON bi_fiyat_listesi_kalemler;
CREATE TRIGGER trg_norm_para_birimi
  BEFORE INSERT OR UPDATE ON bi_fiyat_listesi_kalemler
  FOR EACH ROW EXECUTE FUNCTION norm_para_birimi();
SQL
echo "  ✅ trigger kuruldu"

echo
echo "############ 2) ⚠ KAPI TESTI — TL yazmayi denersek TRY'ye mi doner? ############"
# Gecici bir satirda dene, sonra geri al. Gercek veriye dokunmaz.
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
BEGIN;
-- var olan bir upload_id + tenant al
DO $$
DECLARE _up uuid; _tn uuid;
BEGIN
  SELECT id, tenant_id INTO _up, _tn FROM bi_fiyat_listesi_uploads LIMIT 1;
  IF _up IS NULL THEN RAISE NOTICE 'upload yok — test atlandi'; RETURN; END IF;
  INSERT INTO bi_fiyat_listesi_kalemler (tenant_id, upload_id, para_birimi, ebat)
  VALUES (_tn, _up, 'TL', '__KAPI_TESTI__');
END $$;
SELECT para_birimi AS test_sonucu FROM bi_fiyat_listesi_kalemler WHERE ebat='__KAPI_TESTI__';
ROLLBACK;
SQL
echo "  ⚠ test_sonucu 'TRY' ise kapi calisiyor. (satir ROLLBACK ile silindi)"

echo
echo "############ 3) SON DURUM ############"
$PSQL -c "SELECT para_birimi, count(*) FROM bi_fiyat_listesi_kalemler GROUP BY 1 ORDER BY 2 DESC;"

echo
echo "############ 4) ⚠ bi_satis_faturalari da bolunmus mu? (ayri tablo, kontrol) ############"
$PSQL -c "SELECT para_birimi, count(*) FROM bi_satis_faturalari GROUP BY 1 ORDER BY 2 DESC LIMIT 10;" 2>&1 | sed 's/^/  /'
echo "  ⚠ Orada da TL/TRY bolunmesi varsa ayri trigger/normalize gerekir — rapor ediyorum, dokunmuyorum."

echo
echo "############ SONUC ############"
echo "  ✅ para_birimi kalici kapida: yazim yolu ne olursa olsun TL->TRY."
echo "  ⚠ bi_satis_faturalari ciktisina bak — orada da bolunme varsa sıradaki is."
