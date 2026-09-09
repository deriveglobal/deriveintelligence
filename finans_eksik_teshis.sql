-- FINANS ODA eksik-metrik kaynak teşhis (READ-ONLY). Placeholder'ların gerçek verisi var mı?
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '===== 1) ÖLÜ STOK (LASTIK, 90g hareketsiz) — değer + adet ====='
SELECT round(sum(bsd.toplam_deger)/1e6,1) olu_deger_m, count(*) sku
  FROM bi_stok_durumu bsd
 WHERE bsd.tenant_id::text=:'t' AND bsd.export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=:'t')
   AND bsd.grup_adi ILIKE 'LASTIK%' AND bsd.eldeki_miktar>0
   AND NOT EXISTS (SELECT 1 FROM bi_stok_hareket h WHERE h.tenant_id::text=:'t' AND h.kalem_kodu=bsd.kalem_kodu AND h.cikis>0 AND h.belge_tarihi>=now()-INTERVAL '90 days');

\echo '===== 2) SİPARİŞ BEKLEYEN — bi_stok_durumu kolonları (siparis/taahhut/yolda var mı?) ====='
SELECT column_name FROM information_schema.columns
 WHERE table_name='bi_stok_durumu' AND column_name ~* 'siparis|taahhut|yolda|bekleyen|gelen';
\echo '  bi_stok_anlik taahhut/kullanilabilir:'
SELECT column_name FROM information_schema.columns
 WHERE table_name='bi_stok_anlik' AND column_name ~* 'siparis|taahhut|yolda|bekleyen|kullanil';

\echo '===== 3) ÖLÇÜLEN TAHSİLAT (bi_tahsilat son12, tutar-ağırlıklı gün) ====='
SELECT round(sum(son12_suresi*son12_tutar)/nullif(sum(son12_tutar),0)) olculen_gun,
       round(sum(son12_gec_orani*son12_tutar)/nullif(sum(son12_tutar),0)) gec_orani_pct,
       round(sum(son12_tutar)/1e6,1) kapsam_ciro_m
  FROM bi_tahsilat WHERE tenant_id::text=:'t' AND musteri_mi AND son12_tutar>0;

\echo '===== 4) FİYAT SIZINTISI (bi_marj_atom son 12 ay, maliyet-altı satış = negatif brüt kâr) ====='
SELECT round(sum(-brut_kar) FILTER (WHERE brut_kar<0)/1e6,1) sizinti_m,
       count(*) FILTER (WHERE brut_kar<0) negatif_kalem,
       round(100.0*count(*) FILTER (WHERE brut_kar<0)/nullif(count(*),0),1) negatif_pct
  FROM bi_marj_atom
 WHERE tenant_id::text=:'t' AND ay > ((SELECT max(ay) FROM bi_marj_atom WHERE tenant_id::text=:'t') - 12*INTERVAL '1 month');
