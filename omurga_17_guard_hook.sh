#!/usr/bin/env bash
# OMURGA 17 (#127) — guard'ı yukle endpoint'ine bağla: ingest sonrası otomatik veri_saglik_kapisi(). server.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK"
cp server_container.mjs server_container.mjs.bak_hook
echo "  ✅ .bak_hook"

hr "2. YAMA — sendJson satırından önce guard çağrısı ekle (izole)"
python3 - <<'PY'
import sys
p='server_container.mjs'; s=open(p,encoding='utf-8').read()
OLD="        sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc, tazelenen });"
if s.count(OLD)!=1: print("  ❌ sendJson anchor:",s.count(OLD)); sys.exit(2)
NEW=(
"        // VERİ SAĞLIK KAPISI (#127) — başarılı yüklemede bilinmeyen değer/aralık denetle (sessizce geçmesin)\n"
"        let saglik = null;\n"
"        if (sonuc.ok) {\n"
"          try {\n"
"            const _g = await query(\"SELECT veri_saglik_kapisi($1::uuid) AS alarm\", [session.tenantId]);\n"
"            saglik = { alarm: Number(_g.rows[0]?.alarm ?? 0) };\n"
"            if (saglik.alarm > 0) tazelenen.push(\"⚠ VERİ SAĞLIK: \" + saglik.alarm + \" bilinmeyen değer/aralık — Veri odasında incele\");\n"
"          } catch (e) { console.error(\"[yukle] saglik kapisi:\", e && e.message); tazelenen.push(\"⚠ SAĞLIK KAPISI HATASI: \" + String(e && e.message).slice(0,120)); }\n"
"        }\n"
"        sendJson(response, sonuc.ok ? 200 : 422, { dosya: dosyaAdi, boyut, ...sonuc, tazelenen, saglik });"
)
s=s.replace(OLD,NEW,1)
open(p,'w',encoding='utf-8').write(s)
print("  ✅ guard hook eklendi")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp server_container.mjs.bak_hook server_container.mjs; exit 1; fi

hr "3. SÖZDİZİMİ + DEĞİŞİKLİK"
node --check server_container.mjs && echo "  ✅ sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp server_container.mjs.bak_hook server_container.mjs; exit 1; }
echo "  yukle'de veri_saglik_kapisi çağrısı: $(grep -c 'veri_saglik_kapisi(\$1::uuid) AS alarm' server_container.mjs)"

hr "4. AYAK İZİ + DEPLOY"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_17_#127hook','guard yukle endpointine baglandi','Her ERP yuklemesinden sonra otomatik denetim + alarm yanitta','{}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi"
echo "  ▶ DEPLOY: cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — guard artık her yüklemeye otomatik bağlı. Deploy sonrası bir dosya yükleyince test edilir."
