\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SET statement_timeout='0';
SET lock_timeout='10s';
DROP TABLE IF EXISTS cm; DROP TABLE IF EXISTS _cf;
CREATE TEMP TABLE _cf(segment text, metrik text, deger text, n int, tutar numeric, grup_med numeric, genel_med numeric, z numeric, yon text);
CREATE TEMP TABLE cm AS
WITH
s AS (SELECT f.musteri_kodu mk, count(DISTINCT f.fatura_tarihi) gun, count(DISTINCT f.kategori) ncat,
        count(DISTINCT f.marka) nbrand, min(f.fatura_tarihi) ilk, max(f.fatura_tarihi) son, sum(f.satir_tutar) toplam
      FROM bi_satis_faturalari f
      WHERE f.tenant_id::text=:'t' AND f.satir_tutar>0 AND f.musteri_kodu IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk mr WHERE mr.tenant_id::text=f.tenant_id::text AND mr.muhatap_kodu=f.musteri_kodu AND mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))
      GROUP BY 1),
dv AS (SELECT mk,v FROM (SELECT musteri_kodu mk,odeme_kosulu v,row_number() OVER (PARTITION BY musteri_kodu ORDER BY sum(satir_tutar) DESC) rn FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND coalesce(odeme_kosulu,'')<>'' GROUP BY 1,2) q WHERE rn=1),
ds AS (SELECT mk,v FROM (SELECT musteri_kodu mk,sehir v,row_number() OVER (PARTITION BY musteri_kodu ORDER BY sum(satir_tutar) DESC) rn FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND coalesce(sehir,'')<>'' GROUP BY 1,2) q WHERE rn=1),
dk AS (SELECT mk,v FROM (SELECT musteri_kodu mk,satis_kanali v,row_number() OVER (PARTITION BY musteri_kodu ORDER BY sum(satir_tutar) DESC) rn FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND coalesce(satis_kanali,'')<>'' GROUP BY 1,2) q WHERE rn=1),
dm AS (SELECT mk,v FROM (SELECT musteri_kodu mk,marka v,row_number() OVER (PARTITION BY musteri_kodu ORDER BY sum(satir_tutar) DESC) rn FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND coalesce(marka,'')<>'' GROUP BY 1,2) q WHERE rn=1),
tah AS (SELECT muhatap_kodu mk, ort_gecikme_gun gecikme, gec_odeme_orani gecoran FROM bi_tahsilat WHERE tenant_id::text=:'t'),
viz AS (SELECT k.musteri_kodu mk, count(*) vcount FROM saha_ziyaret z JOIN saha_musteri_kanon k ON k.musteri_id=z.musteri_id WHERE z.durum='TAMAMLANDI' GROUP BY 1)
SELECT s.mk, s.toplam, dv.v dvade, ds.v dsehir, dk.v dkanal, dm.v dmarka,
  extract(year FROM s.ilk)::int kohort, ntile(4) OVER (ORDER BY s.toplam) tier,
  round((s.gun/GREATEST((s.son-s.ilk)/365.0,0.5))::numeric,2) freq,
  s.ncat breadth, s.nbrand brands, (CURRENT_DATE-s.son) recency,
  tah.gecikme, tah.gecoran, coalesce(viz.vcount,0) visits
FROM s LEFT JOIN dv ON dv.mk=s.mk LEFT JOIN ds ON ds.mk=s.mk LEFT JOIN dk ON dk.mk=s.mk LEFT JOIN dm ON dm.mk=s.mk
LEFT JOIN tah ON tah.mk=s.mk LEFT JOIN viz ON viz.mk=s.mk;
DO $$
DECLARE segs text[]:=ARRAY['dvade','dsehir','dkanal','dmarka','kohort','tier'];
        mets text[]:=ARRAY['freq','breadth','brands','recency','gecikme','gecoran','visits'];
        sg text; mt text; sql text;
BEGIN
  FOREACH sg IN ARRAY segs LOOP FOREACH mt IN ARRAY mets LOOP
    CONTINUE WHEN (sg='kohort' AND mt='recency');
    CONTINUE WHEN (sg='tier' AND mt IN ('freq','breadth','brands'));
    sql:=format($q$
      INSERT INTO _cf
      WITH glob AS (SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY %2$I) gm, stddev_pop(%2$I) sd FROM cm WHERE %2$I IS NOT NULL),
      g AS (SELECT %1$I::text sv, count(*) n, sum(toplam) tut, percentile_cont(0.5) WITHIN GROUP (ORDER BY %2$I) med
            FROM cm WHERE %2$I IS NOT NULL AND %1$I IS NOT NULL GROUP BY 1 HAVING count(*)>=50)
      SELECT DISTINCT %1$L,%2$L,sv,n,tut,round(med::numeric,1),round((SELECT gm FROM glob)::numeric,1),
        round(((med-(SELECT gm FROM glob))/NULLIF((SELECT sd FROM glob),0))::numeric,2),
        CASE WHEN med>(SELECT gm FROM glob) THEN 'yuksek' ELSE 'dusuk' END
      FROM g WHERE (SELECT sd FROM glob)>0 AND abs((med-(SELECT gm FROM glob))/NULLIF((SELECT sd FROM glob),0))>=1.3
    $q$, sg, mt);
    BEGIN EXECUTE sql; EXCEPTION WHEN others THEN NULL; END;
  END LOOP; END LOOP;
