-- TANI v2 — Ali Kemal / Tessan: liste fiyati neden gelmiyor? (teklif→musteri musteri_id ile)
--   ssh root@5.161.234.59 "docker exec -i krb-assessment-postgres sh -c 'PGPASSWORD=\$POSTGRES_PASSWORD psql -U assessment_app -d assessment_platform'" < tani_tessan_liste_fiyat2.sql
\pset pager off
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

-- A) Tessan teklif kalemleri + master eslesme (master_liste bos + eslesme=YOK ise sebep dogrulandi)
SELECT t.created_at::date tarih, t.durum, m.firma,
       k.kalem_kodu, k.marka, k.ebat,
       k.liste_fiyati AS teklif_liste, k.birim_fiyat AS teklif_birim, k.musteri_ek_iskonto_pct AS isk,
       mu.liste_fiyati AS master_liste, mu.eslesme_durumu
  FROM saha_teklif t
  JOIN saha_musteri m ON m.id = t.musteri_id
  JOIN users u ON u.id = t.rep_id
  LEFT JOIN saha_teklif_kalem k ON k.teklif_id = t.id
  LEFT JOIN master_urun mu ON mu.tenant_id = t.tenant_id AND mu.kalem_kodu = k.kalem_kodu
 WHERE t.tenant_id = :T AND m.firma ILIKE '%tessan%'
   AND (u.full_name ILIKE '%Ali Kemal%' OR u.email ILIKE '%alikemal%')
 ORDER BY t.created_at DESC LIMIT 20;

-- B) Aktif fiyat listesi yuklemeleri (marka bazinda) — ilgili marka yuklu ve aktif mi?
SELECT UPPER(marka) AS marka, aktif, liste_tarihi
  FROM bi_fiyat_listesi_uploads
 WHERE tenant_id = :T AND aktif = true
 ORDER BY marka;

-- C) Tessan urunlerinin kalem_kodu'su aktif listede numeric-eslesir mi? (bos = kod tutmuyor / marka yuklu degil)
WITH kodlar AS (
  SELECT DISTINCT k.kalem_kodu, k.marka
    FROM saha_teklif t JOIN saha_musteri m ON m.id=t.musteri_id JOIN users u ON u.id=t.rep_id
    JOIN saha_teklif_kalem k ON k.teklif_id=t.id
   WHERE t.tenant_id = :T AND m.firma ILIKE '%tessan%'
     AND (u.full_name ILIKE '%Ali Kemal%' OR u.email ILIKE '%alikemal%')
)
SELECT kd.kalem_kodu, kd.marka,
       ltrim(regexp_replace(kd.kalem_kodu,'\D','','g'),'0') AS kod_num,
       fk.urun_kodu, fk.ebat, fk.desen, fk.liste_fiyati, UPPER(fu.marka) AS liste_marka, fu.liste_tarihi
  FROM kodlar kd
  LEFT JOIN bi_fiyat_listesi_uploads fu
    ON fu.tenant_id = :T AND fu.aktif = true AND UPPER(fu.marka) = UPPER(kd.marka)
  LEFT JOIN bi_fiyat_listesi_kalemler fk
    ON fk.upload_id = fu.id
   AND length(regexp_replace(COALESCE(fk.urun_kodu,''),'\D','','g')) >= 4
   AND ltrim(regexp_replace(kd.kalem_kodu,'\D','','g'),'0') = ltrim(regexp_replace(fk.urun_kodu,'\D','','g'),'0')
 ORDER BY kd.kalem_kodu LIMIT 40;
