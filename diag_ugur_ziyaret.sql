-- diag_ugur_ziyaret.sql — READ-ONLY. Ugur Yildiz'in ziyaret ekranindaki 2 yabanci kaydin kaynagi.
\set ON_ERROR_STOP off
\pset pager off
\echo '==================== 1) UGUR HESABI ===================='
SELECT id, email::text AS email, full_name, name
  FROM users WHERE lower(email::text)='uyildiz@krb.com.tr';

\echo '==================== 2) UGUR rep_id ILE BAGLI TUM ZIYARETLER ===================='
SELECT z.id AS ziyaret_id, z.rep_adi AS ziyaretteki_rep_adi, m.firma, m.il,
       z.tip, z.durum, z.kaynak, z.planlanan_tarih, z.ziyaret_tarihi, z.checkin_at, z.created_at,
       left(coalesce(z.notlar,''),90) AS notlar90, z.katilimci
  FROM saha_ziyaret z
  JOIN users ux ON ux.id = z.rep_id
  LEFT JOIN saha_musteri m ON m.id = z.musteri_id
 WHERE lower(ux.email::text)='uyildiz@krb.com.tr'
 ORDER BY z.created_at DESC;

\echo '==================== 3) BU MUSTERILERIN KAYDI (sahiplik / kaynak) ===================='
SELECT m.id AS musteri_id, m.firma, m.il, m.kayit_kaynagi, m.musteri_kodu, m.created_at,
       m.sorumlu_rep, ru.full_name AS sorumlu_rep_ad
  FROM saha_musteri m
  LEFT JOIN users ru ON ru.id = m.sorumlu_rep
 WHERE m.id IN (SELECT z.musteri_id FROM saha_ziyaret z JOIN users ux ON ux.id=z.rep_id
                WHERE lower(ux.email::text)='uyildiz@krb.com.tr');

\echo '==================== 4) AYNI MUSTERILERE BASKA REPLER DE ZIYARET ETMIS MI? ===================='
SELECT m.firma, m.il, COALESCE(u.full_name,u.email::text,'?') AS rep, count(*) AS ziyaret,
       min(z.created_at) AS ilk, max(z.created_at) AS son
  FROM saha_ziyaret z
  JOIN saha_musteri m ON m.id = z.musteri_id
  LEFT JOIN users u ON u.id = z.rep_id
 WHERE z.musteri_id IN (SELECT z2.musteri_id FROM saha_ziyaret z2 JOIN users ux ON ux.id=z2.rep_id
                        WHERE lower(ux.email::text)='uyildiz@krb.com.tr')
 GROUP BY m.firma, m.il, rep
 ORDER BY m.firma, ziyaret DESC;
\echo '==================== BITTI ===================='
