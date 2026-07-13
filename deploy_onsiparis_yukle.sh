#!/usr/bin/env bash
# ONSIPARIS_TABLO_V1 — bi_on_siparis. Siparis artik SISTEMDE, dosyada degil.
#   ./deploy_onsiparis_yukle.sh --yaz
#
# ⚠ NEDEN TABLO: siparis tek seferlik bir belge DEGIL, SEZON BOYUNCA
#   olcecegimiz bir TAAHHUT. Dosyada kalirsa bir hafta sonra kimse hatirlamaz.
#
# NE ICIN KULLANILACAK:
#   1) GERCEKLESME  : siparis -> sevk (invmoving) -> depo -> satis
#   2) NAKIT TAKVIMI: 1.donem -> 18 Kas + 16 Ara · 2.donem -> 22 Oca + 22 Sub
#   3) SEZON ICI UYARI: "235/65R16C'nin %80'i satildi, sezonun yarisi var — tukenecek"
#   4) KREDI CAKISMASI: Mutaflar'in 23.362 adedi ne zaman sevk edilecek, riski ne olacak?
#   5) MODEL KARNESI: model 27.671 dedi, KRB 34.544 aldi. Sezon sonunda kalibre et.
#
# ⚠ ALICI AYRIMI KRITIK:
#   KRB      38.088 -> KRB'nin KENDI STOK riski
#   MUTAFLAR 23.362 -> ON SATIS (musteri taahhudu) -> KREDI riski, stok riski DEGIL
#   YEDI_OTO  7.272 -> ON SATIS
#   BAR_OTO   3.448 -> ON SATIS
#   Ikisini karistirmak = 72.170 adedi "KRB fazla stok bagladi" diye okumak. YANLIS.
#
# MUTABAKAT (Ozet Tablo ile birebir dogrulandi):
#   LS+BS KRB 12.902 ✅ · DAYTON KRB 2.530 ✅ · MUTAFLAR 17.570 ✅ · YEDI OTO 7.272 ✅
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"
SEZON="2026-27"

[ -f on_siparis_TEMIZ.csv ] || { echo "❌ on_siparis_TEMIZ.csv YOK"; exit 1; }
N=$(($(wc -l < on_siparis_TEMIZ.csv)-1)); echo "✅ CSV: $N satir"
[ "${1:-}" = "--yaz" ] || { echo "  KURU. Yaz: ./deploy_onsiparis_yukle.sh --yaz"; exit 0; }

echo
echo "############ 1) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS bi_on_siparis (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  sezon_yili   text NOT NULL,           -- '2026-27'
  ingested_at  timestamptz NOT NULL DEFAULT now(),
  tedarikci    text NOT NULL,           -- BRISA | CONTINENTAL
  marka        text NOT NULL,
  ebat         text NOT NULL,
  urun_kodu    text,
  sezon        text NOT NULL,           -- KIS | YAZ | 4 MEVSIM
  -- ⚠ ALICI: KRB = kendi stogu (STOK riski)
  --          MUTAFLAR/YEDI_OTO/BAR_OTO = musteri on satisi (KREDI riski)
  alici        text NOT NULL,
  -- ⚠ DONEM: odeme takvimini belirler (Brisa taksit slaydi)
  --   1     -> Tem/Agu/Eyl faturasi -> 18 KASIM + 16 ARALIK
  --   2     -> Eki/Kas/Ara faturasi -> 22 OCAK  + 22 SUBAT
  --   EKIM/KASIM/CEVA -> Conti ek sevkler
  donem        text NOT NULL,
  adet         integer NOT NULL,
  fabrika      text,
  uretim_bas   date,
  uretim_bit   date,
  liste_kdvdahil numeric(12,2)
);
CREATE INDEX IF NOT EXISTS idx_bos_tenant  ON bi_on_siparis (tenant_id, sezon_yili, sezon);
CREATE INDEX IF NOT EXISTS idx_bos_ebat    ON bi_on_siparis (tenant_id, ebat, marka);
CREATE INDEX IF NOT EXISTS idx_bos_alici   ON bi_on_siparis (tenant_id, alici);
SQL
echo "  ✅ tablo hazir"

