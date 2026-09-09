#!/usr/bin/env bash
# _bayilikMi throw teshisi. Hipotez: bi_fiyat_iskonto.tenant_id text ama sorgu ::uuid ->
#   "operator does not exist: text = uuid" -> BAYILIK_V2 catch yutuyor -> maliyet bos.
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_bayilik.sh'
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'

echo "=== (1) bi_fiyat_iskonto kolon tipleri (tenant_id UUID mi TEXT mi?) ==="
$PSQL -c "SELECT column_name, data_type FROM information_schema.columns WHERE table_name='bi_fiyat_iskonto' AND column_name IN ('tenant_id','marka','aktif','rim','sezon','arac_tipi','iskonto_pct') ORDER BY ordinal_position"

echo ""
echo "=== (2) _bayilikMi sorgusu AYNEN (::uuid cast) — HATA verirse hipotez dogru ==="
$PSQL -c "SELECT count(*) AS bayilik_satir FROM bi_fiyat_iskonto WHERE tenant_id=(SELECT id::text FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1)::uuid AND upper(marka)=upper('BRIDGESTONE') AND aktif=true"

echo ""
echo "=== (3) SON 90 DK LOG — gercek yakalanan hata (bayilik_v2 / teklif_v2 / analiz) ==="
docker logs "$(docker compose ps -q krb-assessment)" --since 90m 2>&1 | grep -iE "bayilik_v2|teklif_v2|analiz pricelist|sonalis|uuid|does not exist" | tail -30
echo "--- (log bos ise: mobil app'te DOGAN YILDIZ teklifini bir kez daha ac, sonra tekrar calistir) ---"
