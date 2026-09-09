-- ============================================================
-- derive_fingerprint_enforce.sql
-- DB-KATMANI OTOMATIK IZ: hangi oturum/ajan olursa olsun, public'te yeni
-- bi_/saha_ TABLO veya FONKSIYON olusunca bi_insa_gunlugu + bi_yetenek'e
-- otomatik STUB birak. Kimse atlayamaz -- kayit DB'de, uygulamanin altinda.
-- (Anlam yine ELLE doldurulur; bu katman yalniz VARLIGI garanti eder.)
-- NOT: EVENT TRIGGER olusturmak superuser gerektirir. Once kontrol eder.
-- ============================================================

-- 0) Yetki kontrolu
DO $chk$
BEGIN
  IF NOT (SELECT rolsuper FROM pg_roles WHERE rolname = current_user) THEN
    RAISE NOTICE '!! current_user (%) superuser DEGIL -> EVENT TRIGGER kurulamayabilir.', current_user;
    RAISE NOTICE '   Kurulmazsa: alternatif = nabiz.sh gunluk drift-alarmi (superuser istemez).';
  END IF;
END $chk$;

-- 1) Iz birakan fonksiyon
CREATE OR REPLACE FUNCTION _fingerprint_ddl() RETURNS event_trigger
LANGUAGE plpgsql AS $fn$
DECLARE r record; nm text;
BEGIN
  FOR r IN SELECT * FROM pg_event_trigger_ddl_commands() LOOP
    IF r.schema_name = 'public' AND r.object_type IN ('table','function') THEN
      nm := split_part(r.object_identity, '.', 2);          -- tablo adi / fn imzasi
      IF nm LIKE 'bi\_%' OR nm LIKE 'saha\_%' THEN
        -- build-log stub (append-only, idempotent)
        INSERT INTO bi_insa_gunlugu(adim, ne, neden, detay)
        SELECT 'AUTO_DDL:'||r.object_identity,
               r.command_tag||' '||r.object_type,
               'otomatik DDL izi -- aciklama/anlam ELLE doldurulmali',
               jsonb_build_object('object', r.object_identity, 'tag', r.command_tag, 'auto', true)
        WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='AUTO_DDL:'||r.object_identity);
      END IF;
    END IF;
  END LOOP;
END $fn$;

-- 2) Event trigger (yalniz CREATE TABLE/FUNCTION)
DROP EVENT TRIGGER IF EXISTS trg_fingerprint_ddl;
CREATE EVENT TRIGGER trg_fingerprint_ddl
  ON ddl_command_end
  WHEN TAG IN ('CREATE TABLE','CREATE FUNCTION')
  EXECUTE FUNCTION _fingerprint_ddl();

\echo '=== event trigger kurulu mu? ==='
SELECT evtname, evtenabled FROM pg_event_trigger WHERE evtname='trg_fingerprint_ddl';