echo
echo "############ 2) YUKLE ############"
tr -d '\r' < on_siparis_TEMIZ.csv > /tmp/_os.csv
docker cp /tmp/_os.csv krb-assessment-postgres:/tmp/_os.csv >/dev/null
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
CREATE TEMP TABLE _os (tedarikci text, marka text, ebat text, urun_kodu text, sezon text,
                       alici text, donem text, adet int, fabrika text,
                       uretim_bas text, uretim_bit text, liste numeric) ON COMMIT DROP;
\copy _os FROM '/tmp/_os.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM bi_on_siparis WHERE tenant_id='$TEN' AND sezon_yili='$SEZON';

INSERT INTO bi_on_siparis (tenant_id, sezon_yili, tedarikci, marka, ebat, urun_kodu, sezon,
                           alici, donem, adet, fabrika, uretim_bas, uretim_bit, liste_kdvdahil)
SELECT '$TEN', '$SEZON', tedarikci, marka, ebat, NULLIF(urun_kodu,''), sezon,
       alici, donem, adet, NULLIF(fabrika,''),
       NULLIF(uretim_bas,'')::date, NULLIF(uretim_bit,'')::date, NULLIF(liste,0)
  FROM _os WHERE adet > 0;

DO \$\$
DECLARE n int; k int; m int; y int; dy int;
BEGIN
  SELECT count(*) INTO n FROM bi_on_siparis WHERE tenant_id='$TEN' AND sezon_yili='$SEZON';
  IF n <> $N THEN RAISE EXCEPTION 'RED: % satir yazildi, % bekleniyordu', n, $N; END IF;

  -- ⚠ MUTABAKAT KAPISI — Ozet Tablo ile birebir
  SELECT COALESCE(sum(adet),0) INTO k FROM bi_on_siparis
   WHERE tenant_id='$TEN' AND sezon_yili='$SEZON' AND tedarikci='BRISA'
     AND sezon='KIS' AND alici='KRB' AND marka IN ('LASSA','BRIDGESTONE');
  IF k <> 12902 THEN RAISE EXCEPTION 'RED: LS+BS KRB = % (12.902 bekleniyordu)', k; END IF;

  SELECT COALESCE(sum(adet),0) INTO dy FROM bi_on_siparis
   WHERE tenant_id='$TEN' AND sezon_yili='$SEZON' AND sezon='KIS' AND alici='KRB' AND marka='DAYTON';
  IF dy <> 2530 THEN RAISE EXCEPTION 'RED: DAYTON KRB = % (2.530 bekleniyordu)', dy; END IF;

  SELECT COALESCE(sum(adet),0) INTO m FROM bi_on_siparis
   WHERE tenant_id='$TEN' AND sezon_yili='$SEZON' AND tedarikci='BRISA'
     AND sezon='KIS' AND alici='MUTAFLAR';
  IF m <> 17570 THEN RAISE EXCEPTION 'RED: MUTAFLAR = % (17.570 bekleniyordu)', m; END IF;

  SELECT COALESCE(sum(adet),0) INTO y FROM bi_on_siparis
   WHERE tenant_id='$TEN' AND sezon_yili='$SEZON' AND tedarikci='BRISA'
     AND sezon='KIS' AND alici='YEDI_OTO';
  IF y <> 7272 THEN RAISE EXCEPTION 'RED: YEDI OTO = % (7.272 bekleniyordu)', y; END IF;

  RAISE NOTICE '✅ % satir · mutabakat 4/4 TUTTU', n;
END \$\$;
COMMIT;
SQL
docker exec krb-assessment-postgres rm -f /tmp/_os.csv 2>/dev/null

