#!/usr/bin/env bash
set -euo pipefail
TS=$(date +%Y%m%d_%H%M%S)
T='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'
CID=krb-assessment
PG=krb-assessment-postgres
PSQL="psql -U assessment_app -d assessment_platform"
cd /opt/krb-assessment
SRV=server_container.mjs
BIJS=shells/bi.js
TAD=shells/tenant-admin.js
rollback(){
  echo "  !!! ROLLBACK !!!"
  cp "${SRV}.bak_ikv1_$TS" "$SRV" 2>/dev/null || true
  cp "${BIJS}.bak_ikv1_$TS" "$BIJS" 2>/dev/null || true
  cp "${TAD}.bak_ikv1_$TS" "$TAD" 2>/dev/null || true
  rm -f shells/ik.html 2>/dev/null || true
}
rebuild(){ docker build -t krb-assessment:secure . >/dev/null 2>&1 && docker compose up -d --force-recreate $CID; }
check_js(){ if node --check "$1" 2>/dev/null; then return 0; fi; if node --check "$2" 2>/dev/null; then echo "  FAIL $1"; return 1; fi; echo "  uyari: $1 (yedek de gecmiyor) devam"; return 0; }

echo "== [0] onkosul =="
ROWS=$(docker exec -i $PG $PSQL -tAc "SELECT count(*) FROM saha_rep_gelisim WHERE tenant_id='$T'::uuid;")
echo "  saha_rep_gelisim: $ROWS"
if [ "${ROWS:-0}" -lt 1 ]; then echo "  portre yok DURDU"; exit 1; fi

echo "== [1] yedekler =="
cp "$SRV" "${SRV}.bak_ikv1_$TS"; cp "$BIJS" "${BIJS}.bak_ikv1_$TS"; cp "$TAD" "${TAD}.bak_ikv1_$TS"

