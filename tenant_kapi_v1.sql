-- Cekirdek fact tablolarinin birlesimi; platform_tenants semasina bagimli degil.
CREATE OR REPLACE FUNCTION bi_tenant_listesi()
RETURNS TABLE(tid uuid) LANGUAGE sql STABLE AS $fn$
  SELECT DISTINCT tenant_id::uuid FROM bi_satis_faturalari
  UNION SELECT DISTINCT tenant_id::uuid FROM bi_cari_bakiye
  UNION SELECT DISTINCT tenant_id::uuid FROM bi_musteri_risk
$fn$;

CREATE OR REPLACE FUNCTION bi_foto_borc(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  DELETE FROM bi_borc_foto_gun WHERE foto_gun = p_gun;
  WITH f AS (SELECT tenant_id::uuid tid, vade_tarihi,
                    COALESCE(satir_kdv_haric,0) h, COALESCE(satir_kdv_dahil,0) d
               FROM bi_tedarikci_faturalari
              WHERE COALESCE(odeme_durumu,'')='O'
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

  -- KAPI: HER tenant icin satir. Veri yoksa gecti=NULL, 'veri yok'.
  DELETE FROM bi_foto_mutabakat WHERE foto_gun=p_gun AND kapi='acik_borc_vs_bilanco_ap';
  INSERT INTO bi_foto_mutabakat (tenant_id,foto_gun,kapi,olculen,referans,fark_pct,gecti,not_metin)
  SELECT t.tid, p_gun, 'acik_borc_vs_bilanco_ap', b.kdv_dahil, s.ap_borc,
         round(100*(b.kdv_dahil-s.ap_borc)/NULLIF(s.ap_borc,0),2),
         CASE WHEN b.kdv_dahil IS NULL OR COALESCE(s.ap_borc,0)=0 THEN NULL
              ELSE abs(100*(b.kdv_dahil-s.ap_borc)/s.ap_borc) <= 5 END,
         CASE WHEN b.kdv_dahil IS NULL AND COALESCE(s.ap_borc,0)=0
                   THEN 'veri yok: acik borc da bilanco AP de bos'
              WHEN b.kdv_dahil IS NULL
                   THEN 'veri yok: cari yilda acik tedarikci faturasi yok (AP referansi var)'
              WHEN COALESCE(s.ap_borc,0)=0
                   THEN 'veri yok: bilanco AP referansi yok'
              ELSE 'odeme_durumu=O + cari yil; kapi kapaliysa cikis bacagi banda duser' END
    FROM bi_tenant_listesi() t
    LEFT JOIN bi_borc_foto_gun b
           ON b.tenant_id=t.tid AND b.foto_gun=p_gun AND b.boyut_tipi='TOPLAM'
    LEFT JOIN v_finans_ticari_sermaye s ON s.tenant_id::text=t.tid::text;
  RETURN v;
END $fn$;
