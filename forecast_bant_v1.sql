SET lock_timeout = '5s';

-- 1) VARLIK HIYERARSISI (uzlastirma icin; literal yok, helper'dan turer)
CREATE OR REPLACE VIEW v_varlik_hiyerarsi AS
SELECT DISTINCT tenant_id::uuid tid,'kategori'::text alt_tip, kategori::text alt_kod,
       'segment'::text ust_tip, kategori_segment(kategori, tenant_id::uuid)::text ust_kod
  FROM bi_satis_faturalari WHERE COALESCE(kategori,'')<>''
UNION
SELECT DISTINCT tenant_id::uuid,'segment', kategori_segment(kategori, tenant_id::uuid)::text,
       'TOPLAM','TOPLAM'
  FROM bi_satis_faturalari WHERE COALESCE(kategori,'')<>'';

-- 2) BANT AYARI (konformal: gecmis goreli hata dagiliminin kuantilleri)
CREATE TABLE IF NOT EXISTS bi_tahmin_bant_ayar (
  tenant_id uuid NOT NULL, nesne text NOT NULL, varlik_tipi text NOT NULL,
  varlik_kodu text NOT NULL, ufuk_gun integer NOT NULL, model_ad text NOT NULL,
  hedef_kapsama numeric NOT NULL,
  q_alt numeric, q_ust numeric, n integer, donem_say integer,
  kalibrasyon_son date NOT NULL, hesaplandi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun,model_ad,hedef_kapsama));

CREATE OR REPLACE FUNCTION bi_tahmin_bant_kalibre(
  p_kapsama numeric DEFAULT 0.80, p_muhur_ay integer DEFAULT 12, p_min_donem integer DEFAULT 12)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer; kesim date;
BEGIN
  SELECT (max(hedef_donem) - (p_muhur_ay || ' months')::interval)::date INTO kesim
    FROM bi_tahmin WHERE kosum='backtest';

  DELETE FROM bi_tahmin_bant_ayar WHERE hedef_kapsama = p_kapsama;
  INSERT INTO bi_tahmin_bant_ayar
    (tenant_id,nesne,varlik_tipi,varlik_kodu,ufuk_gun,model_ad,hedef_kapsama,
     q_alt,q_ust,n,donem_say,kalibrasyon_son)
  SELECT t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.ufuk_gun,t.model_ad,p_kapsama,
         percentile_cont((1-p_kapsama)/2)     WITHIN GROUP (ORDER BY (s.gerceklesen-t.tahmin_deger)/t.tahmin_deger),
         percentile_cont(1-(1-p_kapsama)/2)   WITHIN GROUP (ORDER BY (s.gerceklesen-t.tahmin_deger)/t.tahmin_deger),
         count(*)::int, count(DISTINCT t.hedef_donem)::int, kesim
    FROM bi_tahmin t JOIN bi_tahmin_sonuc s ON s.tahmin_id=t.id
   WHERE t.kosum='backtest' AND t.tahmin_deger > 0 AND t.hedef_donem <= kesim
   GROUP BY t.tenant_id,t.nesne,t.varlik_tipi,t.varlik_kodu,t.ufuk_gun,t.model_ad
  HAVING count(DISTINCT t.hedef_donem) >= p_min_donem;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

-- 3) BANDI UYGULA (yalnizca MUHURLU pencerede) + kapsamayi yeniden olc
CREATE OR REPLACE FUNCTION bi_tahmin_bant_uygula(p_kapsama numeric DEFAULT 0.80)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  UPDATE bi_tahmin t
     SET alt_bant = t.tahmin_deger*(1+b.q_alt),
         ust_bant = t.tahmin_deger*(1+b.q_ust)
    FROM bi_tahmin_bant_ayar b
   WHERE b.tenant_id=t.tenant_id AND b.nesne=t.nesne AND b.varlik_tipi=t.varlik_tipi
     AND b.varlik_kodu=t.varlik_kodu AND b.ufuk_gun=t.ufuk_gun AND b.model_ad=t.model_ad
     AND b.hedef_kapsama=p_kapsama
     AND t.kosum='backtest' AND t.hedef_donem > b.kalibrasyon_son AND t.tahmin_deger > 0;
  GET DIAGNOSTICS v = ROW_COUNT;

  UPDATE bi_tahmin_sonuc s
     SET bant_ici = (s.gerceklesen BETWEEN t.alt_bant AND t.ust_bant)
    FROM bi_tahmin t
   WHERE t.id = s.tahmin_id AND t.alt_bant IS NOT NULL;
  RETURN v;
END $fn$;
