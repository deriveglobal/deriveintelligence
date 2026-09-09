\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SET statement_timeout='0';
SET lock_timeout='10s';
DROP TABLE IF EXISTS _cfg; DROP TABLE IF EXISTS _hf;
CREATE TEMP TABLE _cfg(t text); INSERT INTO _cfg VALUES (:'t');
CREATE TEMP TABLE _hf(kombinasyon text, deger text, recent_v numeric, beklenen_v numeric, pct int, z numeric, n int, tip text, yon text, recent_sh numeric);
DO $$
DECLARE dims text[]; ncols int; i int; j int; selx text; guard text; lbl text; sql text;
  v_t text; v_mm date; v_lo date; v_hi date; m0 int; m1 int; m2 int;
BEGIN
  SELECT t INTO v_t FROM _cfg;
  SELECT date_trunc('month', CASE WHEN extract(day FROM md)>=26 THEN md ELSE md - interval '1 month' END)::date
    INTO v_mm FROM (SELECT max(fatura_tarihi) md FROM bi_satis_faturalari WHERE tenant_id::text=v_t AND satir_tutar>0) q;
  IF v_mm IS NULL THEN RETURN; END IF;
  v_lo := (v_mm - interval '2 months')::date;
  v_hi := (v_mm + interval '1 month')::date;
  m0 := extract(month FROM v_mm)::int;
  m1 := extract(month FROM v_mm - interval '1 month')::int;
  m2 := extract(month FROM v_mm - interval '2 months')::int;
  SELECT array_agg(column_name ORDER BY column_name) INTO dims
  FROM information_schema.columns
  WHERE table_schema='public' AND table_name='bi_satis_faturalari' AND data_type IN ('text','character varying')
    AND column_name NOT IN ('tenant_id','musteri_adi','musteri_kodu','fatura_no','kalem_kodu',
      'kalem_tanimi','vergi_no','vergi_dairesi','tc_no','para_birimi','fatura_kesen','depo_adi','jant_capi');
  ncols := array_length(dims,1);
  FOR i IN 1..ncols LOOP
    FOR j IN i..ncols LOOP
      IF i=j THEN
        selx := format('%I', dims[i]);
        guard := format('%I IS NOT NULL AND %I <> ''''', dims[i], dims[i]);
        lbl := dims[i];
      ELSE
        selx := format('%I || '' × '' || %I', dims[i], dims[j]);
        guard := format('%I IS NOT NULL AND %I <> '''' AND %I IS NOT NULL AND %I <> ''''', dims[i],dims[i],dims[j],dims[j]);
        lbl := dims[i] || ' × ' || dims[j];
      END IF;
      sql := format($q$
        INSERT INTO _hf
        WITH
        rec AS (SELECT (%1$s) dv, sum(satir_tutar) v FROM bi_satis_faturalari
                WHERE tenant_id::text=%2$L AND satir_tutar>0 AND %3$s AND fatura_tarihi>=%4$L AND fatura_tarihi<%5$L GROUP BY 1),
        rect AS (SELECT sum(satir_tutar) tv FROM bi_satis_faturalari
                WHERE tenant_id::text=%2$L AND satir_tutar>0 AND fatura_tarihi>=%4$L AND fatura_tarihi<%5$L),
        byr AS (SELECT extract(year FROM fatura_tarihi)::int y, (%1$s) dv, sum(satir_tutar) v FROM bi_satis_faturalari
                WHERE tenant_id::text=%2$L AND satir_tutar>0 AND %3$s AND extract(month FROM fatura_tarihi)::int IN (%6$s,%7$s,%8$s) AND fatura_tarihi<%4$L GROUP BY 1,2),
        byrt AS (SELECT extract(year FROM fatura_tarihi)::int y, sum(satir_tutar) tv FROM bi_satis_faturalari
                WHERE tenant_id::text=%2$L AND satir_tutar>0 AND extract(month FROM fatura_tarihi)::int IN (%6$s,%7$s,%8$s) AND fatura_tarihi<%4$L GROUP BY 1),
        bsh AS (SELECT byr.dv, byr.y, byr.v/NULLIF(byrt.tv,0) sh FROM byr JOIN byrt USING(y)),
        base AS (SELECT dv, avg(sh) ort, stddev_pop(sh) sd, count(*) n FROM bsh GROUP BY dv),
        fin AS (SELECT rec.dv, rec.v recent_v, rec.v/NULLIF((SELECT tv FROM rect),0) recent_sh, base.ort, base.sd, base.n FROM rec JOIN base ON base.dv=rec.dv)
        SELECT %9$L, dv, recent_v, ort*(SELECT tv FROM rect),
          round(100*(recent_sh-ort)/NULLIF(ort,0))::int,
          round(((recent_sh-ort)/NULLIF(GREATEST(sd,0.005),0))::numeric,2), n,
          CASE WHEN ort>=0.003 THEN 'anomali' ELSE 'yeni' END,
          CASE WHEN recent_sh>=ort THEN 'artis' ELSE 'dusus' END,
          recent_sh
        FROM fin WHERE n>=2 AND recent_sh>=0.002 AND recent_sh IS NOT NULL
          AND abs((recent_sh-ort)/NULLIF(GREATEST(sd,0.005),0))>=2.5
      $q$, selx, v_t, guard, v_lo, v_hi, m0, m1, m2, lbl);
      BEGIN EXECUTE sql; EXCEPTION WHEN others THEN NULL; END;
    END LOOP;
  END LOOP;
END $$;
INSERT INTO bi_sinyal_aday AS d (tenant_id,parmak,aile,boyut,deger,yon,ilk_gun,son_gun,gun_sayisi,gorulme,son_z,son_tutar,son_skor,son_detay,durum,guncelleme)
SELECT (SELECT t FROM _cfg)::uuid,
  ('oto-'||tip)||'|'||kombinasyon||'|'||left(deger,50)||'|'||yon,
  'oto-'||tip, kombinasyon, left(deger,50), yon,
  CURRENT_DATE, CURRENT_DATE, 1, 1, round(z,2), round(recent_v)::numeric,
  round(abs(z)*ln(1+recent_v))::numeric,
  jsonb_build_object('olcut','oto_ceyrek_pay','tip',tip,'kombinasyon',kombinasyon,'yon',yon,
    'pct',pct,'son_m',round(recent_v/1e6,2),'beklenen_m',round(beklenen_v/1e6,2),'pay_pct',round(100*recent_sh,2),'n',n),
  'izleniyor', now()
FROM (
  SELECT *, row_number() OVER (PARTITION BY tip ORDER BY (CASE WHEN tip='anomali' THEN abs(z) ELSE recent_sh END) DESC) rn
  FROM _hf WHERE (tip='anomali' AND n>=3 AND abs(z)>=3.0) OR (tip='yeni' AND recent_sh>=0.004)
) g
WHERE (tip='anomali' AND rn<=80) OR (tip='yeni' AND rn<=30)
ON CONFLICT (tenant_id,parmak) DO UPDATE SET
  gorulme=d.gorulme+1,
  gun_sayisi=d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END),
  son_gun=GREATEST(d.son_gun,EXCLUDED.son_gun),
  son_z=EXCLUDED.son_z, son_tutar=EXCLUDED.son_tutar, son_skor=EXCLUDED.son_skor, son_detay=EXCLUDED.son_detay,
  durum=CASE WHEN d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END)>=3 THEN 'dogrulandi' ELSE d.durum END,
  guncelleme=now();
UPDATE bi_sinyal_aday SET durum='soldu', guncelleme=now()
WHERE tenant_id=(SELECT t FROM _cfg)::uuid AND aile LIKE 'oto-%' AND durum<>'soldu' AND son_gun < CURRENT_DATE - 10;
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_OTOKESIF_V1','Otonom kesif motoru: sema-introspeksiyonu ile TUM boyut + boyut-cifti uzayini jenerik tarar; ceyrek-pencere pay-bazli mevsim tabani; yeni/anomali; gorel materyalite; havuza akar.',
 'Aile adi yok. 11 boyut -> 66 uzay. Bar: n>=3, |z|>=3.0, pay>=0.2%, tur-tavani. Tenant-agnostik. FDR: dusuk-n guvenilmez -> siki z+kalicilik; BH tabanlar derinlesince.',
 '{"marker":"SINYAL_OTOKESIF_V1","aile":["oto-anomali","oto-yeni"],"olcut":"oto_ceyrek_pay","dosya":"sinyal_motor_ek3.sql","havuz":"bi_sinyal_aday"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_OTOKESIF_V1');
SELECT aile, count(*) FROM bi_sinyal_aday WHERE tenant_id=(SELECT t FROM _cfg)::uuid AND aile LIKE 'oto-%' GROUP BY 1 ORDER BY 1;
SELECT aile, boyut, left(deger,34) deger, yon, round(son_tutar/1e6,1) son_m, round(son_skor) skor, son_z z, son_detay->>'n' n
FROM bi_sinyal_aday WHERE tenant_id=(SELECT t FROM _cfg)::uuid AND aile LIKE 'oto-%' ORDER BY son_skor DESC LIMIT 25;
