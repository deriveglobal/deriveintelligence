#!/usr/bin/env bash
# READ-ONLY — NET içgörü doğrulama: köprü (brüt/net/mahsup/finansman), en büyük net hesaplar, başlıklar.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
echo "=== NET KÖPRÜ (baglam.etki) ==="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -c \
  "SELECT baglam->'etki'->>'overdue_brut' brut_M_raw, baglam->'etki'->>'overdue' net_raw, baglam->'etki'->>'mahsup' mahsup_raw, baglam->'etki'->>'finans_maliyeti_yil' finans_yil, baglam->'etki'->>'finans_pct_brutkar' pct_brutkar, baglam->'etki'->>'yillik_maliyet_oran' oran FROM bi_finansal_icgoru WHERE gun=CURRENT_DATE;"
echo ""
echo "=== EN BÜYÜK NET GECİKMİŞ HESAPLAR (kim) ==="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
SELECT left(t->>'ad',30) musteri, left(t->>'rep',14) temsilci,
  round((t->>'overdue')::numeric/1e6,1) net_M,
  round((t->>'brut')::numeric/1e6,1) brut_M,
  round((t->>'krb_borc')::numeric/1e6,1) krb_borc_M
FROM bi_finansal_icgoru, jsonb_array_elements(baglam->'koken'->'top') t
WHERE gun=CURRENT_DATE;
SQL
echo ""
echo "=== AI İÇGÖRÜ BAŞLIKLARI + ETKİ ==="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres \
  psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
SELECT (e->>'siddet') siddet, left(e->>'baslik',52) baslik, e->>'etki_tl' etki_tl
FROM bi_finansal_icgoru, jsonb_array_elements(icgoruler) e WHERE gun=CURRENT_DATE;
SQL
echo "== DONE =="
