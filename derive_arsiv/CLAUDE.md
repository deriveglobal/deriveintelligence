# KRB / Derive — Claude Çalışma Talimatları
<!-- Her oturumda otomatik yüklenir. KISA tut (<200 satır). Detay: derive_arsiv/DEVIR_2026-07-16.md → INSA_GUNLUGU.md -->

## Ne inşa ediyoruz
**Küçük–orta ölçekli işletmeler (KOBİ) için çok-kiracılı SaaS.** Hedef sektör-bağımsız genel bir işletme zekâ + operasyon platformu. **Şu an tek tenant: KRB (lastik distribütörü) — tüm platformu inşa etmek için kullanılan PİLOT** (gerçek-dünya ilk vakası). Yani lastik-özel bir araç değil; KRB üzerinden inşa edilen genel bir KOBİ SaaS'ı.

KRB pilotu için kurulan modüller (platformun ilk örneği): **Piyasa** (rakip fiyat scraper + akıllı-eşleme + alarm) · **Saha** (temsilci ziyaret/teklif/müşteri + niyet motoru + sinyal + duyuru + asistan) · **AI asistanlar** (CEO + temsilci) · **Finans/BI** (metrik omurgası + marj atomu + sebep-araştırıcı organizma) · **Ops** (sağlık izleme) · **Platform** (çok-kiracılık/auth/ERP ingest).

**Moat (sektör-bağımsız, ölçeklenir kısım):** kendini-büyüten **sebep-araştırıcı organizma** — herhangi bir KOBİ'nin verisinde işin bütününü görüp **NEDEN** diyen, tek taraflı bakmayan (net/çapraz), bilmediğinde "bilmiyorum" diyen, onaylanan her korelasyonu **kalıcı yasaya** çevirip zamanla bileşik büyüyen katman. Rakip bir özelliği kopyalar; büyüyen organizmayı kopyalayamaz. Bu, bespoke tek-müşteri aracını **ölçeklenir SaaS**'a çeviren şey.

## Değişmez kurallar
- **Fatih tüm ssh/scp'yi KENDİ çalıştırır; asistan SADECE script verir.** scp ve ssh AYRI komut satırında.
- **`docker cp` YASAK.** Deploy: `docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment`. Footprint otomatik (`footprintOnBoot()` her restart).
- Canlı dosyaya (server_container.mjs ~32k / shells/bi.js) körlemesine dokunma: desen keşfi → Python tam-metin yama → `node --check` → varlık/yer doğrula → deploy. **Doğrulama sorgusu da doğrulanmalı.**
- "Doğru" diye kabul etme, çift-kontrol. "Bugün çalışır" ASLA.
- **KENDİ HAKEMİN OL:** her karar önce kendine muhalefet (zayıf nokta/kör taraf/hata).
- Tek taraflı sayı = bug (organizma ilkesi: net/çapraz). Sebebi VARSAYMA, örneğe SAPLANMA.
- **Canlı organizma: HİÇBİR YERDE sabit/hardcoded sayı ya da ifade yok** — her rakam render anında veriden çözülür; bağlı olmayan kaynak sayı ÜRETMEZ ("bağlı değil" der).
- **Odalar/özellikler KULLANICI YETKİSİ bazlı** (`permissions.departments`, bi.js ~satır 7); her kullanıcı her odayı görmez. Oda kaldırma client-tarafı toplu (`allowedDepts=[]`) DEĞİL — yetki katmanından.
- **Chip düzeltmeleri PENDING** (`bi_kokpit_duzeltme.durum='beklemede'`): veri-doğruluğu/öz-öğrenme sinyali (sosyal yorum değil); organizma tartar, otomatik uygulanmaz.
- **Her deploy → DEVIR + INSA_GUNLUGU + `bi_insa_gunlugu` güncellenir.** Ayak izi olmadan deploy yok.
- Rakip B2B şifreleri peşine düşülmez.

## Asistan hata modları — TEKRARLAMA
- Bilineni "yeni buluş / en büyük bulgu" diye sunma → önce günlüğü kontrol et.
- Menü sunup "sen söyle" moduna kayma; Fatih LİDERLİK bekler (plana dayalı net öneri, yabancıya sorar gibi değil).
- Dramatize etme; sade + kanıtlı + mütevazı.
- "Mola / fresh session mı?" diye sürekli sorma.

