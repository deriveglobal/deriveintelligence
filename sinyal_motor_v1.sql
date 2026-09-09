-- ============================================================================
-- SINYAL URETICI · FAZ 1 MOTOR v1 · TEKRAR-HAFIZALI OZERK HAVUZ
-- Mimari: derive-sinyal-uretici.md §6 (bi_sinyal_aday = ham keşif havuzu).
-- Ilke (Fatih): "bugun anlamsiz gorunen sorgu 3 gun arayla ayni sonucu veriyorsa anlamli."
--   → yargic tek-tarama z'si DEGIL, FARKLI-gun TEKRARI. Genis ag at, zamana birak.
-- Bu dosya: (1) havuz tablosu (yoksa kurar), (2) tarayici+hafiza tek deyimde upsert,
--   (3) solma sweep, (4) havuz goruntusu. HER GUN kosmali (cron) — bir kez = tohum.
-- Marker: SINYAL_ADAY_HAVUZ_V1
-- ============================================================================
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on
SET lock_timeout = '5s';

-- (1) HAVUZ — yoksa kur (yeni tablo, canli veriye dokunmaz)
CREATE TABLE IF NOT EXISTS bi_sinyal_aday (
  tenant_id   uuid        NOT NULL,
  parmak      text        NOT NULL,          -- aile|boyut|deger|yon (sayi YOK → gunler sonra eslesir)
  aile        text,
  boyut       text,
  deger       text,
  yon         text,                          -- artis | dusus
  ilk_gun     date        NOT NULL,
  son_gun     date        NOT NULL,
  gun_sayisi  int         NOT NULL DEFAULT 1,-- kac FARKLI gunde goruldu (= tekrar kaniti)
  gorulme     int         NOT NULL DEFAULT 1,
  son_z       numeric,
  son_tutar   numeric,
  son_skor    numeric,
  son_detay   jsonb,
  durum       text        NOT NULL DEFAULT 'izleniyor', -- izleniyor | dogrulandi | soldu
  guncelleme  timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (tenant_id, parmak)
);
CREATE INDEX IF NOT EXISTS ix_sinyal_aday_skor ON bi_sinyal_aday(tenant_id, durum, son_skor DESC);

-- (2) TARAYICI + HAFIZA — bulgu uret, parmak-izine gore upsert et
WITH smx AS (
  SELECT sm, extract(month FROM sm)::int cm FROM (
    SELECT CASE WHEN extract(day FROM md)>=26 THEN date_trunc('month',md)
                ELSE date_trunc('month',md)-INTERVAL '1 month' END sm
    FROM (SELECT max(fatura_tarihi) md FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0) q) w),
tot AS (
  SELECT 'satis' fam, date_trunc('month',fatura_tarihi) mo, sum(satir_tutar) tv FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 GROUP BY 2
  UNION ALL SELECT 'alim', date_trunc('month',fatura_tarihi), sum(satir_kdv_haric) FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 GROUP BY 2),
per AS (
  SELECT b, dv, mo, sum(v) v FROM (
    SELECT 'satis:marka' b, upper(marka) dv, date_trunc('month',fatura_tarihi) mo, satir_tutar v FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND marka<>''
    UNION ALL SELECT 'satis:ebat', ebat, date_trunc('month',fatura_tarihi), satir_tutar FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND ebat IS NOT NULL AND ebat<>''
    UNION ALL SELECT 'satis:kanal', satis_kanali, date_trunc('month',fatura_tarihi), satir_tutar FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND satis_kanali IS NOT NULL AND satis_kanali<>''
    UNION ALL SELECT 'satis:sehir', sehir, date_trunc('month',fatura_tarihi), satir_tutar FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND sehir IS NOT NULL AND sehir<>''
    UNION ALL SELECT 'satis:rep', satis_temsilcisi, date_trunc('month',fatura_tarihi), satir_tutar FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND satis_temsilcisi IS NOT NULL AND satis_temsilcisi<>''
    UNION ALL SELECT 'satis:musteri', musteri_adi, date_trunc('month',fatura_tarihi), satir_tutar FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND musteri_adi IS NOT NULL AND musteri_adi<>''
    UNION ALL SELECT 'alim:tedarikci', tedarikci_adi, date_trunc('month',fatura_tarihi), satir_kdv_haric FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND tedarikci_adi IS NOT NULL AND tedarikci_adi<>''
    UNION ALL SELECT 'alim:marka', upper(marka), date_trunc('month',fatura_tarihi), satir_kdv_haric FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND marka IS NOT NULL AND marka<>''
  ) z GROUP BY 1,2,3),
