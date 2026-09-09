CREATE TABLE IF NOT EXISTS bi_sinyal_geri (
  id          bigserial PRIMARY KEY,
  tenant_id   uuid NOT NULL,
  kapsam      text NOT NULL,
  anahtar     text NOT NULL,
  karar       text NOT NULL,
  yorum       text,
  kullanici   text,
  guncelleme  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, kapsam, anahtar, karar)
);
CREATE INDEX IF NOT EXISTS ix_sinyal_geri_t ON bi_sinyal_geri(tenant_id, karar);
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'SINYAL_GERI_V1','Sinyal kurator/geri-besleme: tenant her sinyali notlar/yorumlar/mute eder (kapsam sinyal/deger/boyut). Yuzey mute-duyarli.',
 'Tenant-agnostik curation: kod hicbir grubu elemez; tenant kendi ogretir. Self-learning ilk halka. Sifir literal.',
 '{"marker":"SINYAL_GERI_V1","tablo":"bi_sinyal_geri"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='SINYAL_GERI_V1');
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,onaylayan,eklendi_at,guncellendi_at,parmak_izi,son_gorulme)
SELECT 'sinyal-kurator','yetenek',
 'Tenant sinyalleri notlar/yorumlar/mute eder; organizma o tenant icin neyin onemli oldugunu ogrenir.',
 'bi_sinyal_geri; yuzey mute-duyarli + not-agirlikli. Odadan yazilir.',
 '', 'aktif', 0.7, '{"marker":"SINYAL_GERI_V1","tablo":"bi_sinyal_geri"}'::jsonb,
 true,'sistem',now(),now(),'SINYAL_GERI_V1',now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='sinyal-kurator');
