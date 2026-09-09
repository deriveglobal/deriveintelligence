#!/usr/bin/env bash
# ============================================================
# Derive · AGNOSTİK TAM DENETİM (SALT-OKUNUR) — TEK bir gap kalmasin.
# Canli kod (/app/server.mjs) + DB view/fonksiyon + cron (/opt) + shells.
# Her kategori: KRB-hardcode / tek-tenant / is-evreni literali -> lokasyon+sayi.
# Hicbir sey yazmaz.
# ============================================================
set -uo pipefail
KRB=f8a5d20f-ecf8-4ce2-a492-69268fbb03fa
APP=/app/server.mjs
DIR=/opt/krb-assessment
PSQL(){ docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -tAc "$1"; }
G(){ docker exec krb-assessment sh -c "$1" 2>/dev/null; }

echo "############ A. HARDCODED KRB TENANT UUID ############"
echo "--- /app/server.mjs (calisan) ---"
G "grep -n '$KRB' $APP | head -40"
echo "--- adet: ---"; G "grep -c '$KRB' $APP"
echo "--- shells/*.js|html ---"
G "grep -rn '$KRB' /app/shells 2>/dev/null | head -20"
echo "--- /opt scriptleri (.sh/.sql/.py/.mjs) ---"
grep -rn "$KRB" $DIR --include=*.sh --include=*.sql --include=*.py --include=*.mjs 2>/dev/null | grep -v -E 'provision_reps|anadolu|diag_|qa_|seed_|reload_|fingerprint|recon' | head -40

echo ""
echo "############ B. İŞ-EVRENİ HARDCODE ('LASTIK%' + kategori varsayimlari) ############"
echo "--- /app/server.mjs 'LASTIK' literali (satir) ---"
G "grep -n \"LASTIK\" $APP | head -40"
echo "--- adet: ---"; G "grep -c 'LASTIK' $APP"
echo "--- lastik/toptanci/tire kimlik ifadeleri ---"
G "grep -n -i 'lastik toptanc\|tire wholesal\|lastik dagit' $APP | head -20"
echo "--- kategori literalleri (PSR/TBR/OTR) server'da ---"
G "grep -n -E \"'(PSR|TBR|OTR)'\" $APP | head -20"
echo "--- ebat/jant regex hardcode ---"
G "grep -n -E 'R22\\.5|jant_capi|ebat_norm|/[0-9]{2,3}R[0-9]{2}/' $APP | head -15"

echo ""
echo "############ C. DB VIEW'LERİNDE İŞ-EVRENİ / TENANT HARDCODE ############"
echo "--- 'LASTIK' iceren VIEW'ler ---"
PSQL "SELECT table_name FROM information_schema.views WHERE table_schema='public' AND pg_get_viewdef(('public.'||table_name)::regclass,true) ILIKE '%LASTIK%' ORDER BY 1;"
echo "--- KRB uuid iceren VIEW'ler ---"
PSQL "SELECT table_name FROM information_schema.views WHERE table_schema='public' AND pg_get_viewdef(('public.'||table_name)::regclass,true) ILIKE '%$KRB%' ORDER BY 1;"

echo ""
echo "############ D. DB FONKSİYONLARINDA İŞ-EVRENİ / TENANT HARDCODE ############"
echo "--- 'LASTIK' iceren fonksiyonlar ---"
PSQL "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND pg_get_functiondef(p.oid) ILIKE '%LASTIK%' ORDER BY 1;"
echo "--- KRB uuid iceren fonksiyonlar ---"
PSQL "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND pg_get_functiondef(p.oid) ILIKE '%$KRB%' ORDER BY 1;"
echo "--- '\\\\set t' / hardcoded tenant iceren fonksiyon yok (kontrol) ---"
PSQL "SELECT p.proname FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='public' AND pg_get_functiondef(p.oid) ~* 'kardes|rot balans' ORDER BY 1;"

echo ""
echo "############ E. CRON SCRIPTLERİ — TEK-TENANT Mİ? ############"
echo "--- crontab ---"
crontab -l 2>/dev/null | grep -v '^#' | grep -E 'krb-assessment|\.sh|\.sql|\.mjs|\.py' | head -30
echo ""
echo "--- her cron scripti: tenant-dongusu VAR MI? (FOR..IN / DISTINCT tenant / hardcode) ---"
for f in $DIR/*.sh $DIR/*.sql $DIR/*.mjs $DIR/*.py; do
  [ -f "$f" ] || continue
  bn=$(basename "$f")
  case "$bn" in provision_reps*|*anadolu*|diag_*|qa_*|seed_*|reload_*|fingerprint*|*recon*|agnostik*) continue;; esac
  loop="yok"
  grep -qE 'FOR +r +IN|DISTINCT +tenant_id|for +t +in|tenant_id.*LOOP|platform_tenants' "$f" 2>/dev/null && loop="VAR(dongu)"
  hard="-"
  grep -q "$KRB" "$f" 2>/dev/null && hard="KRB-HARDCODE"
  setl="-"
  grep -qE "^\\\\set t |[[:space:]]-v t=" "$f" 2>/dev/null && setl="set-t"
  printf "  %-34s dongu=%-10s tenant=%-12s %s\n" "$bn" "$loop" "$hard" "$setl"
done

echo ""
echo "############ F. HARDCODED ALICI / E-POSTA / GÖNDEREN ############"
G "grep -n -E '@krb\\.com\\.tr|consult@deriveglobal|fbilen@|kayaz@' $APP | head -20"
echo "--- nabiz / mail scriptlerinde alici ---"
grep -rn -E '@krb\.com\.tr|consult@deriveglobal|MAILTO|recipient|alici' $DIR --include=*.sh --include=*.mjs 2>/dev/null | grep -iv -E 'anadolu|provision' | head -20

echo ""
echo "############ G. ŞİRKET KİMLİK LİTERALİ (KRB/Kardeş/Rot Balans) server prompt/shell ############"
G "grep -n -E 'KRB|Kardes|Kardeş|Rot Balans' $APP | grep -v -iE 'krb-assessment|//|/\\*' | head -30"
echo "--- adet (kaba): ---"; G "grep -c -E 'KRB|Kardes|Rot Balans' $APP"

echo ""
echo "############ DENETİM SONU — yukaridaki her dolu satir kapatilacak gap ############"