shr AS (
  SELECT p.b, p.dv, p.mo, split_part(p.b,':',1) fam, p.v, p.v/NULLIF(t.tv,0) share, extract(month FROM p.mo)::int cm
  FROM per p JOIN tot t ON t.fam=split_part(p.b,':',1) AND t.mo=p.mo),
sont AS (SELECT t.fam, t.tv FROM tot t, smx WHERE t.mo=smx.sm),
ist AS (
  SELECT s.b, s.dv, s.fam,
    max(s.share) FILTER (WHERE s.mo=(SELECT sm FROM smx))                              son_share,
    max(s.v)     FILTER (WHERE s.mo=(SELECT sm FROM smx))                              son_v,
    avg(s.share) FILTER (WHERE s.mo<(SELECT sm FROM smx) AND s.cm=(SELECT cm FROM smx)) ort_share,
    stddev_pop(s.share) FILTER (WHERE s.mo<(SELECT sm FROM smx) AND s.cm=(SELECT cm FROM smx)) sd,
    count(*)     FILTER (WHERE s.mo<(SELECT sm FROM smx) AND s.cm=(SELECT cm FROM smx)) n
  FROM shr s GROUP BY 1,2,3),
ist2 AS (SELECT i.*, t.tv, i.ort_share*t.tv beklenen, GREATEST(i.sd, 0.10*i.ort_share) denom FROM ist i JOIN sont t ON t.fam=i.fam WHERE i.son_v IS NOT NULL),
-- MARJ
mmax AS (SELECT am, extract(month FROM am)::int cm FROM (SELECT max(ay) am FROM bi_marj_atom WHERE tenant_id::text=:'t') q),
pm AS (
  SELECT b, dv, ay, sum(brut_kar) bk, sum(ciro) c FROM (
    SELECT 'marj:marka' b, upper(marka) dv, ay, brut_kar, ciro FROM bi_marj_atom WHERE tenant_id::text=:'t' AND marka IS NOT NULL AND marka<>''
    UNION ALL SELECT 'marj:kategori', kategori, ay, brut_kar, ciro FROM bi_marj_atom WHERE tenant_id::text=:'t' AND kategori IS NOT NULL AND kategori<>''
  ) z GROUP BY 1,2,3),
im AS (
  SELECT p.b, p.dv,
    (sum(p.bk) FILTER (WHERE p.ay=(SELECT am FROM mmax)))/NULLIF(sum(p.c) FILTER (WHERE p.ay=(SELECT am FROM mmax)),0)*100 son,
    avg(p.bk/NULLIF(p.c,0)*100) FILTER (WHERE p.ay<(SELECT am FROM mmax) AND extract(month FROM p.ay)::int=(SELECT cm FROM mmax)) ort,
    stddev_pop(p.bk/NULLIF(p.c,0)*100) FILTER (WHERE p.ay<(SELECT am FROM mmax) AND extract(month FROM p.ay)::int=(SELECT cm FROM mmax)) sd,
    sum(p.c) FILTER (WHERE p.ay=(SELECT am FROM mmax)) son_ciro,
    count(*) FILTER (WHERE p.ay<(SELECT am FROM mmax) AND extract(month FROM p.ay)::int=(SELECT cm FROM mmax)) n
  FROM pm p GROUP BY 1,2),
-- ZIYARET
zmx AS (SELECT CASE WHEN extract(day FROM md)>=26 THEN date_trunc('month',md) ELSE date_trunc('month',md)-INTERVAL '1 month' END zm
        FROM (SELECT max(ziyaret_tarihi) md FROM saha_ziyaret WHERE tenant_id::text=:'t' AND ziyaret_tarihi IS NOT NULL) q),
