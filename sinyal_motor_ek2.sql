-- SINYAL URETICI · EK2 · KORELASYON AVCISI (musteri-duzeyi kategori birlikteligi -> capraz-satis)
-- Marker: SINYAL_KORELASYON_V1 · gunluk cron · ayni bi_sinyal_aday havuzu.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
SET lock_timeout='8s';
WITH
cust AS (
  SELECT f.musteri_kodu mk, f.kategori kat, sum(f.satir_tutar) v
  FROM bi_satis_faturalari f
  WHERE f.tenant_id::text=:'t' AND f.satir_tutar>0 AND f.musteri_kodu IS NOT NULL AND f.kategori IS NOT NULL AND f.kategori<>''
    AND f.fatura_tarihi >= CURRENT_DATE - INTERVAL '24 months'
    AND NOT EXISTS (SELECT 1 FROM bi_musteri_risk _mr WHERE _mr.tenant_id::text=f.tenant_id::text AND _mr.muhatap_kodu=f.musteri_kodu AND _mr.grup IN ('TEDARİKÇİ','IMALATCI','PERSONEL','GRUP MUSTERILERI'))
  GROUP BY 1,2),
book AS (SELECT mk, sum(v) tv FROM cust GROUP BY 1),
tot  AS (SELECT count(*) n FROM book),
cn   AS (SELECT kat, count(*) c FROM cust GROUP BY 1 HAVING count(*)>=50),
pr   AS (SELECT a.kat ka, b.kat kb, count(*) both_n
         FROM cust a JOIN cust b ON a.mk=b.mk AND a.kat<b.kat
         WHERE a.kat IN (SELECT kat FROM cn) AND b.kat IN (SELECT kat FROM cn)
         GROUP BY 1,2 HAVING count(*)>=30),
lift AS (
  SELECT p.ka, p.kb, p.both_n, ca.c ca_n, cb.c cb_n,
    (p.both_n::numeric*(SELECT n FROM tot))/NULLIF(ca.c::numeric*cb.c,0) lift,
    (p.both_n - ca.c::numeric*cb.c/(SELECT n FROM tot))
      /NULLIF(sqrt(ca.c::numeric*cb.c/(SELECT n FROM tot)*GREATEST(1-ca.c::numeric/(SELECT n FROM tot),0.0001)*GREATEST(1-cb.c::numeric/(SELECT n FROM tot),0.0001)),0) z
  FROM pr p JOIN cn ca ON ca.kat=p.ka JOIN cn cb ON cb.kat=p.kb),
surv AS (
  SELECT * FROM lift
  WHERE lift>=1.5 AND z>=5
    AND NOT ( (SELECT array_agg(w) FROM unnest(string_to_array(upper(ka),' ')) w WHERE length(w)>=3)
              && (SELECT array_agg(w) FROM unnest(string_to_array(upper(kb),' ')) w WHERE length(w)>=3) )),
anb AS (
  SELECT s.ka, s.kb, count(DISTINCT ca.mk) n, coalesce(sum(bk.tv),0) bok
  FROM surv s JOIN cust ca ON ca.kat=s.ka JOIN book bk ON bk.mk=ca.mk
  WHERE NOT EXISTS (SELECT 1 FROM cust cx WHERE cx.mk=ca.mk AND cx.kat=s.kb) GROUP BY 1,2),
bna AS (
  SELECT s.ka, s.kb, count(DISTINCT cb.mk) n, coalesce(sum(bk.tv),0) bok
  FROM surv s JOIN cust cb ON cb.kat=s.kb JOIN book bk ON bk.mk=cb.mk
  WHERE NOT EXISTS (SELECT 1 FROM cust cx WHERE cx.mk=cb.mk AND cx.kat=s.ka) GROUP BY 1,2),
bulgu AS (
  SELECT 'capraz-satis' aile, 'capraz:kategori' boyut, left(s.ka||' + '||s.kb,60) deger, 'firsat' yon,
    GREATEST(coalesce(a.bok,0),coalesce(b.bok,0)) tutar, s.z,
    s.z*ln(1+GREATEST(coalesce(a.bok,0),coalesce(b.bok,0))) skor,
    jsonb_build_object(
      'olcut','lift_capraz','lift',round(s.lift,2),'z',round(s.z,1),'birlikte_n',s.both_n,
      'A',s.ka,'B',s.kb,'A_n',s.ca_n,'B_n',s.cb_n,
      'oner', CASE WHEN coalesce(a.bok,0)>=coalesce(b.bok,0) THEN 'sat:'||s.kb||' ('||s.ka||' alanlara)'
                                                            ELSE 'sat:'||s.ka||' ('||s.kb||' alanlara)' END,
      'A_alip_B_yok_n', coalesce(a.n,0), 'A_alip_B_yok_kitap_m', round(coalesce(a.bok,0)/1e6,1),
      'B_alip_A_yok_n', coalesce(b.n,0), 'B_alip_A_yok_kitap_m', round(coalesce(b.bok,0)/1e6,1)
    ) detay
  FROM surv s LEFT JOIN anb a ON a.ka=s.ka AND a.kb=s.kb LEFT JOIN bna b ON b.ka=s.ka AND b.kb=s.kb)
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

UPDATE bi_sinyal_aday SET durum='soldu', guncelleme=now()
WHERE tenant_id=:'t'::uuid AND aile='capraz-satis' AND durum<>'soldu' AND son_gun < CURRENT_DATE - 10;

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_KORELASYON_V1','Korelasyon avcisi: musteri-duzeyi kategori-birlikteligi (lift+z) -> YENILIK filtresi (ortak kelime-koku elenir) -> capraz-satis boslugu (hedef hesap kitabi TL). Sistem cift-uzayini kendi tarar.',
 '39k musteri = istatistik gucu. Bar: lift>=1.5, z>=5, support>=50/30, ortak-kelime elenir (agnostik). TL=hedef hesaplarin TOPLAM kitabi (donusum degil).',
 '{"marker":"SINYAL_KORELASYON_V1","aile":"capraz-satis","olcut":"lift_capraz","yenilik_filtresi":"kelime-ortusme","dosya":"sinyal_motor_ek2.sql","havuz":"bi_sinyal_aday"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_KORELASYON_V1');

SELECT count(*) capraz_aday FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND aile='capraz-satis';
SELECT deger, round(son_tutar/1e6,1) hedef_kitap_m, round(son_skor) skor, son_detay->>'lift' lift, son_detay->>'oner' oneri
FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND aile='capraz-satis' ORDER BY son_skor DESC NULLS LAST LIMIT 15;
