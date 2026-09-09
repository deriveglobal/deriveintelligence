-- ============================================================
-- derive_fingerprint_catchup.sql
-- Kor kaydolmus (durum=tanimsiz) organizma parcalarini docs'tan ANLAMLANDIR.
-- Idempotent + guvenli: her UPDATE yalniz HALA tarifsizse (ne_ise_yarar bos) yazar.
-- Aciklamalar guven='taslak' -> parcayi kuran oturum DOGRULAMALI (varsayim degil, taslak).
-- Kaynak: proje dokumanlari (derive-*.md).
-- ============================================================

-- ========== 1) bi_ CANLI FEATURE TABLOLARI ==========
UPDATE bi_yetenek SET ne_ise_yarar='Tahsilat/odeme kayitlari (tutar-agirlikli olculen odeme suresi, son12). DSO ve odeme-vadesi hesaplarinin kaynagi.', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_tahsilat' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Finansal icgoru kayitlari (kar-sizintisi/sessiz-kayip; icgoru_uret_finans uretir).', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_finansal_icgoru' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Bolum (dept mudur) icgoruleri; bolum bazli BI ozetleri.', cekmece='icgoru', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_bolum_icgoru' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Sahanin sesi: temsilci/musteri sinyallerinden turetilen saha istihbarati ozetleri.', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_saha_sesi' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Saha hafizasi: saha etkilesimlerinden kalici gozlem/oruntu (gozlem>beyan).', cekmece='hafiza', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_saha_hafiza' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Tenant hafizasi: sirket hakkinda 1. gunden kalici bilgi (beyan vs gozlem kanallari, celiski kaydi).', cekmece='hafiza', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_tenant_hafiza' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Bildirim/inbox kayitlari (push + deep-link); owner/temsilci bildirimleri.', cekmece='bildirim', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_bildirim' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Push token deposu (iOS/Android cihaz kayitlari).', cekmece='bildirim', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_push_token' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Arac/modul yetki kayitlari (Izinler matrisinin arka tablosu; departman/rol grant).', cekmece='yetki', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_arac_yetki' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Kokpit kullanim/etkilesim takip kaydi.', cekmece='kokpit', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_kokpit_takip' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Kokpit kullanici tercihleri (gorunum/kirilim secimleri).', cekmece='kokpit', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_kokpit_tercih' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Kokpit veri duzeltmeleri (kullanici/uzman override kayitlari).', cekmece='kokpit', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_kokpit_duzeltme' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Tesvik segment eslesme haritasi (marka/kategori -> tesvik segmenti).', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_tesvik_segment_map' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Nabiz (kalp atisi) gunluk compute kaydi.', cekmece='sistem', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_nabiz' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Nabiz durum/saglik ozeti.', cekmece='sistem', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_nabiz_durum' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Yasa katmani: onaylanan korelasyonlar kalici yasa olarak burada (her yere uygulanir).', cekmece='yasa', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='bi_yasa' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');

-- ========== 2) ENDPOINT (uc) ==========
UPDATE bi_yetenek SET ne_ise_yarar='Saha sesi API: saha istihbarati ozetini doner.', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/bi/saha-sesi' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Marka kirilim API: ciro/marj marka bazinda.', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/bi/marka-kirilim' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Bolum icgoru API: dept mudur icgorulerini doner.', cekmece='icgoru', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/bi/bolum-icgoru' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Tahsilat ozet API: olculen odeme suresi + DSO + siseren hesap.', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/bi/tahsilat-ozet' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Odeme vadeleri API: vade dagilimi/gecikme.', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/bi/odeme-vadeleri' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Finansal icgoru API: kar-sizintisi/sessiz-kayip anlatisi.', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/bi/finansal-icgoru' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='CEO asistani konusma gecmisi API (brain_conversations).', cekmece='asistan', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='/api/brain/history' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');

-- ========== 3) SAHA FEATURE TABLOLARI ==========
UPDATE bi_yetenek SET ne_ise_yarar='Ziyaret katilimcilari (bir ziyarette birden fazla kisi; KATILIMCI_V1).', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='saha_ziyaret_katilimci' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Gunluk rapor gonderim/goruntuleme logu.', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='saha_rapor_gunluk_log' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Temsilci aktivite izi (uygulama kullanim/hareket).', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='saha_rep_aktivite' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Temsilci gun baslangici (Sabah Rotam gun-basi kaydi/konum).', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='saha_rep_baslangic' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Rota oneri logu (Sabah Rotam: onerilen musteri/skor/sira; ROTAM_CAP_V1).', cekmece='saha', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='saha_rota_log' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');