zper AS (
  SELECT b, dv, mo, count(*) c FROM (
    SELECT 'ziyaret:tip' b, coalesce(nullif(tip,''),'?') dv, date_trunc('month',ziyaret_tarihi) mo FROM saha_ziyaret WHERE tenant_id::text=:'t' AND durum='TAMAMLANDI' AND ziyaret_tarihi IS NOT NULL
    UNION ALL SELECT 'ziyaret:rep', coalesce(nullif(rep_adi,''),'?'), date_trunc('month',ziyaret_tarihi) FROM saha_ziyaret WHERE tenant_id::text=:'t' AND durum='TAMAMLANDI' AND ziyaret_tarihi IS NOT NULL
  ) z, zmx WHERE mo > zmx.zm - INTERVAL '13 months' AND mo <= zmx.zm GROUP BY 1,2,3),
zist AS (SELECT p.b,p.dv, sum(p.c) FILTER (WHERE p.mo=zmx.zm) son, avg(p.c) FILTER (WHERE p.mo<zmx.zm) ort,
          stddev_pop(p.c) FILTER (WHERE p.mo<zmx.zm) sd, count(*) FILTER (WHERE p.mo<zmx.zm) n FROM zper p, zmx GROUP BY 1,2),
-- RAKIP
rmx AS (SELECT date_trunc('month',max(teklif_tarihi)) rm FROM saha_rakip_teklif WHERE tenant_id::text=:'t' AND rakip_fiyat>0),
rper AS (
  SELECT 'rakip:marka+ebat' b, upper(coalesce(rakip_marka,'?'))||' '||coalesce(ebat,'') dv,
         date_trunc('month',teklif_tarihi) mo, avg(rakip_fiyat) f, count(*) c
    FROM saha_rakip_teklif, rmx WHERE tenant_id::text=:'t' AND rakip_fiyat>0 AND teklif_tarihi IS NOT NULL
     AND date_trunc('month',teklif_tarihi) > rmx.rm - INTERVAL '13 months' AND date_trunc('month',teklif_tarihi) <= rmx.rm GROUP BY 1,2,3),
rist AS (SELECT p.b,p.dv, avg(p.f) FILTER (WHERE p.mo=rmx.rm) son, avg(p.f) FILTER (WHERE p.mo<rmx.rm) ort,
          stddev_pop(p.f) FILTER (WHERE p.mo<rmx.rm) sd, sum(p.c) FILTER (WHERE p.mo=rmx.rm) son_n,
          count(*) FILTER (WHERE p.mo<rmx.rm) n FROM rper p, rmx GROUP BY 1,2),
-- KOHORT domaini (kazanim yili = master_musteri.ilk_fatura; retention = o yil bi_satis alimi; kanal + TUMU)
kmm0 AS (SELECT musteri_kodu, extract(year FROM ilk_fatura)::int cy, upper(coalesce(nullif(trim(satis_kanali),''),'?')) kanal
         FROM master_musteri WHERE tenant_id::text=:'t' AND ilk_fatura IS NOT NULL AND musteri_kodu IS NOT NULL),
kmm AS (SELECT musteri_kodu, cy, kanal FROM kmm0 UNION ALL SELECT musteri_kodu, cy, 'TÜMÜ' FROM kmm0),
kact AS (SELECT DISTINCT musteri_kodu, extract(year FROM fatura_tarihi)::int y FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND musteri_kodu IS NOT NULL),
klcy AS (SELECT (extract(year FROM max(fatura_tarihi))::int - 1) lcy FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0),
ksz AS (SELECT kanal, cy, count(*) sz FROM kmm GROUP BY 1,2),
kret1 AS (SELECT m.kanal, m.cy, count(DISTINCT m.musteri_kodu) FILTER (WHERE a.musteri_kodu IS NOT NULL) ret
          FROM kmm m LEFT JOIN kact a ON a.musteri_kodu=m.musteri_kodu AND a.y=m.cy+1 GROUP BY 1,2),
kr AS (SELECT s.kanal, s.cy, s.sz, 100.0*k.ret/NULLIF(s.sz,0) ret1
       FROM ksz s JOIN kret1 k ON k.kanal=s.kanal AND k.cy=s.cy, klcy WHERE s.cy+1 <= klcy.lcy AND s.sz>=20),
