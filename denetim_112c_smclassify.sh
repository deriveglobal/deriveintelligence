#!/usr/bin/env bash
# DENETIM_112C — sm_classify.py / sm_normalize.py: segmenti kim yaziyor, 12 Tem'de ne bozuldu?
#   OKUR. Iki kucuk dosya + cagrilma yolu + git farki.
set -uo pipefail
D=/opt/price_monitor
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi_rakip_fiyat INSERT — segment kolonu VAR MI? (price_monitor.py 1455-1490)"
sed -n '1455,1490p' "$D/price_monitor.py" | nl -ba -v1455 | sed 's/^/  /'

hr "2. sm_classify.py — TAM ICERIK (segment siniflandirici)"
cat -n "$D/sm_classify.py" | sed 's/^/  /'

hr "3. sm_normalize.py — segment/ticari/van/kamyon KISMI"
grep -nE "segment|TICARI|KAMYON|HAFIF|VAN|BINEK|def |UPDATE|bi_rakip_fiyat|DATABASE_URL|os.environ|getenv" "$D/sm_normalize.py" | head -50 | sed 's/^/  /'

hr "4. Bu scriptler NASIL calisiyor? (.env source ediliyor mu?)"
echo "--- crontab TAM ---"
crontab -l 2>/dev/null | sed 's/^/  /'
echo "--- run scriptleri sm_ cagiriyor mu, .env source ediyor mu? ---"
grep -nE "sm_classify|sm_normalize|sm_master|DATABASE_URL|source|\.env" "$D"/run_*.sh "$D"/*.sh 2>/dev/null | sed 's/^/  /'
echo "--- price_monitor.py sm_normalize/sm_classify import/cagiriyor mu? ---"
grep -nE "sm_classify|sm_normalize|sm_master|import sm|subprocess|os.system" "$D/price_monitor.py" 2>/dev/null | sed 's/^/  /'

hr "5. sm_normalize DATABASE_URL'i NASIL aliyor? (.env'siz patlar)"
grep -nE "DATABASE_URL|os.environ|getenv|load_dotenv|dotenv|psycopg|connect" "$D/sm_normalize.py" "$D/sm_classify.py" "$D/sm_master.py" 2>/dev/null | sed 's/^/  /'

hr "6. GIT — sm_normalize.py 12 Tem'de ne degisti? (calisan -> bozuk)"
cd "$D" 2>/dev/null && {
  echo "--- sm_normalize.py son commit'ler ---"
  git log --oneline -6 -- sm_normalize.py sm_classify.py 2>/dev/null | sed 's/^/  /'
  echo "--- calisan (11 Tem) ile simdiki fark — segment satirlari ---"
  git log --oneline --since='2026-07-11' --until='2026-07-13' 2>/dev/null | sed 's/^/  /'
}

hr "7. ⚠ SON KANIT — sm_normalize.py'yi ELLE calistirinca ne oluyor? (kuru, .env ile)"
echo "  (Bu sadece TEST — Fatih calistirirsa segment adimi hata veriyor mu gorulur)"
echo "  Komut:  cd /opt/price_monitor && source .env && venv/bin/python3 sm_normalize.py 2>&1 | tail -20"
echo "  ⚠ Once OKU, calistirmadan; yukaridaki ciktilar sebebi zaten gosterebilir."

hr "BITTI"
