#!/usr/bin/env bash
# OMURGA 12 — Katman 1: bi_metrik_gecmis'e BOYUT ekle (geriye uyumlu) + UNIQUE migrasyonu + cron güncelle. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. KOLON EKLE — boyut_tipi + boyut_deger (mevcut satırlar 'sirket'/'' olur — geriye uyumlu)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
ALTER TABLE bi_metrik_gecmis ADD COLUMN IF NOT EXISTS boyut_tipi  text NOT NULL DEFAULT 'sirket';
ALTER TABLE bi_metrik_gecmis ADD COLUMN IF NOT EXISTS boyut_deger text NOT NULL DEFAULT '';
SQL
echo "  ✅ kolonlar eklendi"

hr "2. UNIQUE MİGRASYONU — eski (tenant,metrik,periyot,donem) → yeni (+ boyut). Dinamik, ada bağımsız."
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
DO $$
DECLARE c text;
BEGIN
  SELECT conname INTO c FROM pg_constraint
   WHERE conrelid='bi_metrik_gecmis'::regclass AND contype='u' LIMIT 1;
  IF c IS NOT NULL THEN EXECUTE 'ALTER TABLE bi_metrik_gecmis DROP CONSTRAINT '||quote_ident(c); END IF;
END $$;
ALTER TABLE bi_metrik_gecmis
  ADD CONSTRAINT bi_metrik_gecmis_u UNIQUE (tenant_id, metrik, boyut_tipi, boyut_deger, periyot, donem);
CREATE INDEX IF NOT EXISTS idx_metrik_boyut ON bi_metrik_gecmis (tenant_id, metrik, boyut_tipi, boyut_deger, periyot, donem);
SQL
echo "  ✅ yeni UNIQUE (boyut dahil) kuruldu"

hr "3. CRON RUNNER'I GÜNCELLE — tüm INSERT'lere boyut='sirket'/'' + ON CONFLICT boyut dahil"
cat > /opt/krb-assessment/metrik_snapshot_gunluk.sh <<'RUNNER'
#!/usr/bin/env bash
# Metrik geçmişi — GÜNLÜK SNAPSHOT (boyut-farkında). Şirket-geneli satırlar boyut_tipi='sirket'.
set -u
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL'
-- A. CIRO (akış)
WITH t_sinir AS (SELECT tenant_id, date_trunc('month',max(fatura_tarihi))::date son_ay, date_trunc('month',min(fatura_tarihi))::date ilk_ay FROM bi_satis_faturalari GROUP BY tenant_id),
aylar AS (SELECT generate_series(date_trunc('month',CURRENT_DATE)::date - interval '2 month', date_trunc('month',CURRENT_DATE)::date, interval '1 month')::date ay)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT ts.tenant_id::uuid, m.metrik,'sirket','','ay',a.ay,
       metrik_ciro(ts.tenant_id::uuid,a.ay,m.lastik),'TL','kesin','bi_satis_faturalari', jsonb_build_object('tam', a.ay < ts.son_ay)
  FROM t_sinir ts CROSS JOIN aylar a CROSS JOIN (VALUES ('ciro_lastik',true),('ciro_tum',false)) AS m(metrik,lastik)
 WHERE a.ay >= ts.ilk_ay
ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, meta=EXCLUDED.meta, hesaplanma_at=now();

-- B. DSO + bileşenleri (içinde bulunulan ay, gerçek)
WITH comp AS (SELECT r.tenant_id, sum(r.hesap_bakiyesi) FILTER (WHERE COALESCE(r.musteri_mi,true)) AS alacak, metrik_gunluk_kredili(r.tenant_id, CURRENT_DATE) AS gunluk FROM bi_musteri_risk r GROUP BY r.tenant_id)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT * FROM (
  SELECT tenant_id,'dso','sirket','','ay',date_trunc('month',CURRENT_DATE)::date, CASE WHEN gunluk>0 THEN round(alacak/gunluk) END,'gun','snapshot','bi_musteri_risk',jsonb_build_object('tam',false) FROM comp
  UNION ALL SELECT tenant_id,'alacak','sirket','','ay',date_trunc('month',CURRENT_DATE)::date,round(alacak),'TL','snapshot','bi_musteri_risk',jsonb_build_object('tam',false) FROM comp
  UNION ALL SELECT tenant_id,'gunluk_kredili_satis','sirket','','ay',date_trunc('month',CURRENT_DATE)::date,round(gunluk),'TL','kesin','bi_satis_faturalari',jsonb_build_object('tam',false) FROM comp
) x
ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

