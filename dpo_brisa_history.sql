-- Brisa bakiyesi export tarihine gore — kis on-siparisiyle mi sicradi? (READ-ONLY, kesin dogrulama)
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '===== Brisa borcu vs toplam borç — her export tarihinde (sicrama = on-siparis) ====='
SELECT export_date,
       round(sum(-LEAST(tedarikci_bakiye,0)) FILTER (WHERE tedarikci_adi ILIKE '%BR_SA%')/1e6,1) brisa_borc_m,
       round(sum(-LEAST(tedarikci_bakiye,0))/1e6,1) tum_borc_m
  FROM bi_cari_bakiye WHERE tenant_id::text=:'t'
 GROUP BY 1 ORDER BY 1;

\echo '===== Kış ön-sipariş toplamı (Brisa tedarikçili) — Brisa borcuyla kıyas ====='
SELECT round(sum(adet*liste_kdvdahil)/1e6,1) onsiparis_tl_m, round(sum(adet)) adet
  FROM bi_on_siparis WHERE tenant_id::text=:'t' AND sezon_yili='2026-27' AND upper(tedarikci) ILIKE 'BR_SA';