klatest AS (SELECT kanal, max(cy) lcy2 FROM kr GROUP BY 1),
kpeer AS (SELECT k.kanal, avg(k.ret1) ort, stddev_pop(k.ret1) sd, count(*) n FROM kr k JOIN klatest l ON l.kanal=k.kanal WHERE k.cy<l.lcy2 GROUP BY 1),
klat AS (SELECT k.kanal, k.cy, k.ret1, k.sz FROM kr k JOIN klatest l ON l.kanal=k.kanal AND k.cy=l.lcy2),
kohort_ret AS (
  SELECT 'kohort-retention' aile, ('kohort:1yil·'||kl.kanal) boyut, kl.cy::text deger,
         CASE WHEN kl.ret1>=kp.ort THEN 'artis' ELSE 'dusus' END yon, kl.sz tutar,
         (kl.ret1-kp.ort)/NULLIF(GREATEST(kp.sd,3.0),0) z,
         abs((kl.ret1-kp.ort)/NULLIF(GREATEST(kp.sd,3.0),0))*ln(1+kl.sz) skor,
         jsonb_build_object('olcut','1yil_retention','kohort',kl.cy,'kanal',kl.kanal,'ret1_pct',round(kl.ret1)::int,'peer_ort_pct',round(kp.ort)::int,'peer_n',kp.n,'kohort_musteri',kl.sz) detay
  FROM klat kl JOIN kpeer kp ON kp.kanal=kl.kanal
  WHERE kp.n>=2 AND kp.sd IS NOT NULL AND abs((kl.ret1-kp.ort)/NULLIF(GREATEST(kp.sd,3.0),0))>=1.5),
kacq AS (SELECT s.kanal, s.cy, s.sz FROM ksz s, klcy WHERE s.cy <= klcy.lcy),
kacql AS (SELECT kanal, max(cy) lcy3 FROM kacq GROUP BY 1),
kacqp AS (SELECT a.kanal, avg(a.sz::numeric) ort, stddev_pop(a.sz::numeric) sd, count(*) n FROM kacq a JOIN kacql l ON l.kanal=a.kanal WHERE a.cy<l.lcy3 GROUP BY 1),
kacqn AS (SELECT a.kanal, a.cy, a.sz FROM kacq a JOIN kacql l ON l.kanal=a.kanal AND a.cy=l.lcy3),
kohort_acq AS (
  SELECT 'kohort-kazanim' aile, ('kohort:kazanim·'||al.kanal) boyut, al.cy::text deger,
         CASE WHEN al.sz>=ap.ort THEN 'artis' ELSE 'dusus' END yon, al.sz tutar,
         (al.sz-ap.ort)/NULLIF(GREATEST(ap.sd,2.0),0) z,
         abs((al.sz-ap.ort)/NULLIF(GREATEST(ap.sd,2.0),0))*ln(1+al.sz) skor,
         jsonb_build_object('olcut','yillik_kazanim','yil',al.cy,'kanal',al.kanal,'yeni',al.sz,'peer_ort',round(ap.ort)::int,'peer_n',ap.n) detay
  FROM kacqn al JOIN kacqp ap ON ap.kanal=al.kanal
  WHERE ap.n>=2 AND ap.sd IS NOT NULL AND al.sz>=20 AND abs((al.sz-ap.ort)/NULLIF(GREATEST(ap.sd,2.0),0))>=1.5),
