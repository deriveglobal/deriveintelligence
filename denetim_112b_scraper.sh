#!/usr/bin/env bash
# DENETIM_112B — GERCEK scraper: /opt/price_monitor/price_monitor.py segment mantigi. OKUR.
#   §6 kanit: ebat dolu, segment bos -> siniflandirici girdisi VAR, kendisi calismiyor.
#   Erime 12 Tem'de basladi. price_monitor.py'nin segment adimini + bagimliligini bul.
set -uo pipefail
PM="/opt/price_monitor/price_monitor.py"
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. Dosya var mi, ne zaman DEGISTI? (12-13 Tem'de mi?)"
ls -la "$PM" 2>/dev/null || { echo "  ❌ $PM yok — cron yolunu tekrar bak"; crontab -l | grep price_monitor; }
echo "  --- /opt/price_monitor icerigi ---"
ls -la /opt/price_monitor/ 2>/dev/null | sed 's/^/  /'

hr "1. segment KELIMESI price_monitor.py'de nerede?"
grep -nE "segment" "$PM" 2>/dev/null | head -40 | sed 's/^/  /'

hr "2. segment NASIL hesaplaniyor? (fonksiyon / lookup / regex)"
grep -nE "def .*segment|segment *=|KAMYON|HAFIF_TICARI|BINEK|TICARI|classify|siniflandir|arac_tipi" "$PM" 2>/dev/null | head -40 | sed 's/^/  /'

hr "3. segment bir DB SORGUSUNA / DOSYAYA mi bagli? (lookup ezilmis olabilir)"
grep -nE "SELECT|FROM |JOIN |read_csv|open\(|\.json|lookup|map|dict\(" "$PM" 2>/dev/null | grep -iE "segment|urun|master|ebat|kategori|arac" | head -20 | sed 's/^/  /'

hr "4. bi_rakip_fiyat'a INSERT — segment kolonu ne yaziliyor?"
grep -nE "INSERT INTO bi_rakip_fiyat|bi_rakip_fiyat|segment" "$PM" 2>/dev/null | grep -iE "insert|values|segment|columns" | head -20 | sed 's/^/  /'

hr "5. HATA LOG — scraper 12-13 Tem'de segment adiminda patladi mi?"
echo "  --- price_monitor log son 40 satir ---"
tail -40 /var/log/price_monitor_full.log 2>/dev/null | sed 's/^/  /' || echo "  (log yok)"
echo "  --- log'da 'segment' / 'error' / 'traceback' gecen son satirlar ---"
grep -inE "segment|error|traceback|exception|warn" /var/log/price_monitor_full.log 2>/dev/null | tail -20 | sed 's/^/  /'

hr "6. GIT / yedek — price_monitor.py 12 Tem'de degisti mi?"
if [ -d /opt/price_monitor/.git ]; then
  cd /opt/price_monitor && git log --oneline -8 -- price_monitor.py 2>/dev/null | sed 's/^/  /'
else
  echo "  (git yok) — .bak / eski kopya var mi:"
  ls -la /opt/price_monitor/*.py* /opt/price_monitor/*.bak* 2>/dev/null | sed 's/^/  /'
fi

hr "7. KIYAS — segmenti hala dolu bir kaynak var mi? (bi_rakip_fiyat_son)"
$PSQL -c "SELECT count(*) toplam, count(*) FILTER (WHERE segment IS NOT NULL AND segment<>'') dolu
          FROM bi_rakip_fiyat_son;" 2>&1 | sed 's/^/  /'

hr "BITTI"
echo "  ⚠ Segment ya price_monitor.py icinde bir regex/lookup ile hesaplaniyordu ve o degisti,"
echo "     ya da bir DB lookup'a bagliydi ve o 12 Tem'de boldu. Cikti hangisi oldugunu soyleyecek."
