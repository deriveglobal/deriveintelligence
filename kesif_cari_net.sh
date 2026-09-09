#!/usr/bin/env bash
# NET POZİSYON keşfi — Mutaflar'a borcumuz var mı, hangi anahtarla müşteri-risk'e bağlanır. OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_cari_bakiye — kolonlar"
$PSQL -c "SELECT string_agg(column_name,', ') FROM information_schema.columns WHERE table_name='bi_cari_bakiye';" 2>&1 | sed 's/^/  /'

hr "2. MUTAFLAR bi_cari_bakiye'de (borç/alacak) — isimle"
$PSQL -x -c "SELECT * FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND (tedarikci_adi ILIKE '%MUTAFLAR%' OR muhatap_adi ILIKE '%MUTAFLAR%');" 2>&1 | head -30 | sed 's/^/  /'

hr "3. MUTAFLAR bi_musteri_risk'te — kod + vergi_no + bakiye"
$PSQL -c "SELECT muhatap_kodu, vergi_no, round(hesap_bakiyesi/1e6,1) hesap_M, round(vadesi_gecmis/1e6,1) vgecmis_M FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND muhatap_adi ILIKE '%MUTAFLAR%';" 2>&1 | sed 's/^/  /'

hr "4. JOIN anahtarı — cari_bakiye'de kod/vergi_no var mı (risk'e bağlamak için)"
$PSQL -c "SELECT column_name FROM information_schema.columns WHERE table_name='bi_cari_bakiye' AND (column_name ~* 'kod|vergi|muhatap|cari');" 2>&1 | sed 's/^/  /'

hr "5. Kaç karşı taraf HEM müşteri HEM borçlu olduğumuz (karşılıklı) — kabaca isimle"
$PSQL -c "
SELECT count(*) FROM (
  SELECT DISTINCT upper(muhatap_adi) ad FROM bi_musteri_risk WHERE tenant_id='$T'::uuid AND COALESCE(musteri_mi,true) AND vadesi_gecmis>1000000
) m JOIN (
  SELECT DISTINCT upper(tedarikci_adi) ad FROM bi_cari_bakiye WHERE tenant_id='$T'::uuid AND tedarikci_bakiye<0
) t ON m.ad=t.ad;" 2>&1 | sed 's/^/  /'

hr "BITTI — net pozisyon nasıl kurulur netleşince facts üreticisini düzeltirim."
