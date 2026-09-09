#!/usr/bin/env bash
# _sonAlisFiyati HATA teshisi. Hipotez: sorgu 'tedarikci_adi' seciyor ama kolon yok ->
#   throw -> BAYILIK_V2 catch yutuyor -> "maliyet bilinmiyor" (oysa alis VAR).
# KULLANIM: ssh -i $KEY $H 'cd /opt/krb-assessment && bash diag_sonalis.sh'
PSQL='docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform'
echo "=== (1) bi_tedarikci_faturalari KOLONLARI ==="
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_tedarikci_faturalari' ORDER BY ordinal_position"
echo ""
echo "=== (2) _sonAlisFiyati sorgusu AYNEN (kalem 656740) — HATA verirse hipotez dogru ==="
$PSQL -c "SELECT birim_fiyat_kdv_haric AS f, fatura_tarihi AS t, tedarikci_adi AS td, vade_gun AS vg, (CURRENT_DATE - fatura_tarihi)::int AS gun FROM bi_tedarikci_faturalari WHERE tenant_id=(SELECT id FROM platform_tenants WHERE status='active' ORDER BY created_at LIMIT 1) AND kalem_kodu='656740' AND birim_fiyat_kdv_haric>0 AND miktar>0 ORDER BY fatura_tarihi DESC LIMIT 1"
