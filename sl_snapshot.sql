SELECT 'satis' AS t, count(*) AS n, max(fatura_tarihi)::date AS son FROM bi_satis_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL SELECT 'tedarikci', count(*), max(fatura_tarihi)::date FROM bi_tedarikci_faturalari WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL SELECT 'stok_hareket', count(*), max(belge_tarihi)::date FROM bi_stok_hareket WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL SELECT 'stok_anlik', count(*), NULL FROM bi_stok_anlik WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL SELECT 'cari_bakiye', count(*), NULL FROM bi_cari_bakiye WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL SELECT 'musteri_risk_KONTROL', count(*), NULL FROM bi_musteri_risk WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
UNION ALL SELECT 'marj_atom', count(*), max(ay) FROM bi_marj_atom WHERE tenant_id::text='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
ORDER BY 1;
