CREATE TABLE IF NOT EXISTS bi_foto_mutabakat (
  tenant_id uuid NOT NULL, foto_gun date NOT NULL, kapi text NOT NULL,
  olculen numeric, referans numeric, fark_pct numeric, gecti boolean,
  not_metin text, yazildi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, foto_gun, kapi));

CREATE OR REPLACE FUNCTION bi_foto_borc(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  DELETE FROM bi_borc_foto_gun WHERE foto_gun = p_gun;
  -- cari yil filtresi: durum alani yalnizca cari yil icin guncelleniyor (mutabakat kanitli)
  WITH f AS (SELECT tenant_id::uuid tid, vade_tarihi,
                    COALESCE(satir_kdv_haric,0) h, COALESCE(satir_kdv_dahil,0) d
               FROM bi_tedarikci_faturalari
              WHERE COALESCE(odeme_durumu,'') = 'O'
                AND fatura_tarihi >= date_trunc('year', p_gun)),
  x AS (SELECT f.*, g.bt, g.bd FROM f, LATERAL (VALUES
          ('TOPLAM','TOPLAM'),
          ('vade_ay',   COALESCE(to_char(f.vade_tarihi,'YYYY-MM'),'(vadesiz)')),
          ('vade_kova', CASE WHEN f.vade_tarihi IS NULL     THEN '(vadesiz)'
                             WHEN f.vade_tarihi <  p_gun    THEN 'gecikmis'
                             WHEN f.vade_tarihi <  p_gun+30 THEN '0-30g'
                             WHEN f.vade_tarihi <  p_gun+60 THEN '30-60g'
                             WHEN f.vade_tarihi <  p_gun+90 THEN '60-90g'
                             ELSE '90g+' END)) AS g(bt,bd))
  INSERT INTO bi_borc_foto_gun
    (tenant_id,foto_gun,boyut_tipi,boyut_deger,fatura_say,kdv_haric,kdv_dahil)
  SELECT tid,p_gun,bt,bd,count(*),sum(h),sum(d) FROM x GROUP BY tid,bt,bd;
  GET DIAGNOSTICS v = ROW_COUNT;

  DELETE FROM bi_foto_mutabakat WHERE foto_gun=p_gun AND kapi='acik_borc_vs_bilanco_ap';
  INSERT INTO bi_foto_mutabakat (tenant_id,foto_gun,kapi,olculen,referans,fark_pct,gecti,not_metin)
  SELECT b.tenant_id, p_gun, 'acik_borc_vs_bilanco_ap', b.kdv_dahil, s.ap_borc,
         round(100*(b.kdv_dahil-s.ap_borc)/NULLIF(s.ap_borc,0),2),
         abs(100*(b.kdv_dahil-s.ap_borc)/NULLIF(s.ap_borc,0)) <= 5,
         'odeme_durumu=O + cari yil; kapi kapaliysa nakit cikis bacagi banda duser'
    FROM bi_borc_foto_gun b
    JOIN v_finans_ticari_sermaye s ON s.tenant_id::text=b.tenant_id::text
   WHERE b.foto_gun=p_gun AND b.boyut_tipi='TOPLAM';
  RETURN v;
END $fn$;
