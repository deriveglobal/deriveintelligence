#!/usr/bin/env bash
# ============================================================================
# deploy_finans_tab.sh — BI masaustu (shells/bi.js) ayri "Finans" sekmesi
#   nav butonu (dept=finansodasi) + iframe odasi src=/api/bi/finans
#   Kokpit (data-dept=finans / kokpit-iki) sekmesine SIFIR dokunus. Client-only.
# SUNUCUDA: cd /opt/krb-assessment && bash deploy_finans_tab.sh
# Idempotent (marker FINANS_TAB_V1). Rollback: bi.js.bak_finanstab_<ts> (repo kokunde)
# ============================================================================
set -euo pipefail
cd /opt/krb-assessment
TS=$(date +%Y%m%d_%H%M%S)

echo "== [1] bi.js yama scriptini yaz =="
cat > /opt/krb-assessment/_bitab_patch.py <<'PY_EOF'
import sys
F="/opt/krb-assessment/shells/bi.js"
MARK="FINANS_TAB_V1"
s=open(F,encoding="utf-8").read()
if MARK in s:
    print("[bitab] ZATEN YAMALI (marker mevcut) — atlaniyor"); sys.exit(0)

# --- A) NAV BUTTON: CEO Assistant butonundan hemen sonra ---
anchorA=(
'          <button class="vmo-tab" data-dept="brain" style="--c:#e11d48">\n'
'            <span>\U0001F9E0</span> CEO Assistant\n'
'          </button>'
)
nA=s.count(anchorA)
if nA!=1:
    print("[bitab] ANCHOR-A sayisi=%d (tam 1 olmali) — DURDU, dokunulmadi"%nA); sys.exit(2)
buttonA=anchorA+'\n          <button class="vmo-tab" data-dept="finansodasi" style="--c:#059669" title="Finans Odasi" data-mark="'+MARK+'"><span>\U0001F4B0</span> Finans</button>'
s=s.replace(anchorA, buttonA, 1)

# --- B) ROOM BLOCK: `var _METRIK_TANIM = {` oncesine sibling blok ---
anchorB='  var _METRIK_TANIM = {'
nB=s.count(anchorB)
if nB!=1:
    print("[bitab] ANCHOR-B sayisi=%d (tam 1 olmali) — DURDU, dokunulmadi"%nB); sys.exit(3)
block=(
"  // "+MARK+" — ayri 'Finans Odasi' sekmesi (dept=finansodasi) -> iframe /api/bi/finans; Kokpit(kokpit-iki)'ye dokunmaz\n"
"  {\n"
"    const _o = container.querySelector('.vmo-office');\n"
"    if (_o && !document.getElementById('vmo-room-finansodasi')) {\n"
"      const _fo = document.createElement('div');\n"
"      _fo.id = 'vmo-room-finansodasi';\n"
"      _fo.dataset.dept = 'finansodasi';\n"
"      _fo.className = 'vmo-room vmo-room-hidden';\n"
"      _fo.style.cssText = 'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0';\n"
"      _fo.innerHTML = '<iframe id=\"finansodasi-frame\" src=\"/api/bi/finans\" style=\"width:100%;height:100%;min-height:82vh;border:0;display:block;background:#0a0e14\" title=\"Finans Odasi\"></iframe>';\n"
"      try { _fo.style.padding = '0'; } catch (e) {}\n"
"      _o.appendChild(_fo);\n"
"    }\n"
"  }\n\n"
)
s=s.replace(anchorB, block+anchorB, 1)
open(F,"w",encoding="utf-8").write(s)
print("[bitab] OK — nav butonu + finansodasi iframe odasi eklendi (Kokpit'e dokunulmadi)")
PY_EOF

echo "== [2] bi.js yedek (shells DISINA -> image kirlenmez) + yama =="
cp shells/bi.js "bi.js.bak_finanstab_$TS"
echo "  yedek: bi.js.bak_finanstab_$TS"
python3 /opt/krb-assessment/_bitab_patch.py

echo "== [3] node --check (.js || .mjs fallback) =="
cp shells/bi.js /tmp/bi_c.mjs
if node --check shells/bi.js 2>/dev/null; then echo "  .js syntax OK";
elif node --check /tmp/bi_c.mjs 2>/dev/null; then echo "  .mjs syntax OK";
else echo "  node --check FAIL — GERI ALINIYOR"; cp "bi.js.bak_finanstab_$TS" shells/bi.js; exit 1; fi
echo "  host marker: $(grep -c FINANS_TAB_V1 shells/bi.js)  (2 bekle)"

echo "== [4] build + deploy =="
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate krb-assessment
sleep 4

echo "== [5] KONTEYNER dogrulama =="
echo "  marker            : $(docker exec krb-assessment grep -c FINANS_TAB_V1 /app/shells/bi.js)  (2 bekle)"
echo "  finansodasi buton : $(docker exec krb-assessment grep -c 'data-dept=\"finansodasi\"' /app/shells/bi.js)  (1 bekle)"
echo "  finans iframe     : $(docker exec krb-assessment grep -c 'src=\"/api/bi/finans\"' /app/shells/bi.js)  (1 bekle)"
echo "  Kokpit DOKUNULMADI: $(docker exec krb-assessment grep -c 'src=\"/api/bi/kokpit-iki\"' /app/shells/bi.js)  (1 bekle)"
echo "  bi.js hash (stamp): $(docker exec krb-assessment sh -c 'grep -o \"bi.js?v=[a-f0-9]*\" /app/index.html | head -1' 2>/dev/null || echo n/a)"

echo "== [6] FINGERPRINT =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform <<'SQL_EOF'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'FINANS_TAB_V1','BI masaustu kabuguna (shells/bi.js) ayri Finans sekmesi: nav butonu dept=finansodasi + iframe odasi src=/api/bi/finans','Finans odasi backend canliydi ama ust menude gorunmuyordu; Kokpit(kokpit-iki) sekmesine dokunmadan CEO Assistant yanina eklendi','{"marker":"FINANS_TAB_V1","dosya":"shells/bi.js","dept":"finansodasi","iframe":"/api/bi/finans"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='FINANS_TAB_V1');

INSERT INTO bi_yetenek (ad,tur,ne_ise_yarar,nasil,cekmece,durum,guven,kanit,aktif,eklendi_at,guncellendi_at,son_gorulme)
SELECT 'finans_odasi_tab','rapor','BI masaustu (Derive Intelligence) ust menusunde Finans sekmesi; CEO Assistant yaninda (dept=finansodasi), /api/bi/finans odasini iframe ile acar. Kokpit sekmesinden (kokpit-iki) ayridir.','shells/bi.js nav butonu data-dept=finansodasi -> vmo-room-finansodasi iframe /api/bi/finans','finans','canli','taslak','{"marker":"FINANS_TAB_V1","dosya":"shells/bi.js"}'::jsonb,true,now(),now(),now()
WHERE NOT EXISTS (SELECT 1 FROM bi_yetenek WHERE ad='finans_odasi_tab');
SQL_EOF
echo "== [6b] dogrulama =="
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "SELECT adim FROM bi_insa_gunlugu WHERE adim='FINANS_TAB_V1'; SELECT ad,tur,durum FROM bi_yetenek WHERE ad='finans_odasi_tab';"
echo "== BITTI — Finans sekmesi canli. Sayfayi yenile (Cmd+Shift+R): ust menude CEO Assistant yaninda 'Finans'. =="
