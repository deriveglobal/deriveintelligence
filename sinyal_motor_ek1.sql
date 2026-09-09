-- SINYAL URETICI · EK1 · CAPRAZ-BOYUT (rep×kategori ciro-MIX + marj). v1 desenine birebir.
-- Marker: SINYAL_REP_KATEGORI_V2 · rep-ciro artik PAY(mix) bazli -> enflasyon-notr.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SET lock_timeout='5s';
WITH
smx AS (SELECT sm, extract(month FROM sm)::int cm FROM (
  SELECT CASE WHEN extract(day FROM md)>=26 THEN date_trunc('month',md) ELSE date_trunc('month',md)-INTERVAL '1 month' END sm
  FROM (SELECT max(fatura_tarihi) md FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0) q) w),
rk AS (
  SELECT satis_temsilcisi rep, kategori kat, date_trunc('month',fatura_tarihi) mo, sum(satir_tutar) v
  FROM bi_satis_faturalari
  WHERE tenant_id::text=:'t' AND satir_tutar>0 AND satis_temsilcisi IS NOT NULL AND satis_temsilcisi<>'' AND kategori IS NOT NULL AND kategori<>''
    AND satis_temsilcisi IN (SELECT sap_temsilci FROM rep_kimlik_koprusu WHERE durum='saha' AND user_id IS NOT NULL AND sap_temsilci<>'Fatih Bilen')
  GROUP BY 1,2,3),
rtot AS (SELECT rep, mo, sum(v) tv FROM rk GROUP BY 1,2),
rks  AS (SELECT rk.rep, rk.kat, rk.mo, rk.v, rk.v/NULLIF(rt.tv,0) sh FROM rk JOIN rtot rt ON rt.rep=rk.rep AND rt.mo=rk.mo),
rki AS (
  SELECT rep, kat,
    sum(v)  FILTER (WHERE mo=(SELECT sm FROM smx)) son_v,
    sum(sh) FILTER (WHERE mo=(SELECT sm FROM smx)) son_sh,
    avg(sh) FILTER (WHERE mo<(SELECT sm FROM smx) AND extract(month FROM mo)::int=(SELECT cm FROM smx)) ort_sh,
    stddev_pop(sh) FILTER (WHERE mo<(SELECT sm FROM smx) AND extract(month FROM mo)::int=(SELECT cm FROM smx)) sd,
    count(*) FILTER (WHERE mo<(SELECT sm FROM smx) AND extract(month FROM mo)::int=(SELECT cm FROM smx)) n
  FROM rks GROUP BY 1,2),
mmax AS (SELECT am, extract(month FROM am)::int cm FROM (SELECT max(ay) am FROM bi_marj_fact WHERE tenant_id::text=:'t') q),
rm AS (
  SELECT satis_temsilcisi rep, kategori kat, ay, sum(brut_kar) bk, sum(ciro) c
  FROM bi_marj_fact
  WHERE tenant_id::text=:'t' AND satis_temsilcisi IS NOT NULL AND satis_temsilcisi<>'' AND kategori IS NOT NULL AND kategori<>''
    AND satis_temsilcisi IN (SELECT sap_temsilci FROM rep_kimlik_koprusu WHERE durum='saha' AND user_id IS NOT NULL AND sap_temsilci<>'Fatih Bilen')
  GROUP BY 1,2,3),
rmi AS (
  SELECT rep, kat,
    sum(bk) FILTER (WHERE ay=(SELECT am FROM mmax))/NULLIF(sum(c) FILTER (WHERE ay=(SELECT am FROM mmax)),0)*100 son,
    avg(bk/NULLIF(c,0)*100) FILTER (WHERE ay<(SELECT am FROM mmax) AND extract(month FROM ay)::int=(SELECT cm FROM mmax)) ort,
    stddev_pop(bk/NULLIF(c,0)*100) FILTER (WHERE ay<(SELECT am FROM mmax) AND extract(month FROM ay)::int=(SELECT cm FROM mmax)) sd,
    sum(c) FILTER (WHERE ay=(SELECT am FROM mmax)) son_c,
    count(*) FILTER (WHERE ay<(SELECT am FROM mmax) AND extract(month FROM ay)::int=(SELECT cm FROM mmax)) n
  FROM rm GROUP BY 1,2),
