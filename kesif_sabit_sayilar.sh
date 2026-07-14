#!/usr/bin/env bash
set -uo pipefail

PG="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
SRC="server_container.mjs"

hr(){ printf '\n=== %s ===\n' "$1"; }

hr "0. CAPA: dosya burada mi"
ls -la "$SRC" || { echo "!! $SRC yok"; pwd; ls; exit 1; }
wc -l "$SRC"

hr "1. SABIT RAKAMLAR (kod)"
grep -nE '[0-9]+[.,][0-9]+ ?(M|milyon|milyar)|[0-9]{2,3}[.,][0-9]+M|ciro|brüt marj|DSO|net sermaye' "$SRC" | head -80

hr "1b. Haziran/SAP/121 gecen her satir"
grep -niE 'haziran|SAP|121[.,]7|121760|ciro *= *[0-9]' "$SRC" | head -40

hr "2. KOKEN METINLERI KODDA MI"
grep -ncE 'tedarikci_borcu|musteri_risk|dso_gun' "$SRC"
grep -nE 'tedarikci_borcu|musteri_risk|dso_gun' "$SRC" | head -40

hr "3. KOKEN METINLERI DB'DE MI"
$PG -c "\dt" 2>/dev/null | grep -iE 'koken|kaynak|sinir|ayar|metin' || echo "(eslesme yok)"
$PG -c "\d bi_ayar" 2>/dev/null || echo "(bi_ayar yok)"

hr "4. tenant_id TIP HARITASI"
$PG -c "SELECT data_type, count(*), string_agg(table_name,', ' ORDER BY table_name) FROM information_schema.columns WHERE column_name='tenant_id' GROUP BY data_type;"

hr "5. RAKAM ICEREBILECEK METIN KOLONLARI"
$PG -c "SELECT table_name, column_name FROM information_schema.columns WHERE data_type IN ('text','character varying') AND (column_name ILIKE '%koken%' OR column_name ILIKE '%kaynak%' OR column_name ILIKE '%sinir%' OR column_name ILIKE '%formul%' OR column_name ILIKE '%varsayim%' OR column_name ILIKE '%aciklama%') ORDER BY table_name;"

hr "6. KUP TABLOLARI"
$PG -c "SELECT table_name FROM information_schema.tables WHERE table_name ILIKE '%kup%' OR table_name ILIKE '%marj_fact%' ORDER BY 1;"

hr "BITTI"
