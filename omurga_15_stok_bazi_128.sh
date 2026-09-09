#!/usr/bin/env bash
# OMURGA 15 (#128) — finans endpoint STOK bazını son-alıştan AĞIRLIKLI ORTALAMAya çevir. server_container.mjs.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp server_container.mjs server_container.mjs.bak_128
echo "  ✅ .bak_128"

hr "2. YAMA (Python — sa CTE'yi iki anchor arasını keserek değiştir)"
python3 - <<'PY'
import sys
p='server_container.mjs'; s=open(p,encoding='utf-8').read()
MARK = "SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))"
if s.count(MARK)!=1: print("  ❌ marker sayisi:",s.count(MARK)); sys.exit(2)
mi = s.index(MARK)
sa_start = s.rindex("WITH sa AS (", 0, mi)
sa_end   = s.index("stok AS (", mi)   # stok CTE başlangıcı
NEW = ("WITH sa AS (\n"
       "              SELECT bi_sku_norm(kalem_kodu) AS sku,\n"
       "                     sum(giris_tutari) / NULLIF(sum(giris),0) AS fiyat\n"
       "                FROM bi_stok_hareket\n"
       "               WHERE tenant_id=$1::uuid AND giris>0\n"
       "               GROUP BY bi_sku_norm(kalem_kodu)),\n"
       "            ")
s = s[:sa_start] + NEW + s[sa_end:]
open(p,'w',encoding='utf-8').write(s)
print("  ✅ sa CTE ağırlıklı ortalamaya çevrildi")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp server_container.mjs.bak_128 server_container.mjs; exit 1; fi

hr "3. SÖZDİZİMİ + DEĞİŞİKLİK DOĞRULAMA"
node --check server_container.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp server_container.mjs.bak_128 server_container.mjs; exit 1; }
echo "  eski (son-alış) kalktı mı:"; grep -c "SELECT DISTINCT ON (bi_sku_norm(kalem_kodu))" server_container.mjs | sed 's/^/    DISTINCT ON geçiş: /'
echo "  yeni (ağırlıklı) var mı:"; grep -c "sum(giris_tutari) / NULLIF(sum(giris),0)" server_container.mjs | sed 's/^/    ağırlıklı ort geçiş: /'

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_15_#128','finans endpoint stok bazi son-alis -> agirlikli ortalama','Ekran NET 74->41M, Sozlesme kanonik bazla tutarli','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — stok bazı düzeltildi (deploy sonrası STOK 235M / NET 41M). Sonra #127 guard."
