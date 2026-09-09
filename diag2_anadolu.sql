-- ANADOLU TANI-2 (SALT-OKUNUR) — v_finans_ticari_sermaye'nin 4 INNER CTE'sini
-- Anadolu icin tek tek olcer. Bos olan = DSO'yu dusuren. Cast uniform ::text.
\pset pager off
SELECT id AS aid FROM platform_tenants WHERE name ILIKE '%anadolu%' LIMIT 1;
\gset

\echo '=== FLOW (bi_marj_atom, son 1 yil) — 0 bekleniyor (blocker) ==='
WITH maxay AS (SELECT max(ay) m FROM bi_marj_atom WHERE tenant_id::text=:'aid')
SELECT count(*) satir, coalesce(round(sum(ciro)),0) ciro
FROM bi_marj_atom a, maxay
WHERE a.tenant_id::text=:'aid' AND a.ay > (maxay.m - interval '1 year');

\echo '=== AR (bi_musteri_risk, musteri, TEDAR haric, son export) ==='
WITH mr AS (SELECT max(export_date) d FROM bi_musteri_risk WHERE tenant_id::text=:'aid')
SELECT count(*) satir, coalesce(round(sum(greatest(hesap_bakiyesi,0))),0) ar_net
FROM bi_musteri_risk r, mr
WHERE r.tenant_id::text=:'aid' AND r.export_date=mr.d
  AND coalesce(r.musteri_mi,true) AND coalesce(r.grup,'') !~~* '%TEDAR%';

\echo '=== STOK (bi_stok_durumu, grup LASTIK%, son export) — KRITIK ==='
SELECT to_regclass('bi_stok_durumu') AS tablo_var_mi;
WITH ms AS (SELECT max(export_date) d FROM bi_stok_durumu WHERE tenant_id::text=:'aid')
SELECT count(*) satir, coalesce(round(sum(toplam_deger)),0) stok_deger
FROM bi_stok_durumu s, ms
WHERE s.tenant_id::text=:'aid' AND s.export_date=ms.d AND s.grup_adi ~~* 'LASTIK%';

\echo '=== bi_stok_durumu Anadolu grup_adi dagilimi (LASTIK var mi?) ==='
SELECT grup_adi, count(*) FROM bi_stok_durumu WHERE tenant_id::text=:'aid' GROUP BY 1 ORDER BY 2 DESC LIMIT 15;

\echo '=== AP (bi_cari_bakiye, negatif tedarikci_bakiye, son export) ==='
WITH mc AS (SELECT max(export_date) d FROM bi_cari_bakiye WHERE tenant_id::text=:'aid')
SELECT count(*) satir, coalesce(round(sum(CASE WHEN tedarikci_bakiye<0 THEN -tedarikci_bakiye ELSE 0 END)),0) ap_borc
FROM bi_cari_bakiye c, mc
WHERE c.tenant_id::text=:'aid' AND c.export_date=mc.d;

\echo '=== bi_stok_hareket Anadolu hareket_sinifi dagilimi (giris lotu var mi?) ==='
SELECT hareket_sinifi, count(*) satir, coalesce(round(sum(giris)),0) giris_adet, coalesce(round(sum(cikis)),0) cikis_adet
FROM bi_stok_hareket WHERE tenant_id::text=:'aid' GROUP BY 1 ORDER BY 2 DESC;

\echo '=== bi_stok_anlik Anadolu grup dagilimi (stok_durumu bunu mu okur?) ==='
SELECT count(*) FROM bi_stok_anlik WHERE tenant_id::text=:'aid';

\echo '=== TANI-2 SONU (yazma yok) ==='
