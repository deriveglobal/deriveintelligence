    function _b2bReclass(r){var m=(r.urun_adi||'').match(/R\s*(\d{2}(?:[.,]\d)?)\s*(C)?/i);var cap=null,cc=false;if(m){cap=parseFloat(m[1].replace(',','.'));cc=!!m[2];}if(!cc&&/\d\s*C\b/i.test((r.ebat||'')+' '+(r.urun_adi||'')))cc=true;if(cap===17.5||cap===19.5||cap===22.5)return 'KAMYON_OTOBUS';if(cc)return 'HAFIF_TICARI';return 'BINEK';}
    function _b2bGrupOf(r){var s=r.segment||_b2bReclass(r);return s==='BINEK'?'BINEK|'+(r.mevsim||'?'):s;}
    function _b2bTL(n){return n==null?'—':Number(n).toLocaleString('tr-TR')+' ₺';}
    function _b2bEsc(s){return String(s==null?'':s).replace(/"/g,'&quot;').replace(/</g,'&lt;');}
    function _b2bMevRoz(m){var b='font-size:9px;font-weight:700;padding:1px 6px;border-radius:7px';return m==='yaz'?'<span style="background:rgba(245,158,11,.18);color:#fbbf24;'+b+'">Yaz</span>':m==='kis'?'<span style="background:rgba(59,130,246,.18);color:#93c5fd;'+b+'">Kış</span>':m==='4mevsim'?'<span style="background:rgba(34,197,94,.16);color:#86efac;'+b+'">4 Mev</span>':'<span style="background:rgba(148,163,184,.15);color:#cbd5e1;'+b+'">?</span>';}
    // ── AKILLI EŞLEŞTİRME v6.2 · + placeholder/tek-ilan temizliği ──────
    // Türkçe katla + küçült (İ→i, ı→i, ş→s…)
    function _b2bFold(s){return String(s==null?'':s).replace(/İ/g,'i').toLowerCase().replace(/̇/g,'').replace(/ı/g,'i').replace(/ş/g,'s').replace(/ğ/g,'g').replace(/ç/g,'c').replace(/ö/g,'o').replace(/ü/g,'u');}
    function _b2bMarkaN(m){return _b2bFold(m).replace(/[^a-z0-9]/g,'');}
    // ebat + adı temizle → yük/hız (91v) ve xl çıkar
    function _b2bLoadXL(name,ebat){
      var s=_b2bFold((name||'')+' '+(ebat||''));
      s=s.replace(/\d{3}\s*\/\s*\d{2,3}\s*z?\s*r\s*\d{2}(?:[.,]\d)?\s*c?/g,' ');
      var m=s.match(/\b(\d{2,3}(?:\/\d{2,3})?)\s?([qstuhvwyz])\b/);
      return {ls:m?(m[1]+m[2]):'', xl:/\bxl\b/.test(s)?'x':''};
    }
    // Desen imzası: boşluk/noktalama at → "premiumcontact7", "ventusprime4k135", "pzeropz4"
    function _b2bSig(name,marka){
      var s=_b2bFold(name);
      s=s.replace(/\d{3}\s*\/\s*\d{2,3}\s*z?\s*r\s*\d{2}(?:[.,]\d)?\s*c?/g,' ');   // ebat
      s=s.replace(/\br\s*\d{2}(?:[.,]\d)?\b/g,' ');                                 // r16
      s=s.replace(/\b\d{2,3}(?:\/\d{2,3})?\s?[qstuhvwyz]\b/g,' ');                   // 91v
      s=s.replace(/\b(19|20)\d{2}\b/g,' ');                                         // yıl
      s=s.replace(/[*+()]/g,' ');
      s=s.replace(/\b4\s*mevsim\b/g,' ').replace(/\b4\s*x\s*4\b/g,' ');            // mevsim/çekiş çöpü (model "4"ü koru)
      // yalnız gerçek çöp kelimeleri at — model kelimelerine (premium, contact, eco, prime 4…) DOKUNMA
      s=s.replace(/\b(yaz|kis|mevsim|dort|winter|summer|oto|otomobil|suv|van|lastigi|lastik|seti|set|olarak|adet|takim|takimi|uretim|tarihi|tarih|yil|xl|fr|rft|rf|ssr|moe|mo|ncs|elt|vol|ev|sc|pncs|seg|soa|msf|ms|kg|dot|adedi|yeni|sifir|lu|li|adetli)\b/g,' ');
      var mk=_b2bMarkaN(marka);
      s=s.split(/[^a-z0-9]+/).filter(function(t){return t && t!==mk;}).join('');
      if(mk==='continental')s=s.replace(/^conti/,'');
      return s;
    }
    function _b2bSigComp(a,b){
      if(!a||!b)return true;
      if(a===b)return true;
      var s=a.length<=b.length?a:b, l=a.length<=b.length?b:a;
      if(s.length>=5 && l.indexOf(s)===0)return true;   // ventusprime4 ⊂ ventusprime4k135
      if(s.length>=7 && l.indexOf(s)>=0)return true;     // contipremiumcontact7 ⊇ premiumcontact7
      return false;
    }
    // kaba kova anahtarı: marka+ebat+yük/hız+xl+mevsim (desen ayrı kümelenir)
    function _b2bMatchKey(r){var ebat=_b2bFold(r.ebat).replace(/\s/g,'');if(!r.marka||!ebat)return '';var lx=_b2bLoadXL(r.urun_adi,r.ebat);return _b2bMarkaN(r.marka)+'|'+ebat+'|'+lx.ls+'|'+lx.xl+'|'+(r.mevsim||'');}
    function _b2bPiyEbat(x){var pcap=String(x.cap==null?'':x.cap).replace(/\.0+$/,'');if(!x.genislik||!x.profil||!pcap)return '';return x.genislik+'/'+x.profil+'R'+pcap;}
    var _B2BGRUP=[{k:'BINEK|yaz',ad:'☀️ Binek Yaz',sw:'#f59e0b'},{k:'BINEK|kis',ad:'❄️ Binek Kış',sw:'#3b82f6'},{k:'BINEK|4mevsim',ad:'🌦️ Binek 4 Mevsim',sw:'#22c55e'},{k:'HAFIF_TICARI',ad:'🚐 Hafif Ticari',sw:'#a78bfa'},{k:'KAMYON_OTOBUS',ad:'🚛 Kamyon/Otobüs',sw:'#f97316'},{k:'IS_MAKINESI',ad:'🚜 İş Mak./Diğer',sw:'#94a3b8'}];
    var _B2BRENK=['#3b82f6','#22c55e','#f59e0b','#ef4444','#8b5cf6','#06b6d4','#f97316','#84cc16','#ec4899','#14b8a6','#eab308','#a78bfa'];
    function _b2bSUP(){var s=[{k:'yuke',ad:'Yuke'},{k:'haskar',ad:'Haskar'},{k:'cakiroglu',ad:'Çakıroğlu'},{k:'mutaflar',ad:'Mutaflar'},{k:'lastikpark',ad:'Lastikpark'}];((window._b2bData||{}).kaynaklar||[]).forEach(function(k){if(!s.find(function(x){return x.k===k.kaynak;}))s.push({k:k.kaynak,ad:k.kaynak});});return s;}
    function _b2bAktifSet(){var a={};((window._b2bData||{}).kaynaklar||[]).forEach(function(k){a[k.kaynak]=1;});return a;}
    function _b2bFiltre(){var rows=((window._b2bData||{}).urunler||[]).slice();if(window._b2bKaynak)rows=rows.filter(function(r){return r.kaynak===window._b2bKaynak;});if(window._b2bGrup)rows=rows.filter(function(r){return _b2bGrupOf(r)===window._b2bGrup;});var q=(window._b2bArama||'').trim().toLowerCase();if(q)rows=rows.filter(function(r){return ((r.marka||'')+' '+(r.ebat||'')+' '+(r.urun_adi||'')+' '+(r.urun_kodu||'')).toLowerCase().indexOf(q)>=0;});return rows;}
    function _b2bFiltreKaynakSadece(){var rows=((window._b2bData||{}).urunler||[]).slice();if(window._b2bGrup)rows=rows.filter(function(r){return _b2bGrupOf(r)===window._b2bGrup;});return rows;}
    // B2C piyasa → kova anahtarına göre [{f,sig}] listesi
    function _b2bSet(nm){return /\btakim\b|takimi|\bset\b|adet|4\s*lu\b|4\s*li\b/.test(_b2bFold(nm));}  // 4'lü takım ilanı mı
    function _b2bPiyaList(){var pm={};(((window._b2bData||{}).piyasa)||[]).forEach(function(x){var eb=_b2bPiyEbat(x);if(!eb)return;if(_b2bSet(x.model))return;var r={marka:x.marka,ebat:eb,urun_adi:x.model,mevsim:x.mevsim};var key=_b2bMatchKey(r);if(!key)return;var f=Number(x.fiyat);if(!(f>0))return;(pm[key]=pm[key]||[]).push({f:f,sig:_b2bSig((x.model||'')+' '+eb,x.marka)});});return pm;}
    // Kova içinde desen imzasına göre kümele → gerçekten aynı lastikleri birleştir
    function _b2bB2Bgruplar(rows,matSUP){
      var buckets={};
      rows.forEach(function(r){var key=_b2bMatchKey(r);if(!key)return;(buckets[key]=buckets[key]||[]).push(r);});
      var out=[];
      Object.keys(buckets).forEach(function(key){
        var items=buckets[key].map(function(r){return {r:r,sig:_b2bSig(r.urun_adi,r.marka)};});
        items.sort(function(a,b){return b.sig.length-a.sig.length;});   // spesifik olan küme temsilcisi olsun
        var cl=[];
        items.forEach(function(it){
          var g=null;for(var i=0;i<cl.length;i++){if(_b2bSigComp(cl[i].sig,it.sig)){g=cl[i];break;}}
          if(!g){g={sig:it.sig,rows:[]};cl.push(g);}
          if(it.sig.length>g.sig.length)g.sig=it.sig;
          g.rows.push(it.r);
        });
        cl.forEach(function(c){
          var G={key:key,dsig:c.sig,marka:c.rows[0].marka,ebat:c.rows[0].ebat,mevsim:c.rows[0].mevsim,fy:{},ad:{},urun_adi:''};
          c.rows.forEach(function(r){
            if(G.fy[r.kaynak]==null||r.alis_fiyat<G.fy[r.kaynak]){G.fy[r.kaynak]=r.alis_fiyat;G.ad[r.kaynak]=r.urun_adi;}
            if((r.urun_adi||'').length>(G.urun_adi||'').length)G.urun_adi=r.urun_adi;
            if(!G.mevsim)G.mevsim=r.mevsim;if(!G.ebat)G.ebat=r.ebat;
          });
          out.push(G);
        });
      });
      return out.map(function(G){
        var vals=matSUP.map(function(s){return G.fy[s.k];}).filter(function(v){return v!=null;});
        G.nsup=vals.length;G.mn=vals.length?Math.min.apply(null,vals):null;G.mx=vals.length?Math.max.apply(null,vals):null;
        G.fark=G.nsup>1?Math.round((G.mx-G.mn)/G.mn*100):null;
        G.eu=matSUP.find(function(s){return G.fy[s.k]===G.mn;});
        G.dconf=(G.dsig&&G.dsig.length>=5);                 // desen tanındı mı
        G.suspect=(G.fark!=null&&G.fark>=45&&!G.dconf);      // yüksek fark + desen belirsiz
        return G;
      });
    }
    window.b2bSetView=function(v){window._b2bView=v;window.b2bRender();};
    window.b2bSetKaynak=function(k){window._b2bKaynak=(window._b2bKaynak===k?null:k);window.b2bRender();};
    window.b2bSetGrup=function(g){window._b2bGrup=(window._b2bGrup===g?null:g);window.b2bRender();};
    window.b2bMatSort=function(){var s=window._b2bMatSort||'overlap';window._b2bMatSort=(s==='overlap'?'fark_desc':s==='fark_desc'?'fark_asc':'overlap');window.b2bListeCards();};
    window.b2bSatSort=function(){var s=window._b2bSatSort||'marj_desc';window._b2bSatSort=(s==='marj_desc'?'marj_asc':'marj_desc');window.b2bListeCards();};
    window.b2bRender=function(){
      var el=document.getElementById('rf-b2b-govde');if(!el)return;
      var d=window._b2bData||{};var urunler=d.urunler||[],kaynaklar=d.kaynaklar||[];
      if(!urunler.length){el.innerHTML='<div style="color:#667;padding:20px">Henüz B2B verisi yok.</div>';return;}
      var SUP=_b2bSUP();var AKTIF={};kaynaklar.forEach(function(k){AKTIF[k.kaynak]=k.n;});
      var view=window._b2bView||'ozet';
      var vlab={ozet:'Genel Bakış',matris:'Çapraz Matris',satis:'💰 Alış-Satış'};
      var h='<div style="display:flex;gap:6px;margin-bottom:14px;flex-wrap:wrap">'+['ozet','matris','satis'].map(function(v){return '<button onclick="b2bSetView(\''+v+'\')" style="padding:7px 15px;border:1px solid '+(view===v?'#3182ce':'rgba(255,255,255,0.12)')+';background:'+(view===v?'rgba(49,130,206,0.18)':'transparent')+';color:#e2e8f0;border-radius:7px;font-size:12.5px;font-weight:600;cursor:pointer">'+vlab[v]+'</button>';}).join('')+'<span style="margin-left:auto;color:#667;font-size:11.5px;align-self:center">'+urunler.length+' ürün · '+kaynaklar.length+' tedarikçi</span></div>';
      function tchip(k,ad,n,aktif){var sel=(window._b2bKaynak===k);return '<div '+(aktif?'onclick="b2bSetKaynak('+(k===null?'null':'\''+k+'\'')+')" ':'')+'style="background:'+(sel?'rgba(49,130,206,0.20)':'rgba(255,255,255,0.05)')+';border:1px solid '+(sel?'#3182ce':'rgba(255,255,255,0.10)')+';border-radius:8px;padding:6px 12px;font-size:12.5px;'+(aktif?'cursor:pointer':'opacity:.4')+'"><b>'+ad+'</b>'+(n!=null?' <span style="color:#94a3b8">'+n+'</span>':'')+'</div>';}
      h+='<div style="font-size:12px;color:#94a3b8;margin-bottom:7px;font-weight:600">Tedarikçi</div><div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px">'+tchip(null,'Tümü',urunler.length,true)+SUP.map(function(s){return tchip(s.k,s.ad,AKTIF[s.k]||null,!!AKTIF[s.k]);}).join('')+'</div>';
      function gsay(k){return _b2bFiltreKaynakSadece().filter(function(r){return _b2bGrupOf(r)===k;}).length;}
      h+='<div style="font-size:12px;color:#94a3b8;margin-bottom:7px;font-weight:600">Kategori</div><div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px">';
      h+='<div onclick="b2bSetGrup(null)" style="background:'+(!window._b2bGrup?'rgba(49,130,206,0.20)':'rgba(255,255,255,0.05)')+';border:1px solid '+(!window._b2bGrup?'#3182ce':'rgba(255,255,255,0.10)')+';border-radius:8px;padding:6px 12px;font-size:12px;cursor:pointer"><b>Tümü</b></div>';
      h+=_B2BGRUP.map(function(g){var sel=(window._b2bGrup===g.k);return '<div onclick="b2bSetGrup(\''+g.k+'\')" style="display:flex;align-items:center;gap:7px;background:'+(sel?'rgba(49,130,206,0.20)':'rgba(255,255,255,0.05)')+';border:1px solid '+(sel?'#3182ce':'rgba(255,255,255,0.10)')+';border-radius:8px;padding:6px 12px;font-size:12px;cursor:pointer"><span style="width:9px;height:9px;border-radius:3px;background:'+g.sw+'"></span>'+g.ad+' <span style="color:#667">'+gsay(g.k)+'</span></div>';}).join('')+'</div>';
      var av=(window._b2bArama||'').replace(/"/g,'&quot;');
      h+='<input id="b2b-ara" oninput="window._b2bArama=this.value;window.b2bListeCards();" value="'+av+'" placeholder="🔍 Marka / ebat / model / kod ara…" style="width:100%;max-width:420px;padding:9px 13px;background:rgba(255,255,255,0.05);border:1px solid rgba(255,255,255,0.12);border-radius:8px;color:#e2e8f0;font-size:13px;margin-bottom:16px">';
      h+='<div id="b2b-dinamik"></div>';
      el.innerHTML=h;window.b2bListeCards();
    };
    window.b2bListeCards=function(){
      var box=document.getElementById('b2b-dinamik');if(!box)return;
      var rows=_b2bFiltre();var view=window._b2bView||'ozet';var SUP=_b2bSUP();
      if(!rows.length){box.innerHTML='<div style="color:#667;padding:24px;text-align:center">Eşleşen ürün yok.</div>';return;}
      var actSet=_b2bAktifSet();var matSUP=SUP.filter(function(s){return actSet[s.k];});if(!matSUP.length)matSUP=SUP.slice(0,2);
      var bb2='padding:9px 12px;border-bottom:1px solid rgba(255,255,255,0.05)';
      var th2=function(t,r,cl,click){return '<th '+(cl?'onclick="'+click+'()" title="Sırala" style="cursor:pointer;':'style="')+'text-align:'+(r?'right':'left')+';padding:10px 12px;border-bottom:2px solid rgba(255,255,255,0.12);color:#94a3b8;white-space:nowrap;position:sticky;top:0;background:#0d1526">'+t+'</th>';};
      if(view==='ozet'){
        var g={};rows.forEach(function(r){(g[r.marka]=g[r.marka]||[]).push(r.alis_fiyat);});
        var arr=Object.keys(g).map(function(m){var fs=g[m];return {m:m,n:fs.length,min:Math.min.apply(null,fs),max:Math.max.apply(null,fs)};}).sort(function(a,b){return b.n-a.n;});
        var tot=rows.length;
        var out='<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(180px,1fr));gap:12px;margin-bottom:20px">'+arr.map(function(x,i){var c=_B2BRENK[i%_B2BRENK.length];var pct=Math.round(x.n/tot*100);var w=Math.min(100,Math.round((x.max-x.min)/x.max*200));return '<div style="background:rgba(255,255,255,0.04);border:1px solid rgba(255,255,255,0.10);border-radius:11px;padding:12px 15px"><div style="display:flex;align-items:center;gap:7px;margin-bottom:7px"><span style="width:8px;height:8px;border-radius:50%;background:'+c+'"></span><span style="font-size:13px;font-weight:700;white-space:nowrap;overflow:hidden;text-overflow:ellipsis">'+x.m+'</span></div><div style="font-size:17px;font-weight:800;color:'+c+'">'+_b2bTL(x.min)+'</div><div style="font-size:11px;color:#94a3b8;margin-top:2px">min · maks '+_b2bTL(x.max)+'</div><div style="height:3px;background:rgba(255,255,255,0.1);border-radius:2px;margin-top:8px;overflow:hidden"><i style="display:block;height:100%;width:'+w+'%;background:'+c+';opacity:.7"></i></div><div style="font-size:11px;color:#667;margin-top:6px">'+x.n+' SKU · %'+pct+' pay</div></div>';}).join('')+'</div>';
        var bb='padding:8px 11px;border-bottom:1px solid rgba(255,255,255,0.05)';
        var th=function(t,r){return '<th style="text-align:'+(r?'right':'left')+';padding:9px 11px;border-bottom:2px solid rgba(255,255,255,0.12);color:#94a3b8;white-space:nowrap;position:sticky;top:0;background:#0d1526">'+t+'</th>';};
        rows.sort(function(a,b){return (a.marka||'').localeCompare(b.marka||'')||(a.ebat||'').localeCompare(b.ebat||'');});
        out+='<div style="border:1px solid rgba(255,255,255,0.10);border-radius:11px;overflow:auto;max-height:560px"><table style="width:100%;border-collapse:collapse;font-size:12.5px"><thead><tr>'+th('Tedarikçi')+th('Marka')+th('Ebat')+th('Ürün')+th('Mevsim')+th('Alış Fiyatı',1)+'</tr></thead><tbody>'+rows.slice(0,3000).map(function(r){return '<tr><td style="'+bb+';color:#94a3b8">'+r.kaynak+'</td><td style="'+bb+';font-weight:600">'+r.marka+'</td><td style="'+bb+';font-family:monospace;color:#9ab;white-space:nowrap">'+(r.ebat||'—')+'</td><td style="'+bb+';color:#cbd5e1;max-width:380px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+_b2bEsc(r.urun_adi)+'">'+(r.urun_adi||'')+'</td><td style="'+bb+'">'+_b2bMevRoz(r.mevsim)+'</td><td style="'+bb+';text-align:right;font-weight:700;white-space:nowrap">'+_b2bTL(r.alis_fiyat)+'</td></tr>';}).join('')+'</tbody></table></div><div style="margin-top:8px;font-size:11.5px;color:#667">'+rows.length+' ürün'+(rows.length>3000?' (ilk 3000)':'')+'</div>';
        box.innerHTML=out;
      } else if(view==='satis'){
        var gl=_b2bB2Bgruplar(rows,matSUP);var pm=_b2bPiyaList();
        gl.forEach(function(G){
          var lst=pm[G.key];if(!lst||!lst.length){G.pn=0;return;}
          var comp=lst.filter(function(p){return _b2bSigComp(G.dsig,p.sig);});
          if(G.mn){comp=comp.filter(function(p){return p.f<=G.mn*2.8;});}   // 4'lü set / aykırı ilan yedek temizliği
          G.dm=(G.dconf&&comp.length>0);                 // desenle doğrulanmış B2C eşi
          if(!comp.length){G.pn=0;return;}
          var a=comp.map(function(p){return p.f;}).sort(function(x,y){return x-y;});
          if(a.length>=2){var ch=a[0];a=a.filter(function(f){return f<=ch*2.0;});}   // aynı lastik retail yayılımı <2× → yüksek placeholder'ı at
          if(!a.length){G.pn=0;return;}
          G.pu=a[0];G.pmed=a[Math.floor(a.length/2)];G.py=a[a.length-1];G.pn=a.length;
          G.marj=(G.mn!=null)?(G.pmed-G.mn):null;G.marjp=(G.mn)?Math.round((G.pmed-G.mn)/G.mn*100):null;
        });
        var eslesen=gl.filter(function(G){return G.pn>0&&G.mn!=null;});
        var srt=window._b2bSatSort||'marj_desc';
        eslesen.sort(function(a,b){var av=a.marjp==null?-1e9:a.marjp,bv=b.marjp==null?-1e9:b.marjp;return srt==='marj_asc'?av-bv:bv-av;});
        var marjOk=srt==='marj_desc'?' ▼':' ▲';
        var out='<div style="background:rgba(34,197,94,0.08);border:1px solid rgba(34,197,94,0.28);border-radius:9px;padding:10px 13px;font-size:12px;color:#bbf7d0;margin-bottom:12px"><b>Kaça alıp kaça satıyoruz?</b> Sol = B2B <b>alış</b>, sağ = B2C <b>piyasa satış</b> (taranan ucuz/medyan/yüksek). <b>Marj</b> = medyan satış − en ucuz alış. Eşleşme <b>desen imzasıyla</b> (aynı ebat+model); "4\'lü takım/set" ilanları ve aynı lastiğin en ucuzunun 2 katını aşan placeholder fiyatlar elenir. Medyan yanındaki <b style="color:#eab308">·1</b> = tek B2C ilanı (marj soluk, düşük güven). <b>'+eslesen.length+'</b> lastik eşleşti. Marj % başlığına tıkla → sırala.</div>';
        if(!eslesen.length){out+='<div style="color:#667;padding:20px">Desenle doğrulanmış B2B↔B2C kesişimi yok (B2C çoğu binek-yaz akakçe). B2C taraması genişledikçe dolar.</div>';box.innerHTML=out;return;}
        out+='<div style="overflow:auto;max-height:600px;border:1px solid rgba(255,255,255,0.10);border-radius:11px"><table style="width:100%;border-collapse:collapse;font-size:12px"><thead><tr>'+th2('Marka')+th2('Ebat')+th2('Ürün')+th2('Mev')+matSUP.map(function(s){return th2(s.ad+' alış',1);}).join('')+th2('En Ucuz Alış',1)+th2('Piyasa Ucuz',1)+th2('Piyasa Medyan',1)+th2('Piyasa Yüksek',1)+th2('Marj ₺',1)+th2('Marj %'+marjOk,1,1,'b2bSatSort')+'</tr></thead><tbody>'+eslesen.slice(0,3000).map(function(G){var cells=matSUP.map(function(s){return G.fy[s.k]!=null?'<td title="'+_b2bEsc(G.ad[s.k])+'" style="text-align:right;'+bb2+';white-space:nowrap;color:'+(G.fy[s.k]===G.mn?'#86efac':'#cbd5e1')+'">'+_b2bTL(G.fy[s.k])+'</td>':'<td style="text-align:right;'+bb2+';color:#556">—</td>';}).join('');var mc=G.marj>0?'#4ade80':G.marj<0?'#f87171':'#94a3b8';var tek=(G.pn<=1);var mc2=tek?'#8a8f98':mc;return '<tr'+(tek?' title="Tek B2C ilanı — düşük güven"':'')+'><td style="'+bb2+';font-weight:600;white-space:nowrap">'+(G.marka||'')+'</td><td style="'+bb2+';font-family:monospace;color:#9ab;white-space:nowrap">'+(G.ebat||'—')+'</td><td style="'+bb2+';color:#cbd5e1;max-width:240px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+_b2bEsc(G.urun_adi)+'">'+(G.urun_adi||'')+'</td><td style="'+bb2+'">'+_b2bMevRoz(G.mevsim)+'</td>'+cells+'<td style="text-align:right;'+bb2+';font-weight:700;color:#86efac;white-space:nowrap">'+_b2bTL(G.mn)+'</td><td style="text-align:right;'+bb2+';color:#93c5fd;white-space:nowrap">'+_b2bTL(G.pu)+'</td><td style="text-align:right;'+bb2+';font-weight:700;color:#e2e8f0;white-space:nowrap">'+_b2bTL(G.pmed)+(G.pn>1?' <span style="color:#667;font-size:10px">·'+G.pn+'</span>':' <span style="color:#eab308;font-size:10px">·1</span>')+'</td><td style="text-align:right;'+bb2+';color:#94a3b8;white-space:nowrap">'+_b2bTL(G.py)+'</td><td style="text-align:right;'+bb2+';font-weight:700;color:'+mc2+';white-space:nowrap">'+_b2bTL(G.marj)+'</td><td style="text-align:right;'+bb2+';font-weight:800;color:'+mc2+';white-space:nowrap">'+(G.marjp==null?'—':'%'+G.marjp)+'</td></tr>';}).join('')+'</tbody></table></div><div style="margin-top:8px;font-size:11.5px;color:#667">'+eslesen.length+' eşleşen lastik · Marj = medyan piyasa − en ucuz alış · ürün adına gel = tam ad</div>';
        box.innerHTML=out;
      } else {
        var gl2=_b2bB2Bgruplar(rows,matSUP);
        var srt=window._b2bMatSort||'overlap';
        gl2.sort(function(a,b){if(srt==='fark_desc')return (b.fark==null?-1:b.fark)-(a.fark==null?-1:a.fark)||b.nsup-a.nsup;if(srt==='fark_asc')return (a.fark==null?9e9:a.fark)-(b.fark==null?9e9:b.fark)||b.nsup-a.nsup;return b.nsup-a.nsup||((b.fark||0)-(a.fark||0))||(a.marka||'').localeCompare(b.marka||'');});
        var cakisan=gl2.filter(function(G){return G.nsup>1;}).length;var supq=gl2.filter(function(G){return G.suspect;}).length;
        var farkOk=srt==='fark_desc'?' ▼':srt==='fark_asc'?' ▲':' ⇅';
        var out2='<div style="background:rgba(49,130,206,0.10);border:1px solid rgba(49,130,206,0.3);border-radius:9px;padding:10px 13px;font-size:12px;color:#bcdcff;margin-bottom:12px"><b>'+cakisan+'</b> lastik birden çok tedarikçide (aynı ebat+yük/hız+<b>desen</b>). Eşleştirme desen imzasıyla: "PremiumContact 7" ≠ "EcoContact 6" artık karışmaz. En ucuz <b style="color:#86efac">yeşil</b>; <b>Fark %</b> tıkla→sırala.'+(supq?' <b style="color:#fbbf24">⚠ '+supq+'</b> deseni belirsiz.':'')+'</div>';
        out2+='<div style="border:1px solid rgba(255,255,255,0.10);border-radius:11px;overflow:auto;max-height:600px"><table style="width:100%;border-collapse:collapse;font-size:12.5px"><thead><tr>'+th2('Marka')+th2('Ebat')+th2('Ürün')+th2('Mevsim')+matSUP.map(function(s){return th2(s.ad,1);}).join('')+th2('En Ucuz',1)+th2('Fark %'+farkOk,1,1,'b2bMatSort')+'</tr></thead><tbody>'+gl2.slice(0,3000).map(function(G){var cells=matSUP.map(function(s){return G.fy[s.k]!=null?'<td title="'+_b2bEsc(G.ad[s.k])+'" style="text-align:right;'+bb2+';font-weight:700;white-space:nowrap;color:'+(G.fy[s.k]===G.mn&&G.nsup>1?'#86efac':'#e2e8f0')+'">'+_b2bTL(G.fy[s.k])+'</td>':'<td style="text-align:right;'+bb2+';color:#556">—</td>';}).join('');var fark=G.fark!=null?('<b style="color:'+(G.suspect?'#fbbf24':G.fark>0?'#cbd5e1':'#86efac')+'">%'+G.fark+(G.suspect?' ⚠':'')+'</b>'):'<span style="color:#667">tek</span>';var hi=G.nsup>1?(G.suspect?'background:rgba(245,158,11,0.05);':'background:rgba(34,197,94,0.05);'):'';return '<tr style="'+hi+'"><td style="'+bb2+';font-weight:600;white-space:nowrap">'+(G.marka||'')+'</td><td style="'+bb2+';font-family:monospace;color:#9ab;white-space:nowrap">'+(G.ebat||'—')+'</td><td style="'+bb2+';color:#cbd5e1;max-width:340px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="'+_b2bEsc(G.urun_adi)+'">'+(G.urun_adi||'')+'</td><td style="'+bb2+'">'+_b2bMevRoz(G.mevsim)+'</td>'+cells+'<td style="text-align:right;'+bb2+';color:#86efac;white-space:nowrap">'+(G.nsup>1?(G.eu?G.eu.ad:'—'):'—')+'</td><td style="text-align:right;'+bb2+';white-space:nowrap">'+fark+'</td></tr>';}).join('')+'</tbody></table></div><div style="margin-top:8px;font-size:11.5px;color:#667">'+gl2.length+' lastik ('+cakisan+' ortak · '+supq+' deseni belirsiz) · ürün adına gel = tam ad</div>';
        box.innerHTML=out2;
      }
    };
    window.rfYukleB2B=async function(){
      var el=document.getElementById('rf-b2b-govde');if(!el)return;
      if(!window._b2bData){el.innerHTML='<div style="color:#778;padding:20px">B2B yükleniyor…</div>';try{window._b2bData=await rfApi('/api/b2b/ozet');}catch(e){el.innerHTML='<div style="color:#e53e3e;padding:20px">B2B yüklenemedi: '+(e&&e.message||e)+'</div>';return;}}
      window.b2bRender();
    };
