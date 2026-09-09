#!/usr/bin/env bash
# OMURGA 46 — TOPLU TASLAK: tanımsız yetenekleri AI-taslakla (ne_ise_yarar+cekmece). Hedef %100 taslak.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ÖLÜ/YEDEK tablolar → cekmece=olu (canlı değil, araştırıcı kullanmaz)"
$PSQL -v ON_ERROR_STOP=1 -c "
UPDATE bi_yetenek SET cekmece='olu', durum='taslak', guven='taslak', aktif=false,
  ne_ise_yarar='ÖLÜ/YEDEK tablo — canlı değil, sebep-araştırıcı KULLANMAZ (temizlik adayı #117/#118).'
 WHERE tur='tablo' AND durum='tanimsiz' AND ad ~ '(_yedek|_silinen)';" 2>&1 | sed 's/^/  /'

hr "2. CANLI TABLOLAR taslak"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_yetenek y SET ne_ise_yarar=v.a, cekmece=v.c, durum='taslak', guven='taslak', guncellendi_at=now()
FROM (VALUES
('bi_agent_memory','hafiza','AI ajan hafızası (departman bazlı notlar).'),
('bi_arac_kategorileri','ayar','Araç kategori etiket sözlüğü (binek/kamyon vb).'),
('bi_ayar','ayar','Kiracı ayarları: sermaye maliyeti %, stok hedef gün, aktif/uyuyan müşteri eşiği, saha acil eşik.'),
('bi_bilinen_deger','veri-saglik','Veri sağlık kapısı whitelist''i (bilinen/onaylı değerler).'),
('bi_conversations','hafiza','Departman sohbet geçmişi (mesaj json).'),
('bi_deploy_log','denetim','Deploy damgaları (bi.js hash, yetenek özeti) — "her şey iz bırakır".'),
('bi_ekonomik_parametreler','doviz','Ekonomik parametreler: TCMB faiz, kredi/mevduat, TÜFE, USD/EUR, lastik fiyat artışı — enflasyon/finansman bağlamı.'),
('bi_etkinlik','hafiza','Oda-scoped etkinlik/hafıza timeline (Katman 6).'),
('bi_fatura_tahsilat','vade','Fatura tahsilat özeti: vade, tahsilat türü, ilk/son tahsilat, gecikme gün.'),
('bi_fiyat_listesi_kalemler','fiyat','Fiyat listesi kalemleri: ebat başına liste/bayi/net/perakende fiyatı.'),
('bi_fiyat_listesi_uploads','fiyat','Fiyat listesi yükleme başlıkları.'),
('bi_geri_bildirim','sinyal','Kullanıcı geri bildirimleri (hedef/tür/metin/işlendi).'),
('bi_icgoru_geribildirim','metrik','İçgörü geri bildirimi (faydalı/aksiyon alındı) — öğrenme.'),
('bi_ingestion_log','denetim','ERP yükleme günlüğü: dosya tipi, export tarihi, satır sayıları, hash. Süreklilik/dedup.'),
('bi_insa_gunlugu','denetim','İnşa günlüğü (adım/ne/neden) — ayak izi.'),
('bi_itiraz','sinyal','Kullanıcı sayı-itirazları — sayı savunmaz, kaynağı açar.'),
('bi_kullanici_profil','ekip','Kullanıcı davranış profili (sinyal ağırlığı).'),
('bi_maliyet_ay','maliyet','SKU×ay birim maliyet (ERP türevi). Kanonik marj için bi_marj_atom.'),
('bi_maliyet_sku','maliyet','SKU birim maliyet özeti. Dönem-eşleşmeli için bi_marj_atom kanonik.'),
('bi_marj_atom','marj','🔑 KANONİK marj atomu: SKU×ay fiyat·dönem-eşleşmeli maliyet·adet·brut_kar·marj%. TÜM marj türevi buradan.'),
('bi_morning_briefings','hafiza','Günlük sabah brifingleri (üretilen içerik json).'),
('bi_musteri_risk_odeme','vade','Müşteri ödeme biçimi + ort tahsilat/gecikme günü.'),
('bi_on_siparis','kacan','Ön siparişler: sezon/tedarikçi/marka/ebat/adet/üretim tarihleri. "Yolda ne var".'),
('bi_paylasim_log','hafiza','İçgörü paylaşım günlüğü (kime/kanal/özet).'),
('bi_pazar_talep','piyasa','Pazar talep skoru (n11/cimri listing/yorum/fiyat).'),
('bi_price_monitor','piyasa','Fiyat izleme: bizim vs rakip fiyat + fark (scraper), SKU bazlı.'),
('bi_rakip_fiyat','piyasa','Rakip/piyasa fiyatları (scraper güncel): marka/ebat/fiyat/satıcı sayısı/segment.'),
('bi_rakip_fiyat_alarm','piyasa','Rakip fiyat değişim alarmları (eşik aşımı).'),
('bi_rakip_izle','piyasa','İzlenen rakip ürünler + eşik (düşük/yüksek).'),
('bi_rakip_izle_ayar','piyasa','Rakip izleme ayarları.'),
('bi_saglik_agrega','veri-saglik','Veri sağlık agrega checkpoint (ort sıçrama/mükerrer).'),
('bi_saglik_alarm','veri-saglik','Veri sağlık alarmları (bilinmeyen değer/aralık/mükerrer). İnsan kararı.'),
('bi_saglik_config','veri-saglik','Veri sağlık kapısı korunan tablo/kolon listesi.'),
('bi_sayi_koken','metrik','Sayı kökeni: anahtar başına kaynak/formül/varsayım/sınır/güven. Topraklama.'),
('bi_scrape_run','piyasa','Scraper koşu günlüğü (kaynak/komut/durum/süre).'),
('bi_sinyal','sinyal','İş sinyalleri: ödeme takvimi, riskli müşteri (tutar/son tarih/oda/karar). Finans odası besleniyor.'),
('bi_sinyal_gecmis','sinyal','Sinyal karar geçmişi (eylem/kullanıcı/gerekçe).'),
('bi_sistem_sorusu','ogrenme','Sistemin kullanıcıya sorduğu sorular (kanıt/seçenek/cevap) — öğrenme döngüsü çekirdeği.'),
('bi_tedarikci_kampanya','tesvik','Tedarikçi kampanyaları (marka/kapsam/indirim/tarih). Maliyet/marj etkisi.'),
('bi_tedarikci_tesvik','tesvik','🔑 Tedarikçi teşvik/prim: fatura-altı, dönem primi, sellout, büyüme bonusu, vade. NET marj için maliyetten düşülmeli.'),
('bi_yetenek','denetim','🔑 Yetenek defteri: sistemin kendi haritası (tablo/fonksiyon/endpoint/cron), kendini-kaydeder.'),
('brain_conversations','hafiza','CEO asistanı sohbet geçmişi. ⚠#93 user_id yok — tenant-geneli.'),
('brain_notes','hafiza','CEO asistanı notları (etiketli).'),
('brain_preferences','hafiza','Sahip/şirket tercihleri (ad/unvan/şehir/konum/timezone).'),
('brain_tasks','ekip','CEO görev listesi (başlık/öncelik/durum/atanan/tarih).'),
('master_musteri','musteri','Müşteri master: ciro/bakiye/vadesi geçmiş/ort gecikme/marka-kategori kırılımı/kredi limiti/risk. ⚠#119 bizim_borcumuz kirli.'),
('master_urun','mix','Ürün master: SKU↔ebat↔marka↔kategori + liste fiyatı. Kırılım/piyasa join köprüsü.'),
('ops_ayar','ayar','Ops ayarları (key/value).'),
('ops_health','denetim','Ops sağlık kontrolleri (pipeline/sistem/veri/app) durumu.'),
('ops_incident','denetim','Ops olayları (severity/ilk-son görülme/çözüm).'),
('saha_bildirim_ayar','ekip','Saha WhatsApp bildirim ayarları.'),
('saha_cari_cache','musteri','Saha cari (müşteri) önbelleği (ERP eşleşme).'),
('saha_denetim','denetim','Saha denetim izi (kim/eylem/varlık/alanlar).'),
('saha_dosya','ziyaret','Saha yüklenen dosyalar (rakip fiyat listesi, müşteri belgesi).'),
('saha_duyuru','ekip','Saha duyuruları (duyuru/piyasa bilgisi).'),
('saha_duyuru_okundu','ekip','Duyuru okundu takibi.'),
('saha_duyuru_yorum','ekip','Duyuru yorumları.'),
('saha_eslestirme_oneri','musteri','Saha müşteri↔ERP eşleştirme önerileri (skor/karar).'),
('saha_giden_eposta','ekip','Saha/asistan giden e-postalar.'),
('saha_hata_log','denetim','Saha UI hata log (404/500/JS) — ops monitörüne besleniyor.'),
('saha_iskonto_ayar','iskonto','Saha iskonto onay eşikleri (oto-onay/müdür max).'),
('saha_iskonto_kural','iskonto','İskonto kuralları (marka/kategori/sezon oto-onay/müdür max).'),
('saha_iskonto_talep','iskonto','İskonto talepleri (istenen oran/gerekçe/onay). "Fiyat neden kırıldı".'),
('saha_konusma','ekip','Saha içi mesajlaşma — konuşma.'),
('saha_konusma_mesaj','ekip','Saha içi mesajlar.'),
('saha_konusma_okundu','ekip','Mesaj okundu takibi.'),
('saha_musteri','musteri','Saha müşteri kaydı: firma/segment/konum/raf markaları/rakip toptancılar/stok — saha istihbaratı.'),
('saha_musteri_lokasyon','musteri','Müşteri şube/lokasyonları (adres/koordinat).'),
('saha_musteri_tedarikci_destek','tesvik','Müşteri bazlı tedarikçi destek %.'),
('saha_musteri_tedarikci_destek_log','tesvik','Müşteri tedarikçi destek % değişim log.'),
('saha_oneri','ekip','Saha öneri/feedback ticket sistemi.'),
('saha_oneri_ayar','ekip','Öneri bildirim ayarı.'),
('saha_oneri_mesaj','ekip','Öneri mesajları.'),
('saha_oneri_okuma','ekip','Öneri okundu takibi.'),
('saha_rakip_teklif','piyasa','Sahadan rakip teklifleri (rakip marka/model/fiyat, müşteri). Gerçek pazar teklifi.'),
('saha_rep_conversations','hafiza','Temsilci asistanı sohbet geçmişi.'),
('saha_rep_gunluk_baslangic','ekip','Temsilci günlük başlangıç noktası (şehir/konum).'),
('saha_rep_not','ekip','Temsilci notları (hatırlatma).'),
('saha_rep_profil','ekip','Temsilci profili (baz adres/konum).'),
('saha_rep_sehir','ekip','Temsilci sorumlu iller.'),
('saha_sinyal','sinyal','Saha aktivite sinyalleri (intent motorundan): ham metin+özet, owner bildirim.'),
('saha_teklif','teklif','Saha teklifleri: marka/ebat/adet/fiyat/iskonto/teşvik/kampanya/sonuç. "Teklifte fiyat kırıldı mı".'),
('saha_teklif_kalem','teklif','Teklif kalemleri (SKU bazlı fiyat/iskonto/teşvik).'),
('saha_teklif_log','teklif','Teklif değişim log.'),
('saha_wa_oturum','ekip','WhatsApp oturum eşleşmesi.'),
('saha_ziyaret_foto','ziyaret','Ziyaret fotoğrafları.'),
('saha_ziyaret_yorum','ziyaret','Ziyaret yorumları.')
) v(ad,c,a)
WHERE y.ad=v.ad AND y.tur='tablo' AND y.durum='tanimsiz';
SQL
echo "  ✅ tablolar"

