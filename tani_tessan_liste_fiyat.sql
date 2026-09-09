-- TANI — Ali Kemal / Tessan teklifinde liste fiyati gelmiyor. master_urun eslesme + fiyat listesi kontrolu.
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_tessan_liste_fiyat.sql

\pset pager off

-- A) Ali Kemal'in Tessan teklif kalemleri + master_urun karsiligi (liste_fiyati / eslesme_durumu)
SELECT t.created_at::date tarih, t.durum,
       k.kalem_kodu, k.marka, k.ebat,
       k.liste_fiyati AS teklif_liste, k.birim_fiyat AS teklif_birim, k.musteri_ek_iskonto_pct AS isk,
       mu.liste_fiyati AS master_liste, mu.eslesme_durumu, mu.ebat_norm, mu.liste_tarihi
  FROM saha_teklif t
  JOIN saha_teklif_kalem k ON k.teklif_id = t.id
  JOIN users u ON u.id = t.rep_id
  LEFT JOIN master_urun mu ON mu.tenant_id = t.tenant_id AND mu.kalem_kodu = k.kalem_kodu
 WHERE t.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND t.firma ILIKE '%tessan%'
   AND (u.full_name ILIKE '%Ali Kemal%' OR u.email ILIKE '%alikemal%')
 ORDER BY t.created_at DESC LIMIT 15;

-- B) Bu ebatlar AKTIF fiyat listesinde var mi? (master eslesmese bile fiyat listede duruyor mu)
SELECT fk.ebat, fk.urun_kodu, fk.desen, fk.liste_fiyati, fu.liste_tarihi, fu.aktif
  FROM bi_fiyat_listesi_kalemler fk
  JOIN bi_fiyat_listesi_uploads  fu ON fu.id = fk.upload_id
 WHERE fk.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND fu.aktif = true
   AND fk.ebat IN (
     SELECT DISTINCT k.ebat FROM saha_teklif t
       JOIN saha_teklif_kalem k ON k.teklif_id = t.id
       JOIN users u ON u.id = t.rep_id
      WHERE t.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
        AND t.firma ILIKE '%tessan%'
        AND (u.full_name ILIKE '%Ali Kemal%' OR u.email ILIKE '%alikemal%'))
 ORDER BY fk.ebat, fk.liste_fiyati LIMIT 40;

-- C) master_urun'da liste_fiyati NULL olan ama YOK/EBAT eslesen urun sayaci (genel resim)
SELECT eslesme_durumu, COUNT(*) n, COUNT(*) FILTER (WHERE liste_fiyati IS NULL) liste_bos
  FROM master_urun WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
 GROUP BY eslesme_durumu ORDER BY n DESC;