## Altyapı
- SSH: `ssh -i ~/.ssh/roomsium_hetzner_ed25519 root@5.161.234.59` · repo `/opt/krb-assessment` · app localhost:8080
- DB: `docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform` · KRB tenant `f8a5d20f-ecf8-4ce2-a492-69268fbb03fa`
- Cron: metrik+atom snapshot 08:15 · nabız 08:35 · scraper /opt/price_monitor 02:00-10:00
- E-posta: Microsoft Graph, sender consult@deriveglobal.com. ⚠ DKIM/DMARC yok (#78) → spam riski.
- Belgeler (kalıcı): `/opt/krb-assessment/derive_arsiv/` (DEVIR + INSA + TESPIT). Çalışan kopyalar: `~/Desktop/krb-session-outputs/`.

## Mevcut durum (özet — detay DEVIR §2 + §EK-8..21)  ⟵ SON: 2026-07-17 (omurga_68→84; BI home 5 oda/Kokpit açılış, CEO Assistant organizmaya bağlı, denetim 2 kırmızı düzeldi)
- **Organizma CANLI:** marj atomu (dönem-eşleşmeli maliyet), sebep-araştırıcı (marka+müşteri), yasa katmanı (`bi_yasa`+`capraz_kontrol`), hunter (`korelasyon_avci`), öğrenme döngüsü (`ogren_sor`+trigger), içgörü servisi (`GET /api/bi/icgoru`), nabız (news-only e-posta).
- **Maliyet bazı DOĞRULANDI** (Brisa alış faturasıyla eşleşti). Ekranda **BRÜT** marj + "incentive system has not been applied" notu = dürüst gerçek.
- **Teşvik-net katmanı DORMANT + HATALI** (çifte-sayım + yaz lastiğine kış teşviki). Hiçbir ekran okumuyor → canlı etki yok. **ERTELENDİ.** Rebuild: ürün-bazlı gerçek sezon + kesin-net=brüt + arka-uç prim (veride yok).
- **`zararina_hacim` yasası CANLI** (omurga_68, onaylandı → taslak, capraz_kontrol'de ateşliyor). **Güven bacağı:** 3 sorunlu satır onaylı (omurga_69); defter onaylı 3·taslak 212·tanımsız 15 (çekirdek)·değişti 1. İlke: onaylı=teyit, TOPLU damgalanmaz.
- **Boyutlar (§6.5) TAMAM** (omurga_70/71/72): backbone **marka+segment+sezon+KANAL+stok** pivot. İçgörü: YENİLEME −%6,2; sezon YAZ %4,2/KIŞ %18,2; **kanal TOPTAN %4,7 (ince) vs PERAKENDE %15,9 vs E-TİCARET %21,7** (kanal=bi_musteri_risk.grup, kanal_normalize).
- **ERP ingest MANUEL + ~5 gün geride** (kırık DEĞİL; SNAPSHOT-İLERİ kararı, otomasyon KRB-IT/SAP-kapılı hatta park — §EK-8). Piyasa/scraper canlı.
- **CAM-KOKPİT (§6.7) CANLI — Finans odasının ANA görünümü** (omurga_73: `/api/bi/kokpit` + `kokpit-data`, bi.js finans→iframe; omurga_74: düzen kalıcılığı `bi_kokpit_tercih` + bekleyen-düzeltme `bi_kokpit_duzeltme` öğrenme döngüsü + tam canlılık/sabit sayı yok; omurga_75: **Piyasa Radar CANLI = izlenen SKU** (`bi_rakip_izle` son_min+hedef+alarm), tüm-piyasa dökümü değil). ⓘ=`shells/bi.js` DEFS. **v1 dashboard reddedildi.** omurga_76: Finans sekme adı→"Kokpit" (yetki/rota dokunulmadı). omurga_77: trend YIL-ÜSTÜ/YoY karşılaştırma (m−12 self-join; geçmiş yoksa çizilmez). Detay DEVIR §EK-13/14/15. Sıradaki: biz-vs-rakip eşleşme (`bi_price_monitor` doldur) · düzeltme adjudication.
- **SAHA modülü — rep raporları KAPANDI** (omurga_78, §EK-16): 2 gerçek temsilcinin 1 haftalık kullanımından çıkan tüm hata/istek maddeleri canlı — dosya yükleme+silme · yükleme→owner e-posta · VKN/TC autofill · not→müşteri bağlama · **müşteri ziyaret geçmişi PAYLAŞIMLI** (per-rep değil; Fatih "everyone should see all visits") · teklif VADE (veri-güdümlü split) · ziyaret formu kimlik şeridi · **VKN→ERP OTOMATİK eşleşme** (kayıt anı + refresh toplu + manuel "🔍 ERP'de Ara"). Doğrulama 278/236/orphan=0. Kalan iyileştirme (rapor değil): il-ilçe oto-seçim · tip/durum/kanal etiketleri. ⚠ saha.js deploy → **Cmd+Shift+R** şart. Ders: scoping yönünü modeli teyit etmeden kurma.
- **SAHA cila + E2E denetim** (omurga_79, §EK-17): ✅ tema sızıntısı fix (app.js `<html data-tema=koyu>` → saha `.saha-app`/`.modal-fon`'a açık token sabitlendi; BI koyu kalır, saha hep açık) · ✅ Plan takviminde hatırlatmalar · ✅ günlük özet e-postası markdown→HTML (`_mdToHtml`, Fatih Bilen). **Denetim:** tek responsive shell (ayrı masaüstü YOK; yan-menü inşa edilmemiş, geniş ekranda uçtan uca). 🟢 **2 kırmızı DÜZELDİ** (omurga_84): konuşma yetki doğrulaması + kalem-karar `[manager,admin]` + 3 takılma fix.
- **BI home 5 oda** (omurga_82, §EK-20): Kokpit(açılış) · CEO Assistant · Fiyat · Rakip Fiyatları · Veri. Diğerleri (sales/pricing/warehouse/it/orders/marka/bugün) OFFICERS tanımından çıkarıldı (org-geneli; endpoint/veri durur). bi.js.
- **CEO Assistant organizmaya bağlı** (omurga_83, §EK-21): Brain promptunda SİSTEM HARİTASI (bi_marj_atom·sebep_arastir·bi_yasa/capraz_kontrol·bi_icgoru·kokpit·saha·5-oda) + kendini-tanıtan defterleri (bi_yetenek/bi_insa_gunlugu/bi_icgoru) dinamik okur (doküman gönderme DEĞİL). Ziyaret+duyuru essential. get_dept_kpis (eski dept) kaldırıldı. ⚠ **Ders:** asistanı yapıya bağlamak = kendini-tanıtan deftere bağla, statik doküman dökme.
- **Açık büyük iş:** masaüstü düzeni (responsive shell'de yan menü yok, geniş ekranda uçtan uca — §EK-17).
- **Zengin müşteri kartı** (omurga_80, §EK-18): `GET /api/saha/musteriler/:id/finansal` — ERP finansalları + son 5 alım (SKU/adet/fiyat/tarih) + 12 ay ciro trendi + açık teklifler; musteriDetayModal 💰 bölümü. Her rep her müşteriyi görür. ERP'siz → "veri yok" (uydurmaz).
- **Ziyaret "görüldü"** (omurga_81, §EK-19): `saha_ziyaret_gorulme` + `POST /ziyaretler/:id/gordum` + liste 👁 rozeti + detay "N kişi gördü · isimler"; herkes görür, detay açılınca otomatik. ⚠ **Ders:** yeni tabloyu kritik liste sorgusuna bağlarken `ensureSahaSchema` init'ine güvenme (sessiz CREATE hatası → "relation does not exist" → liste kırıldı); bağımsız migration'ı baştan ver (değişmez kural 10).

## Uzun proje sürekliliği (çalışma biçimi)
Tek oturumu sonsuza uzatma → uzun oturum bozulur. **Kısa, odaklı oturumlar aç; süreklilik bu dosyada + DEVIR'de.** Her oturum başı: bu CLAUDE.md + `derive_arsiv/DEVIR_2026-07-16.md` → `INSA_GUNLUGU.md` oku, SONRA çalış. Yan görevleri sub-agent'a ver (ana bağlam yalın kalsın).
