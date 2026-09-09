-- Footprint — MUSTERI_HATIRLATMA_DUZENLE_V2 + MUSTERI_OLAYLAR_ZIYARET_FIX_V1 + MUSTERI_OLAYLAR_ZIYARET_TIK_V1
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < footprint_ziyaret_olaylar.sql

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT v.adim, v.ne, v.neden, v.detay::jsonb
FROM (VALUES
  ('MUSTERI_HATIRLATMA_DUZENLE_V2',
   'Hatirlatma duzenleme modali artik Musteri Kartini EZMIYOR. V1 modal() tek #saha-modal konteynerini eziyordu → kart kayboluyordu. V2: karti ezmeyen katmanli overlay (#saha-modal''e ikinci .modal-fon child, z-index:70), kapaninca yalniz kendini kaldirir; PUT sonrasi _mkYukle() karti yerinde yeniler.',
   'Kullanici (Fatih): "closes customer card, no way to go back, card disappears". Kok-neden: modal() innerHTML ezmesi.',
   '{"marker":"MUSTERI_HATIRLATMA_DUZENLE_V2","dosya":["shells/saha.js"]}'),
  ('MUSTERI_OLAYLAR_ZIYARET_FIX_V1',
   '/api/saha/musteriler/:id/olaylar ziyaret alt-sorgusu duzeltildi. Onceden var olmayan iki kolon (lokasyon_adi, foto_sayisi) seciliyordu → sorgu "column does not exist" atip q() ile yutuluyor, HAREKETLER''de ziyaretler bos kaliyordu (sayac COUNT''tan geldigi icin dolu gorunuyordu). Fix: LEFT JOIN saha_musteri_lokasyon l (l.ad AS lokasyon_adi) + (SELECT count(*) FROM saha_ziyaret_foto) alt-sorgusu + z.id.',
   'Kullanici (Fatih): "card counts visits but no visits are listed". Bagimsiz, onceden var olan sessiz hata.',
   '{"marker":"MUSTERI_OLAYLAR_ZIYARET_FIX_V1","dosya":["server_container.mjs"],"tablo":["saha_ziyaret","saha_musteri_lokasyon","saha_ziyaret_foto"]}'),
  ('MUSTERI_OLAYLAR_ZIYARET_TIK_V1',
   'Musteri Karti "Hareketler"de ziyaret satiri tiklanabilir. Fatih secimi: kartin ustunde katman (kart yerinde kalir). Overlay: tarih/temsilci/konum/katilimcilar + tam not + fotograflar (fotoUrl/fotoBuyut) + "Ziyaret detayini ac" → tam ziyaretDetayModal. Server o.zid (ZIYARET_FIX_V1) uzerinden.',
   'Ozellik (Fatih): "add same feature to visits as well". Hatirlatma tiklama ozelliginin ziyaret karsiligi.',
   '{"marker":"MUSTERI_OLAYLAR_ZIYARET_TIK_V1","dosya":["shells/saha.js"],"payload":"olaylar[].zid"}')
) AS v(adim, ne, neden, detay)
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu g WHERE g.adim = v.adim);

SELECT adim, ts::date FROM bi_insa_gunlugu
 WHERE adim IN ('MUSTERI_HATIRLATMA_DUZENLE_V2','MUSTERI_OLAYLAR_ZIYARET_FIX_V1','MUSTERI_OLAYLAR_ZIYARET_TIK_V1')
 ORDER BY adim;