bulgu AS (
  SELECT 'rep-ciro-anomali' aile, 'satis:rep-kategori' boyut, left(rep||' · '||kat,40) deger,
    CASE WHEN son_sh>=ort_sh THEN 'artis' ELSE 'dusus' END yon, son_v tutar,
    (son_sh-ort_sh)/NULLIF(GREATEST(sd,0.03),0) z,
    abs((son_sh-ort_sh)/NULLIF(GREATEST(sd,0.03),0))*ln(1+son_v) skor,
    jsonb_build_object('olcut','rep_kat_mix','son_pay_pct',round(100*son_sh,1),'baz_pay_pct',round(100*ort_sh,1),'son_m',round(son_v/1e6,2),'n',n) detay
  FROM rki
  WHERE n>=3 AND son_v>300000 AND son_sh IS NOT NULL AND ort_sh IS NOT NULL
    AND abs((son_sh-ort_sh)/NULLIF(GREATEST(sd,0.03),0))>=1.5
  UNION ALL
  SELECT 'rep-marj-anomali','marj:rep-kategori', left(rep||' · '||kat,40),
    CASE WHEN son>=ort THEN 'artis' ELSE 'dusus' END, son_c, (son-ort)/NULLIF(GREATEST(sd,1.0),0),
    abs((son-ort)/NULLIF(GREATEST(sd,1.0),0))*ln(1+son_c),
    jsonb_build_object('olcut','rep_kat_marj_pct','son_pct',round(son,1),'baz_pct',round(ort,1),'n',n)
  FROM rmi WHERE n>=3 AND son_c>500000 AND abs((son-ort)/NULLIF(GREATEST(sd,1.0),0))>=1.5)
INSERT INTO bi_sinyal_aday AS d (tenant_id,parmak,aile,boyut,deger,yon,ilk_gun,son_gun,gun_sayisi,gorulme,son_z,son_tutar,son_skor,son_detay,durum,guncelleme)
SELECT :'t'::uuid, aile||'|'||boyut||'|'||deger||'|'||yon, aile,boyut,deger,yon,CURRENT_DATE,CURRENT_DATE,1,1,round(z,2),tutar,round(skor)::numeric,detay,'izleniyor',now()
FROM bulgu
ON CONFLICT (tenant_id,parmak) DO UPDATE SET
  gorulme=d.gorulme+1,
  gun_sayisi=d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END),
  son_gun=GREATEST(d.son_gun,EXCLUDED.son_gun),
  son_z=EXCLUDED.son_z,son_tutar=EXCLUDED.son_tutar,son_skor=EXCLUDED.son_skor,son_detay=EXCLUDED.son_detay,
  durum=CASE WHEN d.gun_sayisi+(CASE WHEN d.son_gun<EXCLUDED.son_gun THEN 1 ELSE 0 END)>=3 THEN 'dogrulandi' ELSE d.durum END,
  guncelleme=now();

DELETE FROM bi_sinyal_aday
WHERE tenant_id=:'t'::uuid AND aile='rep-ciro-anomali' AND son_detay->>'olcut'='rep_kat_ciro';

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_REP_KATEGORI_V2','Rep-ciro anomali ham TL -> mix-pay bazina cevrildi (enflasyon-notr; dusus de uretir).',
 'TL enflasyonu ham TL YoY kiyasinda her rep-i sahte artis gosteriyordu. Mix-payinda paydayla sadelesir. Marj zaten % oldugundan dokunulmadi.',
 '{"marker":"SINYAL_REP_KATEGORI_V2","degisen":"rep-ciro-anomali","olcut_eski":"rep_kat_ciro","olcut_yeni":"rep_kat_mix","dosya":"sinyal_motor_ek1.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_REP_KATEGORI_V2');

SELECT aile, yon, count(*) FROM bi_sinyal_aday WHERE aile IN ('rep-ciro-anomali','rep-marj-anomali') GROUP BY 1,2 ORDER BY 1,2;
SELECT aile, deger, yon, round(son_skor) skor, son_detay FROM bi_sinyal_aday WHERE aile IN ('rep-ciro-anomali','rep-marj-anomali') ORDER BY son_skor DESC NULLS LAST LIMIT 15;
