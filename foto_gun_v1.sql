SET lock_timeout = '5s';

CREATE TABLE IF NOT EXISTS bi_alacak_foto_gun (
  tenant_id uuid NOT NULL, foto_gun date NOT NULL,
  boyut_tipi text NOT NULL, boyut_deger text NOT NULL,
  musteri_say integer, gecikmis_musteri_say integer,
  brut_gecikmis numeric, net_gecikmis numeric,
  toplam_risk numeric, hesap_bakiyesi numeric,
  odenmemis_cekler numeric, odenmemis_senetler numeric,
  kaynak_export_date date, yazildi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, foto_gun, boyut_tipi, boyut_deger));

CREATE TABLE IF NOT EXISTS bi_stok_foto_gun (
  tenant_id uuid NOT NULL, foto_gun date NOT NULL,
  boyut_tipi text NOT NULL, boyut_deger text NOT NULL,
  sku_say integer, eldeki_miktar numeric, siparis_miktar numeric, toplam_deger numeric,
  kaynak_export_date date, yazildi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, foto_gun, boyut_tipi, boyut_deger));

CREATE TABLE IF NOT EXISTS bi_borc_foto_gun (
  tenant_id uuid NOT NULL, foto_gun date NOT NULL,
  boyut_tipi text NOT NULL, boyut_deger text NOT NULL,
  fatura_say integer, kdv_haric numeric, kdv_dahil numeric,
  yazildi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, foto_gun, boyut_tipi, boyut_deger));

CREATE TABLE IF NOT EXISTS bi_alacak_foto_musteri (
  tenant_id uuid NOT NULL, foto_gun date NOT NULL, muhatap_kodu text NOT NULL,
  grup text, satis_calisani text,
  toplam_risk numeric, brut_gecikmis numeric, net_gecikmis numeric,
  hesap_bakiyesi numeric, kredi_limiti numeric, limit_asimi numeric,
  PRIMARY KEY (tenant_id, foto_gun, muhatap_kodu));

