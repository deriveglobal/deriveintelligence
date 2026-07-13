#!/usr/bin/env bash
# SEZON_DURUM_V1 — /api/bi/sezon/durum. Zincirin tamami tek uctan.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

grep -q "ONSIPARIS_V1" server_container.mjs || { echo "❌ DUR: ONSIPARIS_V1 yok"; exit 1; }

echo "############ 1) ON KOSUL — 5 tablo da yerinde mi? ############"
for T in bi_on_siparis bi_stok_hareket bi_stok_anlik bi_musteri_risk bi_fatura_tahsilat; do
  C=$($PSQL -tA -c "SELECT count(*) FROM $T WHERE tenant_id='$TEN'::uuid;" 2>/dev/null || echo "0")
  printf "  %-22s %8s satir  %s\n" "$T" "$C" "$([ "$C" -gt 0 ] && echo '✅' || echo '❌ BOS')"
done

echo
echo "############ 2) YAMA ############"
if grep -q "SEZON_DURUM_V1" server_container.mjs; then echo "  ZATEN YAMALI"; else
  cp server_container.mjs server_container.mjs.bak_sdurum
  python3 patch_sezon_durum.py server_container.mjs || {
    echo "❌ geri alindi"; cp server_container.mjs.bak_sdurum server_container.mjs; exit 1; }
  node --check server_container.mjs || {
    echo "❌ NODE FAIL"; cp server_container.mjs.bak_sdurum server_container.mjs; exit 1; }
  echo "  NODE_OK"
fi

echo
echo "############ 3) ⚠ SQL'i POSTGRES'E DOGRULAT ############"
$PSQL -v ON_ERROR_STOP=1 -c "
EXPLAIN WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
         regexp_replace(upper(ebat),'\s+','','g') AS ebat, marka
    FROM bi_satis_faturalari WHERE tenant_id='$TEN'::text AND ebat<>''
   ORDER BY kalem_kodu, fatura_tarihi DESC),
siparis AS (
  SELECT upper(marka) marka, regexp_replace(upper(ebat),'\s+','','g') ebat,
         SUM(adet) FILTER (WHERE alici='KRB') krb,
         SUM(adet) FILTER (WHERE alici<>'KRB') musteri, SUM(adet) toplam,
         SUM(adet) FILTER (WHERE donem='1') d1, SUM(adet) FILTER (WHERE donem='2') d2
    FROM bi_on_siparis WHERE tenant_id='$TEN'::uuid AND sezon_yili='2026-27' AND sezon='KIS'
   GROUP BY 1,2),
sevk AS (
  SELECT upper(ke.marka) marka, ke.ebat, SUM(h.giris) gelen, MAX(h.belge_tarihi) son
    FROM bi_stok_hareket h JOIN kod_ebat ke ON ke.kalem_kodu=h.kalem_kodu
   WHERE h.tenant_id='$TEN'::uuid AND h.sevk_girisi_mi AND h.lastik_mi
     AND h.belge_tarihi >= DATE '2026-06-01' GROUP BY 1,2),
stok AS (
  SELECT upper(ke.marka) marka, ke.ebat, SUM(s.adet) mevcut
    FROM bi_stok_anlik s JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 GROUP BY 1,2)
SELECT sp.marka, sp.ebat, sp.krb, sp.toplam, COALESCE(sv.gelen,0), COALESCE(st.mevcut,0)
  FROM siparis sp LEFT JOIN sevk sv ON sv.marka=sp.marka AND sv.ebat=sp.ebat
  LEFT JOIN stok st ON st.marka=sp.marka AND st.ebat=sp.ebat;" >/dev/null \
 && echo "  SQL_OK: zincir" || { echo "❌ SQL FAIL"; cp server_container.mjs.bak_sdurum server_container.mjs; exit 1; }

echo
echo "############ 4) DAGIT ############"
docker cp server_container.mjs krb-assessment:/app/server.mjs
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/

echo
echo "############ 5) ⚠⚠ ZINCIR — siparis / sevk / stok / gecen sezon ############"
$PSQL -c "
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu,
         regexp_replace(upper(ebat),'\s+','','g') AS ebat, marka
    FROM bi_satis_faturalari WHERE tenant_id='$TEN' AND ebat<>''
   ORDER BY kalem_kodu, fatura_tarihi DESC),
sp AS (
  SELECT upper(marka) marka, regexp_replace(upper(ebat),'\s+','','g') ebat,
         SUM(adet) FILTER (WHERE alici='KRB') krb,
         SUM(adet) FILTER (WHERE alici<>'KRB') mus, SUM(adet) tp
    FROM bi_on_siparis WHERE tenant_id='$TEN' AND sezon_yili='2026-27' AND sezon='KIS'
   GROUP BY 1,2),
