#!/usr/bin/env bash
# OMURGA 30 — yetenek defteri YAŞAM DÖNGÜSÜ: parmak izi + değişim/silinme tespiti (guard simetrisi).
# yetenek_tara() v2: yeni / değişen(güven geri al) / kayıp. + kukla tabloyla KANIT. DB-only.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. ŞEMA — parmak izi + son görülme kolonları"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
ALTER TABLE bi_yetenek ADD COLUMN IF NOT EXISTS parmak_izi text;
ALTER TABLE bi_yetenek ADD COLUMN IF NOT EXISTS son_gorulme timestamptz;
SQL
echo "  ✅"

hr "2. TARAYICI v2 — parmak izi diff (yeni/değişen/kayıp)"
$PSQL -v ON_ERROR_STOP=1 <<'SQL' || exit 1
DROP FUNCTION IF EXISTS yetenek_tara();
CREATE OR REPLACE FUNCTION yetenek_tara() RETURNS jsonb AS $fn$
DECLARE yeni int:=0; degisen int:=0; kayip int:=0;
BEGIN
  CREATE TEMP TABLE _cur ON COMMIT DROP AS
    SELECT t.table_name AS ad,
           md5(string_agg(c.column_name||':'||c.data_type, ',' ORDER BY c.ordinal_position)) AS fp,
           array_agg(c.column_name ORDER BY c.ordinal_position) AS kolonlar
    FROM information_schema.tables t
    JOIN information_schema.columns c ON c.table_name=t.table_name AND c.table_schema='public'
    WHERE t.table_schema='public' AND t.table_type='BASE TABLE'
      AND t.table_name ~ '^(bi_|saha_|ops_|master_|brain_)'
    GROUP BY t.table_name;

  -- YENİ (defterde yok)
  INSERT INTO bi_yetenek (ad,tur,durum,parmak_izi,son_gorulme,kanit)
  SELECT ad,'tablo','tanimsiz',fp,now(),jsonb_build_object('kolonlar',kolonlar)
  FROM _cur c WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek y WHERE y.ad=c.ad AND y.tur='tablo');
  GET DIAGNOSTICS yeni = ROW_COUNT;

  -- İLK PARMAK İZİ (null olanlara ata — değişim SAYILMAZ, geçmiş seed/scan)
  UPDATE bi_yetenek y SET parmak_izi=c.fp, son_gorulme=now()
  FROM _cur c WHERE y.ad=c.ad AND y.tur='tablo' AND y.parmak_izi IS NULL;

  -- DEĞİŞEN (parmak izi farklı) — onaylı/taslak güveni GERİ AL
  UPDATE bi_yetenek y SET
    durum = CASE WHEN y.durum IN ('onayli','taslak') THEN 'degisti' ELSE y.durum END,
    kanit = jsonb_set(COALESCE(y.kanit,'{}'::jsonb),'{kolonlar}',to_jsonb(c.kolonlar)) || jsonb_build_object('eski_parmak_izi',y.parmak_izi),
    parmak_izi = c.fp, son_gorulme=now(), guncellendi_at=now()
  FROM _cur c
  WHERE y.ad=c.ad AND y.tur='tablo' AND y.parmak_izi IS NOT NULL AND y.parmak_izi IS DISTINCT FROM c.fp;
  GET DIAGNOSTICS degisen = ROW_COUNT;

  UPDATE bi_yetenek y SET son_gorulme=now() FROM _cur c WHERE y.ad=c.ad AND y.tur='tablo';

  -- KAYIP (defterde var, tabloda yok) — deaktif
  UPDATE bi_yetenek y SET durum='kayip', aktif=false, guncellendi_at=now()
  WHERE y.tur='tablo' AND y.durum<>'kayip' AND NOT EXISTS (SELECT 1 FROM _cur c WHERE c.ad=y.ad);
  GET DIAGNOSTICS kayip = ROW_COUNT;

  RETURN jsonb_build_object('yeni',yeni,'degisen',degisen,'kayip',kayip);
END; $fn$ LANGUAGE plpgsql;
SQL
echo "  ✅ yetenek_tara v2"

hr "3. BACKFILL — mevcut 114 çekmeceye parmak izi ata (temiz baz)"
$PSQL -c "SELECT yetenek_tara() AS ilk;" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT count(*) FILTER (WHERE parmak_izi IS NOT NULL) parmakli, count(*) toplam FROM bi_yetenek WHERE tur='tablo';" 2>&1 | sed 's/^/  /'

hr "4. KANIT — kukla tablo yaşam döngüsü"
echo "  --- a) tablo OLUŞTUR → tara: yeni=1 (tanımsız) → sonra insan onaylar (durum=onayli) ---"
$PSQL -c "CREATE TABLE bi_yz_test(id int, ad text);" >/dev/null 2>&1
$PSQL -c "SELECT yetenek_tara() AS sonuc;" 2>&1 | sed 's/^/    /'
$PSQL -c "UPDATE bi_yetenek SET durum='onayli', ne_ise_yarar='test çekmecesi' WHERE ad='bi_yz_test';" >/dev/null 2>&1
$PSQL -c "SELECT ad,durum,left(parmak_izi,8) fp FROM bi_yetenek WHERE ad='bi_yz_test';" 2>&1 | sed 's/^/    /'

echo "  --- b) tablo DEĞİŞTİR (kolon ekle) → tara: değişen=1, durum onayli→degisti ---"
$PSQL -c "ALTER TABLE bi_yz_test ADD COLUMN yeni_kolon numeric;" >/dev/null 2>&1
$PSQL -c "SELECT yetenek_tara() AS sonuc;" 2>&1 | sed 's/^/    /'
$PSQL -c "SELECT ad,durum,left(parmak_izi,8) fp, kanit->>'eski_parmak_izi' eski FROM bi_yetenek WHERE ad='bi_yz_test';" 2>&1 | sed 's/^/    /'

echo "  --- c) tablo SİL → tara: kayıp=1, durum=kayip aktif=false ---"
$PSQL -c "DROP TABLE bi_yz_test;" >/dev/null 2>&1
$PSQL -c "SELECT yetenek_tara() AS sonuc;" 2>&1 | sed 's/^/    /'
$PSQL -c "SELECT ad,durum,aktif FROM bi_yetenek WHERE ad='bi_yz_test';" 2>&1 | sed 's/^/    /'
$PSQL -c "DELETE FROM bi_yetenek WHERE ad='bi_yz_test';" >/dev/null 2>&1  # temizlik

hr "5. DURUM — defter (kayıp/değişti alarmları görünür)"
$PSQL -c "SELECT durum, count(*) FROM bi_yetenek WHERE tur='tablo' GROUP BY durum ORDER BY 2 DESC;" 2>&1 | sed 's/^/  /'

hr "BITTI — defter değişim+silinmeye karşı kendini iyileştiriyor. Onaylı tanım, altı değişince güveni kaybeder."
