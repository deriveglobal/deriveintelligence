#!/usr/bin/env bash
# finance2026 dosyasını BUL + ne içerdiğine bak + DB'ye girmiş mi. SADECE OKUR.
set -uo pipefail
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. DOSYAYI BUL — diskte finance2026 (her uzantı)"
find /opt /root /tmp /home /var/lib -iname '*finance2026*' 2>/dev/null | head -20

hr "2. DOSYA TÜRÜ + BOYUT (bulunanlar)"
for f in $(find /opt /root /tmp /home /var/lib -iname '*finance2026*' 2>/dev/null | head -5); do
  echo "  --- $f ---"; file "$f" 2>/dev/null | sed 's/^/    /'; ls -lh "$f" 2>/dev/null | awk '{print "    boyut:",$5}'
done

hr "3. İÇERİK PEEK — CSV ise başlık+ilk satır; XLSX ise sheet/başlık (python)"
F=$(find /opt /root /tmp /home /var/lib -iname '*finance2026*' 2>/dev/null | head -1)
if [ -n "$F" ]; then
  case "$F" in
    *.csv|*.txt) echo "  [CSV başlık + 2 satır]"; head -3 "$F" | sed 's/^/    /' ;;
    *.xlsx|*.xls) python3 - "$F" <<'PY' 2>&1 | sed 's/^/    /'
import sys
try:
    import openpyxl
    wb=openpyxl.load_workbook(sys.argv[1], read_only=True)
    for ws in wb.worksheets:
        print("SHEET:", ws.title, "boyut:", ws.max_row, "x", ws.max_column)
        rows=list(ws.iter_rows(min_row=1, max_row=2, values_only=True))
        for r in rows: print("  ", r)
except Exception as e:
    print("openpyxl yok/okunamadı:", e)
PY
    ;;
    *) echo "  (tanınmayan uzantı — elle bak)" ;;
  esac
else
  echo "  ⚠ Diskte bulunamadı — belki ERP inbox'ta ya da başka yolda. §5 DB'ye bakalım."
fi

hr "4. ERP INGEST INBOX / LOG — finance2026 işlendi mi"
ls -lt /opt/price_monitor/*.py /opt/krb-assessment/erp_ingest.py 2>/dev/null | head -3 | sed 's/^/  /'
find /opt -iname '*.csv' -o -iname '*.xlsx' 2>/dev/null | grep -iE 'finance|alacak|receiv|acik|aging|vade' | head -10 | sed 's/^/  /'

hr "5. DB — bugün ingested olan alacak-ilişkili tablolar (yeni veri girmiş mi)"
for TBL in bi_musteri_risk bi_fatura_tahsilat bi_odeme_gecmisi; do
  echo "  --- $TBL ---"
  $PSQL -tAc "SELECT '   satir='||count(*)||' max_ingest='||max(ingested_at)::text||' export='||max(export_date)::text FROM $TBL WHERE tenant_id='$T'::uuid;" 2>&1 | sed 's/^/  /'
done

hr "6. YENİ TABLO VAR MI — alacak/finans/açık-kalem benzeri"
$PSQL -c "SELECT table_name FROM information_schema.tables WHERE table_schema='public' AND table_name ~* 'alacak|acik|aging|vade|finance|finans|acikkalem|open' ORDER BY 1;"

hr "BITTI — finance2026 ne, nerede, DB'ye girdi mi görülecek. Sonra DSO'yu kesinleştirir mi bakarız."
