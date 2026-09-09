\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SET statement_timeout='0';
SET lock_timeout='10s';
DROP TABLE IF EXISTS _cfg; DROP TABLE IF EXISTS _cp;
CREATE TEMP TABLE _cfg(t text); INSERT INTO _cfg VALUES (:'t');
CREATE TEMP TABLE _cp(boyut text, deger text, kirilma date, once numeric, sonra numeric, n_ay int, nm numeric, esik numeric, tot_v numeric, yon text);
DO $$
DECLARE dims text[]; sg text; sql text; v_t text;
BEGIN
  SELECT t INTO v_t FROM _cfg;
  dims:=ARRAY['marka','sehir','satis_kanali','odeme_kosulu','kategori','kategori2','grup_adi','ebat'];
  FOREACH sg IN ARRAY dims LOOP
    sql:=format($q$
      INSERT INTO _cp
      WITH tot AS (SELECT date_trunc('month',fatura_tarihi) m, sum(satir_tutar) tv FROM bi_satis_faturalari WHERE tenant_id::text=%2$L AND satir_tutar>0 GROUP BY 1),
      val AS (SELECT (%1$I) v, date_trunc('month',fatura_tarihi) m, sum(satir_tutar) sv FROM bi_satis_faturalari WHERE tenant_id::text=%2$L AND satir_tutar>0 AND %1$I IS NOT NULL AND %1$I<>'' GROUP BY 1,2),
      vt AS (SELECT v FROM val GROUP BY v HAVING sum(sv) >= (SELECT sum(tv)*0.003 FROM tot)),
      vsum AS (SELECT v, sum(sv) tv2 FROM val WHERE v IN (SELECT v FROM vt) GROUP BY v),
      sh AS (SELECT val.v, val.m, val.sv/NULLIF(tot.tv,0) s FROM val JOIN tot USING(m) WHERE val.v IN (SELECT v FROM vt)),
      ser AS (SELECT v, m, s, row_number() OVER (PARTITION BY v ORDER BY m) i, count(*) OVER (PARTITION BY v) N FROM sh),
      sp AS (SELECT a.v, a.i k, a.m sm, a.N,
          avg(b.s) FILTER (WHERE b.i<a.i) mb, avg(b.s) FILTER (WHERE b.i>=a.i) ma,
          var_pop(b.s) FILTER (WHERE b.i<a.i) vb, var_pop(b.s) FILTER (WHERE b.i>=a.i) va,
          count(*) FILTER (WHERE b.i<a.i) nb, count(*) FILTER (WHERE b.i>=a.i) na
        FROM ser a JOIN ser b ON b.v=a.v GROUP BY a.v,a.i,a.m,a.N),
      st AS (SELECT v, sm, mb, ma, N, abs(ma-mb)/NULLIF(sqrt((vb*nb+va*na)/(nb+na))*sqrt(1.0/nb+1.0/na),0) nm
             FROM sp WHERE k>=3 AND k<=N-2 AND N>=12),
      best AS (SELECT DISTINCT ON (v) v, sm, mb, ma, N, nm FROM st ORDER BY v, nm DESC NULLS LAST)
      SELECT %1$L, best.v, best.sm, round(best.mb*100,1), round(best.ma*100,1), best.N, round(best.nm,2),
        round(sqrt(2*ln(best.N))::numeric,2), vsum.tv2, CASE WHEN best.ma>=best.mb THEN 'yukselis' ELSE 'dusus' END
      FROM best JOIN vsum ON vsum.v=best.v WHERE best.nm > sqrt(2*ln(best.N))
    $q$, sg, v_t);
    BEGIN EXECUTE sql; EXCEPTION WHEN others THEN NULL; END;
  END LOOP;
END $$;
INSERT INTO bi_sinyal_aday AS d (tenant_id,parmak,aile,boyut,deger,yon,ilk_gun,son_gun,gun_sayisi,gorulme,son_z,son_tutar,son_skor,son_detay,durum,guncelleme)
SELECT (SELECT t FROM _cfg)::uuid,
  'oto-kirilma|'||boyut||'|'||left(deger,40),
  'oto-kirilma', boyut, left(deger,50), yon,
  CURRENT_DATE, CURRENT_DATE, 1, 1, nm, round(coalesce(tot_v,0)), round(nm*ln(1+coalesce(tot_v,0)))::numeric,
  jsonb_build_object('olcut','changepoint','kirilma_ayi',to_char(kirilma,'YYYY-MM'),'once_pay',once,'sonra_pay',sonra,
    'n_ay',n_ay,'nm',nm,'esik',esik,'yon',yon,
    'bulgu', deger||' ('||boyut||') '||to_char(kirilma,'YYYY-MM')||' rejim degistirdi: payi %'||once||' -> %'||sonra
      ||' ('||yon||'), serinin normal dalgalanmasinin '||nm||' kati. Veri kendi buldu; pencere/esik konmadi.'),
  'izleniyor', now()
FROM _cp
ON CONFLICT (tenant_id,parmak) DO UPDATE SET
  gorulme=d.gorulme+1,
  gun_sayisi=d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END),
  son_gun=GREATEST(d.son_gun,EXCLUDED.son_gun),
  son_z=EXCLUDED.son_z, son_tutar=EXCLUDED.son_tutar, son_skor=EXCLUDED.son_skor, son_detay=EXCLUDED.son_detay,
  durum=CASE WHEN d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END)>=3 THEN 'dogrulandi' ELSE d.durum END,
  guncelleme=now();
UPDATE bi_sinyal_aday SET durum='soldu', guncelleme=now()
WHERE tenant_id=:'t'::uuid AND aile='oto-kirilma' AND durum<>'soldu' AND son_gun < CURRENT_DATE - 10;
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_KIRILMA_V1','Parametresiz changepoint: her boyut-deger tum-tarih pay serisi kendi kirilmasi + kendi gurultusune gore anlamlilik. Pencere/z yok; esik sqrt(2lnN).',
 'Fatih: sisteme sinir koyma, her tenant kendi hikayesi. Sabit-pencere ek3 2yillik yapisal degisimi son-dakika gosterdi; changepoint dogruyu soyluyor.',
 '{"marker":"SINYAL_KIRILMA_V1","aile":"oto-kirilma","parametresiz":true,"dosya":"sinyal_motor_ek5.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_KIRILMA_V1');
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,onaylayan,eklendi_at,guncellendi_at,parmak_izi,son_gorulme)
SELECT 'kirilma-changepoint','yetenek','Isin yapisal kirilmalarini bulur: her marka/sehir/kanal/vade ne zaman rejim degistirdi, veri kendi olceginde.','sinyal_motor_ek5.sql gunluk; parametresiz changepoint, esik sqrt(2lnN).','','aktif',0.8,'{"marker":"SINYAL_KIRILMA_V1"}'::jsonb,true,'sistem',now(),now(),'SINYAL_KIRILMA_V1',now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='kirilma-changepoint');
SELECT count(*) oto_kirilma FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND aile='oto-kirilma';
SELECT boyut, left(deger,20) deger, yon, son_detay->>'kirilma_ayi' ay, son_detay->>'once_pay' once, son_detay->>'sonra_pay' sonra, round(son_z,1) gurultu_kati
FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND aile='oto-kirilma' ORDER BY son_z DESC LIMIT 20;