-- 1) ALACAK günlük foto (gecikmiş KANON = v_net_gecikmis_musteri)
CREATE OR REPLACE FUNCTION bi_foto_alacak(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  WITH se AS (SELECT tenant_id, max(export_date) ed FROM bi_musteri_risk GROUP BY 1),
  r AS (SELECT m.*, se.ed FROM bi_musteri_risk m
          JOIN se ON se.tenant_id::text=m.tenant_id::text AND se.ed=m.export_date
         WHERE COALESCE(m.musteri_mi::text,'') NOT IN ('false','f','0','H','HAYIR')),
  j AS (SELECT r.tenant_id::uuid tid, COALESCE(NULLIF(r.grup,''),'(grupsuz)') grup, r.ed,
               COALESCE(r.toplam_risk,0) risk, COALESCE(r.hesap_bakiyesi,0) bak,
               COALESCE(r.odenmemis_cekler,0) cek, COALESCE(r.odenmemis_senetler,0) sen,
               COALESCE(n.brut_gecikmis,0) brut, COALESCE(n.net_gecikmis,0) net
          FROM r LEFT JOIN v_net_gecikmis_musteri n
            ON n.tenant_id::text=r.tenant_id::text AND n.muhatap_kodu=r.muhatap_kodu),
  x AS (SELECT j.*, g.bt, g.bd FROM j,
          LATERAL (VALUES ('TOPLAM','TOPLAM'),('grup',j.grup)) AS g(bt,bd))
  INSERT INTO bi_alacak_foto_gun AS t
    (tenant_id,foto_gun,boyut_tipi,boyut_deger,musteri_say,gecikmis_musteri_say,
     brut_gecikmis,net_gecikmis,toplam_risk,hesap_bakiyesi,
     odenmemis_cekler,odenmemis_senetler,kaynak_export_date)
  SELECT tid,p_gun,bt,bd,count(*),count(*) FILTER (WHERE net>0),
         sum(brut),sum(net),sum(risk),sum(bak),sum(cek),sum(sen),max(ed)
    FROM x GROUP BY tid,bt,bd
  ON CONFLICT (tenant_id,foto_gun,boyut_tipi,boyut_deger) DO UPDATE SET
    musteri_say=EXCLUDED.musteri_say, gecikmis_musteri_say=EXCLUDED.gecikmis_musteri_say,
    brut_gecikmis=EXCLUDED.brut_gecikmis, net_gecikmis=EXCLUDED.net_gecikmis,
    toplam_risk=EXCLUDED.toplam_risk, hesap_bakiyesi=EXCLUDED.hesap_bakiyesi,
    odenmemis_cekler=EXCLUDED.odenmemis_cekler, odenmemis_senetler=EXCLUDED.odenmemis_senetler,
    kaynak_export_date=EXCLUDED.kaynak_export_date, yazildi_at=now();
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- 2) STOK günlük foto
CREATE OR REPLACE FUNCTION bi_foto_stok(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  WITH se AS (SELECT tenant_id, max(export_date) ed FROM bi_stok_durumu GROUP BY 1),
  s AS (SELECT d.tenant_id::uuid tid, se.ed,
               COALESCE(NULLIF(d.marka,''),'(markasız)') marka,
               COALESCE(NULLIF(d.kategori,''),'(kategorisiz)') kategori,
               COALESCE(d.eldeki_miktar,0) adet, COALESCE(d.siparis_miktar,0) sip,
               COALESCE(d.toplam_deger,0) deger
          FROM bi_stok_durumu d
          JOIN se ON se.tenant_id::text=d.tenant_id::text AND se.ed=d.export_date),
  x AS (SELECT s.*, g.bt, g.bd FROM s,
          LATERAL (VALUES ('TOPLAM','TOPLAM'),('marka',s.marka),('kategori',s.kategori)) AS g(bt,bd))
  INSERT INTO bi_stok_foto_gun AS t
    (tenant_id,foto_gun,boyut_tipi,boyut_deger,sku_say,eldeki_miktar,siparis_miktar,toplam_deger,kaynak_export_date)
  SELECT tid,p_gun,bt,bd,count(*),sum(adet),sum(sip),sum(deger),max(ed)
    FROM x GROUP BY tid,bt,bd
  ON CONFLICT (tenant_id,foto_gun,boyut_tipi,boyut_deger) DO UPDATE SET
    sku_say=EXCLUDED.sku_say, eldeki_miktar=EXCLUDED.eldeki_miktar,
    siparis_miktar=EXCLUDED.siparis_miktar, toplam_deger=EXCLUDED.toplam_deger,
    kaynak_export_date=EXCLUDED.kaynak_export_date, yazildi_at=now();
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- 3) TEDARİKÇİ vade takvimi (ileri nakit ÇIKIŞ taahhüdü)
CREATE OR REPLACE FUNCTION bi_foto_borc(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  WITH f AS (SELECT tenant_id::uuid tid, vade_tarihi,
                    COALESCE(satir_kdv_haric,0) h, COALESCE(satir_kdv_dahil,0) d
               FROM bi_tedarikci_faturalari
              WHERE vade_tarihi IS NOT NULL AND vade_tarihi >= p_gun),
  x AS (SELECT f.*, g.bt, g.bd FROM f,
          LATERAL (VALUES ('TOPLAM','TOPLAM'),
                          ('vade_ay', to_char(f.vade_tarihi,'YYYY-MM'))) AS g(bt,bd))
  INSERT INTO bi_borc_foto_gun AS t
    (tenant_id,foto_gun,boyut_tipi,boyut_deger,fatura_say,kdv_haric,kdv_dahil)
  SELECT tid,p_gun,bt,bd,count(*),sum(h),sum(d) FROM x GROUP BY tid,bt,bd
  ON CONFLICT (tenant_id,foto_gun,boyut_tipi,boyut_deger) DO UPDATE SET
    fatura_say=EXCLUDED.fatura_say, kdv_haric=EXCLUDED.kdv_haric,
    kdv_dahil=EXCLUDED.kdv_dahil, yazildi_at=now();
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- 4) MÜŞTERİ düzeyi foto (haftalık — disk için)
CREATE OR REPLACE FUNCTION bi_foto_alacak_musteri(p_gun date DEFAULT CURRENT_DATE)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  WITH se AS (SELECT tenant_id, max(export_date) ed FROM bi_musteri_risk GROUP BY 1),
  r AS (SELECT m.* FROM bi_musteri_risk m
          JOIN se ON se.tenant_id::text=m.tenant_id::text AND se.ed=m.export_date
         WHERE COALESCE(m.musteri_mi::text,'') NOT IN ('false','f','0','H','HAYIR'))
  INSERT INTO bi_alacak_foto_musteri AS t
    (tenant_id,foto_gun,muhatap_kodu,grup,satis_calisani,toplam_risk,
     brut_gecikmis,net_gecikmis,hesap_bakiyesi,kredi_limiti,limit_asimi)
  SELECT r.tenant_id::uuid,p_gun,r.muhatap_kodu,r.grup,r.satis_calisani,
         COALESCE(r.toplam_risk,0),COALESCE(n.brut_gecikmis,0),COALESCE(n.net_gecikmis,0),
         COALESCE(r.hesap_bakiyesi,0),COALESCE(r.kredi_limiti,0),COALESCE(r.limit_asimi,0)
    FROM r LEFT JOIN v_net_gecikmis_musteri n
      ON n.tenant_id::text=r.tenant_id::text AND n.muhatap_kodu=r.muhatap_kodu
  ON CONFLICT (tenant_id,foto_gun,muhatap_kodu) DO UPDATE SET
    toplam_risk=EXCLUDED.toplam_risk, brut_gecikmis=EXCLUDED.brut_gecikmis,
    net_gecikmis=EXCLUDED.net_gecikmis, hesap_bakiyesi=EXCLUDED.hesap_bakiyesi,
    kredi_limiti=EXCLUDED.kredi_limiti, limit_asimi=EXCLUDED.limit_asimi;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

CREATE OR REPLACE FUNCTION bi_foto_gunluk() RETURNS text LANGUAGE sql AS
$fn$ SELECT 'alacak='||bi_foto_alacak()||' stok='||bi_foto_stok()||' borc='||bi_foto_borc(); $fn$;
