#!/usr/bin/env bash
# OMURGA 14c — SADECE bi.js DÜZELT: container+çağrı ciz_finans'ın KENDİ commit'ine. Server endpoint zaten doğru.
set -uo pipefail
cd /opt/krb-assessment || exit 1
hr(){ printf '\n════════ %s ════════\n' "$1"; }

hr "1. bi.js'i TEMİZ yedekten geri al (.bak_trend2 = trend öncesi)"
cp shells/bi.js.bak_trend2 shells/bi.js
echo "  ✅ bi.js temizlendi (trend kodu tamamen kalktı)"
cp shells/bi.js shells/bi.js.bak_trend3

hr "2. DOĞRU YAMA — fonksiyon + container/çağrı ciz_finans'ın KENDİ commit'inde"
python3 - <<'PY'
import sys
p='shells/bi.js'; u=open(p,encoding='utf-8').read()
A_fn="async function ciz_finans() {"
if u.count(A_fn)!=1: print("  ❌ ciz_finans anchor:",u.count(A_fn)); sys.exit(2)

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
# fonksiyonu ciz_finans'tan hemen once ekle
u = u.replace(A_fn, TREND_FN + "  " + A_fn, 1)

# ciz_finans def sonrasi ILK 'g.innerHTML = h;' = ciz_finans'in KENDI commit'i
fn_start = u.index(A_fn)
commit = "g.innerHTML = h;"
cpos = u.index(commit, fn_start)
container = "h += '<div id=\"finans-trend-bolum\" style=\"margin-top:28px\"><div style=\"color:var(--tx-2);font-size:13px\">Marka trendi yükleniyor…</div></div>';\n      "
u = u[:cpos] + container + commit + "\n      _finansTrendCiz();" + u[cpos+len(commit):]
open(p,'w',encoding='utf-8').write(u)
print("  ✅ yeniden yamandı (doğru commit)")
PY
PYRC=$?
if [ $PYRC -ne 0 ]; then echo "  ⚠ başarısız, geri al"; cp shells/bi.js.bak_trend3 shells/bi.js; exit 1; fi

hr "3. SÖZDİZİMİ + YER DOĞRULAMA"
cp shells/bi.js /tmp/_bic.mjs
node --check /tmp/_bic.mjs && echo "  ✅ bi.js sözdizimi OK" || { echo "  ❌ bozuk, geri al"; cp shells/bi.js.bak_trend3 shells/bi.js; exit 1; }
FNDEF=$(grep -n "async function ciz_finans" shells/bi.js | cut -d: -f1)
CONT=$(grep -n 'h += .<div id="finans-trend-bolum' shells/bi.js | cut -d: -f1)
echo "  ciz_finans def: $FNDEF · container h+=: $CONT"
if [ -n "$CONT" ] && [ "$CONT" -gt "$FNDEF" ]; then
  echo "  ✅ container ARTIK ciz_finans içinde (def sonrası) — doğru"
else
  echo "  ❌ hâlâ yanlış — geri al"; cp shells/bi.js.bak_trend3 shells/bi.js; exit 1
fi

hr "BITTI — bi.js düzeltildi + doğrulandı. DEPLOY:"
echo "  cd /opt/krb-assessment && docker build -t krb-assessment:secure . && docker compose up -d --force-recreate krb-assessment"
