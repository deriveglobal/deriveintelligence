-- TAHSILAT_V1 — yeni tablo bi_tahsilat (odeme davranisi / gercek DSO). Yuklemeden ONCE calistir.
-- Idempotent (IF NOT EXISTS). Mevcut tablolara DOKUNMAZ.
CREATE TABLE IF NOT EXISTS bi_tahsilat (
  tenant_id            uuid    NOT NULL,
  muhatap_kodu         text,
  muhatap_adi          text,
  grup                 text,
  satis_calisani       text,
  tahsilat_adedi       integer,
  toplam_tahsilat      numeric,
  ort_tahsilat_suresi  numeric,   -- tutar-agirlikli fatura->odeme gun (tam gecmis)
  ort_gecikme_gun      numeric,   -- tutar-agirlikli Vadesi Gecen Gun (isaretli: - erken, + gec)
  gec_odeme_orani      numeric,   -- gec odenen VALUE orani % (tam gecmis)
  son12_adedi          integer,
  son12_tutar          numeric,
  son12_suresi         numeric,   -- son 12 ay pencere
  son12_gecikme_gun    numeric,
  son12_gec_orani      numeric,
  son_tahsilat_tarihi  date,
  musteri_mi           boolean,
  export_date          date DEFAULT CURRENT_DATE
);
CREATE INDEX IF NOT EXISTS ix_bi_tahsilat_tenant ON bi_tahsilat (tenant_id);
CREATE INDEX IF NOT EXISTS ix_bi_tahsilat_kod    ON bi_tahsilat (tenant_id, muhatap_kodu);

SELECT 'bi_tahsilat hazir', count(*) FROM bi_tahsilat;
