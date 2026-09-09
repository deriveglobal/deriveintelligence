-- GÜVENLİK DENETİMİ: bugünkü onboarding MEVCUT reptlerin (Eftal/Hüseyin) verisine dokundu mu?
\pset pager off
\echo '== 1) BUGÜN DEN ÖNCE oluşturulmuş ama BUGÜN updated_at olan müşteri (dokunulmuş olabilir) =='
SELECT count(*) AS bugun_guncellenen_eski_musteri
 FROM saha_musteri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND created_at::date < current_date AND updated_at::date = current_date;
\echo '   -- (varsa) hangileri:'
SELECT id, firma, il, musteri_kodu, sorumlu_rep, created_at::date, updated_at::date
 FROM saha_musteri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND created_at::date < current_date AND updated_at::date = current_date
 ORDER BY updated_at DESC LIMIT 50;
\echo '== 2) MEVCUT reptlerin (Eftal/Hüseyin) müşteri sayısı + ERP link — DEĞİŞMEDİ doğrulaması =='
SELECT sorumlu_rep,
       count(*) AS musteri,
       count(*) FILTER (WHERE musteri_kodu IS NOT NULL) AS erp_link
 FROM saha_musteri
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND sorumlu_rep IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
 GROUP BY sorumlu_rep;
\echo '== 3) Eftal/Hüseyin ziyaretleri — sayı DEĞİŞMEDİ (kendi kaynakları) =='
SELECT rep_id, count(*) AS ziyaret, max(updated_at)::date AS son_guncelleme
 FROM saha_ziyaret
 WHERE tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND rep_id IN ('ae0c55f9-68cc-421d-96d9-409222452f1a','80fff50c-ffc7-4623-a382-a814263609c4')
 GROUP BY rep_id;
\echo '== 4) Bugün ESKİ müşterilere eklenen öneri (benim eklediğim) — mevcut kaydı etkiledi mi =='
SELECT count(*) AS eski_musteriye_bugun_oneri
 FROM saha_eslestirme_oneri o JOIN saha_musteri m ON m.id=o.saha_musteri_id
 WHERE o.tenant_id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
   AND m.created_at::date < current_date AND o.created_at::date = current_date;