hr "3. FONKSİYONLAR taslak"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_yetenek y SET ne_ise_yarar=v.a, cekmece=v.c, durum='taslak', guven='taslak' FROM (VALUES
('audit_bi_access','denetim','BI erişim denetim tetikleyicisi.'),
('bi_ebat_norm','arac','Ebat normalizasyon (315/70R22.5 standardize).'),
('bi_profil_ogren','ekip','Kullanıcı profili öğrenme (sinyal ağırlığı).'),
('bi_sinyal_geri_ac','sinyal','Susturulmuş sinyali geri açma.'),
('bi_sinyal_puan','sinyal','Sinyal önem puanlama.'),
('bi_sinyal_puan_detay','sinyal','Sinyal puan detayı.'),
('bi_sinyal_puan_kisisel','sinyal','Kullanıcıya özel sinyal puanı.'),
('bi_sku_norm','arac','SKU kod normalizasyon.'),
('bi_soru_uret','ogrenme','Sistem sorusu üretici (kullanıcıya sorulacak).'),
('derive_rakip_segment','piyasa','Rakip ürün segment türetme.'),
('fn_piyasa_fiyat_matrix','piyasa','Piyasa fiyat matrisi (ebat×kaynak).'),
('icgoru_uret_finans','metrik','Finans içgörü motoru (kâr-sızıntısı, sessiz-kayıp).'),
('metrik_alacak_recon','metrik','Alacak reconstruction (as-of).'),
('metrik_ciro','metrik','Ciro hesap (ay, lastik/tüm).'),
('metrik_gunluk_kredili','vade','Günlük kredili satış hesap (DSO paydası).'),
('metrik_marj_atom_uret','marj','🔑 Kanonik marj atomu üretici (dönem-eşleşmeli).'),
('metrik_snapshot_al','metrik','Metrik omurgası günlük snapshot (tek kiracı).'),
('metrik_stok_deger_recon','metrik','Stok değeri reconstruction (as-of).'),
('norm_para_birimi','doviz','Para birimi normalizasyon.'),
('saha_musteri_durum_yenile','musteri','Saha müşteri durum yenileme.'),
('sebep_arastir_marj','metrik','🔑 Sebep-araştırıcı: marj düşüşünü fiyat/maliyet/mix köprüsüyle açıklar (atomdan).'),
('tr_norm','arac','Türkçe metin normalizasyon (noktasız-I güvenli).'),
('veri_saglik_baz_al','veri-saglik','Veri sağlık whitelist baz alma.'),
('veri_saglik_kapisi','veri-saglik','Veri sağlık kapısı ana kontrol (bilinmeyen/aralık/mutabakat).'),
('veri_saglik_mukerrer','veri-saglik','Mükerrer-artış takibi.'),
('veri_saglik_mutabakat','veri-saglik','Ortalama-sıçrama mutabakat (×10.000).'),
('yetenek_tara','denetim','🔑 Yetenek defteri tarama (kendini-kaydet).')
) v(ad,c,a) WHERE y.ad=v.ad AND y.tur='fonksiyon' AND y.durum='tanimsiz';
SQL
echo "  ✅ fonksiyonlar"

