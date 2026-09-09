#!/usr/bin/env bash
# MUSTERIMI_GRUP_V1 — musteri_mi TEDARİKÇİ grubunu hariç tutar. erp_ingest fix + migration + rebuild.
# Migration bi_musteri_risk'i anında düzeltir; restart master_musteri'yi tazeler. Idempotent.
set -e
cd /opt/krb-assessment
set -a; [ -f .env ] && . ./.env; set +a
PW="${POSTGRES_PASSWORD:-}"
cp erp_ingest.py erp_ingest.py.bak.$(date +%s)

echo "== 1) erp_ingest musteri_mi fix =="
printf '%s' 'IyEvdXNyL2Jpbi9lbnYgcHl0aG9uMwojIE1VU1RFUklNSV9HUlVQX1YxIOKAlCBtdXN0ZXJpX21pIGFydMSxayB5YWxuxLF6IGtvZCDDtm5la2kgJ00nIERFxJ7EsEw7IGdydXAgJ1RFREFSxLBLw4fEsCcgaXNlIE3DnMWeVEVSxLAgU0FZSUxNQVouCiMgU2ViZXA6IE9UT01PVMSwViBMQVNUxLBLTEVSxLAgVEVWWsSwIChDb250aW5lbnRhbCkga29kIE0gYW1hIGdydXAgVEVEQVLEsEvDh8SwIOKGkiBwaGFudG9tIDM1TSBnZWNpa21pxZ8uCiMgQnUgdGVrIGRlxJ9pxZ9pa2xpayB0w7xtIGRvd25zdHJlYW0naSBkw7x6ZWx0aXIgKG11c3RlcmlfbWkgaWxlIGZpbHRyZWxleWVuIHTDvG0gcmlzay9EU08vbWFzdGVyIHNvcmd1bGFyxLEpLgojIGdydXAgc2F0xLFyZGEgbWV2Y3V0IChLQVlJVCBtYXAsICJHcnVwIikuIElkZW1wb3RlbnQuIC9vcHQva3JiLWFzc2Vzc21lbnQuIFJFQlVJTEQgZ2VyZWtpci4KZGVmIHJlYWQocCk6IHJldHVybiBvcGVuKHAsIGVuY29kaW5nPSJ1dGYtOCIpLnJlYWQoKQpkZWYgd3JpdGUocCwgcyk6IG9wZW4ocCwgInciLCBlbmNvZGluZz0idXRmLTgiKS53cml0ZShzKQoKRlAgPSAiZXJwX2luZ2VzdC5weSIKcyA9IHJlYWQoRlApCmlmICJNVVNURVJJTUlfR1JVUF9WMSIgaW4gczoKICAgIHByaW50KCJtdXN0ZXJpbWk6IGFscmVhZHkgcHJlc2VudCwgc2tpcCIpOyBwcmludCgiRE9ORS4iKTsgcmFpc2UgU3lzdGVtRXhpdAoKYSA9ICcgICAgICAibXVzdGVyaV9taSIgOiBsYW1iZGEgcjogclsibXVoYXRhcF9rb2R1Il0udXBwZXIoKS5zdGFydHN3aXRoKCJNIiksJwpuID0gKCcgICAgICAjIE1VU1RFUklNSV9HUlVQX1YxIOKAlCBrb2Qgw7ZuZWtpIE0gKyBncnVwIFRFREFSxLBLw4fEsCBkZcSfaWwgKHRlZGFyaWvDp2kgbcO8xZ90ZXJpIHNhecSxbG1heikuXG4nCiAgICAgJyAgICAgICJtdXN0ZXJpX21pIiA6IGxhbWJkYSByOiByWyJtdWhhdGFwX2tvZHUiXS51cHBlcigpLnN0YXJ0c3dpdGgoIk0iKSBhbmQgIlRFREFSIiBub3QgaW4gKHIuZ2V0KCJncnVwIikgb3IgIiIpLnVwcGVyKCksJykKYXNzZXJ0IHMuY291bnQoYSkgPT0gMSwgIm11c3RlcmlfbWkgYW5jaG9yIgpzID0gcy5yZXBsYWNlKGEsIG4sIDEpCgp3cml0ZShGUCwgcykKcHJpbnQoIm11c3RlcmltaTogbXVzdGVyaV9taSBhcnTEsWsgVEVEQVLEsEvDh8SwIGdydWJ1bnUgaGFyacOnIHR1dHV5b3IiKQpwcmludCgiRE9ORS4iKQo=' | base64 -d > musterimi_fix.py
python3 musterimi_fix.py
python3 -c "import ast; ast.parse(open('erp_ingest.py').read()); print('PY_OK')"

echo "== 2) migration: mevcut TEDARİKÇİ satırlarını müşteri OLMAKTAN çıkar =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off <<'SQL'
WITH upd AS (
  UPDATE bi_musteri_risk SET musteri_mi=false
  WHERE musteri_mi=true AND grup ILIKE '%TEDAR%'
  RETURNING 1)
SELECT count(*) AS musteriden_cikarilan FROM upd;
SQL

echo "== 3) durum yeniden hesapla (opsiyonel, hata olsa da devam) =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "SELECT saha_musteri_durum_yenile();" || echo "(durum yenile atlandı)"

echo "== 4) build + up (restart → master_musteri tazelenir) =="
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 6

echo "== verify: erp marker + en büyük gecikmiş MÜŞTERİLER (TEVZİ olMAMALI) =="
docker exec krb-assessment sh -c "grep -c MUSTERIMI_GRUP_V1 /app/erp_ingest.py" || true
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -F $'\t' -A <<'SQL'
WITH tn AS (SELECT tenant_id::text t FROM bi_satis_faturalari GROUP BY 1 ORDER BY count(*) DESC LIMIT 1)
SELECT left(muhatap_adi,30) musteri, round(vadesi_gecmis/1e6,1) gecikmis_M, left(COALESCE(grup,'—'),14) grup
FROM (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, muhatap_adi, vadesi_gecmis, grup, musteri_mi
      FROM bi_musteri_risk m JOIN tn ON m.tenant_id::text=tn.t ORDER BY muhatap_kodu, export_date DESC) r
WHERE musteri_mi AND vadesi_gecmis>0 ORDER BY vadesi_gecmis DESC LIMIT 6;
SQL
echo "== kalan TEDARİKÇİ-müşteri (beklenen 0) =="
docker exec -i -e PGPASSWORD="$PW" krb-assessment-postgres psql -U assessment_app -d assessment_platform -P pager=off -c "SELECT count(*) tedarikci_hala_musteri FROM bi_musteri_risk WHERE musteri_mi=true AND grup ILIKE '%TEDAR%';"
echo "== DONE =="