END $$;
INSERT INTO bi_sinyal_aday AS d (tenant_id,parmak,aile,boyut,deger,yon,ilk_gun,son_gun,gun_sayisi,gorulme,son_z,son_tutar,son_skor,son_detay,durum,guncelleme)
SELECT :'t'::uuid,
  'oto-gercek|'||segment||'|'||metrik||'|'||left(deger,40)||'|'||yon,
  'oto-gercek',
  (CASE segment WHEN 'dvade' THEN 'vade' WHEN 'dsehir' THEN 'sehir' WHEN 'dkanal' THEN 'kanal' WHEN 'dmarka' THEN 'ana marka' WHEN 'kohort' THEN 'kohort yili' WHEN 'tier' THEN 'buyukluk dilimi' ELSE segment END),
  left(deger,50), yon, CURRENT_DATE, CURRENT_DATE, 1, 1, z, round(coalesce(tutar,0)), round(abs(z)*ln(1+n))::numeric,
  jsonb_build_object('olcut','compound','metrik',metrik,'grup_med',grup_med,'genel_med',genel_med,'yon',yon,'n',n,
    'bulgu',
    (CASE segment WHEN 'dvade' THEN 'Vade' WHEN 'dsehir' THEN 'Sehir' WHEN 'dkanal' THEN 'Kanal' WHEN 'dmarka' THEN 'Ana marka' WHEN 'kohort' THEN 'Kohort' WHEN 'tier' THEN 'Buyukluk dilimi' ELSE segment END)
    ||' = '||deger||' olan musteriler, '||
    (CASE metrik WHEN 'gecoran' THEN 'gec odeme orani' WHEN 'gecikme' THEN 'odeme gecikmesi' WHEN 'recency' THEN 'son alistan bu yana gun' WHEN 'breadth' THEN 'kategori genisligi' WHEN 'brands' THEN 'marka genisligi' WHEN 'freq' THEN 'siparis sikligi' WHEN 'visits' THEN 'ziyaret sayisi' ELSE metrik END)
    ||' bakimindan genelden '||(CASE WHEN yon='yuksek' THEN 'YUKSEK' ELSE 'DUSUK' END)||' ('||grup_med||' vs genel '||genel_med||').'),
  'izleniyor', now()
FROM _cf
ON CONFLICT (tenant_id,parmak) DO UPDATE SET
  gorulme=d.gorulme+1,
  gun_sayisi=d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END),
  son_gun=GREATEST(d.son_gun,EXCLUDED.son_gun),
  son_z=EXCLUDED.son_z, son_tutar=EXCLUDED.son_tutar, son_skor=EXCLUDED.son_skor, son_detay=EXCLUDED.son_detay,
  durum=CASE WHEN d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END)>=3 THEN 'dogrulandi' ELSE d.durum END,
  guncelleme=now();
UPDATE bi_sinyal_aday SET durum='soldu', guncelleme=now()
WHERE tenant_id=:'t'::uuid AND aile='oto-gercek' AND durum<>'soldu' AND son_gun < CURRENT_DATE - 10;
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_COMPOUND_V1','Tam-tarih bilesik-gercek madencisi: metrik x segment, tum gecmis, MEDYAN, totoloji-eleme+dedup+|z|>=1.3.',
 'Makine compound sorulari kendi turetir. OTR->%78, 90gun->%48 kimse sormadan. Ortalama yalan, medyan gercek. Sifir literal.',
 '{"marker":"SINYAL_COMPOUND_V1","aile":"oto-gercek","dosya":"sinyal_motor_ek4.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_COMPOUND_V1');
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,onaylayan,eklendi_at,guncellendi_at,parmak_izi,son_gorulme)
SELECT 'compound-madenci','yetenek','Makine segment x metrik uzayini kendi tarar, tum gecmiste sira disiligi bulur.','sinyal_motor_ek4.sql gunluk; medyan, totoloji-eleme, |z|>=1.3, n>=50.','','aktif',0.7,'{"marker":"SINYAL_COMPOUND_V1"}'::jsonb,true,'sistem',now(),now(),'SINYAL_COMPOUND_V1',now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='compound-madenci');
SELECT count(*) oto_gercek FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND aile='oto-gercek';
SELECT boyut, left(deger,20) deger, yon, son_detay->>'metrik' metrik, son_detay->>'grup_med' grup, son_detay->>'genel_med' genel, round(son_z,2) z
FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND aile='oto-gercek' ORDER BY abs(son_z) DESC LIMIT 20;
