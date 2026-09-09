#!/usr/bin/env bash
# FOOTPRINT omurga_68 — bi_insa_gunlugu satırı (idempotent). DB-only.
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform"
PSQLI="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. INSERT — bi_insa_gunlugu omurga_68 (yoksa ekle)"
$PSQLI <<'SQL'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'omurga_68',
  'zararina_hacim yasasi aday->taslak (Fatih onayi). Bekleyen aday-yasa sorusu Evet -> trg_aday_yasa promote. Yasa artik capraz_kontrol runnerinda canli atesliyor.',
  'Hunter 19 SKU / 8.891 adet / -4,93M TL gercek zarar buldu (hepsi donem-maliyetli = guvenilir; SAILUN 6 SKU / -3,86M yogun). Yasa oto-aksiyon almaz, marka-seviyesi teshis sinyali uretir = dusuk risk. Kapali dongu ucdan uca kanitlandi.',
  '{"tur":"DB-only (rebuild yok)","yasa_kod":"zararina_hacim","yeni_durum":"taslak","kaynak":"hunter+kullanici","soru_id":"977fa6c5-7921-4a34-8c47-789c90474362","dogrulama_SAILUN":"fired=true; 175/65R14 -35,2%, 175/70R13 -48,8%, 195/65R15 -45,7%","script":"omurga_68_zararina_yasa.sh"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_68');
SQL

hr "2. DOĞRULAMA — satır eklendi mi"
$PSQL -c "SELECT adim, ts, left(ne,70) ne FROM bi_insa_gunlugu WHERE adim='omurga_68';" 2>&1 | sed 's/^/  /'

hr "BITTI — omurga_68 DB günlüğü yazıldı. .md belgeleri (DEVIR+INSA) ayrıca güncellenip derive_arsiv'e scp'lenecek."
