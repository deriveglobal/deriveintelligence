#!/usr/bin/env bash
# HAREKET_V1 — bi_stok_hareket. Sevk takibi baslasin.
#   ./deploy_hareket.sh --yaz
#
# ⚠ ESKI bi_stok_hareketleri (358.028 satir) 12 HAZIRAN'DA DONMUS ve 8 uc onu
#   okuyor. Onu SILMIYORUZ (o uclar yeniden yazilirken emekli edilecek).
#   Yeni tablo TEMIZ: tarih onarilmis, transfer ayrilmis, hammadde etiketli.
#
# ⚠ KAPSAM: bu tablo TALEP hesabina GIRMEZ. Satis icin tek kaynak
#   bi_satis_faturalari. Bu tablo IKI IS yapar:
#     1) MAL_GIRISI  -> sevk takibi (siparisin ne kadari geldi)
#     2) TRANSFER    -> depo hareketi (talep DEGIL)
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

[ -f hareket_TEMIZ.csv ] || { echo "❌ hareket_TEMIZ.csv YOK"; exit 1; }
N=$(($(wc -l < hareket_TEMIZ.csv)-1)); echo "✅ CSV: $N satir"
[ "${1:-}" = "--yaz" ] || { echo "  KURU. Yaz: ./deploy_hareket.sh --yaz"; exit 0; }

