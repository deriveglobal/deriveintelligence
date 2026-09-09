#!/usr/bin/env python3
# OMURGA 25 — Metrik tanım sistemi: tek sözlük + ⓘ işaretçisi + tıkla-aç kart.
# FINANSAL_METRIK_SOZLESMESI'ni ekrana taşır. bi.js UI-only.
import sys, subprocess
BIJS='/opt/krb-assessment/shells/bi.js'
def rd(p):
    with open(p,encoding='utf-8') as f: return f.read()
def wr(p,s):
    with open(p,'w',encoding='utf-8') as f: f.write(s)
b=rd(BIJS)

if '_METRIK_TANIM' in b:
    print('  ⏭ zaten yamalı'); sys.exit(0)

FUNCS = r'''  var _METRIK_TANIM = {
    dso:{ ad:'DSO — Tahsilat Süresi', tanim:'Alacağın ortalama kaç günde tahsile döndüğü. Düşük = para hızlı geliyor.', formul:'alacak ÷ günlük kredili satış', kaynak:'bi_musteri_risk + satış faturaları', guven:'snapshot (bugün) · geçmiş yaklaşık', uyari:'Markaya/segmente bölünemez (allocation yasak).' },
    stok_deger:{ ad:'Stok Değeri', tanim:'Eldeki stoğun maliyet değeri — satış fiyatı değil, alış maliyeti.', formul:'Σ adet × birim ağırlıklı alış maliyeti', kaynak:'bi_stok_anlik × bi_stok_hareket', guven:'snapshot · geçmiş yaklaşık (~%0,2)', uyari:'Pozisyon metriği — bugün itibarıyla.' },
    alacak:{ ad:'Alacak', tanim:'Müşterilerden tahsil edilecek toplam bakiye (çek/senet hariç).', formul:'Σ hesap_bakiyesi (müşteri)', kaynak:'bi_musteri_risk', guven:'snapshot · geçmiş yaklaşık', uyari:'toplam_risk DEĞİL — çek/senet + bekleyen sipariş hariç.' },
    ciro:{ ad:'Ciro — Lastik Satış Geliri', tanim:'Lastik satışından gelen gelir (KDV hariç satır tutarı).', formul:'Σ satır_tutar · ebat dolu = lastik', kaynak:'bi_satis_faturalari', guven:'kesin', uyari:'Yalnız lastik; servis/diğer kalemler hariç.' },
    adet:{ ad:'Adet — Satış Hacmi', tanim:'Satılan lastik adedi. Fiyattan bağımsız hacim göstergesi.', formul:'Σ miktar', kaynak:'bi_satis_faturalari', guven:'kesin', uyari:'—' },
    marj:{ ad:'Marj — Brüt Kâr (TL)', tanim:'Satış geliri eksi satılan malın alış maliyeti. TL cinsinden, yüzde DEĞİL.', formul:'Σ (satır_tutar − miktar × birim maliyet)', kaynak:'satış × bi_stok_hareket ağırlıklı maliyet', guven:'kesin (kapsam etiketli)', uyari:'BRÜT — iskonto/prim/gider düşülmemiş · güncel maliyet bazı · #38 prim-marjından farklı.' },
    net:{ ad:'Net İşletme Sermayesi', tanim:'İşe bağlı net para: stok + alacak − tedarikçi borcu.', formul:'stok + alacak − borç', kaynak:'türev (üç metrik)', guven:'snapshot', uyari:'En zayıf bacağı kadar güçlü; borç geçmişi yok.' }
  };
  function _metrikInfo(key){
    if(!_METRIK_TANIM[key]) return '';
    return '<span class="mi-ikon" data-mi="'+key+'" style="display:inline-flex;align-items:center;justify-content:center;width:14px;height:14px;border-radius:50%;border:0.5px solid var(--cizgi-g);color:var(--tx-2);font-size:9px;cursor:pointer;margin-left:5px;vertical-align:middle" title="tanım">i</span>';
  }
  function _metrikInfoAc(ev, key){
    ev.stopPropagation();
    var old=document.getElementById('mi-pop'); if(old) old.remove();
    var t=_METRIK_TANIM[key]; if(!t) return;
    var p=document.createElement('div'); p.id='mi-pop';
    p.style.cssText='position:fixed;z-index:99999;max-width:300px;background:var(--zemin-1);border:0.5px solid var(--cizgi-g);border-radius:10px;padding:12px 14px;box-shadow:0 8px 30px rgba(0,0,0,.28);font-size:12px;line-height:1.6';
    p.innerHTML='<div style="font-weight:600;font-size:13px;margin-bottom:6px">'+esc(t.ad)+'</div>'
      + '<div style="color:var(--tx-1);margin-bottom:8px">'+esc(t.tanim)+'</div>'
      + '<div style="color:var(--tx-2)"><b>Formül:</b> '+esc(t.formul)+'</div>'
      + '<div style="color:var(--tx-2)"><b>Kaynak:</b> '+esc(t.kaynak)+'</div>'
      + '<div style="color:var(--tx-2)"><b>Güven:</b> '+esc(t.guven)+'</div>'
      + (t.uyari && t.uyari!=='—' ? '<div style="color:#E8B84B;margin-top:6px"><b>⚠</b> '+esc(t.uyari)+'</div>':'');
    document.body.appendChild(p);
    var x=Math.min(ev.clientX, window.innerWidth-320); var y=ev.clientY+14;
    if(y > window.innerHeight-190) y=ev.clientY-190;
    p.style.left=Math.max(8,x)+'px'; p.style.top=Math.max(8,y)+'px';
    setTimeout(function(){ document.addEventListener('click', function _c(){ var e=document.getElementById('mi-pop'); if(e)e.remove(); document.removeEventListener('click',_c); }); },0);
  }
  if(!window.__miInit){ window.__miInit=true;
    document.addEventListener('click', function(e){
      var el=e.target && e.target.closest ? e.target.closest('.mi-ikon') : null;
      if(el){ _metrikInfoAc(e, el.getAttribute('data-mi')); }
    });
  }

  function _spark(vals, w, hh, col, partial){'''