hr "4. ENDPOINT'LER taslak (grup pattern + tekil)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_yetenek SET cekmece='piyasa', durum='taslak', guven='taslak',
  ne_ise_yarar='Rakip/piyasa scraper endpoint''i (alarm/izle/geçmiş/trend/özet/ürün master/DOT).'
 WHERE tur='endpoint' AND durum='tanimsiz' AND ad LIKE '/api/rakip/%';
UPDATE bi_yetenek SET cekmece='fiyat', durum='taslak', guven='taslak',
  ne_ise_yarar='Fiyat listesi endpoint''i (kalem/karşılaştırma/iskonto tier/teşvik/rekabet/satış hacmi/upload).'
 WHERE tur='endpoint' AND durum='tanimsiz' AND ad LIKE '/api/price-list/%';
UPDATE bi_yetenek SET cekmece='metrik', durum='taslak', guven='taslak',
  ne_ise_yarar='Finans odası endpoint''i (trend/seri/marka-detay/drag).'
 WHERE tur='endpoint' AND durum='tanimsiz' AND ad LIKE '/api/bi/finans%';
UPDATE bi_yetenek y SET ne_ise_yarar=v.a, cekmece=v.c, durum='taslak', guven='taslak' FROM (VALUES
('/api/ai/chat','hafiza','AI sohbet endpoint''i.'),
('/api/ai/interpret-firsat','metrik','Fırsat yorumlama (LLM).'),
('/api/brain/chat','hafiza','CEO asistanı sohbet.'),
('/api/brain/preferences','hafiza','CEO tercihleri.'),
('/api/bi/account-health','musteri','Müşteri sağlık skoru.'),
('/api/bi/ana','metrik','Ana finans/özet (EVA/net).'),
('/api/bi/brand-alerts','piyasa','Marka alarmları.'),
('/api/bi/brand-compare','piyasa','Marka karşılaştırma.'),
('/api/bi/brand-compare/sizes','piyasa','Marka×ebat karşılaştırma.'),
('/api/bi/brand-index','piyasa','Marka index.'),
('/api/bi/itiraz','sinyal','Sayı itiraz kaydet.'),
('/api/bi/itiraz/acik','sinyal','Açık itirazlar.'),
('/api/bi/koken','metrik','Sayı kökeni.'),
('/api/bi/orders/brand-mix','mix','Sipariş marka-mix.'),
('/api/bi/preorder/recommend-v2','kacan','Ön sipariş öneri.'),
('/api/bi/pricing/season-compare','fiyat','Sezon fiyat karşılaştırma.'),
('/api/bi/saglik-alarm','veri-saglik','Veri sağlık alarm listesi.'),
('/api/bi/saglik-alarm-karar','veri-saglik','Alarm insan kararı (kabul/reddet).'),
('/api/bi/yukle','denetim','ERP dosya yükleme.'),
('/api/bi/yukle/durum','denetim','Yükleme dosya durumu.'),
('/api/platform/feedback','sinyal','Platform geri bildirim.'),
('/api/tcmb/policy-rate','doviz','TCMB politika faizi.')
) v(ad,c,a) WHERE y.ad=v.ad AND y.tur='endpoint' AND y.durum='tanimsiz';
SQL
echo "  ✅ endpoint'ler"