echo
echo "############ 1) SEMA ############"
$PSQL -v ON_ERROR_STOP=1 <<'SQL'
CREATE TABLE IF NOT EXISTS bi_stok_hareket (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     uuid NOT NULL REFERENCES platform_tenants(id) ON DELETE CASCADE,
  ingested_at   timestamptz NOT NULL DEFAULT now(),
  belge_tarihi  date,
  belge_turu    text,
  -- ⚠ MAL_GIRISI = sevk takibi · TRANSFER = TALEP DEGIL (depolar arasi)
  hareket_sinifi text NOT NULL,
  belge_no      text,
  muhatap_kodu  text, muhatap_adi text, satis_calisani text,
  depo          text,
  kalem_kodu    text NOT NULL,
  grup_adi      text, kategori text, marka text, kalem_tanimi text,
  giris         numeric(14,2), cikis numeric(14,2),
  -- ⚠ lastik_mi=false -> HAMMADDE, birim KG olabilir. Adet varsayma.
  lastik_mi     boolean NOT NULL DEFAULT true,
  sevk_girisi_mi boolean NOT NULL DEFAULT false,
  notlar        text
);
CREATE INDEX IF NOT EXISTS idx_bsh_tenant ON bi_stok_hareket (tenant_id, belge_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_bsh_kalem  ON bi_stok_hareket (tenant_id, kalem_kodu, belge_tarihi DESC);
CREATE INDEX IF NOT EXISTS idx_bsh_sevk   ON bi_stok_hareket (tenant_id, belge_tarihi DESC) WHERE sevk_girisi_mi;
CREATE INDEX IF NOT EXISTS idx_bsh_sinif  ON bi_stok_hareket (tenant_id, hareket_sinifi);
SQL
echo "  ✅ tablo hazir"

echo
echo "############ 2) YUKLE ############"
tr -d '\r' < hareket_TEMIZ.csv > /tmp/_h.csv
KOL=$(head -1 /tmp/_h.csv)
docker cp /tmp/_h.csv krb-assessment-postgres:/tmp/_h.csv >/dev/null
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
CREATE TEMP TABLE _h (LIKE bi_stok_hareket INCLUDING DEFAULTS) ON COMMIT DROP;
ALTER TABLE _h DROP COLUMN id, DROP COLUMN tenant_id, DROP COLUMN ingested_at;
\copy _h ($KOL) FROM '/tmp/_h.csv' WITH (FORMAT csv, HEADER true)

DELETE FROM bi_stok_hareket
 WHERE tenant_id='$TEN'
   AND belge_tarihi >= (SELECT min(belge_tarihi) FROM _h)
   AND belge_tarihi <= (SELECT max(belge_tarihi) FROM _h);

INSERT INTO bi_stok_hareket (tenant_id, $KOL) SELECT '$TEN', $KOL FROM _h;

DO \$\$
DECLARE n int; tg numeric; tc numeric; mg numeric; gel int;
BEGIN
  SELECT count(*) INTO n FROM bi_stok_hareket WHERE tenant_id='$TEN';
  IF n <> $N THEN RAISE EXCEPTION 'RED: % yazildi, % bekleniyordu', n, $N; END IF;

  -- ⚠ TRANSFER KAPISI: kendi icinde kapanmali
  SELECT COALESCE(sum(giris),0), COALESCE(sum(cikis),0) INTO tg, tc
    FROM bi_stok_hareket WHERE tenant_id='$TEN' AND hareket_sinifi='TRANSFER';
  IF abs(tg - tc) > greatest(1, tg*0.01) THEN
    RAISE EXCEPTION 'RED: TRANSFER kapanmiyor — giris % cikis %', tg, tc;
  END IF;

  SELECT COALESCE(sum(giris),0) INTO mg FROM bi_stok_hareket
   WHERE tenant_id='$TEN' AND sevk_girisi_mi AND lastik_mi;
  IF mg < 1000 THEN RAISE EXCEPTION 'RED: mal girisi % — sevk takibi calismaz', mg; END IF;

  SELECT count(*) INTO gel FROM bi_stok_hareket
   WHERE tenant_id='$TEN' AND belge_tarihi > CURRENT_DATE;
  IF gel > 0 THEN RAISE EXCEPTION 'RED: % satir GELECEK tarihli', gel; END IF;

  RAISE NOTICE '✅ % satir · transfer kapaniyor (%=%) · mal girisi % adet', n, tg, tc, mg;
END \$\$;
COMMIT;
SQL
docker exec krb-assessment-postgres rm -f /tmp/_h.csv 2>/dev/null

echo
echo "############ 3) ⚠ AKIS CANLI MI? — eski tablo 12 Haziran'da donmustu ############"
$PSQL -c "
SELECT 'bi_stok_hareketleri (ESKI)' AS tablo,
       count(*) AS satir, max(belge_tarihi)::text AS son_hareket,
       (CURRENT_DATE - max(belge_tarihi))::text || ' gun once' AS bayatlik
  FROM bi_stok_hareketleri WHERE tenant_id='$TEN'
UNION ALL
SELECT 'bi_stok_hareket (YENI)', count(*), max(belge_tarihi)::text,
       (CURRENT_DATE - max(belge_tarihi))::text || ' gun once'
  FROM bi_stok_hareket WHERE tenant_id='$TEN';"

echo
echo "############ 4) ⚠⚠ SEVK TAKIBI — siparisin ne kadari geldi? ############"
$PSQL -c "
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, ebat, marka
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
gelen AS (
  SELECT ke.marka, regexp_replace(upper(ke.ebat),'\s+','','g') AS ebat,
         SUM(h.giris) AS gelen_adet, max(h.belge_tarihi) AS son_giris
    FROM bi_stok_hareket h JOIN kod_ebat ke ON ke.kalem_kodu = h.kalem_kodu
   WHERE h.tenant_id='$TEN' AND h.sevk_girisi_mi AND h.lastik_mi
     AND h.belge_tarihi >= DATE '2026-06-01'
   GROUP BY 1,2),
siparis AS (
  SELECT marka, regexp_replace(upper(ebat),'\s+','','g') AS ebat,
         SUM(adet) FILTER (WHERE alici='KRB') AS krb_siparis,
         SUM(adet) AS toplam_siparis
    FROM bi_on_siparis
   WHERE tenant_id='$TEN' AND sezon_yili='2026-27' AND sezon='KIS'
   GROUP BY 1,2)
SELECT s.marka, s.ebat,
       s.krb_siparis, s.toplam_siparis,
       COALESCE(round(g.gelen_adet),0) AS GELEN,
       s.toplam_siparis - COALESCE(round(g.gelen_adet),0) AS BEKLEYEN,
       round(100.0*COALESCE(g.gelen_adet,0)/NULLIF(s.toplam_siparis,0)) AS gerceklesme_pct,
       g.son_giris
  FROM siparis s LEFT JOIN gelen g ON g.marka=s.marka AND g.ebat=s.ebat
 WHERE s.toplam_siparis > 200
 ORDER BY s.toplam_siparis DESC LIMIT 15;"
echo
echo "  ⚠ TEMMUZ'dayiz. Kis on siparisinin sevki AGUSTOS-EYLUL'de basliyor."
echo "     Bu yuzden 'GELEN' su an SIFIRA YAKIN olmali — NORMAL."
echo "     Bu tablo ASIL Agustos'tan itibaren anlam kazanacak."
echo "     Simdi kurulmasinin sebebi: sevk basladiginda HAZIR olmasi."

echo
echo "############ 5) DEPOLAR ARASI TRANSFER — hangi depo besliyor? ############"
$PSQL -c "
SELECT depo,
       round(sum(giris)) AS transfer_giris,
       round(sum(cikis)) AS transfer_cikis,
       round(sum(giris) - sum(cikis)) AS net
  FROM bi_stok_hareket
 WHERE tenant_id='$TEN' AND hareket_sinifi='TRANSFER' AND lastik_mi
 GROUP BY 1 ORDER BY abs(sum(giris)-sum(cikis)) DESC LIMIT 8;"
echo "  ^ net NEGATIF = o depo besliyor. POZITIF = besleniyor."

git add -A && git commit -q -m "feat(stok): HAREKET_V1 — bi_stok_hareket kuruldu (37.044 satir, 2026). Tarih onarildi (15.873 datetime satirinin HEPSINDE gun<=12 -> Excel takasi kesin). TRANSFER (43.469 giris = 43.469 cikis, fark 0) TALEP DEGIL diye ayrildi. HAMMADDE (birim KG, 'BDM1 250' = 1.044,53 kg) lastik_mi=false ile etiketlendi. MAL_GIRISI (90.193 adet) sevk takibinin kaynagi. ⚠ Bu tablo TALEP hesabina GIRMEZ — satis icin tek kaynak bi_satis_faturalari." && echo "  COMMITTED"