FUNC_ANCHOR = '  function _spark(vals, w, hh, col, partial){'

# METRİK TRENDİ satır etiketi → ⓘ
SERI_OLD = "        + '<div style=\"flex:1;min-width:0\"><div style=\"font-size:13px;margin-bottom:2px\">'+esc(c.ad)+'</div>'"
SERI_NEW = "        + '<div style=\"flex:1;min-width:0\"><div style=\"font-size:13px;margin-bottom:2px\">'+esc(c.ad)+_metrikInfo(c.key)+'</div>'"

# MARKA TRENDİ başlığı → ⓘ (ciro)
MARKA_OLD = "      var h = '<div class=\"etiket\" style=\"margin-bottom:10px\">MARKA TRENDİ — lastik cirosu · H1 2025 → H1 2026</div><div class=\"kart\">';"
MARKA_NEW = "      var h = '<div class=\"etiket\" style=\"margin-bottom:10px\">MARKA TRENDİ — lastik cirosu · H1 2025 → H1 2026'+_metrikInfo('ciro')+'</div><div class=\"kart\">';"

# drill metr dizisi → key ekle
METR_OLD = r'''    var metr=[
      {ad:'Ciro', renk:'#5AA9E6', get:function(p){return p.ciro;}, fmt:function(v){return _M(v);}},
      {ad:'Adet', renk:'#B98AE6', get:function(p){return p.adet;}, fmt:function(v){return Number(v).toLocaleString('tr-TR');}},
      {ad:'Marj', renk:'#7EC97E', get:function(p){return p.marj;}, fmt:function(v){return v==null?'—':_M(v);}}
    ];'''
METR_NEW = r'''    var metr=[
      {ad:'Ciro', key:'ciro', renk:'#5AA9E6', get:function(p){return p.ciro;}, fmt:function(v){return _M(v);}},
      {ad:'Adet', key:'adet', renk:'#B98AE6', get:function(p){return p.adet;}, fmt:function(v){return Number(v).toLocaleString('tr-TR');}},
      {ad:'Marj', key:'marj', renk:'#7EC97E', get:function(p){return p.marj;}, fmt:function(v){return v==null?'—':_M(v);}}
    ];'''
# drill etiket → ⓘ
DLBL_OLD = "        + '<div style=\"width:52px;font-size:12px;color:var(--tx-2)\">'+m.ad+'</div>'"
DLBL_NEW = "        + '<div style=\"width:52px;font-size:12px;color:var(--tx-2)\">'+m.ad+_metrikInfo(m.key)+'</div>'"

edits=[('FUNCS',FUNC_ANCHOR,FUNCS),('SERI',SERI_OLD,SERI_NEW),('MARKA',MARKA_OLD,MARKA_NEW),('METR',METR_OLD,METR_NEW),('DLBL',DLBL_OLD,DLBL_NEW)]
for name, old, _new in edits:
    c=b.count(old)
    if c!=1:
        print(f'  ✗ {name} anchor {c} kez (1 bekleniyor) — DURDU'); sys.exit(1)
b=b.replace(FUNC_ANCHOR,FUNCS,1).replace(SERI_OLD,SERI_NEW,1).replace(MARKA_OLD,MARKA_NEW,1).replace(METR_OLD,METR_NEW,1).replace(DLBL_OLD,DLBL_NEW,1)
wr(BIJS,b)
print('  ✅ 5 değişim uygulandı (tanım sözlüğü + ⓘ ×3 yer)')

r=subprocess.run(['node','--check',BIJS],capture_output=True,text=True)
print('  ✅ node --check OK' if r.returncode==0 else '  ✗ SYNTAX')
if r.returncode!=0: print(r.stderr); sys.exit(1)
b2=rd(BIJS)
print('  sözlük :', '_METRIK_TANIM = {' in b2)
print('  ⓘ seri :', '+esc(c.ad)+_metrikInfo(c.key)+' in b2)
print('  ⓘ marka:', "H1 2026'+_metrikInfo('ciro')+" in b2)
print('  ⓘ drill:', "+m.ad+_metrikInfo(m.key)+" in b2)
print('  init   :', 'window.__miInit' in b2)
print('\n  ✅ YAMA TAMAM — sırada docker build')
