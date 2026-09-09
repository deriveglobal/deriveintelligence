#!/usr/bin/env bash
# OMURGA 14b — GÖRÜNÜR KIL (düzeltilmiş): sağlam anchor, yazmadan önce doğrula, hata=abort+geri al.
set -uo pipefail
cd /opt/krb-assessment || exit 1
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "0. Önceki başarısız denemenin sahte ayak izini temizle"
$PSQL -c "DELETE FROM bi_insa_gunlugu WHERE adim='omurga_14';" 2>/dev/null | sed 's/^/  /' || true

hr "1. YEDEK"
cp server_container.mjs server_container.mjs.bak_trend2
cp shells/bi.js shells/bi.js.bak_trend2
echo "  ✅ .bak_trend2"

hr "2. YAMA (Python — TÜM anchor'ları önce doğrula, sonra yaz)"
python3 - <<'PY'
import sys
srv_path='server_container.mjs'; ui_path='shells/bi.js'
s=open(srv_path,encoding='utf-8').read()
u=open(ui_path,encoding='utf-8').read()

# --- anchor'lar (girinti içermez, substring) ---
A_srv = "if (request.method === 'GET' && url.pathname === '/api/bi/yukle/durum') {"
A_fn  = "async function ciz_finans() {"
A_dn  = "g.querySelectorAll('.dn')"
A_commit = "g.innerHTML = h;"

# --- DOĞRULA (yazmadan önce) ---
errs=[]
if s.count(A_srv)!=1: errs.append(f"server yukle/durum anchor={s.count(A_srv)}")
if u.count(A_fn)!=1:  errs.append(f"ciz_finans anchor={u.count(A_fn)}")
if A_dn not in u:     errs.append("bi.js .dn marker yok")
if errs:
    print("  ❌ ANCHOR HATASI:", "; ".join(errs)); sys.exit(2)

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
s = s.replace(A_srv, ENDPOINT + A_srv, 1)

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
u = u.replace(A_fn, TREND_FN + "  " + A_fn, 1)

# container + call: .dn marker'a en yakin onceki commit
i = u.index(A_dn)
j = u.rindex(A_commit, 0, i)
container = "h += '<div id=\"finans-trend-bolum\" style=\"margin-top:28px\"><div style=\"color:var(--tx-2);font-size:13px\">Marka trendi yükleniyor…</div></div>';\n      "
u = u[:j] + container + u[j:].replace(A_commit, A_commit + "\n      _finansTrendCiz();", 1)

open(srv_path,'w',encoding='utf-8').write(s)
open(ui_path,'w',encoding='utf-8').write(u)
print("  ✅ server endpoint + bi.js trend bölümü yazıldı")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then
  echo "  ⚠ YAMA BAŞARISIZ (rc=$PYRC) — geri alınıyor, deploy YOK"
  cp server_container.mjs.bak_trend2 server_container.mjs
  cp shells/bi.js.bak_trend2 shells/bi.js
  echo "  ↩ geri alındı."
  exit 1
fi

hr "3. SÖZDİZİMİ KAPISI — node --check"
OK=1
node --check server_container.mjs && echo "  ✅ server OK" || OK=0
cp shells/bi.js /tmp/_bicheck.mjs
node --check /tmp/_bicheck.mjs && echo "  ✅ bi.js OK" || OK=0
if [ "$OK" != "1" ]; then
  echo "  ⚠ SÖZDİZİMİ BOZUK — geri al, deploy YOK"
  cp server_container.mjs.bak_trend2 server_container.mjs
  cp shells/bi.js.bak_trend2 shells/bi.js
  echo "  ↩ geri alındı."
  exit 1
fi

hr "4. DOĞRULAMA — eklemeler gerçekten dosyada mı"
grep -c "finans-trend" server_container.mjs | sed 's/^/  server finans-trend geçiş sayısı: /'
grep -c "_finansTrendCiz" shells/bi.js | sed 's/^/  bi.js _finansTrendCiz geçiş sayısı: /'

hr "5. AYAK İZİ + DEPLOY komutu"
$PSQL -c "INSERT INTO bi_insa_gunlugu (adim,ne,neden,detay) VALUES ('omurga_14','finans-trend endpoint + Finans odasi Marka Trendi bolumu','Gorunur kil: metrik omurgasi ilk kez ekranda','{\"script\":\"omurga_14b\",\"deploy\":\"bekliyor\"}');" >/dev/null 2>&1 || true
echo "  ✅ ayak izi düşüldü"
echo ""
echo "  ▶ DEPLOY (ayrı çalıştır):"
echo "      cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"

hr "BITTI — yama uygulandı (gerçekten), sözdizimi + varlık doğrulandı. Deploy yukarıda."
