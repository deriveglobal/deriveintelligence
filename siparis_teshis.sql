-- SİPARİŞ BEKLEYEN teşhis (READ-ONLY). Proxy değeri sağlıklı mı? Daha iyi maliyet kolonu var mı?
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'

\echo '===== 1) bi_stok_durumu maliyet/deger kolonlari (birim_maliyet var mi?) ====='
SELECT column_name FROM information_schema.columns
 WHERE table_name='bi_stok_durumu' AND column_name ~* 'maliyet|deger|fiyat|birim|siparis|eldeki';

\echo '===== 2) siparis bekleyen — proxy deger + adet + eldeki=0 kac SKU (eksik sayilan) ====='
SELECT round(sum(siparis_miktar * CASE WHEN eldeki_miktar>0 THEN toplam_deger/eldeki_miktar ELSE 0 END)/1e6,2) proxy_deger_m,
       round(sum(siparis_miktar))::int toplam_adet,
       count(*) FILTER (WHERE siparis_miktar>0) siparisli_sku,
       count(*) FILTER (WHERE siparis_miktar>0 AND (eldeki_miktar IS NULL OR eldeki_miktar=0)) eldeki_sifir_sku,
       round(sum(siparis_miktar) FILTER (WHERE eldeki_miktar IS NULL OR eldeki_miktar=0))::int eldeki_sifir_adet
  FROM bi_stok_durumu
 WHERE tenant_id::text=:'t' AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=:'t')
   AND grup_adi ILIKE 'LASTIK%';

\echo '===== 3) siparis_miktar dagilimi — gercekten dolu mu, ornek satirlar ====='
SELECT kalem_kodu, marka, round(siparis_miktar) siparis, round(eldeki_miktar) eldeki, round(toplam_deger) deger
  FROM bi_stok_durumu
 WHERE tenant_id::text=:'t' AND export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=:'t')
   AND grup_adi ILIKE 'LASTIK%' AND siparis_miktar>0
 ORDER BY siparis_miktar DESC LIMIT 8;

\echo '===== 4) daha iyi maliyet: tedarikci son alis fiyati (bi_tedarikci_faturalari) ile deger ====='
WITH sa AS (SELECT DISTINCT ON (bi_sku_norm(kalem_kodu)) bi_sku_norm(kalem_kodu) sku, birim_fiyat_kdv_haric fiyat
              FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND birim_fiyat_kdv_haric>0
             ORDER BY 1, fatura_tarihi DESC)
SELECT round(sum(s.siparis_miktar*sa.fiyat)/1e6,2) tedarikci_maliyet_deger_m
  FROM bi_stok_durumu s LEFT JOIN sa ON sa.sku=bi_sku_norm(s.kalem_kodu)
 WHERE s.tenant_id::text=:'t' AND s.export_date=(SELECT max(export_date) FROM bi_stok_durumu WHERE tenant_id::text=:'t')
   AND s.grup_adi ILIKE 'LASTIK%' AND s.siparis_miktar>0;
