-- İKTİSATÇI MOTORU — ÇOK-AÇILI EKONOMİ TEŞHİSİ (READ-ONLY). Ön-sipariş DIŞI dört analizör.
\set t 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
\pset numericlocale on

\echo '################ 1) VADE MAKASI — satış vadesi vs alım vadesi (kim kimi finanse ediyor) ################'
\echo '   makas = satış_gün − alım_gün ; POZİTİF = müşteriyi finanse ediyorsun (nakit baskısı).'
WITH sat AS (
  SELECT satir_tutar t,
         CASE WHEN odeme_kosulu ~* 'pe(ş|s)in|nakit|havale|kredi kart|(ç|c)ek|senet|mukabil' THEN 0
              WHEN odeme_kosulu ~ '[0-9]+' THEN (regexp_match(odeme_kosulu,'([0-9]+)'))[1]::int END g,
         fatura_tarihi ft
    FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-730),
al AS (
  SELECT satir_kdv_haric t, vade_gun g, fatura_tarihi ft
    FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND satir_kdv_haric>0 AND fatura_tarihi>=CURRENT_DATE-730)
SELECT
  round(sum(s.g*s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft>=CURRENT_DATE-365)/NULLIF(sum(s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft>=CURRENT_DATE-365),0),1) satis_vade_12ay,
  round((SELECT sum(a.g*a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft>=CURRENT_DATE-365)/NULLIF(sum(a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft>=CURRENT_DATE-365),0) FROM al a),1) alim_vade_12ay,
  round(sum(s.g*s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(s.t) FILTER (WHERE s.g IS NOT NULL AND s.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0),1) satis_vade_onceki,
  round((SELECT sum(a.g*a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(a.t) FILTER (WHERE a.g IS NOT NULL AND a.ft BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0) FROM al a),1) alim_vade_onceki
  FROM sat s;

\echo '################ 2) FİYAT GEÇİŞGENLİĞİ — alım zammı satışa geçiyor mu? (top markalar, YoY %) ################'
WITH al AS (
  SELECT marka,
         sum(birim_fiyat_kdv_haric*miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365),0) alim_bu,
         sum(birim_fiyat_kdv_haric*miktar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0) alim_onceki,
         sum(miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365) hacim
    FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND birim_fiyat_kdv_haric>0 GROUP BY 1),
sa AS (
  SELECT marka,
         sum(satir_tutar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi>=CURRENT_DATE-365),0) satis_bu,
         sum(satir_tutar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366)/NULLIF(sum(miktar) FILTER (WHERE fatura_tarihi BETWEEN CURRENT_DATE-730 AND CURRENT_DATE-366),0) satis_onceki
    FROM bi_satis_faturalari WHERE tenant_id::text=:'t' AND miktar>0 AND satir_tutar>0 AND grup_adi LIKE 'LASTIK%' GROUP BY 1)
SELECT al.marka, round(al.hacim) alim_adet,
       round(100*(al.alim_bu/NULLIF(al.alim_onceki,0)-1)) alim_zam_pct,
       round(100*(sa.satis_bu/NULLIF(sa.satis_onceki,0)-1)) satis_zam_pct,
       round(100*(sa.satis_bu/NULLIF(sa.satis_onceki,0)-1) - 100*(al.alim_bu/NULLIF(al.alim_onceki,0)-1)) gecisgenlik_farki
  FROM al JOIN sa ON sa.marka=al.marka
 WHERE al.hacim>2000 AND al.alim_onceki>0 AND sa.satis_onceki>0
 ORDER BY al.hacim DESC LIMIT 12;

\echo '################ 3) ÖDEME DİSİPLİNİ — KRB tedarikçiye gerçekte ne zaman ödüyor (vade vs fiili) ################'
SELECT COALESCE(NULLIF(TRIM(odeme_durumu),''),'—') durum, count(*) fatura,
       round(sum(satir_kdv_haric)/1e6,1) tutar_m,
       round(avg(odeme_tarihi - vade_tarihi) FILTER (WHERE odeme_tarihi IS NOT NULL AND vade_tarihi IS NOT NULL),1) ort_gun_fark
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND fatura_tarihi>=CURRENT_DATE-365
 GROUP BY 1 ORDER BY tutar_m DESC NULLS LAST;
\echo '--- 3b) ödenenler: erken / zamanında / geç dağılımı (₺ ağırlıklı) ---'
SELECT
  round(sum(satir_kdv_haric) FILTER (WHERE odeme_tarihi < vade_tarihi)/1e6,1) erken_m,
  round(sum(satir_kdv_haric) FILTER (WHERE odeme_tarihi BETWEEN vade_tarihi AND vade_tarihi+5)/1e6,1) zamaninda_m,
  round(sum(satir_kdv_haric) FILTER (WHERE odeme_tarihi > vade_tarihi+5)/1e6,1) gec_m,
  round(avg(odeme_tarihi - vade_tarihi) FILTER (WHERE odeme_tarihi IS NOT NULL AND vade_tarihi IS NOT NULL),1) ort_gun
  FROM bi_tedarikci_faturalari WHERE tenant_id::text=:'t' AND fatura_tarihi>=CURRENT_DATE-365 AND odeme_tarihi IS NOT NULL AND vade_tarihi IS NOT NULL;

\echo '################ 4) MÜŞTERİ KOHORT / CHURN — geçmiş ciro vs son 12 ay (en çok küçülen 15) ################'
WITH risk AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, musteri_mi, grup,
                COALESCE(ciro_2019,0)+COALESCE(ciro_2020,0)+COALESCE(ciro_2021,0) gecmis3,
                COALESCE(ciro_2021,0) c2021
              FROM bi_musteri_risk WHERE tenant_id::text=:'t' ORDER BY muhatap_kodu, export_date DESC),
now AS (SELECT musteri_kodu, sum(satir_tutar) son12 FROM bi_satis_faturalari
          WHERE tenant_id::text=:'t' AND satir_tutar>0 AND fatura_tarihi>=CURRENT_DATE-365 GROUP BY 1)
SELECT r.muhatap_adi, COALESCE(r.grup,'—') grup,
       round(r.c2021/1e6,1) ciro_2021_m, round(COALESCE(n.son12,0)/1e6,1) son12_m,
       round((COALESCE(n.son12,0)-r.c2021)/1e6,1) degisim_m,
       CASE WHEN r.c2021>0 THEN round(100*COALESCE(n.son12,0)/r.c2021)::int ELSE NULL END pct_2021e_gore
  FROM risk r LEFT JOIN now n ON n.musteri_kodu=r.muhatap_kodu
 WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' AND r.c2021 > 3e6
 ORDER BY (COALESCE(n.son12,0)-r.c2021) ASC LIMIT 15;

\echo '################ 5) KAÇAN SATIŞLAR — yapı (3 örnek satır) ################'
SELECT * FROM bi_kacan_satislar WHERE tenant_id::text=:'t' LIMIT 3;