sv AS (
  SELECT upper(ke.marka) marka, ke.ebat, SUM(h.giris) gelen, MAX(h.belge_tarihi) son
    FROM bi_stok_hareket h JOIN kod_ebat ke ON ke.kalem_kodu=h.kalem_kodu
   WHERE h.tenant_id='$TEN'::uuid AND h.sevk_girisi_mi AND h.lastik_mi
     AND h.belge_tarihi >= DATE '2026-06-01' GROUP BY 1,2),
st AS (
  SELECT upper(ke.marka) marka, ke.ebat, SUM(s.adet) mevcut
    FROM bi_stok_anlik s JOIN kod_ebat ke ON ke.kalem_kodu=s.kalem_kodu
   WHERE s.tenant_id='$TEN'::uuid AND s.adet>0 GROUP BY 1,2),
gc AS (
  SELECT upper(marka) marka, regexp_replace(upper(ebat),'\s+','','g') ebat, SUM(miktar) gs
    FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND grup_adi LIKE 'LASTIK%' AND miktar>0 AND kategori ILIKE '%KIS%'
     AND fatura_tarihi >= DATE '2025-10-01' AND fatura_tarihi < DATE '2026-02-01'
   GROUP BY 1,2)
SELECT sp.marka, sp.ebat,
       sp.krb AS krb_stok, sp.mus AS musteri_onsatis, sp.tp AS toplam_siparis,
       COALESCE(round(sv.gelen),0) AS gelen,
       round(100.0*COALESCE(sv.gelen,0)/NULLIF(sp.tp,0)) AS gerc_pct,
       COALESCE(st.mevcut,0) AS mevcut_stok,
       COALESCE(gc.gs,0) AS gecen_sezon_satis,
       CASE WHEN COALESCE(sv.gelen,0) = 0 THEN '🔴 HIC GELMEDI'
            WHEN 100.0*sv.gelen/sp.tp < 25 THEN '🟠 GERIDE'
            WHEN 100.0*sv.gelen/sp.tp < 75 THEN '🟡 YOLDA'
            ELSE '🟢 GELDI' END AS durum
  FROM sp LEFT JOIN sv ON sv.marka=sp.marka AND sv.ebat=sp.ebat
          LEFT JOIN st ON st.marka=sp.marka AND st.ebat=sp.ebat
          LEFT JOIN gc ON gc.marka=sp.marka AND gc.ebat=sp.ebat
 WHERE sp.tp > 300 ORDER BY sp.tp DESC LIMIT 18;"

echo
echo "############ 6) ⚠ SEVK GERCEKLESMESI — marka bazinda ############"
$PSQL -c "
WITH kod_ebat AS (
  SELECT DISTINCT ON (kalem_kodu) kalem_kodu, marka FROM bi_satis_faturalari
   WHERE tenant_id='$TEN' AND ebat<>'' ORDER BY kalem_kodu, fatura_tarihi DESC),
sp AS (SELECT upper(marka) m, SUM(adet) tp FROM bi_on_siparis
        WHERE tenant_id='$TEN' AND sezon_yili='2026-27' AND sezon='KIS' GROUP BY 1),
sv AS (SELECT upper(ke.marka) m, SUM(h.giris) gelen
         FROM bi_stok_hareket h JOIN kod_ebat ke ON ke.kalem_kodu=h.kalem_kodu
        WHERE h.tenant_id='$TEN'::uuid AND h.sevk_girisi_mi AND h.lastik_mi
          AND h.belge_tarihi >= DATE '2026-06-01' GROUP BY 1)
SELECT sp.m AS marka, sp.tp AS siparis, COALESCE(round(sv.gelen),0) AS gelen,
       sp.tp - COALESCE(round(sv.gelen),0) AS bekleyen,
       round(100.0*COALESCE(sv.gelen,0)/NULLIF(sp.tp,0)) AS gerc_pct
  FROM sp LEFT JOIN sv ON sv.m=sp.m ORDER BY sp.tp DESC;"
echo "  ⚠ Markalar arasi fark BUYUKSE: tedarikci sevk plani sorunlu ya da"
echo "     KRB'nin siparisi tedarikcide bekliyor. Fatih Bilen'in sormasi gereken soru."

git add -A && git commit -q -m "feat(sezon): SEZON_DURUM_V1 — /api/bi/sezon/durum. Zincirin tamami tek uctan: siparis (bi_on_siparis) -> sevk (bi_stok_hareket MAL_GIRISI) -> stok (bi_stok_anlik) -> talep (bi_satis_faturalari) -> kredi (bi_musteri_risk). Musteri on satisi (34.082) KREDI riski, KRB stogu (38.088) STOK riski — ayri raporlaniyor. Odeme takvimi Brisa slaydindan." && echo "  COMMITTED"
