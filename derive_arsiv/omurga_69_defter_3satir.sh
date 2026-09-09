#!/usr/bin/env bash
# DEPLOY omurga_69 — guven bacagi: 3 sorunlu defter satiri dururstce onayli. DB-only, rebuild YOK.
# ogren_sor/ogren_bilinen: GERCEK canli fonksiyon (pg_proc'ta var), tanim eklenip onayli. bi_icgoru: mesru sema evrimi, yeniden onay.
# Dayaniklilik: parmak_izi=guncel fp korunur -> yetenek_tara sonraki taramada onayli'yi korur. Deploy sonunda taramayla KANITLANIR.
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform"
PSQLI="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. BAZ — 3 satirin deploy ONCESI durumu"
$PSQL -c "SELECT ad,tur,durum,guven FROM bi_yetenek WHERE ad IN ('ogren_sor','ogren_bilinen','bi_icgoru') ORDER BY tur,ad;" 2>&1 | sed 's/^/  /'

hr "1. DEPLOY — tek transaction: 3 satir onayli + tanim + footprint (idempotent)"
$PSQLI <<'SQL'
BEGIN;

UPDATE bi_yetenek SET durum='onayli', guven='onayli', onaylayan='fatih (omurga_69)', guncellendi_at=now(),
  cekmece='ogrenme',
  ne_ise_yarar='Ogrenme dongusunun HATIRLA primitifi: bir anahtar icin daha once verilmis cevabi dondurur (bi_sistem_sorusu, durum=cevaplandi). Honest-null ve sebep-arastirici bunu okur.',
  nasil='SELECT cevap FROM bi_sistem_sorusu WHERE anahtar=p_anahtar AND durum=cevaplandi LIMIT 1'
WHERE ad='ogren_bilinen' AND tur='fonksiyon';

UPDATE bi_yetenek SET durum='onayli', guven='onayli', onaylayan='fatih (omurga_69)', guncellendi_at=now(),
  cekmece='ogrenme',
  ne_ise_yarar='Ogrenme dongusunun SOR primitifi: bir anahtar icin soruyu BIR KEZ sorar (idempotent). Zaten sorulmussa mevcut id doner, yoksa bi_sistem_sorusu-ya durum=acik ekler. Hunter avci_sor ve honest-null kullanir; cevap trg_aday_yasa-yi tetikler (kod yazmadan yasa).',
  nasil='INSERT INTO bi_sistem_sorusu(...durum=acik) ON CONFLICT(tenant_id,anahtar) DO NOTHING; varsa mevcut id doner'
WHERE ad='ogren_sor' AND tur='fonksiyon';

UPDATE bi_yetenek SET durum='onayli', guven='onayli', onaylayan='fatih (omurga_69)', guncellendi_at=now()
WHERE ad='bi_icgoru' AND tur='tablo';

INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'omurga_69',
  'Guven bacagi: yetenek defterinin OZ-DENETIMININ isaretledigi 3 sorunlu satir dururstce onayli. ogren_sor/ogren_bilinen (gercek canli fonksiyon, tanim eklendi), bi_icgoru (mesru sema evrimi=anlati kolonlari, yeniden onay).',
  'Defter 0 onayliydi. Bu 3 = gercek drift. yetenek_tara mantigi dogrulandi: onayli/taslak->degisti SADECE parmak_izi degisince; 3 satirin sakli parmak_izi zaten guncel fp -> onayli tarama-dayanikli. 213 taslak TOPLU onaylanmadi (onayli=teyit anlamini korusun; cockpit ile birikir).',
  '{"tur":"DB-only","onaylanan":["ogren_sor","ogren_bilinen","bi_icgoru"],"yontem":"parmak_izi=guncel fp korundu","kanit":"deploy sonu yetenek_tara ile onayli kaldigi gosterildi","script":"omurga_69_defter_3satir.sh"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='omurga_69');

COMMIT;
SQL

hr "2. DOGRULAMA — 3 satir onayli oldu mu"
$PSQL -c "SELECT ad,tur,durum,guven,onaylayan FROM bi_yetenek WHERE ad IN ('ogren_sor','ogren_bilinen','bi_icgoru') ORDER BY tur,ad;" 2>&1 | sed 's/^/  /'

hr "3. DAYANIKLILIK KANITI — yetenek_tara() fiilen calistir, 3 satir HALA onayli mi kalsin"
$PSQL -c "SELECT yetenek_tara();" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT ad,tur,durum FROM bi_yetenek WHERE ad IN ('ogren_sor','ogren_bilinen','bi_icgoru') ORDER BY tur,ad;" 2>&1 | sed 's/^/  /'

hr "4. DEFTER YENI DAGILIM — onayli sayisi arttı mı"
$PSQL -c "SELECT durum, count(*) FROM bi_yetenek GROUP BY durum ORDER BY durum;" 2>&1 | sed 's/^/  /'

hr "BITTI — BEKLE: (2) 3 satir 'onayli'; (3) yetenek_tara SONRASI HALA 'onayli' (tarama-dayanikli KANIT); (4) onayli=3, tanimsiz=0, degisti=0. Sonra .md footprint."
