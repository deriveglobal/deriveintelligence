#!/usr/bin/env bash
# OMURGA 33 — yüksek-değerli çekmecelere GERÇEK yapıdan taslak-tanım (durum=taslak, insan onayı bekler). DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TASLAK TANIMLAR — 6 çekmece (veriden, varsayım değil)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
UPDATE bi_yetenek SET cekmece='piyasa', durum='taslak', guven='kesin',
  ne_ise_yarar='Rakip/piyasa fiyat GEÇMİŞİ (scraper: kolayoto vb., 62K satır). "Bu ebat/markanın piyasa fiyatı ne, zamanla nasıl değişti — bizim fiyat düşüşümüzü piyasa haklı çıkarıyor mu" sorusuna.',
  nasil='marka + (genislik/profil/cap→ebat) + gecerli_tarih; fiyat trendi. tenant_id TEXT.'
 WHERE ad='bi_rakip_fiyat_gecmis' AND tur='tablo';

UPDATE bi_yetenek SET cekmece='piyasa', durum='taslak', guven='yaklasik',
  ne_ise_yarar='Piyasa referans fiyatı (cimri): marka+ebat başına en düşük 3 fiyat + satıcı sayısı (82 satır, küçük/kürasyonlu). "Bu ürün piyasada kaça, kaç satıcıda" sorusuna.',
  nasil='marka+ebat eşleme; cimri_fiyat_1, guncelleme_tarihi'
 WHERE ad='bi_pazar_fiyat' AND tur='tablo';

UPDATE bi_yetenek SET cekmece='vade', durum='taslak', guven='kesin',
  ne_ise_yarar='Fatura ödeme/tahsilat GEÇMİŞİ (303K satır, GERÇEK odeme_tarihi dolu): vade, gecikme_gun, tahsilat_turu, dso_contribution. "Bu müşteri gerçekte kaç günde ödüyor, vade uzadı mı, yavaş-ödeyen mi, DSO katkısı ne" sorusuna. ⭐ DSO snapshot değil KESİN yapılabilir.',
  nasil='musteri_kodu/fatura_no; gecikme_gun, odeme_tarihi-fatura_tarihi, dso_contribution'
 WHERE ad='bi_odeme_gecmisi' AND tur='tablo';

UPDATE bi_yetenek SET cekmece='ziyaret', durum='taslak', guven='yaklasik',
  ne_ise_yarar='Saha ziyaret raporları (854, SERBEST METİN): notlar (fiyat savaşı, rakip hamlesi, müşteri şikayeti, talep) + detay jsonb (rakipler, raf_markalari, stok). "Sahada ne oldu, bu müşteride/bölgede rakip ne yapıyor" sorusuna — SAYI DEĞİL istihbarat.',
  nasil='musteri_id + ziyaret_tarihi; notlar metin arama (ILIKE/tsvector) + detay->rakipler/raf_markalari'
 WHERE ad='saha_ziyaret' AND tur='tablo';

UPDATE bi_yetenek SET cekmece='marj', durum='taslak', guven='yaklasik',
  ne_ise_yarar='HAZIR marj fact (28K, aylık): marka/ebat/kategori/müşteri/SKU + ŞUBE/ŞEHİR/TEMSİLCİ kırılımı ile adet·ciro·birim_maliyet·smm·brut_kar·marj_pct. Marj decomposition için hazır (temsilci/şube boyutu bizde yok!). ⚠ TAZELİK+tanım doğrulanmalı (maliyet_kaynak, 235M ile tutuyor mu).',
  nasil='GROUP BY marka/musteri/kalem/sube/temsilci + ay filtresi; marj_pct, brut_kar'
 WHERE ad='bi_marj_fact' AND tur='tablo';

UPDATE bi_yetenek SET cekmece='kacan', durum='taslak', guven='yaklasik', aktif=false,
  ne_ise_yarar='Kaçan satışlar (talep-karşılanan-kaçan miktar + tahmini_gelir_kaybi + neden). "Stoksuzluk/başka nedenle ne sattırmadık" sorusuna. ⚠ 0 SATIR — tablo tanımlı ama BESLENMİYOR (akış kur).',
  nasil='(boş) — beslenince: musteri/kalem + kacan_miktar, tahmini_gelir_kaybi, neden'
 WHERE ad='bi_kacan_satislar' AND tur='tablo';
SQL
echo "  ✅ 6 çekmece taslaklandı"

hr "2. DURUM — defter tür×durum (taslak arttı mı)"
$PSQL -c "SELECT tur, durum, count(*) FROM bi_yetenek GROUP BY tur,durum ORDER BY tur,durum;" 2>&1 | sed 's/^/  /'

hr "3. TASLAK ÇEKMECELER — sebep-araştırıcının okuyacağı (cekmece etiketli)"
$PSQL -c "SELECT cekmece, ad, guven, left(ne_ise_yarar,70) FROM bi_yetenek WHERE tur='tablo' AND durum='taslak' AND cekmece IS NOT NULL ORDER BY cekmece,ad;" 2>&1 | sed 's/^/  /'

hr "BITTI — çekmeceler tanımlı (taslak). Onayınca sebep-araştırıcı defteri okur."
