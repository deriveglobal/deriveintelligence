#!/usr/bin/env bash
# OMURGA 18 (#127) — agrega mutabakat: ortalama sıçraması (×10.000 dedektörü) guard'a. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. TABLO — bi_saglik_agrega (ortalama checkpoint geçmişi)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE TABLE IF NOT EXISTS bi_saglik_agrega (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id uuid, tablo text, olcum text, deger numeric, ts timestamptz DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_saglik_agrega ON bi_saglik_agrega (tenant_id, tablo, olcum, ts DESC);
SQL
echo "  ✅ tablo"

hr "2. FONKSİYON — veri_saglik_mutabakat (ort kıyas, %50+ sıçrama → alarm)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION veri_saglik_mutabakat(p_tenant uuid) RETURNS void AS $$
DECLARE cur_avg numeric; prev_avg numeric; d numeric; i int;
  cfg text[] := ARRAY['bi_satis_faturalari','satir_tutar',
                      'bi_tedarikci_faturalari','satir_kdv_haric',
                      'bi_stok_anlik','adet',
                      'bi_musteri_risk','hesap_bakiyesi',
                      'bi_cari_bakiye','tedarikci_bakiye'];
  tbl text; kol text;
BEGIN
  i := 1;
  WHILE i <= array_length(cfg,1) LOOP
    tbl := cfg[i]; kol := cfg[i+1];
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name=tbl AND column_name=kol) THEN
      EXECUTE format('SELECT avg(%I) FROM %I WHERE tenant_id::text=$1::text', kol, tbl) INTO cur_avg USING p_tenant;
      SELECT deger INTO prev_avg FROM bi_saglik_agrega
        WHERE tenant_id=p_tenant AND tablo=tbl AND olcum='avg_'||kol ORDER BY ts DESC LIMIT 1;
      IF prev_avg IS NOT NULL AND prev_avg<>0 AND cur_avg IS NOT NULL THEN
        d := abs(cur_avg-prev_avg)/abs(prev_avg);
        IF d > 0.5 THEN
          INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,tip)
          VALUES (p_tenant, tbl, kol, 'ort '||round(prev_avg)||' → '||round(cur_avg)||' (%'||round(d*100)||' sıçrama)', 'mutabakat');
        END IF;
      END IF;
      IF cur_avg IS NOT NULL THEN
        INSERT INTO bi_saglik_agrega (tenant_id,tablo,olcum,deger) VALUES (p_tenant, tbl, 'avg_'||kol, cur_avg);
      END IF;
    END IF;
    i := i + 2;
  END LOOP;
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ veri_saglik_mutabakat"

hr "3. veri_saglik_kapisi'na BAĞLA — sonunda mutabakat da çalışsın"
$PSQL -v ON_ERROR_STOP=1 -c "
CREATE OR REPLACE FUNCTION veri_saglik_kapisi(p_tenant uuid) RETURNS integer AS \$\$
DECLARE c record;
BEGIN
  DELETE FROM bi_saglik_alarm WHERE tenant_id=p_tenant AND durum='yeni';
  FOR c IN SELECT tablo,kolon FROM bi_saglik_config LOOP
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name=c.tablo AND column_name=c.kolon) THEN
      EXECUTE format(
        'INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
           SELECT \$1,%L,%L,v,cnt,''bilinmeyen_deger''
             FROM (SELECT %I::text v, count(*) cnt FROM %I WHERE tenant_id::text=\$1::text AND %I IS NOT NULL GROUP BY 1) s
            WHERE NOT EXISTS (SELECT 1 FROM bi_bilinen_deger b WHERE b.tenant_id=\$1 AND b.tablo=%L AND b.kolon=%L AND b.deger=s.v)',
         c.tablo,c.kolon,c.kolon,c.tablo,c.kolon,c.tablo,c.kolon) USING p_tenant;
    END IF;
  END LOOP;
  INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
  SELECT p_tenant,'bi_satis_faturalari','fatura_tarihi','aralık dışı ('||min(fatura_tarihi)||'..'||max(fatura_tarihi)||')',
         count(*) FILTER (WHERE fatura_tarihi<DATE '2015-01-01' OR fatura_tarihi>CURRENT_DATE+1),'aralik'
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text
   HAVING count(*) FILTER (WHERE fatura_tarihi<DATE '2015-01-01' OR fatura_tarihi>CURRENT_DATE+1) > 0;
  INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
  SELECT p_tenant,'bi_satis_faturalari','satir_tutar','>50M şüpheli (×10.000?)',
         count(*) FILTER (WHERE satir_tutar>50000000),'aralik'
    FROM bi_satis_faturalari WHERE tenant_id::text=p_tenant::text
   HAVING count(*) FILTER (WHERE satir_tutar>50000000) > 0;
  PERFORM veri_saglik_mutabakat(p_tenant);
  RETURN (SELECT count(*) FROM bi_saglik_alarm WHERE tenant_id=p_tenant AND durum='yeni');
END; \$\$ LANGUAGE plpgsql;"
echo "  ✅ veri_saglik_kapisi mutabakat'ı çağırıyor"

hr "4. BAZ — ilk çalıştır (agrega snapshot alınır, önceki yok → mutabakat alarmı yok)"
$PSQL -c "SELECT veri_saglik_kapisi('$T'::uuid) AS yeni_alarm;"
$PSQL -c "SELECT tablo, olcum, round(deger,1) ort FROM bi_saglik_agrega WHERE tenant_id='$T'::uuid ORDER BY tablo;"

hr "5. ⚠ DEMO — son snapshot'ı 10× yap (×10.000 bug simülasyonu), kapı yakalıyor mu?"
$PSQL -c "UPDATE bi_saglik_agrega SET deger=deger*0.1 WHERE tenant_id='$T'::uuid AND tablo='bi_satis_faturalari' AND olcum='avg_satir_tutar' AND ts=(SELECT max(ts) FROM bi_saglik_agrega WHERE tenant_id='$T'::uuid AND tablo='bi_satis_faturalari' AND olcum='avg_satir_tutar');" >/dev/null
$PSQL -c "SELECT veri_saglik_kapisi('$T'::uuid) AS yeni_alarm;"
$PSQL -c "SELECT tablo,kolon,deger,tip FROM bi_saglik_alarm WHERE tenant_id='$T'::uuid AND durum='yeni' AND tip='mutabakat';"
echo "  ⚠ 'ort ... sıçrama' mutabakat alarmı görünmeli (önceki ×0.1, şimdi gerçek → ~%900 sıçrama)."

hr "6. AYAK İZİ"
$PSQL -c "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_18_#127mutabakat','agrega mutabakat: ort sicramasi (x10000 dedektoru) guarda','Toplu deger bozulmasi sessizce gecmesin','{}');" >/dev/null 2>&1 || true
echo "  ✅"

hr "BITTI — guard artık bilinmeyen-değer + aralık + ORTALAMA-SIÇRAMA denetliyor. Kalan: alarm UI."
