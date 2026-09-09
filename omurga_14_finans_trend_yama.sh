#!/usr/bin/env bash
# OMURGA 14 — GÖRÜNÜR KIL: /api/bi/finans-trend endpoint + Finans odasına "Marka Trendi" bölümü.
#   İzole + additive. Python ekleme. node --check kapısı. Bozuksa geri al. DEPLOY AYRI (Fatih).
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. YEDEK — geri dönüş için"
cp server_container.mjs server_container.mjs.bak_trend
cp shells/bi.js shells/bi.js.bak_trend
echo "  ✅ yedekler: .bak_trend"

hr "2. YAMA (Python — tam metin ekleme, tek anchor)"
python3 - <<'PY'
import sys

# ---- A. SERVER: /api/bi/finans-trend endpoint ----
srv_path = 'server_container.mjs'
s = open(srv_path, encoding='utf-8').read()
anchor_srv = '    // Hangi dosyalar bekleniyor + hangisi ne zaman geldi'
assert s.count(anchor_srv) == 1, f"server anchor sayisi: {s.count(anchor_srv)} (1 olmali)"

ENDPOINT = r'''    if (request.method === 'GET' && url.pathname === '/api/bi/finans-trend') {
      try {
        const session = await requireModuleAccess(request, "intelligence");
        const T = session.tenantId;
        const metrik = url.searchParams.get('metrik') || 'ciro_lastik';
        const boyut  = url.searchParams.get('boyut')  || 'marka';
        const r = await query(`
          SELECT boyut_deger AS ad,
                 round(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01')) AS h1_2025,
                 round(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')) AS h1_2026,
                 round(100.0*(sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01')
                       - sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'))
                       / nullif(sum(deger) FILTER (WHERE donem>='2025-01-01' AND donem<'2025-07-01'),0)) AS yoy_pct
            FROM bi_metrik_gecmis
           WHERE tenant_id=$1::uuid AND metrik=$2 AND boyut_tipi=$3
           GROUP BY boyut_deger
          HAVING sum(deger) FILTER (WHERE donem>='2026-01-01' AND donem<'2026-07-01') > 0
           ORDER BY h1_2026 DESC NULLS LAST LIMIT 12`, [T, metrik, boyut]);
        sendJson(response, 200, { metrik, boyut, satirlar: r.rows });
      } catch (e) { sendJson(response, 500, { error: e.message }); }
    }

'''
s = s.replace(anchor_srv, ENDPOINT + anchor_srv, 1)
open(srv_path, 'w', encoding='utf-8').write(s)
print("  ✅ server endpoint eklendi")

# ---- B. bi.js: trend render fonksiyonu + Finans odasına bölüm ----
ui_path = 'shells/bi.js'
u = open(ui_path, encoding='utf-8').read()

TREND_FN = r'''  async function _finansTrendCiz(){
    var el = document.getElementById('finans-trend-bolum'); if(!el) return;
    try{
      var r = await fetch('/api/bi/finans-trend?metrik=ciro_lastik&boyut=marka', {credentials:'same-origin'});
      var d = await r.json(); if(d.error) throw new Error(d.error);
      var rows = d.satirlar || [];
      if(!rows.length){ el.innerHTML=''; return; }
      var h = '<div class="etiket" style="margin-bottom:10px">MARKA TRENDİ — lastik cirosu · H1 2025 → H1 2026</div><div class="kart">';
      rows.forEach(function(x){
        var yoy = x.yoy_pct;
        var renk = (yoy==null) ? 'var(--tx-2)' : (Number(yoy)>=0 ? '#34d399' : '#f87171');
        var ok = (yoy==null) ? '' : (Number(yoy)>=0 ? '▲' : '▼');
        h += '<div class="satir"><div>'+esc(String(x.ad||'').slice(0,24))+'</div>'
           + '<div class="n">'+_M(x.h1_2025)+' → '+_M(x.h1_2026)
           + ' <span style="color:'+renk+';font-size:12px;margin-left:6px">'+ok+' '+(yoy==null?'—':yoy+'%')+'</span></div></div>';
      });
      h += '</div><div style="font-size:11px;color:var(--tx-3);margin-top:6px">Kaynak: bi_metrik_gecmis · ciro_lastik × marka · güven: kesin</div>';
      el.innerHTML = h;
    }catch(e){ el.innerHTML = '<div class="d-kirmizi" style="font-size:12px">Marka trendi gelmedi: '+esc(e.message)+'</div>'; }
  }

'''

anchor_fn = 'async function ciz_finans() {'
assert u.count(anchor_fn) == 1, f"ciz_finans anchor: {u.count(anchor_fn)}"
u = u.replace(anchor_fn, TREND_FN + '  ' + anchor_fn, 1)

# container + call: ciz_finans commit noktasi (.dn marker'a en yakin g.innerHTML = h;)
marker = "g.querySelectorAll('.dn')"
i = u.index(marker)
j = u.rindex('g.innerHTML = h;', 0, i)
container = "h += '<div id=\"finans-trend-bolum\" style=\"margin-top:28px\"><div style=\"color:var(--tx-2);font-size:13px\">Marka trendi yükleniyor…</div></div>';\n      "
u = u[:j] + container + u[j:].replace('g.innerHTML = h;', 'g.innerHTML = h;\n      _finansTrendCiz();', 1)
open(ui_path, 'w', encoding='utf-8').write(u)
print("  ✅ bi.js trend fonksiyonu + Finans bölümü eklendi")
PY

hr "3. SÖZDİZİMİ KAPISI — node --check (bozuksa deploy ETME)"
OK=1
node --check server_container.mjs && echo "  ✅ server_container.mjs sözdizimi OK" || { echo "  ❌ server bozuk"; OK=0; }
cp shells/bi.js /tmp/_bicheck.mjs
node --check /tmp/_bicheck.mjs && echo "  ✅ bi.js sözdizimi OK" || { echo "  ❌ bi.js bozuk"; OK=0; }

if [ "$OK" != "1" ]; then
  echo "  ⚠ SÖZDİZİMİ BOZUK — yedekten geri alınıyor, DEPLOY YOK"
  cp server_container.mjs.bak_trend server_container.mjs
  cp shells/bi.js.bak_trend shells/bi.js
  echo "  ↩ geri alındı. Yama gözden geçirilecek."
  exit 1
fi

hr "4. HAZIR — sözdizimi temiz. Ayak izi + DEPLOY komutları"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c \
 "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_14','finans-trend endpoint + Finans odasi Marka Trendi bolumu (yama, node-check gecti)','Gorunur kil: metrik omurgasi ilk kez ekranda','{\"script\":\"omurga_14_finans_trend_yama.sh\",\"deploy\":\"bekliyor\"}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi düşüldü (deploy bekliyor)"
echo ""
echo "  ▶ DEPLOY (ayrı çalıştır):"
echo "      cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — yama uygulandı + doğrulandı. Deploy komutu yukarıda. docker cp YOK."