-- BIRLESIK BULGU (her aile -> ortak sema; genis ag: |z|>=1.5)
bulgu AS (
  SELECT 'dilim-anomali' aile, b boyut, left(dv,40) deger,
         CASE WHEN son_share>=ort_share THEN 'artis' ELSE 'dusus' END yon,
         son_v tutar, (son_share-ort_share)/NULLIF(denom,0) z,
         abs((son_share-ort_share)/NULLIF(denom,0))*ln(1+son_v) skor,
         jsonb_build_object('olcut','pay','son_m',round(son_v/1e6,2),'beklenen_m',round(beklenen/1e6,2),
           'pct',round(100*(son_v-beklenen)/NULLIF(beklenen,0))::int,'n',n) detay
  FROM ist2 WHERE n>=3 AND beklenen>=200000 AND son_v>500000 AND abs((son_share-ort_share)/NULLIF(denom,0))>=1.5
  UNION ALL
  SELECT 'yeni-yukselen', b, left(dv,40), 'artis', son_v, NULL,
         son_v/1e5, jsonb_build_object('tip','yeni','son_m',round(son_v/1e6,2),'beklenen_m',round(beklenen/1e6,2))
  FROM ist2 WHERE son_v>=1000000 AND beklenen<200000
  UNION ALL
  SELECT 'marj-anomali', b, left(dv,40),
         CASE WHEN son>=ort THEN 'artis' ELSE 'dusus' END, son_ciro, (son-ort)/NULLIF(GREATEST(sd,1.0),0),
         abs((son-ort)/NULLIF(GREATEST(sd,1.0),0))*ln(1+son_ciro),
         jsonb_build_object('olcut','marj_pct','son_pct',round(son,1),'baz_pct',round(ort,1),'n',n)
  FROM im WHERE n>=3 AND son_ciro>1000000 AND abs((son-ort)/NULLIF(GREATEST(sd,1.0),0))>=1.5
  UNION ALL
  SELECT 'ziyaret-hacim', b, left(dv,40), CASE WHEN son>=ort THEN 'artis' ELSE 'dusus' END, NULL,
         (son-ort)/NULLIF(sd,0), abs((son-ort)/NULLIF(sd,0))*ln(1+son),
         jsonb_build_object('olcut','adet','son',round(son),'baz',round(ort),'n',n)
  FROM zist WHERE n>=4 AND son>=15 AND sd>0 AND abs((son-ort)/NULLIF(sd,0))>=1.5
  UNION ALL
  SELECT 'rakip-fiyat', b, left(dv,40), CASE WHEN son>=ort THEN 'artis' ELSE 'dusus' END, NULL,
         (son-ort)/NULLIF(sd,0), abs((son-ort)/NULLIF(sd,0))*ln(1+son_n),
         jsonb_build_object('olcut','rakip_fiyat','son',round(son),'baz',round(ort),'teklif_n',son_n)
  FROM rist WHERE n>=4 AND son_n>=3 AND sd>0 AND abs((son-ort)/NULLIF(sd,0))>=1.5
  UNION ALL SELECT aile,boyut,deger,yon,tutar,z,skor,detay FROM kohort_ret
  UNION ALL SELECT aile,boyut,deger,yon,tutar,z,skor,detay FROM kohort_acq)
INSERT INTO bi_sinyal_aday AS d
  (tenant_id, parmak, aile, boyut, deger, yon, ilk_gun, son_gun, gun_sayisi, gorulme, son_z, son_tutar, son_skor, son_detay, durum, guncelleme)
SELECT :'t'::uuid, aile||'|'||boyut||'|'||deger||'|'||yon, aile, boyut, deger, yon,
       CURRENT_DATE, CURRENT_DATE, 1, 1, round(z,2), tutar, round(skor)::numeric, detay, 'izleniyor', now()
FROM bulgu
ON CONFLICT (tenant_id, parmak) DO UPDATE SET
  gorulme    = d.gorulme + 1,
  gun_sayisi = d.gun_sayisi + (CASE WHEN d.son_gun < EXCLUDED.son_gun THEN 1 ELSE 0 END),
  son_gun    = GREATEST(d.son_gun, EXCLUDED.son_gun),
  son_z      = EXCLUDED.son_z, son_tutar = EXCLUDED.son_tutar, son_skor = EXCLUDED.son_skor,
  son_detay  = EXCLUDED.son_detay,
  durum      = CASE WHEN d.gun_sayisi + (CASE WHEN d.son_gun < EXCLUDED.son_gun THEN 1 ELSE 0 END) >= 3
                    THEN 'dogrulandi' ELSE d.durum END,
  guncelleme = now();

-- (3) SOLMA — 10 gundur tekrar etmeyen aday soldu
UPDATE bi_sinyal_aday SET durum='soldu', guncelleme=now()
WHERE tenant_id=:'t'::uuid AND durum<>'soldu' AND son_gun < CURRENT_DATE - 10;

