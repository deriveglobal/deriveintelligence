-- FINANS ÖRÜNTÜ — VERİ YÜZEYİ ENVANTERİ (READ-ONLY). "Mükemmel" katman = önce tam veri haritası.
-- Alım/satım/vade/sipariş/ön-sipariş açılarının hangi tablo+kolon+terim+tarih aralığında yaşadığını çıkarır.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '################ 1) İLGİLİ TABLOLAR (sipariş/satış/alım/stok/cari) ################'
SELECT table_name
  FROM information_schema.tables
 WHERE table_schema='public'
   AND (table_name ~* 'siparis|order|satin|alim|preorder|on_sip|satis|tedarikci|fatura|stok|cari|musteri_risk|marj_atom|tahsilat')
 ORDER BY table_name;

\echo '################ 2) ÇEKİRDEK TABLOLARIN KOLONLARI ################'
SELECT table_name, ordinal_position pos, column_name, data_type
  FROM information_schema.columns
 WHERE table_schema='public'
   AND table_name IN ('bi_satis_faturalari','bi_tedarikci_faturalari','bi_on_siparis',
                      'bi_stok_durumu','bi_stok_hareket','bi_musteri_risk','bi_cari_bakiye','bi_marj_atom','bi_tahsilat')
 ORDER BY table_name, ordinal_position;

\echo '################ 3) HACİM + TARİH ARALIĞI (çekirdek işlem tabloları) ################'
\echo '--- 3a) bi_satis_faturalari (SATIŞ) ---'
SELECT count(*) satir, count(DISTINCT musteri_kodu) musteri, count(DISTINCT kalem_kodu) sku,
       to_char(min(fatura_tarihi),'YYYY-MM-DD') ilk, to_char(max(fatura_tarihi),'YYYY-MM-DD') son
  FROM bi_satis_faturalari WHERE tenant_id::text=:'t';
\echo '--- 3b) bi_tedarikci_faturalari (ALIM) ---'
SELECT count(*) satir, to_char(min(fatura_tarihi),'YYYY-MM-DD') ilk, to_char(max(fatura_tarihi),'YYYY-MM-DD') son
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t';
\echo '--- 3c) bi_on_siparis (SEZON ÖN-SİPARİŞ) — kolon başına dolu-sayısı için önce 4 örnek satır ---'
SELECT * FROM bi_on_siparis WHERE tenant_id::text=:'t' LIMIT 4;
\echo '--- 3c2) bi_on_siparis hacim ---'
SELECT count(*) satir FROM bi_on_siparis WHERE tenant_id::text=:'t';

\echo '################ 4) TERİM SÖZLÜĞÜ — SATIŞ vadesi (odeme_kosulu) son 12 ay ################'
SELECT COALESCE(NULLIF(TRIM(odeme_kosulu),''),'—') satis_vade, count(*) n, round(sum(satir_tutar)/1e6,1) tutar_m
  FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1 ORDER BY tutar_m DESC LIMIT 25;

\echo '################ 5) TERİM SÖZLÜĞÜ — ALIM vadesi (vade_turu) son 12 ay ################'
SELECT COALESCE(NULLIF(TRIM(vade_turu),''),'—') alim_vade, count(*) n, round(sum(satir_kdv_haric)/1e6,1) tutar_m
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1 ORDER BY tutar_m DESC LIMIT 25;

\echo '################ 6) SATIŞ MEVSİMSELLİĞİ — aylık ciro + adet (12 ay, sezon örüntüsü) ################'
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay,
       round(sum(satir_tutar)/1e6,2) ciro_m, round(sum(miktar))::int adet
  FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND grup_adi LIKE 'LASTIK%'
   AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-INTERVAL '13 month'
 GROUP BY 1 ORDER BY 1;

\echo '################ 7) ALIM MEVSİMSELLİĞİ — aylık alım tutarı + adet (12 ay) ################'
SELECT to_char(date_trunc('month',fatura_tarihi),'YYYY-MM') ay,
       round(sum(satir_kdv_haric)/1e6,2) alim_m, round(sum(miktar))::int adet
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0
   AND fatura_tarihi>=date_trunc('month',CURRENT_DATE)-INTERVAL '13 month'
 GROUP BY 1 ORDER BY 1;
