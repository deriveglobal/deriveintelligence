-- TANI — saha_musteri profil kolonlari VAR MI + ziyaret detay doluyor mu (rakip/raf profili kaydedilmiyor)
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_musteri_profil_kolon.sql
\pset pager off
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- 1) saha_musteri'de hangi profil kolonlari VAR? (bos donen = YOK; PUT o kolona yazamaz → profil kaydolmaz)
SELECT column_name, data_type
  FROM information_schema.columns
 WHERE table_schema='public' AND table_name='saha_musteri'
   AND column_name IN ('raf_markalar','bayilikler','rakip_toptancilar','kis_stok','yaz_stok',
                       'kullanilan_markalar','sektorler','tedarikci_markalar','arac_parki','yillik_potansiyel')
 ORDER BY column_name;

-- 2) Son 10 tamamlanan TUKETICI ziyaretinde detay (raf/rakip) gercekten dolu mu? (ziyaret kaydinda)
SELECT z.ziyaret_tarihi::date, LEFT(m.firma,22) firma,
       z.detay->'raf_markalari' AS raf, z.detay->'rakipler' AS rakip, z.detay->'bayilikler' AS bayi
  FROM saha_ziyaret z JOIN saha_musteri m ON m.id=z.musteri_id
 WHERE z.tenant_id=:T AND z.durum='TAMAMLANDI' AND m.tip='TUKETICI'
 ORDER BY z.created_at DESC LIMIT 10;
