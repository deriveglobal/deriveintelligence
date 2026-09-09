#!/usr/bin/env bash
# OMURGA 29 — bi_yetenek kayıt defteri (moat çekirdeği): şema + bilinen çekmece seed (taslak)
# + yetenek_tara() mevcut evi enumerate + tanımsızları işaretle (guard simetrisi). DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ŞEMA — bi_yetenek (platform-seviyesi, tenant'sız; sistem neyi biliyor)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_yetenek (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ad text, tur text,                       -- tablo/endpoint/arac/metrik
  ne_ise_yarar text,                       -- hangi soruya cevap verir (sebep-araştırıcı bunu okur)
  nasil text,                              -- nasıl sorgulanır / araç ref
  cekmece text,                            -- fiyat/maliyet/vade/iskonto/mix/iade/musteri/piyasa/ziyaret/teklif/doviz/metrik
  durum text DEFAULT 'tanimsiz',           -- onayli(insan) / taslak(AI) / tanimsiz(bilinmiyor)
  guven text, kanit jsonb, aktif boolean DEFAULT true,
  onaylayan text, eklendi_at timestamptz DEFAULT now(), guncellendi_at timestamptz DEFAULT now(),
  UNIQUE(ad, tur));
SQL
echo "  ✅ bi_yetenek"

hr "2. SEED — bildiğim çekmeceler (durum=taslak; insan onayı bekler)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven) VALUES
('bi_satis_faturalari','tablo','Bizim satış fiyatımız, adet, ciro, ödeme koşulu(vade), müşteri, marka, ebat. "Ne, kime, kaça, hangi vadeyle sattık" sorusuna cevap.','SELECT ... WHERE marka/musteri_kodu/kalem_kodu + fatura_tarihi aralığı; ebat IS NOT NULL=lastik, miktar>0=iade hariç','fiyat','taslak','kesin'),
('bi_tedarikci_faturalari','tablo','Tedarikçiden ne kaça aldık (alış/maliyet). "Alış maliyeti arttı mı" sorusuna.','SELECT ... WHERE kalem_kodu + fatura_tarihi','maliyet','taslak','kesin'),
('bi_stok_hareket','tablo','Stok giriş/çıkış; ağırlıklı ortalama birim alış maliyeti buradan türetilir. "Bu SKU maliyeti ne" sorusuna.','sum(giris_tutari)/sum(giris) GROUP BY kalem_kodu','maliyet','taslak','kesin'),
('bi_stok_anlik','tablo','Eldeki anlık stok adet/değer. "Elde ne kadar var" sorusuna.','SELECT adet WHERE kalem_kodu','mix','taslak','kesin'),
('bi_musteri_risk','tablo','Müşteri bakiye/risk: alacak, çek/senet, kredi limiti. "Müşteri ne kadar borçlu/riskli, ne kadar geç ödüyor" sorusuna.','SELECT hesap_bakiyesi/vadesi_gecmis WHERE musteri','musteri','taslak','kesin'),
('bi_cari_bakiye','tablo','Tedarikçi borcu (cari). "Kime ne kadar borçluyuz" sorusuna.','SELECT tedarikci_bakiye<0','maliyet','taslak','kesin'),
('bi_fiyat_iskonto','tablo','Liste fiyatı + iskonto/prim tavanı. "İskonto disiplini/prim değişti mi, net fiyat neden düştü" sorusuna.','SELECT ... WHERE urun/segment','iskonto','taslak','yaklasik'),
('saha_ziyaret','tablo','Saha temsilcisi SERBEST-METİN notları (fiyat savaşı, müşteri şikayeti, rakip hamlesi). "Sahada ne oldu, temsilci ne dedi" sorusuna — sayı değil METİN.','SELECT notlar/rapor WHERE musteri/tarih; metin arama','ziyaret','taslak','yaklasik'),
('bi_metrik_gecmis','tablo','Metrik geçmişi omurgası: her metriğin aylık trendi (ciro/dso/stok/alacak/borç/net + marka kırılımı). "X metriği zamanla nasıl" sorusuna.','SELECT deger WHERE metrik/boyut/donem','metrik','taslak','kesin'),
('bi_urun_master','tablo','Ürün master: SKU↔ebat↔segment köprüsü. Kırılım join + piyasa eşleme.','JOIN ON kalem_kodu/ebat','mix','taslak','kesin'),
('bi_icgoru','tablo','Üretilen içgörüler (kâr sızıntısı, sessiz kayıp) + para etkisi. Sebep-araştırıcının başlangıç NE listesi.','SELECT WHERE durum=yeni ORDER BY surpriz_skoru','metrik','taslak','kesin')
ON CONFLICT (ad,tur) DO NOTHING;
SQL
echo "  ✅ 11 çekmece taslak"

hr "3. TARAYICI — yetenek_tara(): mevcut evi enumerate, tanımsızları işaretle (guard simetrisi)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION yetenek_tara() RETURNS int AS $fn$
DECLARE yeni int;
BEGIN
  INSERT INTO bi_yetenek (ad, tur, durum, kanit)
  SELECT t.table_name, 'tablo', 'tanimsiz',
    jsonb_build_object(
      'kolonlar',(SELECT array_agg(column_name ORDER BY ordinal_position) FROM information_schema.columns c WHERE c.table_name=t.table_name AND c.table_schema='public'))
  FROM information_schema.tables t
  WHERE t.table_schema='public' AND t.table_type='BASE TABLE'
    AND t.table_name ~ '^(bi_|saha_|ops_|master_|brain_)'
    AND NOT EXISTS (SELECT 1 FROM bi_yetenek y WHERE y.ad=t.table_name AND y.tur='tablo')
  ON CONFLICT (ad,tur) DO NOTHING;
  GET DIAGNOSTICS yeni = ROW_COUNT;
  RETURN yeni;
END; $fn$ LANGUAGE plpgsql;
SQL
$PSQL -c "SELECT yetenek_tara() AS yeni_tanimsiz_cekmece;" 2>&1 | sed 's/^/  /'

hr "4. DURUM — defter dolumu (onayli/taslak/tanimsiz)"
$PSQL -c "SELECT durum, count(*) FROM bi_yetenek WHERE tur='tablo' GROUP BY durum ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'

hr "5. BOŞLUK — tanımsız çekmeceler (AI'ın taslaklayıp insanın onaylayacağı ilk 30)"
$PSQL -c "SELECT ad, array_length((kanit->'kolonlar')::jsonb::text[],1) FROM bi_yetenek WHERE tur='tablo' AND durum='tanimsiz' ORDER BY ad LIMIT 30;" 2>&1 | sed 's/^/  /'

hr "6. PİYASA çekmecesi var mı — scraper/rakip tabloları tanımsızlar arasında"
$PSQL -c "SELECT ad FROM bi_yetenek WHERE tur='tablo' AND durum='tanimsiz' AND ad ~* 'piyasa|rakip|akakce|scrape|market|fiyat|urun|watch|sizescan|smart' ORDER BY ad;" 2>&1 | sed 's/^/  /'

hr "BITTI — defter mevcut evi taradı; taslaklar + tanımsız boşluk görünür. Sonra: piyasa/ziyaret çekmecelerini onayla + sebep-araştırıcı defteri okusun."