hr "5. CRON'LAR taslak (scraper grup + tekil)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_yetenek SET cekmece='piyasa', durum='taslak', guven='taslak',
  ne_ise_yarar='Piyasa scraper cron (fiyat çekme/özet/eşleşme) — /opt/price_monitor.'
 WHERE tur='cron' AND durum='tanimsiz' AND ad LIKE '%price_monitor%';
UPDATE bi_yetenek SET cekmece='metrik', durum='taslak', guven='taslak',
  ne_ise_yarar='Metrik snapshot + marj atomu günlük cron (08:15).'
 WHERE tur='cron' AND durum='tanimsiz' AND ad LIKE '%metrik_snapshot%';
UPDATE bi_yetenek SET cekmece='denetim', durum='taslak', guven='taslak',
  ne_ise_yarar='DB cron (psql exec) — segment/metrik yazıcı ya da bakım.'
 WHERE tur='cron' AND durum='tanimsiz' AND ad LIKE '%docker exec%';
UPDATE bi_yetenek SET cekmece='ayar', durum='taslak', guven='taslak', aktif=false,
  ne_ise_yarar='crontab SHELL ayarı — cron değil (bash zorunlu #59).'
 WHERE tur='cron' AND durum='tanimsiz' AND ad LIKE 'SHELL%';
SQL
echo "  ✅ cron'lar"

hr "6. KAPSAM — hedef %100 taslak"
$PSQL -c "SELECT tur, count(*) FILTER (WHERE durum IN('taslak','onayli')) tanimli, count(*) FILTER (WHERE durum='tanimsiz') tanimsiz, round(100.0*count(*) FILTER (WHERE durum IN('taslak','onayli'))/count(*)) yuzde FROM bi_yetenek GROUP BY tur ORDER BY tur;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT ad, tur FROM bi_yetenek WHERE durum='tanimsiz' ORDER BY tur, ad;" 2>&1 | sed 's/^/  /'

hr "BITTI — kapsam %100'e yakın taslak. Kalan tanımsız (varsa) yukarıda; sen onaylarsın taslak→onayli."
