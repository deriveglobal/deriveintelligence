#!/usr/bin/env bash
# OMURGA 19 (#127) — guard'a doğal-anahtar mükerrer-ARTIŞ takibi (mevcut baz, yeni artış → alarm). DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. FONKSİYON — veri_saglik_mukerrer (flow tabloları doğal-anahtar tekrar sayısı, artış → alarm)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
CREATE OR REPLACE FUNCTION veri_saglik_mukerrer(p_tenant uuid) RETURNS void AS $$
DECLARE cur_extra numeric; prev_extra numeric; i int;
  cfg text[] := ARRAY[
    'bi_satis_faturalari','fatura_no,kalem_kodu,fatura_tarihi',
    'bi_tedarikci_faturalari','fatura_no,kalem_kodu,fatura_tarihi',
    'bi_stok_hareket','belge_no,belge_tarihi,kalem_kodu,depo'];
  tbl text; cols text;
BEGIN
  i := 1;
  WHILE i <= array_length(cfg,1) LOOP
    tbl := cfg[i]; cols := cfg[i+1];
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name=tbl) THEN
      EXECUTE format('SELECT count(*) - count(DISTINCT (%s)) FROM %I WHERE tenant_id::text=$1::text', cols, tbl)
        INTO cur_extra USING p_tenant;
      SELECT deger INTO prev_extra FROM bi_saglik_agrega
        WHERE tenant_id=p_tenant AND tablo=tbl AND olcum='mukerrer_fazla' ORDER BY ts DESC LIMIT 1;
      -- yeni artış: önceki + %5'ten fazla mükerrer eklendi mi
      IF prev_extra IS NOT NULL AND cur_extra > prev_extra * 1.05 + 10 THEN
        INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,adet,tip)
        VALUES (p_tenant, tbl, 'doğal_anahtar',
                'mükerrer '||prev_extra||' → '||cur_extra||' (YENİ tekrar eklendi — incele)', cur_extra-prev_extra, 'mukerrer');
      END IF;
      INSERT INTO bi_saglik_agrega (tenant_id,tablo,olcum,deger) VALUES (p_tenant, tbl, 'mukerrer_fazla', cur_extra);
    END IF;
    i := i + 2;
  END LOOP;
END; $$ LANGUAGE plpgsql;
SQL
echo "  ✅ veri_saglik_mukerrer"

hr "2. mutabakat'a BAĞLA — sonunda mükerrer takibi de çalışsın"
$PSQL -v ON_ERROR_STOP=1 -c "
CREATE OR REPLACE FUNCTION veri_saglik_mutabakat(p_tenant uuid) RETURNS void AS \$\$
DECLARE cur_avg numeric; prev_avg numeric; d numeric; i int;
  cfg text[] := ARRAY['bi_satis_faturalari','satir_tutar','bi_tedarikci_faturalari','satir_kdv_haric','bi_stok_anlik','adet','bi_musteri_risk','hesap_bakiyesi','bi_cari_bakiye','tedarikci_bakiye'];
  tbl text; kol text;
BEGIN
  i := 1;
  WHILE i <= array_length(cfg,1) LOOP
    tbl := cfg[i]; kol := cfg[i+1];
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name=tbl AND column_name=kol) THEN
      EXECUTE format('SELECT avg(%I) FROM %I WHERE tenant_id::text=\$1::text', kol, tbl) INTO cur_avg USING p_tenant;
      SELECT deger INTO prev_avg FROM bi_saglik_agrega WHERE tenant_id=p_tenant AND tablo=tbl AND olcum='avg_'||kol ORDER BY ts DESC LIMIT 1;
      IF prev_avg IS NOT NULL AND prev_avg<>0 AND cur_avg IS NOT NULL THEN
        d := abs(cur_avg-prev_avg)/abs(prev_avg);
        IF d > 0.5 THEN
          INSERT INTO bi_saglik_alarm (tenant_id,tablo,kolon,deger,tip)
          VALUES (p_tenant, tbl, kol, 'ort '||round(prev_avg)||' → '||round(cur_avg)||' (%'||round(d*100)||' sıçrama)', 'mutabakat');
        END IF;
      END IF;
      IF cur_avg IS NOT NULL THEN INSERT INTO bi_saglik_agrega (tenant_id,tablo,olcum,deger) VALUES (p_tenant, tbl, 'avg_'||kol, cur_avg); END IF;
    END IF;
    i := i + 2;
  END LOOP;
  PERFORM veri_saglik_mukerrer(p_tenant);
END; \$\$ LANGUAGE plpgsql;"
echo "  ✅ mutabakat mükerrer'i çağırıyor (kapı zaten mutabakat'ı çağırıyor)"

hr "3. BAZ — mevcut mükerrer sayıları (baz nokta; artış olmadığı için alarm yok)"
$PSQL -c "SELECT veri_saglik_kapisi('$T'::uuid) AS yeni_alarm;"
$PSQL -c "SELECT tablo, olcum, round(deger) mevcut_mukerrer FROM bi_saglik_agrega WHERE tenant_id='$T'::uuid AND olcum='mukerrer_fazla' ORDER BY tablo;"

hr "4. AYAK İZİ"
$PSQL -c "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_19_#127mukerrer','guard dogal-anahtar mukerrer-artis takibi','52x emisyon gibi belirsiz tekrar: mevcut baz, yeni artis alarm (either way possible - otomatik silme yok)','{}');" >/dev/null 2>&1 || true
echo "  ✅"

hr "BITTI — guard mükerrer-artışı da izliyor. Mevcut 40K baz; gelecekte artarsa alarm + insan karar verir."
