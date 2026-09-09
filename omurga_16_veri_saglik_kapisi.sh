#!/usr/bin/env bash
# OMURGA 16 (#127) — Veri Sağlık Kapısı: bilinen-değer kaydı + alarm + kapı fonksiyonu + demo. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TABLOLAR — config + bilinen-değer kaydı + alarm"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_saglik_config (
  tablo text, kolon text, PRIMARY KEY (tablo,kolon));
CREATE TABLE IF NOT EXISTS bi_bilinen_deger (
  tenant_id uuid, tablo text, kolon text, deger text,
  UNIQUE (tenant_id, tablo, kolon, deger));
CREATE TABLE IF NOT EXISTS bi_saglik_alarm (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid, tablo text, kolon text, deger text, adet bigint,
  tip text, durum text DEFAULT 'yeni', tespit_at timestamptz DEFAULT now());
-- guard edilecek kategorik kolonlar (bugün tuzak yaşadıklarımız öncelikli)
INSERT INTO bi_saglik_config (tablo,kolon) VALUES
  ('bi_satis_faturalari','marka'),
  ('bi_satis_faturalari','odeme_kosulu'),
  ('bi_satis_faturalari','grup_adi'),
  ('bi_tedarikci_faturalari','kdv_orani'),
  ('bi_stok_anlik','marka'),
  ('bi_stok_anlik','grup_adi'),
  ('bi_fatura_tahsilat','tahsilat_turu'),
  ('bi_stok_hareket','belge_turu')
ON CONFLICT DO NOTHING;
SQL
echo "  ✅ tablolar + config"

hr "2. FONKSİYONLAR — baz al (whitelist) + kapı (denetle)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
-- Bilinen-değer whitelist'ini MEVCUT veriden seed et (bugün = baz).
CREATE OR REPLACE FUNCTION veri_saglik_baz_al(p_tenant uuid) RETURNS void AS $$
DECLARE c record;
BEGIN
  FOR c IN SELECT tablo,kolon FROM bi_saglik_config LOOP
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name=c.tablo AND column_name=c.kolon) THEN
      EXECUTE format(
        'INSERT INTO bi_bilinen_deger (tenant_id,tablo,kolon,deger)
           SELECT $1,%L,%L,v FROM (SELECT DISTINCT %I::text v FROM %I WHERE tenant_id::text=$1::text AND %I IS NOT NULL) s
         ON CONFLICT (tenant_id,tablo,kolon,deger) DO NOTHING',
         c.tablo,c.kolon,c.kolon,c.tablo,c.kolon) USING p_tenant;
    END IF;
  END LOOP;
END; $$ LANGUAGE plpgsql;

-- KAPI: bilinmeyen değer + aralık kapıları → alarm. Tanımadığını SESSİZCE KABUL ETME.
CREATE OR REPLACE FUNCTION veri_saglik_kapisi(p_tenant uuid) RETURNS integer AS $$
DECLARE c record;
BEGIN
  -- önceki 'yeni' alarmları temizle (idempotent); çözülenler kalır
  DELETE FROM bi_saglik_alarm WHERE tenant_id=p_tenant AND durum='yeni';
  -- 1) bilinmeyen kategorik değer
  FOR c IN SELECT tablo,kolon FROM bi_saglik_config LOOP
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name=c.tablo AND column_name=c.kolon) THEN
      EXECUTE format(
        'INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
           SELECT $1,%L,%L,v,cnt,''bilinmeyen_deger''
             FROM (SELECT %I::text v, count(*) cnt FROM %I WHERE tenant_id::text=$1::text AND %I IS NOT NULL GROUP BY 1) s
            WHERE NOT EXISTS (SELECT 1 FROM bi_bilinen_deger b WHERE b.tenant_id=$1 AND b.tablo=%L AND b.kolon=%L AND b.deger=s.v)',
         c.tablo,c.kolon,c.kolon,c.tablo,c.kolon,c.tablo,c.kolon) USING p_tenant;
    END IF;
  END LOOP;
  -- 2) aralık kapısı: fatura tarihi [2015, bugün+1] dışı
  INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
  SELECT p_tenant,'bi_satis_faturalari','fatura_tarihi','aralık dışı ('||min(fatura_tarihi)||'..'||max(fatura_tarihi)||')',
         count(*) FILTER (WHERE fatura_tarihi<DATE '2015-01-01' OR fatura_tarihi>CURRENT_DATE+1),'aralik'
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text
   HAVING count(*) FILTER (WHERE fatura_tarihi<DATE '2015-01-01' OR fatura_tarihi>CURRENT_DATE+1) > 0;
  -- 3) ×10.000 dedektörü: satir_tutar mantıksız tavan
  INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
  SELECT p_tenant,'bi_satis_faturalari','satir_tutar','>50M şüpheli (×10.000?)',
         count(*) FILTER (WHERE satir_tutar>50000000),'aralik'
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text
   HAVING count(*) FILTER (WHERE satir_tutar>50000000) > 0;
  RETURN (SELECT count(*) FROM bi_saglik_alarm WHERE tenant_id=p_tenant AND durum='yeni');
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ veri_saglik_baz_al + veri_saglik_kapisi"

hr "3. BAZ AL — bugünkü değerleri whitelist'e (baz nokta)"
$PSQL -c "SELECT veri_saglik_baz_al('$T'::uuid);" >/dev/null
$PSQL -c "SELECT tablo, kolon, count(*) bilinen_deger FROM bi_bilinen_deger WHERE tenant_id='$T'::uuid GROUP BY 1,2 ORDER BY 1,2;"

hr "4. KAPIYI ÇALIŞTIR — baz sonrası temiz olmalı (0 bilinmeyen)"
$PSQL -c "SELECT veri_saglik_kapisi('$T'::uuid) AS yeni_alarm;"
$PSQL -c "SELECT tip, count(*) FROM bi_saglik_alarm WHERE tenant_id='$T'::uuid AND durum='yeni' GROUP BY 1;"

hr "5. ⚠ DEMO — 'SAILUN' whitelist'ten çıkar, yükleme simüle et, kapı yakalıyor mu?"
$PSQL -c "DELETE FROM bi_bilinen_deger WHERE tenant_id='$T'::uuid AND tablo='bi_satis_faturalari' AND kolon='marka' AND deger='SAILUN';" >/dev/null
$PSQL -c "SELECT veri_saglik_kapisi('$T'::uuid) AS yeni_alarm;"
echo "  --- kapının yakaladığı (SAILUN bilinmeyen görünmeli) ---"
$PSQL -c "SELECT tablo,kolon,deger,adet,tip FROM bi_saglik_alarm WHERE tenant_id='$T'::uuid AND durum='yeni' AND deger='SAILUN';"
echo "  --- demo temizliği: SAILUN'u geri ekle + yeniden denetle ---"
$PSQL -c "INSERT INTO bi_bilinen_deger VALUES ('$T'::uuid,'bi_satis_faturalari','marka','SAILUN') ON CONFLICT DO NOTHING; SELECT veri_saglik_kapisi('$T'::uuid) AS temiz_mi;"

hr "6. AYAK İZİ"
$PSQL -c "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_16_#127','Veri Saglik Kapisi: bilinen-deger kaydi + alarm + veri_saglik_kapisi() fonksiyonu','Yeni yuklemede bilinmeyen deger/aralik sessizce gecmesin','{}');" >/dev/null 2>&1 || true
echo "  ✅ kaydedildi"

hr "BITTI — guard çekirdeği kuruldu + demo kanıtladı. Sonraki: ingest sonrası cron'a bağla + UI."
