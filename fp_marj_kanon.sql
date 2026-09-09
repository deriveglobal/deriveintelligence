-- FINGERPRINT — MARJ_KANON_AKIS_V1 (maliyet kanonu canlı)
-- Calistir:  cat fp_marj_kanon.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'MARJ_KANON_AKIS_V1',
 'metrik_marj_atom_uret maliyet mantigi AKIS yontemine cevrildi: maliyet(SKU,ay)= o ay satilan adet kadar en son alim LOTLARININ adet-agirlikli ort. (sinir lotu kismi agirlik; N=satilan adet, sihirli parametre yok; MAL_GIRISI/ACILIS). Eski son-alis-ayi yontemi kirilgandi (9 adetlik lot 534 satisin marjini yonetiyordu). Sonuc: birim_maliyet/brut_kar/marj_pct/kesin_net app-geneli (69 tuketici) kanon; gunluk 08:15 metrik_snapshot_gunluk.sh PERFORM ile otomatik tazeleniyor. Cost disi (satis gruplama, tesvik LATERAL, tum kolonlar) DEGISMEDI.',
 'Kokpit/finans/portfoyum farkli+kirilgan maliyet tabaniyla TUTARSIZ ve YANILTICI marj gosteriyordu; sahte marj cokusu (son ay %2) gercek degildi, kirilgan maliyettendi. Fatih: uygulama her yerde ayni + gercek sayiyi soylesin.',
 '{"marker":"MARJ_KANON_AKIS_V1","fonksiyon":"metrik_marj_atom_uret","yontem":"akis: satilan-adet kadar son alim lotu, adet-agirlikli, sinir kismi","kaynak_maliyet":["bi_stok_hareket(MAL_GIRISI/ACILIS)"],"etki":"birim_maliyet/brut_kar/marj_pct/kesin_net; 69 atom tuketici; gunluk rebuild","dogrulama":{"bridgestone_656876":"-20.7 -> +7.2","aylik_cokus":"2026-05..07 %4.2/3.7/2.0 -> %10.1/7.6/6.3","genel_marj":"%11.5","negatif_pct":"19.3"},"acik":["bu-ay(cari ay) atom disi hala ayrisik","tesvik verisi seyrek(6 marka 2026) - marj TESVIK ONCESI"],"yedek":"metrik_marj_atom_uret.BAK.sql"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='MARJ_KANON_AKIS_V1');

-- bi_yetenek: fonksiyon yetenegini guncelle (varsa) / ekle
UPDATE bi_yetenek SET nasil='metrik_marj_atom_uret(tenant,ay_geri): bi_marj_atom kanonik uretim — maliyet AKIS yontemi (satilan-adet kadar son alim lotu, adet-agirlikli)',
  kanit='{"marker":"MARJ_KANON_AKIS_V1"}'::jsonb, guncellendi_at=now(), son_gorulme=now()
WHERE ad='metrik_marj_atom_uret';
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'metrik_marj_atom_uret','fonksiyon','Kanonik marj/maliyet uretimi — TEK kaynak: bi_marj_atom (birim_maliyet/brut_kar/marj_pct/kesin_net). Tum marj yuzeyleri buradan okur.','AKIS maliyeti (satilan-adet kadar son alim lotu, adet-agirlikli, sinir kismi); gunluk 08:15 rebuild','finans','canli','kanitli','{"marker":"MARJ_KANON_AKIS_V1"}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='metrik_marj_atom_uret');

SELECT adim, ne_kadar_once FROM (SELECT adim, now()-eklendi_at ne_kadar_once FROM bi_insa_gunlugu WHERE adim='MARJ_KANON_AKIS_V1') x;
SELECT ad, durum FROM bi_yetenek WHERE ad='metrik_marj_atom_uret';
