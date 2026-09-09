-- ============================================================================
-- NET GECİKMİŞ BAĞLAMA-1 — v_finans_ticari_sermaye.net_gecikmis → KANON (v_net_gecikmis_musteri)
-- Yalnız netgec CTE değişir (ham +tedarikci_bakiye → kanon LEAST mahsuplu). Diğer 16 kolon AYNEN.
-- CREATE OR REPLACE VIEW atomik: kolon adı/sıra/tip aynı olmalı (öyle) — hata olursa hiç uygulanmaz.
-- ÖNKOŞUL: v_net_gecikmis_musteri CANLI olmalı (kanon_net_gecikmis_view.sql çalışmış).
-- Calistirma:  cat kanon_finans_netgec_bind.sql | docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform
-- ============================================================================
\set T '''f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'''

CREATE OR REPLACE VIEW v_finans_ticari_sermaye AS
 WITH maxay AS (
         SELECT max(bi_marj_atom.ay) AS m
           FROM bi_marj_atom
        ), flow AS (
         SELECT sum(bi_marj_atom.ciro) AS net_satis,
            sum(bi_marj_atom.ciro - bi_marj_atom.brut_kar) AS smm,
            sum(bi_marj_atom.brut_kar) AS brut_kar
           FROM bi_marj_atom
          WHERE bi_marj_atom.ay > (( SELECT maxay.m FROM maxay) - '1 year'::interval)
        ), ar AS (
         SELECT sum(GREATEST(bi_musteri_risk.hesap_bakiyesi, 0::numeric)) AS ar_net
           FROM bi_musteri_risk
          WHERE bi_musteri_risk.musteri_mi AND bi_musteri_risk.grup !~~* '%TEDAR%'::text
        ), stok AS (
         SELECT sum(bi_stok_durumu.toplam_deger) AS stok_deger
           FROM bi_stok_durumu
          WHERE bi_stok_durumu.export_date = (( SELECT max(bi_stok_durumu_1.export_date) AS max
                   FROM bi_stok_durumu bi_stok_durumu_1)) AND bi_stok_durumu.grup_adi ~~* 'LASTIK%'::text
        ), ap AS (
         SELECT sum(
                CASE
                    WHEN bi_cari_bakiye.tedarikci_bakiye < 0::numeric THEN - bi_cari_bakiye.tedarikci_bakiye
                    ELSE 0::numeric
                END) AS ap_borc
           FROM bi_cari_bakiye
          WHERE bi_cari_bakiye.export_date = (( SELECT max(bi_cari_bakiye_1.export_date) AS max
                   FROM bi_cari_bakiye bi_cari_bakiye_1))
        ), netgec AS (
         -- KANON: v_net_gecikmis_musteri (son export · müşteri başına · LEAST mahsup · floor · müşteri&TEDAR-dışı)
         SELECT sum(v.net_gecikmis) AS net_gecikmis
           FROM v_net_gecikmis_musteri v
          WHERE v.tenant_id::text = 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::text
        ), tumciro AS (
         SELECT sum(bi_satis_faturalari.satir_tutar) AS toplam_ciro
           FROM bi_satis_faturalari
          WHERE bi_satis_faturalari.satir_tutar > 0::numeric AND bi_satis_faturalari.fatura_tarihi >= (( SELECT maxay.m FROM maxay) - '11 mons'::interval) AND bi_satis_faturalari.fatura_tarihi < (( SELECT maxay.m FROM maxay) + '1 mon'::interval)
        )
 SELECT 'f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid AS tenant_id,
    ar.ar_net,
    stok.stok_deger,
    ap.ap_borc,
    flow.net_satis AS net_satis_lastik,
    tumciro.toplam_ciro AS ciro_tum_sirket,
    flow.smm,
    flow.brut_kar,
    round(100.0 * flow.brut_kar / NULLIF(flow.net_satis, 0::numeric), 1) AS marj_pct,
    netgec.net_gecikmis,
    round(netgec.net_gecikmis * 0.5) AS finansman_yil,
    round(ar.ar_net / NULLIF(flow.net_satis, 0::numeric) * 365::numeric) AS dso,
    round(stok.stok_deger / NULLIF(flow.smm, 0::numeric) * 365::numeric) AS dio,
    round(ap.ap_borc / NULLIF(flow.smm, 0::numeric) * 365::numeric) AS dpo,
    round(ar.ar_net / NULLIF(flow.net_satis, 0::numeric) * 365::numeric + stok.stok_deger / NULLIF(flow.smm, 0::numeric) * 365::numeric - ap.ap_borc / NULLIF(flow.smm, 0::numeric) * 365::numeric) AS ccc,
    round(ar.ar_net + stok.stok_deger - ap.ap_borc) AS twc,
    round(100.0 * (ar.ar_net + stok.stok_deger - ap.ap_borc) / NULLIF(flow.net_satis, 0::numeric), 1) AS bagli_sermaye_oran
   FROM flow,
    ar,
    stok,
    ap,
    netgec,
    tumciro;

-- DOĞRULA: net_gecikmis artık 53,4M (kanon) — diğer kolonlar bozulmadı mı?
SELECT round(net_gecikmis/1e6,1) net_gecikmis_M, round(finansman_yil/1e6,1) finansman_M,
       round(net_satis_lastik/1e6,1) net_satis_M, marj_pct, dso, dio, dpo, ccc, round(twc/1e6,1) twc_M
FROM v_finans_ticari_sermaye WHERE tenant_id=:T::uuid;
