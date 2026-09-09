CREATE OR REPLACE FUNCTION bi_foto_borc(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  DELETE FROM bi_borc_foto_gun WHERE foto_gun = p_gun;
  WITH f AS (SELECT tenant_id::uuid tid, vade_tarihi,
                    COALESCE(satir_kdv_haric,0) h, COALESCE(satir_kdv_dahil,0) d
               FROM bi_tedarikci_faturalari
              WHERE COALESCE(odeme_durumu,'') = 'O'),
  x AS (SELECT f.*, g.bt, g.bd FROM f, LATERAL (VALUES
          ('TOPLAM','TOPLAM'),
          ('vade_ay',   COALESCE(to_char(f.vade_tarihi,'YYYY-MM'),'(vadesiz)')),
          ('vade_kova', CASE WHEN f.vade_tarihi IS NULL      THEN '(vadesiz)'
                             WHEN f.vade_tarihi <  p_gun     THEN 'gecikmis'
                             WHEN f.vade_tarihi <  p_gun+30  THEN '0-30g'
                             WHEN f.vade_tarihi <  p_gun+60  THEN '30-60g'
                             WHEN f.vade_tarihi <  p_gun+90  THEN '60-90g'
                             ELSE '90g+' END)) AS g(bt,bd))
  INSERT INTO bi_borc_foto_gun
    (tenant_id,foto_gun,boyut_tipi,boyut_deger,fatura_say,kdv_haric,kdv_dahil)
  SELECT tid,p_gun,bt,bd,count(*),sum(h),sum(d) FROM x GROUP BY tid,bt,bd;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;