-- (4) HAVUZ GORUNTUSU
SELECT durum, count(*) adet, round(avg(gun_sayisi),1) ort_gun FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid GROUP BY 1 ORDER BY 1;

SELECT durum, gun_sayisi gun, aile, boyut, left(deger,22) deger, yon,
       round(son_skor) tek_skor, round(son_skor*(1+ln(gun_sayisi))) tekrar_skor, son_detay
FROM bi_sinyal_aday WHERE tenant_id=:'t'::uuid AND durum<>'soldu'
ORDER BY son_skor*(1+ln(gun_sayisi)) DESC LIMIT 30;

-- (5) FINGERPRINT — motor kendini deftere yazar (idempotent; her kosuda guvenli)
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_ADAY_HAVUZ_V1',
 'Sinyal uretici Faz1 motoru: bi_sinyal_aday tekrar-hafizali aday havuzu + cok-domain tarayici upsert (dilim-anomali/yeni-yukselen/marj/ziyaret/rakip). Mevsim+enflasyon direncli (ayni-ay-onceki-yil pay bazi). Ayni parmak 3 ayri gun -> dogrulandi; 10 gun gorulmezse soldu.',
 'Otonom sinyal uretici: yargic tek-tarama z si degil FARKLI-gun tekrari (genis ag, zaman dogrular). Insan yuzeyi bi_sinyal kirlenmesin diye ayri ham havuz (mimari derive-sinyal-uretici.md §6).',
 '{"marker":"SINYAL_ADAY_HAVUZ_V1","tablo":"bi_sinyal_aday","aileler":["dilim-anomali","yeni-yukselen","marj-anomali","ziyaret-hacim","rakip-fiyat"],"kosum":"gunluk cron 08:40","dosya":"sinyal_motor_v1.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_ADAY_HAVUZ_V1');

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_KOHORT_DOMAIN_V1',
 'Sinyal motoruna KOHORT domaini: kazanim yili (master_musteri.ilk_fatura) x kanal(+TUMU) kohortlari; son tam kohortun 1-yil retention ve yillik kazanim hacmi, gecmis kohortlarin ayni-yas dagilimina gore z-anomali. bi_sinyal_aday havuzuna akar (tekrar-hafiza).',
 'Fatih: Yonetici Portfoy kohort ekrani statikti; kohort-decay/kazanim dususu sinyallerini SISTEM kendi bulsun (aile #4 Kohort & yasam-dongusu).',
 '{"marker":"SINYAL_KOHORT_DOMAIN_V1","aileler":["kohort-retention","kohort-kazanim"],"kaynak":["master_musteri.ilk_fatura","bi_satis_faturalari"],"dosya":"sinyal_motor_v1.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_KOHORT_DOMAIN_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'bi_sinyal_aday','tablo',
 'Otonom sinyal uretici ham aday havuzu (FDR-oncesi). Cok-domain dilim anomalileri parmak-izi ile birikir; ayni parmak farkli gunlerde tekrar edince gun_sayisi artar, 3 ayri gun -> durum=dogrulandi (tekrar=dogruluk). 10 gun gorulmezse soldu. Terfi hedefi bi_sinyal (insan yuzeyi).',
 'Gunluk kosulan sinyal_motor_v1.sql INSERT..ON CONFLICT ile doldurur. Okuma: SELECT ... WHERE tenant_id=? AND durum=''dogrulandi'' ORDER BY son_skor*(1+ln(gun_sayisi)) DESC.',
 'sinyal','canli','taslak',
 '{"marker":"SINYAL_ADAY_HAVUZ_V1","kolon":["parmak","gun_sayisi","durum","son_skor","son_detay"],"terfi_hedefi":"bi_sinyal"}'::jsonb,
 true, now(), now(), now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='bi_sinyal_aday');

UPDATE bi_yetenek SET ne_ise_yarar='Otonom sinyal uretici ham aday havuzu (FDR-oncesi); parmak-izi tekrar-hafizasi, ayni parmak 3 ayri gun -> dogrulandi. Terfi hedefi bi_sinyal.',
  cekmece='sinyal', durum='canli', guncellendi_at=now()
WHERE ad='bi_sinyal_aday' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