echo "== [2] shells/ik.html =="
cp shells/ik.html "ik.html.bak_ikv1_$TS" 2>/dev/null || true
cat > shells/ik.html <<'IK_HTML'
<!DOCTYPE html><html lang="tr" data-theme="dark"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Derive · İK Odası</title>
<style>
:root{--page:#09090b;--s1:#111116;--s2:#16161c;--line:rgba(255,255,255,.07);--ink0:#f5f5f1;--ink1:#adaca6;--ink2:#75746f;--ink3:#4c4c4a;--accent:#a78bfa;--glow:rgba(167,139,250,.14);--warn:#fab219;--up:#2fd06f;--r:16px;color-scheme:dark;}
*{box-sizing:border-box;margin:0;padding:0}
html,body{background:var(--page);color:var(--ink0);font-family:system-ui,-apple-system,"Segoe UI",sans-serif;-webkit-font-smoothing:antialiased}
body{padding:22px}.stage{max-width:1000px;margin:0 auto}
.topbar{display:flex;align-items:center;gap:14px;padding:6px 4px 18px;flex-wrap:wrap}
.brand{display:flex;align-items:center;gap:11px;font-weight:600}
.brand .mk{width:26px;height:26px;border-radius:8px;background:conic-gradient(from 210deg,var(--accent),#7c3aed,var(--accent));box-shadow:0 0 20px var(--glow)}
.brand b{font-weight:680}.brand .sub{color:var(--ink2)}.brand .fin{color:var(--accent);font-weight:680}
.live{display:flex;align-items:center;gap:7px;color:var(--ink1);font-size:12px}
.live .p{width:7px;height:7px;border-radius:50%;background:var(--up);animation:pulse 2.4s infinite}
@keyframes pulse{0%,100%{box-shadow:0 0 0 0 rgba(47,208,111,.5)}50%{box-shadow:0 0 0 6px rgba(47,208,111,0)}}
.asof{margin-left:auto;color:var(--ink2);font-size:12px}
.intro{background:var(--s2);border:1px solid var(--line);border-radius:var(--r);padding:15px 18px;margin-bottom:18px;color:var(--ink1);font-size:13.5px;line-height:1.6}
.intro b{color:var(--ink0)}.cards{display:flex;flex-direction:column;gap:16px}
.rep{background:var(--s1);border:1px solid var(--line);border-radius:var(--r);padding:20px 22px}
.rep .h{display:flex;align-items:center;gap:12px;margin-bottom:14px;flex-wrap:wrap}
.rep .nm{font-size:19px;font-weight:640;letter-spacing:-.01em;color:var(--ink0)}
.badge{font-size:10px;letter-spacing:.05em;text-transform:uppercase;padding:3px 9px;border-radius:6px;font-weight:640}
.badge.taslak{background:rgba(250,178,25,.13);color:var(--warn)}
.badge.ok{background:rgba(47,208,111,.14);color:var(--up)}
.rep .model{margin-left:auto;color:var(--ink3);font-size:11px}
.rep .portre p{font-size:14.5px;line-height:1.68;color:var(--ink0);font-weight:420;margin-bottom:11px}
.rep .portre p:last-child{margin-bottom:0}
.empty,.err{background:var(--s2);border:1px solid var(--line);border-radius:var(--r);padding:26px;text-align:center;color:var(--ink2);font-size:14px;line-height:1.6}
.foot{margin-top:22px;color:var(--ink3);font-size:11.5px;line-height:1.6;text-align:center}
</style></head><body>
<div class="stage">
  <div class="topbar">
    <div class="brand"><span class="mk"></span><b>DERİVE</b><span class="sub">▸</span><span class="fin">İK Odası</span></div>
    <div class="live"><span class="p" id="liveDot"></span><span id="liveTxt">canlı</span></div>
    <div class="asof" id="asof">yükleniyor…</div>
  </div>
  <div class="intro"><b>Karakter &amp; Gelişim.</b> Her temsilcinin kendi satış, portföy, saha ve uygulama-kullanım verisinden çıkarılan karakter portresi ve gelişim yönü. Dil gelişim dilidir — yargı değil. Bu ilk tur <b>taslak</b>: veri biriktikçe derinleşir. Yalnız yetkili yöneticilere görünür.</div>
  <div class="cards" id="cards"></div>
  <div class="foot" id="foot"></div>
</div>
<script>
function esc(s){return String(s==null?'':s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c];});}
function paras(t){var raw=String(t||'').trim();if(!raw)return '';return raw.split(/\n\s*\n/).map(function(p){return '<p>'+esc(p.trim()).replace(/\n/g,'<br>')+'</p>';}).join('');}
function setLive(ok){var d=document.getElementById('liveDot'),t=document.getElementById('liveTxt');if(ok){if(t)t.textContent='canlı';if(d)d.style.background='var(--up)';}else{if(t)t.textContent='ulaşılamadı';if(d)d.style.background='var(--warn)';}}
function render(data){var cards=document.getElementById('cards'),asof=document.getElementById('asof'),foot=document.getElementById('foot');var list=(data&&data.kisiler)||[];if(asof)asof.textContent=(data&&data.as_of)?('son okuma · '+data.as_of):'';if(!list.length){cards.innerHTML='<div class="empty">Henüz portre üretilmedi — veri birikiyor.</div>';if(foot)foot.textContent='';return;}cards.innerHTML=list.map(function(r){var badge=(r.guven==='taslak')?'<span class="badge taslak">taslak · ilk okuma</span>':(r.guven?'<span class="badge ok">'+esc(r.guven)+'</span>':'');var model=r.model?'<span class="model">'+esc(r.model)+'</span>':'';return '<div class="rep"><div class="h"><span class="nm">'+esc(r.ad)+'</span>'+badge+model+'</div><div class="portre">'+paras(r.portre)+'</div></div>';}).join('');if(foot)foot.textContent=list.length+' temsilci · yalnız yetkili yöneticilere görünür · aylık otomatik yenilenir';}
function load(){fetch('/api/bi/ik/oda',{headers:{'Accept':'application/json'},credentials:'same-origin'}).then(function(r){if(!r.ok)throw new Error('HTTP '+r.status);return r.json();}).then(function(j){var d=(j&&j.data&&typeof j.data==='object')?j.data:j;render(d);setLive(true);}).catch(function(){setLive(false);var c=document.getElementById('cards');if(c)c.innerHTML='<div class="err">Canlı veriye ulaşılamadı. Sayfayı yenileyin.</div>';});}
load();
</script></body></html>
IK_HTML
echo "  ik.html $(wc -c < shells/ik.html) bayt"

echo "== [3] payloadlar =="
cat > /opt/krb-assessment/_ik_endpoint.js <<'EP_EOF'
  if (request.method === "GET" && url.pathname === "/api/bi/ik-odasi") { /* IK_ODASI_SHELL_V1 */
    if (response.headersSent) return;
    try {
      let _isess = await requireBiDept(request, "ikodasi").catch(() => null);  /* IK_GATE_SRV_V1 */
      if (!_isess) { if (!response.headersSent) sendJson(response, 403, { error: "yetki yok" }); return; }
      const _h = await readFile("/app/shells/ik.html", "utf8");
      response.writeHead(200, { "Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store" });
      response.end(_h);
    } catch (e) { if (!response.headersSent) sendJson(response, 404, { error: "ik odasi bulunamadi" }); }
    return;
  }
  if (request.method === "GET" && url.pathname === "/api/bi/ik/oda") { /* IK_ODA_DATA_V1 */
    if (response.headersSent) return;
    try {
      let session = await requireBiDept(request, "ikodasi").catch(() => null);  /* IK_GATE_SRV_V1 */
      if (!session) { if (!response.headersSent) sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId; if (!T) { if (!response.headersSent) sendJson(response, 401, { error: "oturum yok" }); return; }
      const _dept = (url.searchParams.get("dept") || "saha");
      const rows = (await query(
        "SELECT DISTINCT ON (g.user_id) g.user_id, to_char(g.gun,'YYYY-MM-DD') gun, g.portre, g.guven, g.model, " +
        "COALESCE(NULLIF(TRIM(u.name),''), NULLIF(TRIM(u.full_name),''), k.sap_temsilci) ad, k.kanal_etiket " +
        "FROM saha_rep_gelisim g " +
        "JOIN rep_kimlik_koprusu k ON k.tenant_id=g.tenant_id AND k.user_id=g.user_id AND k.durum=$2 " +
        "LEFT JOIN users u ON u.id=g.user_id " +
        "WHERE g.tenant_id=$1::uuid " +
        "ORDER BY g.user_id, g.gun DESC, g.hesaplandi_at DESC",
        [String(T), _dept])).rows;
      const kisiler = rows.map(r => ({ ad: r.ad || "—", portre: r.portre, guven: r.guven, model: r.model, kanal: r.kanal_etiket, gun: r.gun }))
        .sort((a, b) => String(a.ad).localeCompare(String(b.ad), "tr"));
      const asof = kisiler.reduce((m, r) => (!m || (r.gun && r.gun > m)) ? r.gun : m, null);
      const data = { as_of: asof, dept: _dept, kisi_sayisi: kisiler.length, kisiler: kisiler };
      if (!response.headersSent) sendJson(response, 200, { data: data });
    } catch (e) { console.error("[ik-oda]", e && e.message); if (!response.headersSent) sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
EP_EOF
printf '%s\n' '          ${allowedDepts.includes("ikodasi") ? '"'"'<button class="vmo-tab" data-dept="ikodasi" style="--c:#7c3aed" title="İK Odası" data-mark="IK_TAB_V1"><span>👥</span> İK</button>'"'"' : '"'"''"'"'}' > /opt/krb-assessment/_ik_navbtn.txt
cat > /opt/krb-assessment/_ik_room.txt <<'RM_EOF'
  // IK_TAB_V1 — 'İK Odası' sekmesi (dept=ikodasi) -> iframe /api/bi/ik-odasi
  {
    const _o = container.querySelector('.vmo-office');
    if (_o && allowedDepts.includes("ikodasi") && !document.getElementById('vmo-room-ikodasi')) {  /* IK_GATE_V1 */
      const _io = document.createElement('div');
      _io.id = 'vmo-room-ikodasi';
      _io.dataset.dept = 'ikodasi';
      _io.className = 'vmo-room vmo-room-hidden';
      _io.style.cssText = 'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0';
      _io.innerHTML = '<iframe id="ikodasi-frame" src="/api/bi/ik-odasi" style="width:100%;height:100%;min-height:82vh;border:0;display:block;background:#0a0e14" title="İK Odası"></iframe>';
      _o.appendChild(_io);
    }
  }
RM_EOF
printf '%s\n' '["Odalar", [["finansodasi", "Finans Odası"]]]' > /opt/krb-assessment/_tad_find.txt
printf '%s\n' '["Odalar", [["finansodasi", "Finans Odası"], ["ikodasi", "İK Odası"]]]' > /opt/krb-assessment/_tad_repl.txt

cat > /opt/krb-assessment/_patch_ik_server.py <<'PY1_EOF'
import sys
F="/opt/krb-assessment/server_container.mjs"; B="/opt/krb-assessment/_ik_endpoint.js"
s=open(F,encoding="utf-8").read()
if "IK_ODASI_SHELL_V1" in s: print("[ik-server] ZATEN var"); sys.exit(0)
payload=open(B,encoding="utf-8").read().rstrip("\n")
anchor='  if (request.method === "GET" && url.pathname === "/api/bi/finans-odasi") { /* FINANS_ODASI_SHELL_V2 */'
if s.count(anchor)!=1: print("[ik-server] anchor=%d DURDU"%s.count(anchor)); sys.exit(2)
open(F,"w",encoding="utf-8").write(s.replace(anchor, payload+"\n"+anchor, 1))
print("[ik-server] OK")
PY1_EOF
cat > /opt/krb-assessment/_patch_ik_bijs.py <<'PY2_EOF'
import sys
F="/opt/krb-assessment/shells/bi.js"
s=open(F,encoding="utf-8").read()
if "IK_TAB_V1" in s: print("[ik-bijs] ZATEN var"); sys.exit(0)
btn=open("/opt/krb-assessment/_ik_navbtn.txt",encoding="utf-8").read().rstrip("\n")
room=open("/opt/krb-assessment/_ik_room.txt",encoding="utf-8").read().rstrip("\n")
sig='allowedDepts.includes("finansodasi") ? '
if s.count(sig)!=1: print("[ik-bijs] nav sig=%d DURDU"%s.count(sig)); sys.exit(2)
i=s.find(sig); nl=s.find("\n", i)
s=s[:nl+1]+btn+"\n"+s[nl+1:]
anc="  // YONPORTFOY_ODA_V1"
if s.count(anc)!=1: print("[ik-bijs] room anchor=%d DURDU"%s.count(anc)); sys.exit(2)
s=s.replace(anc, room+"\n\n"+anc, 1)
open(F,"w",encoding="utf-8").write(s)
print("[ik-bijs] OK")
PY2_EOF
cat > /opt/krb-assessment/_patch_ik_tadmin.py <<'PY3_EOF'
import sys
F="/opt/krb-assessment/shells/tenant-admin.js"
s=open(F,encoding="utf-8").read()
if "ikodasi" in s: print("[ik-tadmin] ZATEN var"); sys.exit(0)
old=open("/opt/krb-assessment/_tad_find.txt",encoding="utf-8").read().rstrip("\n")
new=open("/opt/krb-assessment/_tad_repl.txt",encoding="utf-8").read().rstrip("\n")
if s.count(old)!=1: print("[ik-tadmin] frag=%d DURDU"%s.count(old)); sys.exit(2)
open(F,"w",encoding="utf-8").write(s.replace(old,new,1))
print("[ik-tadmin] OK")
PY3_EOF

echo "== [4] patch =="
python3 /opt/krb-assessment/_patch_ik_server.py || { rollback; exit 1; }
python3 /opt/krb-assessment/_patch_ik_bijs.py   || { rollback; exit 1; }
python3 /opt/krb-assessment/_patch_ik_tadmin.py || { rollback; exit 1; }

echo "== [5] node --check =="
check_js "$SRV" "${SRV}.bak_ikv1_$TS" || { rollback; exit 1; }
check_js "$BIJS" "${BIJS}.bak_ikv1_$TS" || { rollback; exit 1; }
check_js "$TAD" "${TAD}.bak_ikv1_$TS" || { rollback; exit 1; }

echo "== [6] grep sanity =="
DATAV=$(grep -c 'url.pathname === "/api/bi/ik/oda"' "$SRV" || true)
SHELLV=$(grep -c 'url.pathname === "/api/bi/ik-odasi"' "$SRV" || true)
NAVV=$(grep -c IK_TAB_V1 "$BIJS" || true)
TADV=$(grep -c ikodasi "$TAD" || true)
echo "  /ik/oda=$DATAV /ik-odasi=$SHELLV bi.js=$NAVV tadmin=$TADV"
if [ "$DATAV" != "1" ] || [ "$SHELLV" != "1" ] || [ "$TADV" != "1" ] || [ "$NAVV" -lt 1 ]; then rollback; exit 1; fi

echo "== [7] build + restart =="
docker build -t krb-assessment:secure .
docker compose up -d --force-recreate $CID

echo "== [8] dogrula =="
echo "  container: $(docker ps --filter name=$CID --format '{{.Status}}')"
echo "  server IK_ODASI_SHELL_V1: $(docker exec $CID grep -c IK_ODASI_SHELL_V1 /app/server.mjs || true)"
echo "  ik.html bayt: $(docker exec $CID sh -c 'wc -c < /app/shells/ik.html' || echo yok)"
echo "  bi.js IK_TAB_V1: $(docker exec $CID grep -c IK_TAB_V1 /app/shells/bi.js || true) · tadmin ikodasi: $(docker exec $CID grep -c ikodasi /app/shells/tenant-admin.js || true)"

echo "== [9] COKME kontrolu =="
HS=$(docker logs --since 90s $CID 2>&1 | grep -c ERR_HTTP_HEADERS_SENT || true)
echo "  ERR_HTTP_HEADERS_SENT: $HS · $(docker ps --filter name=$CID --format '{{.Status}}')"
if [ "$HS" != "0" ]; then echo "  COKME — ROLLBACK"; rollback; rebuild; exit 1; fi

echo "== [10] backfill =="
docker exec -i $PG $PSQL <<'SQL_BF'
UPDATE tenant_user_modules
SET permissions_json = jsonb_set(permissions_json,'{departments}', COALESCE(permissions_json->'departments','[]'::jsonb) || '["ikodasi"]'::jsonb), updated_at = now()
WHERE module_id='intelligence' AND module_role IN ('admin','manager') AND active
  AND NOT (COALESCE(permissions_json->'departments','[]'::jsonb) @> '["ikodasi"]'::jsonb);
SELECT module_role, count(*) FILTER (WHERE permissions_json->'departments' @> '["ikodasi"]'::jsonb) AS ikodasi_var FROM tenant_user_modules WHERE module_id='intelligence' GROUP BY module_role ORDER BY module_role;
SQL_BF

echo "== [11] fingerprint =="
docker exec -i $PG $PSQL <<'SQL_FP'
INSERT INTO bi_insa_gunlugu (adim, ne, neden, detay)
SELECT 'IK_ODASI_V1','İK Odası v1 canli — Bolum 1 Karakter & Gelisim (yonetici-yuzu). Yeni oda ikodasi; iki uc requireBiDept(ikodasi), saha fallback yok. shells/ik.html saha_rep_gelisim portrelerini taslak rozetiyle gosterir.','Karakter motoru uretiyordu ama gorunmuyordu; oda kabugu ileri bolumlerin tekrar kullanacagi tenant+departman-kapsamli iskelet. Bugun yalniz satis (durum=saha) veriye sahip; endpoint dept-parametreli.','{"marker":"IK_ODASI_V1","dept_key":"ikodasi","uclar":["/api/bi/ik-odasi","/api/bi/ik/oda"],"tablo":"saha_rep_gelisim","kisi":7,"guven":"taslak"}'::jsonb
WHERE NOT EXISTS (SELECT 1 FROM bi_insa_gunlugu WHERE adim='IK_ODASI_V1');
INSERT INTO bi_yetenek (ad, tur, ne_ise_yarar, nasil, durum, guven, kanit, aktif, guncellendi_at, son_gorulme)
VALUES ('ik_odasi_veri','oda','İK Odası Bolum 1 — temsilci karakter & gelisim portreleri (yonetici-yuzu).','GET /api/bi/ik/oda -> saha_rep_gelisim en guncel portre/kisi, dept-kapsamli (varsayilan saha). Shell /api/bi/ik-odasi (no-store). requireBiDept(ikodasi); owner+intelligence-admin bypass, saha fallback yok. Tum portreler taslak.','canli','taslak','{"marker":"IK_ODASI_V1","uc":["/api/bi/ik-odasi","/api/bi/ik/oda"],"tablo":"saha_rep_gelisim","gate":"ikodasi","kisi":7}'::jsonb,true,now(),now())
ON CONFLICT (ad,tur) DO UPDATE SET ne_ise_yarar=EXCLUDED.ne_ise_yarar, nasil=EXCLUDED.nasil, durum=EXCLUDED.durum, guven=EXCLUDED.guven, kanit=EXCLUDED.kanit, guncellendi_at=now(), son_gorulme=now();
SELECT adim FROM bi_insa_gunlugu WHERE adim='IK_ODASI_V1';
SELECT ad, tur, durum FROM bi_yetenek WHERE ad='ik_odasi_veri';
SQL_FP

echo "== [12] temizlik =="
rm -f /opt/krb-assessment/_ik_endpoint.js /opt/krb-assessment/_ik_navbtn.txt /opt/krb-assessment/_ik_room.txt /opt/krb-assessment/_tad_find.txt /opt/krb-assessment/_tad_repl.txt /opt/krb-assessment/_patch_ik_server.py /opt/krb-assessment/_patch_ik_bijs.py /opt/krb-assessment/_patch_ik_tadmin.py 2>/dev/null || true
echo "== BITTI — İK Odası v1 CANLI. Yonetici hesabinda BI'da 👥 İK sekmesi. =="