echo
echo "############ 3) ⚠ KIM NE ALDI — stok riski vs kredi riski ############"
$PSQL -c "
SELECT CASE WHEN alici='KRB' THEN '🏭 KRB (KENDI STOGU — stok riski)'
            ELSE '🤝 MUSTERI ON SATISI (kredi riski)' END AS tur,
       alici, sum(adet) AS adet,
       round(100.0*sum(adet)/SUM(sum(adet)) OVER (),1) AS pct
  FROM bi_on_siparis WHERE tenant_id='$TEN' AND sezon_yili='$SEZON'
 GROUP BY 1,2 ORDER BY 3 DESC;"
echo "  ⚠ Ikisini karistirmak = 72.170'i 'KRB fazla stok bagladi' diye okumak. YANLIS."

echo
echo "############ 4) ⚠⚠ NAKIT TAKVIMI — hangi tarihte ne kadar odeme? ############"
$PSQL -c "
WITH son AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, birim_fiyat_kdv_haric AS m
    FROM bi_tedarikci_faturalari
   WHERE tenant_id='$TEN'::uuid AND birim_fiyat_kdv_haric>0 AND miktar>0
   ORDER BY kalem_kodu, fatura_tarihi DESC),
eb_mal AS (   -- ebat basina ort. alis maliyeti
  SELECT regexp_replace(upper(f.ebat),'\s+','','g') AS ebat, AVG(son.m) AS maliyet
    FROM bi_satis_faturalari f JOIN son ON son.kalem_kodu=f.kalem_kodu
   WHERE f.tenant_id='$TEN' AND f.grup_adi LIKE 'LASTIK%' AND f.ebat<>''
   GROUP BY 1)
SELECT o.tedarikci, o.donem,
       CASE WHEN o.tedarikci='BRISA' AND o.donem='1' THEN '18 Kas + 16 Ara 2026'
            WHEN o.tedarikci='BRISA' AND o.donem='2' THEN '22 Oca + 22 Sub 2027'
            WHEN o.donem IN ('EKIM','KASIM','CEVA') THEN 'Conti ek sevk'
            ELSE '?' END AS odeme_takvimi,
       sum(o.adet) AS adet,
       round(sum(o.adet * COALESCE(m.maliyet,0))/1e6,1) AS TAHMINI_ODEME_MTL
  FROM bi_on_siparis o
  LEFT JOIN eb_mal m ON m.ebat = regexp_replace(upper(o.ebat),'\s+','','g')
 WHERE o.tenant_id='$TEN' AND o.sezon_yili='$SEZON'
 GROUP BY 1,2,3 ORDER BY 1,2;"
echo "  ⚠ Maliyet = ayni ebatin ORTALAMA alis fiyati (tahmin). Gercek fatura gelince guncellenir."
echo "     Bu, KRB'nin Kasim-Aralik'ta ne kadar nakit cikaracaginin ILK tahmini."

echo
echo "############ 5) ⚠ MODEL KARNESI — model ne dedi, KRB ne aldi? ############"
$PSQL -c "
SELECT 'Model onerisi (baz 32.000 - mevcut 4.329)' AS kaynak, 27671 AS adet
UNION ALL
SELECT 'KRB kendi kis siparisi (gercek)',
       (SELECT sum(adet) FROM bi_on_siparis
         WHERE tenant_id='$TEN' AND sezon_yili='$SEZON' AND alici='KRB' AND sezon='KIS')
UNION ALL
SELECT 'Model iyimser (40.000 - 4.329)', 35671;"
echo "  ^ Sezon sonunda GERCEK SATISLA kiyaslanacak. Model kendi hatasindan ogrenecek."

git add -A && git commit -q -m "feat(sezon): ONSIPARIS_TABLO_V1 — bi_on_siparis kuruldu. 1.786 satir, 72.170 adet. Alici ayrimi KRITIK: KRB 38.088 (kendi stogu, STOK riski) vs Mutaflar 23.362 + Yedi Oto 7.272 + Bar Oto 3.448 (musteri on satisi, KREDI riski). Mutabakat Ozet Tablo ile 4/4 birebir. Donem -> Brisa taksit takvimi (1.donem 18 Kas + 16 Ara, 2.donem 22 Oca + 22 Sub) -> nakit takvimi hesaplanabilir." && echo "  COMMITTED"
