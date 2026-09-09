#!/usr/bin/env bash
# DEPLOY omurga_68 — zararina_hacim yasası aday→taslak (Fatih onayı, 2026-07-16). DB-ONLY, container rebuild YOK.
# Yol: bekleyen aday-yasa sorusunu 'Evet' cevapla → trg_aday_yasa aday→taslak (blessed, endpoint ile birebir).
# GUARD: yasa_zararina_hacim fonksiyonu yoksa TEK İŞLEMDE promote İPTAL (firing fonksiyonsuz canlı yasa = gürültü).
set -uo pipefail
PSQL="docker exec krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
QID='977fa6c5-7921-4a34-8c47-789c90474362'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. BAZ (deploy ÖNCESİ) + firing fonksiyonu mevcut mu"
$PSQL -c "SELECT kod,durum,kaynak FROM bi_yasa WHERE kod='zararina_hacim';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT id,durum,cevap FROM bi_sistem_sorusu WHERE id='$QID';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT proname, pg_get_function_arguments(oid) args FROM pg_proc WHERE proname='yasa_zararina_hacim';" 2>&1 | sed 's/^/  /'

hr "1. DEPLOY — tek işlem (guard + cevap). Guard raise ederse UPDATE uygulanmaz (atomik)."
$PSQL -c "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_proc WHERE proname='yasa_zararina_hacim') THEN RAISE EXCEPTION 'yasa_zararina_hacim fonksiyonu YOK -> promote iptal (once fonksiyon kur)'; END IF; END \$\$; UPDATE bi_sistem_sorusu SET cevap='Evet', cevap_zamani=now(), durum='cevaplandi' WHERE id='$QID' AND anahtar='aday-yasa:zararina_hacim' AND durum='acik';" 2>&1 | sed 's/^/  /'

hr "2. DOĞRULAMA — yasa taslak oldu mu, soru cevaplandı mı"
$PSQL -c "SELECT kod,durum,kaynak FROM bi_yasa WHERE kod='zararina_hacim';" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT id,durum,cevap FROM bi_sistem_sorusu WHERE id='$QID';" 2>&1 | sed 's/^/  /'

hr "3. UÇTAN-UCA — yasa fiilen ateşliyor mu (SAILUN'da): doğrudan çağrı + runner"
$PSQL -c "SELECT jsonb_pretty(yasa_zararina_hacim('$T'::uuid,'marka','SAILUN'));" 2>&1 | sed 's/^/  /'
$PSQL -c "SELECT jsonb_pretty(capraz_kontrol('$T'::uuid,'marka','SAILUN'));" 2>&1 | sed 's/^/  /'

hr "BITTI — BEKLE: (2) durum='taslak' & kaynak='hunter+kullanici' + soru 'cevaplandi'/'Evet'. (3) fired=true + bulgu. Hepsi tamam ise footprint (DEVIR+INSA+bi_insa_gunlugu) yazılacak."
