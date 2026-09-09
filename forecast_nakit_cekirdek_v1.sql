SET lock_timeout='5s';

-- Fatura tabani (odeme satirlari mukerrer; fatura basina tekille)
CREATE OR REPLACE VIEW v_fatura_kohort AS
SELECT tenant_id::uuid tid, fatura_no,
       min(fatura_tarihi) fatura_tarihi, max(COALESCE(fatura_tutari,0)) fatura_tutari
  FROM bi_odeme_gecmisi
 WHERE fatura_no IS NOT NULL AND fatura_tarihi IS NOT NULL
 GROUP BY 1,2;

CREATE OR REPLACE VIEW v_kohort_aylik AS
SELECT tid, date_trunc('month',fatura_tarihi)::date kohort_ay, sum(fatura_tutari) fatura_tutar
  FROM v_fatura_kohort GROUP BY 1,2;

-- Kohort x gecikme-ayi tahsilat
CREATE OR REPLACE VIEW v_tahsilat_gecikme AS
SELECT o.tenant_id::uuid tid,
       date_trunc('month',o.fatura_tarihi)::date kohort_ay,
       ((extract(year FROM o.odeme_tarihi)-extract(year FROM o.fatura_tarihi))*12
        + (extract(month FROM o.odeme_tarihi)-extract(month FROM o.fatura_tarihi)))::int gecikme_ay,
       sum(COALESCE(o.odenen_tutar,0)) tutar
  FROM bi_odeme_gecmisi o
 WHERE o.odeme_tarihi IS NOT NULL AND o.fatura_tarihi IS NOT NULL
   AND o.odeme_tarihi <= CURRENT_DATE
 GROUP BY 1,2,3;

CREATE TABLE IF NOT EXISTS bi_tahsilat_cekirdek (
  tenant_id uuid NOT NULL, kohort_kesim date NOT NULL, gecikme_ay integer NOT NULL,
  agirlik numeric, kohort_say integer, hesaplandi_at timestamptz DEFAULT now(),
  PRIMARY KEY (tenant_id, kohort_kesim, gecikme_ay));

CREATE OR REPLACE FUNCTION bi_tahsilat_cekirdek_uret(
  p_kohort_son date DEFAULT DATE '2024-12-01', p_max_lag integer DEFAULT 11)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer;
BEGIN
  DELETE FROM bi_tahsilat_cekirdek WHERE kohort_kesim = p_kohort_son;
  INSERT INTO bi_tahsilat_cekirdek (tenant_id,kohort_kesim,gecikme_ay,agirlik,kohort_say)
  SELECT g.tid, p_kohort_son, g.gecikme_ay,
         sum(g.tutar) / NULLIF(sum(DISTINCT_taban.taban),0),
         count(DISTINCT g.kohort_ay)
    FROM v_tahsilat_gecikme g
    JOIN LATERAL (SELECT sum(k.fatura_tutar) taban FROM v_kohort_aylik k
                   WHERE k.tid=g.tid AND k.kohort_ay <= p_kohort_son) DISTINCT_taban ON true
   WHERE g.kohort_ay <= p_kohort_son
     AND g.gecikme_ay BETWEEN 0 AND p_max_lag
   GROUP BY g.tid, g.gecikme_ay;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;

INSERT INTO bi_tahmin_model (model_ad,aile,aciklama) VALUES
 ('tahsilat_cekirdek','yapisal',
  'Faturalanan tutarin olculmus gecikme dagilimiyla konvolusyonu: Tahsilat_M = SUM(agirlik_k x Faturalanan_M-k)')
ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION bi_tahmin_cekirdek_kos(
  p_kohort_son date DEFAULT DATE '2024-12-01', p_son_hedef date DEFAULT DATE '2025-12-01',
  p_ay_geri integer DEFAULT 48)
RETURNS integer LANGUAGE plpgsql AS $fn$
DECLARE v integer; ilk date;
BEGIN
  ilk := (p_son_hedef - ((p_ay_geri-1)||' months')::interval)::date;
  INSERT INTO bi_tahmin (tenant_id,uretim_gun,nesne,varlik_tipi,varlik_kodu,hedef_donem,
                         ufuk_gun,yontem,model_ad,tahmin_deger,kosum)
  SELECT h.tid,(h.hedef-1),'ciro','tahsilat','TOPLAM',h.hedef,30,'taban','tahsilat_cekirdek',
         sum(w.agirlik * COALESCE(ka.fatura_tutar,0)),'backtest'
    FROM (SELECT DISTINCT tid, donem hedef FROM mv_gerceklesen_aylik
           WHERE varlik_tipi='tahsilat' AND donem BETWEEN ilk AND p_son_hedef) h
    JOIN bi_tahsilat_cekirdek w ON w.tenant_id=h.tid AND w.kohort_kesim=p_kohort_son
    LEFT JOIN v_kohort_aylik ka ON ka.tid=h.tid
         AND ka.kohort_ay = (h.hedef - (GREATEST(w.gecikme_ay,1)||' months')::interval)::date
   GROUP BY h.tid,h.hedef
  HAVING sum(w.agirlik * COALESCE(ka.fatura_tutar,0)) > 0
  ON CONFLICT DO NOTHING;
  GET DIAGNOSTICS v = ROW_COUNT; RETURN v;
END $fn$;