-- ========== 4) FOUNDATION FONKSIYONLARI (07-16 organizma) ==========
UPDATE bi_yetenek SET ne_ise_yarar='Sebep-arastirici (musteri): bir musteri sonucunun nedenini tum cekmecelerden arastirir.', cekmece='sebep', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='sebep_arastir_musteri' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Icgoru uret (musteri): musteri bazli icgoru uretimi.', cekmece='icgoru', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='icgoru_uret_musteri' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Korelasyon avcisi: aday korelasyonlari kesfeder (hunter).', cekmece='ogrenme', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='korelasyon_avci' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Avci sorgu araci: hunter ciktisini sorgular.', cekmece='ogrenme', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='avci_sor' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Capraz kontrol: bir metrigi bagimsiz kaynaklarla dogrular (tek tarafli sayi=bug).', cekmece='dogrulama', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='capraz_kontrol' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Yasa: net pozisyon kurali.', cekmece='yasa', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='yasa_net_pozisyon' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Yasa: veri makullugu kurali.', cekmece='yasa', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='yasa_veri_makul' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Yasa: odeme celiski kurali (soz vs davranis).', cekmece='yasa', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='yasa_celiski_odeme' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Yasa: zararina hacim kurali (aday bekliyor).', cekmece='yasa', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='yasa_zararina_hacim' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Kanal normalize (satis kanali metin normalizasyonu).', cekmece='veri', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='kanal_normalize' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Kategori->sezon esleme.', cekmece='veri', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='kategori_sezon' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Kategori->segment esleme.', cekmece='veri', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='kategori_segment' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');
UPDATE bi_yetenek SET ne_ise_yarar='Stok deger (marka bazli) metrigi.', cekmece='finans', durum='canli', guven='taslak', guncellendi_at=now()
 WHERE ad='metrik_stok_deger_marka' AND (ne_ise_yarar IS NULL OR ne_ise_yarar='');

-- ========== 5) YEDEK TABLOLARI -> PASIF (defteri kirletmesin) ==========
UPDATE bi_yetenek SET aktif=false, durum='yedek', guncellendi_at=now()
 WHERE ad IN ('saha_ziyaret_yedek_ugur_fix','bi_musteri_risk_yedek_20260724');

-- ========== 6) BUILD-LOG BACKFILL (docs'tan; auto_backfill etiketli, orijinal an degil) ==========
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
SELECT 'TENANT_SAHA_HAFIZA','Tenant + saha hafizasi (bi_tenant_hafiza / bi_saha_hafiza)','1. gunden unutmayan yapay insan; beyan vs gozlem kanallari','{"auto_backfill":true,"dok":["derive-tenant-hafiza.md","derive-kokpit2-saha-hafiza.md"]}'::jsonb
 WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TENANT_SAHA_HAFIZA');
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
SELECT 'VOICE_OF_FIELD','Sahanin sesi (bi_saha_sesi + /api/bi/saha-sesi)','saha sinyallerini owner icin istihbarata cevir','{"auto_backfill":true,"dok":"derive-kokpit2-voice-of-field.md"}'::jsonb
 WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='VOICE_OF_FIELD');
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
SELECT 'BOLUM_ICGORU','Bolum icgorusu (bi_bolum_icgoru + /api/bi/bolum-icgoru)','dept mudur bazli BI ozeti','{"auto_backfill":true,"dok":"derive-birim-kpi-kokpit-deploy-dersleri.md"}'::jsonb
 WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='BOLUM_ICGORU');
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
SELECT 'TAHSILAT_DSO','Tahsilat/DSO (bi_tahsilat + /api/bi/tahsilat-ozet + /api/bi/odeme-vadeleri)','olculen odeme suresi vs DSO ayrimi','{"auto_backfill":true,"dok":["derive-tahsilat-durumu-phase.md","derive-alacak-yaslandirma-dryrun.md"]}'::jsonb
 WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='TAHSILAT_DSO');
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
SELECT 'FINANSAL_ICGORU','Finansal icgoru (bi_finansal_icgoru + /api/bi/finansal-icgoru)','kar-sizintisi/sessiz-kayip anlatisi','{"auto_backfill":true,"dok":"derive-financial-insights.md"}'::jsonb
 WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANSAL_ICGORU');
INSERT INTO bi_insa_gunlugu(adim,ne,neden,detay)
SELECT 'BILDIRIM_PUSH','Bildirim/push (bi_bildirim + bi_push_token)','owner/temsilci push + deep-link inbox','{"auto_backfill":true,"dok":["derive-push-notifications.md","derive-push-deeplink-inbox.md","derive-ios-push.md"]}'::jsonb
 WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='BILDIRIM_PUSH');

-- ========== 7) DOGRULAMA ==========
\echo '=== kalan tanimsiz (bu kadar dustu) ==='
SELECT count(*) AS kalan_tanimsiz FROM bi_yetenek WHERE aktif AND (ne_ise_yarar IS NULL OR ne_ise_yarar='' OR durum='tanimsiz');
\echo '=== yeni build-log backfill ==='
SELECT adim FROM bi_insa_gunlugu WHERE detay->>'auto_backfill'='true' ORDER BY adim;