-- C. STOK DEĞERİ (içinde bulunulan ay, gerçek)
WITH km AS (SELECT tenant_id, kalem_kodu, sum(giris_tutari) gt, sum(giris) g FROM bi_stok_hareket WHERE giris>0 GROUP BY tenant_id, kalem_kodu),
sd AS (SELECT a.tenant_id, sum(a.adet*(km.gt/km.g)) deger FROM bi_stok_anlik a JOIN km ON km.tenant_id=a.tenant_id AND km.kalem_kodu=a.kalem_kodu WHERE a.adet>0 GROUP BY a.tenant_id)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT tenant_id,'stok_deger','sirket','','ay',date_trunc('month',CURRENT_DATE)::date,round(deger),'TL','snapshot','bi_stok_anlik',jsonb_build_object('tam',false) FROM sd
ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

-- D. TEDARİKÇİ BORCU (snapshot-only)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT tenant_id,'tedarikci_borcu','sirket','','ay',date_trunc('month',CURRENT_DATE)::date, round(sum(abs(tedarikci_bakiye)) FILTER (WHERE tedarikci_bakiye<0)),'TL','snapshot','bi_cari_bakiye', jsonb_build_object('tam',false,'not','snapshot-only') FROM bi_cari_bakiye GROUP BY tenant_id
ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, kaynak=EXCLUDED.kaynak, meta=EXCLUDED.meta, hesaplanma_at=now();

-- E. NET İŞLETME SERMAYESİ (türev)
INSERT INTO bi_metrik_gecmis (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem,deger,birim,guven,kaynak,meta)
SELECT s.tenant_id,'net_isletme_sermayesi','sirket','','ay',date_trunc('month',CURRENT_DATE)::date, s.deger+a.deger-b.deger,'TL','snapshot','turev',jsonb_build_object('tam',false,'formul','stok+alacak-borc')
  FROM (SELECT tenant_id,deger FROM bi_metrik_gecmis WHERE metrik='stok_deger' AND boyut_tipi='sirket' AND donem=date_trunc('month',CURRENT_DATE)::date) s
  JOIN (SELECT tenant_id,deger FROM bi_metrik_gecmis WHERE metrik='alacak' AND boyut_tipi='sirket' AND donem=date_trunc('month',CURRENT_DATE)::date) a USING(tenant_id)
  JOIN (SELECT tenant_id,deger FROM bi_metrik_gecmis WHERE metrik='tedarikci_borcu' AND boyut_tipi='sirket' AND donem=date_trunc('month',CURRENT_DATE)::date) b USING(tenant_id)
ON CONFLICT (tenant_id,metrik,boyut_tipi,boyut_deger,periyot,donem) DO UPDATE SET deger=EXCLUDED.deger, guven=EXCLUDED.guven, meta=EXCLUDED.meta, hesaplanma_at=now();
SQL
echo "[$(date '+%F %T')] metrik snapshot tamam (boyut-farkinda)"
RUNNER
chmod +x /opt/krb-assessment/metrik_snapshot_gunluk.sh
echo "  ✅ cron runner boyut-farkında yeniden yazıldı"

hr "4. TEST — güncellenen cron çalışıyor mu (idempotent, sirket satırları bozulmadı mı)"
bash /opt/krb-assessment/metrik_snapshot_gunluk.sh

hr "5. DOĞRULA — mevcut satırlar boyut='sirket', sayı korundu, UNIQUE yeni"
$PSQL -c "SELECT boyut_tipi, count(*) FROM bi_metrik_gecmis WHERE tenant_id='$T'::uuid GROUP BY 1;"
$PSQL -c "SELECT conname FROM pg_constraint WHERE conrelid='bi_metrik_gecmis'::regclass AND contype='u';"

hr "6. SONRAKİ ADIM İÇİN — bi_satis_faturalari boyut kolonları (ciro×marka için ne var?)"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_satis_faturalari' AND column_name IN ('marka','ebat','sezon','grup_adi','kategori','kalem_kodu','segment') ORDER BY 1;"

hr "7. DİJİTAL AYAK İZİ — bi_insa_gunlugu (flashback için) + bu adımı kaydet"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_insa_gunlugu (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ts timestamptz DEFAULT now(),
  adim text, ne text, neden text, detay jsonb DEFAULT '{}'::jsonb
);
SQL
$PSQL -c "INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay) VALUES
 ('omurga_12','bi_metrik_gecmis boyut kolonlari (boyut_tipi/boyut_deger) + UNIQUE migrasyonu + cron boyut-farkinda',
  'Finans odasi Katman 1: metrikleri marka/ebat/segment/sezon/musteri kirilimiyla tutabilmek',
  jsonb_build_object('script','omurga_12_boyut_migrasyon.sh','kolon','boyut_tipi,boyut_deger','unique','+boyut','cron','guncellendi'));" >/dev/null
echo "  ✅ ayak izi kaydedildi. Son 5 adım:"
$PSQL -c "SELECT to_char(ts,'MM-DD HH24:MI') zaman, adim, left(ne,46) ne FROM bi_insa_gunlugu WHERE true ORDER BY ts DESC LIMIT 5;" 2>&1 | sed 's/^/  /'

hr "BITTI — Katman 1 (boyutlu omurga) kuruldu, cron uyumlu, ayak izi düşüldü. Sonraki: ciro×marka."
