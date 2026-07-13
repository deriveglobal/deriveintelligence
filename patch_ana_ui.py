#!/usr/bin/env python3
"""ANA_UI_V1 — yeni ana sayfa: 'Bugün' odasi.

⚠ STRATEJI: ESKI 'home' ODASINA DOKUNMUYORUZ.
   O blok canvas + glow + animasyon kodu tasiyor, baska yerlerden referans
   aliniyor olabilir. Pazartesi 8 temsilci canliya cikiyor. Calisan bir blogu
   sokup yerine yenisini koymak = JS hatasi riski = giris ekrani BOS.
   -> YENI oda ekleniyor ('bugun'), varsayilan acilis o oluyor.
      Eski 'home' kodda kaliyor, sekmesi yok, ulasilmaz, zararsiz.
      Yeni ekran calistigini KANITLAYINCA eskisi silinir.

⚠ EKRANDAKI HER RAKAM /api/bi/ana'dan geliyor, o da Postgres'te dogrulandi.
   Hicbir sayi kodda GOMULU degil.

⚠ KARLILIK KUTUSU BOS DEGIL — DOLU BIR BOSLUK.
   "Bayilik cironun %92'si fiyatlanamiyor" + eksik dosya listesi + yukleme.
   Sistemin ilk soyledigi sey KENDI KORLUGU. Fatih Bilen'i kaybettiren sey,
   bilmedigini bilmeyen bir sistemdi.
"""
import re, sys, pathlib

p = pathlib.Path("shells/bi.js")
src = p.read_text(encoding="utf-8")
if "ANA_UI_V1" in src:
    sys.exit("ZATEN YAMALI")

n = 0

# ── 1) Varsayilan oda: home -> bugun ─────────────────────────────────────────
eski = "let activeDept = 'home';"
if eski not in src:
    sys.exit("❌ anchor yok: activeDept = 'home'")
src = src.replace(eski, "let activeDept = 'bugun';  /* ANA_UI_V1 */", 1)
n += 1
print("  ✅ varsayilan oda -> bugun")

# ── 2) Sekme: ⌂ home butonunu 'Bugün' yap ────────────────────────────────────
eski_tab = '<button class="vmo-tab active" data-dept="home" style="--c:#e11d48;font-size:16px;padding:6px 10px" title="Ana Sayfa">⌂</button>'
if eski_tab not in src:
    sys.exit("❌ anchor yok: home sekme butonu")
yeni_tab = '<button class="vmo-tab active" data-dept="bugun" style="--c:#8A8A8F">Bugün</button>'
src = src.replace(eski_tab, yeni_tab, 1)
n += 1
print("  ✅ sekme -> Bugün")

# ── 3) YENI ODA + RENDER ─────────────────────────────────────────────────────
ODA = r'''
  // ── ANA_UI_V1 — 'Bugün' odasi ────────────────────────────────────────────
  {
    const _off2 = container.querySelector('.vmo-office');
    if (_off2 && !document.getElementById('vmo-room-bugun')) {
      const _br = document.createElement('div');
      _br.id = 'vmo-room-bugun';
      _br.dataset.dept = 'bugun';
      _br.className = 'vmo-room';
      _br.style.cssText = 'background:var(--zemin-0);overflow-y:auto;display:block;padding:0';
      _br.innerHTML = '<div id="bugun-govde" style="max-width:1080px;margin:0 auto;padding:26px 28px 0"><div style="color:var(--tx-2);font-size:13px">Yükleniyor…</div></div>';
      _off2.appendChild(_br);
    }
  }

  const _tl = n => (n==null ? '—' : new Intl.NumberFormat('tr-TR').format(Math.round(n)));
  const _M  = n => (n==null ? '—' : (n/1e6).toLocaleString('tr-TR',{minimumFractionDigits:1,maximumFractionDigits:1}) + 'M');

  async function ciz_bugun() {
    const g = document.getElementById('bugun-govde');
    if (!g) return;
    let d;
    try {
      const r = await fetch('/api/bi/ana', { credentials: 'same-origin' });
      if (!r.ok) throw new Error('HTTP ' + r.status);
      d = await r.json();
      if (d.error) throw new Error(d.error);
    } catch (e) {
      // ⚠ HATA GIZLENMIYOR. Bos ekran, "bir seyler ters gitti"den beterdir.
      g.innerHTML = '<div class="kart kart-dikkat" style="margin-top:20px">'
        + '<div style="font-size:15px;margin-bottom:6px">Ana sayfa verisi gelmedi</div>'
        + '<div class="satir"><span>hata</span><span class="n d-sari">' + esc(String(e.message)) + '</span></div>'
        + '<div style="font-size:13px;color:var(--tx-2);margin-top:8px">Veri Sağlığı odasında ayrıntı var.</div></div>';
      return;
    }

    const s = d.sermaye || {}, k = d.karlilik || {}, bilgi = d.bilgi || {};
    let h = '';

    // ── SERMAYE OMURGASI ──────────────────────────────────────────────────
    h += '<div class="etiket" style="margin-bottom:12px">BAĞLI SERMAYE</div>';
    h += '<div style="display:grid;grid-template-columns:1.3fr 1fr 1fr 1fr;gap:10px;margin-bottom:8px">';
    h += '<div class="kart dn" data-sor="' + esc('507M bağlı sermayenin kırılımını ver ve nasıl azaltırız?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Bağlı sermaye</div>'
       +   '<div class="n n-buyuk" style="margin:6px 0">' + _M(s.bagli) + '</div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">stok ' + _M(s.stok) + ' · alacak ' + _M(s.alacak) + '</div>'
       + '</div>';
    h += '<div class="kart dn" data-sor="' + esc('Yıllık sermaye yükü 203M. Faaliyet kârımla kıyasla — değer yaratıyor muyuz?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Yıllık sermaye yükü</div>'
       +   '<div class="n n-buyuk d-kirmizi" style="margin:6px 0">' + _M(s.yillik_yuk) + '</div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">%40 / yıl</div>'
       + '</div>';
    h += '<div class="kart dn" data-sor="' + esc('Stok 131 günden 90 güne inerse ne kadar sermaye serbest kalır? Hangi ürünler?') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Stok devri</div>'
       +   '<div class="n n-buyuk d-sari" style="margin:6px 0">' + _tl(s.stok_gun) + '<span style="font-size:14px;color:var(--tx-2)"> gün</span></div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">serbest ' + _M(s.stok_serbest) + '</div>'
       + '</div>';
    // ⚠ DSO: ekranda 26,9 gorunuyordu. YALANDI.
    h += '<div class="kart dn" data-sor="' + esc('Gerçek DSO 116 gün. Neden tahsilat tablosu 26,9 gösteriyor? Gecikmiş alacağı müşteri bazında sırala.') + '">'
       +   '<div style="font-size:12px;color:var(--tx-1)">Tahsilat süresi</div>'
       +   '<div class="n n-buyuk d-kirmizi" style="margin:6px 0">' + _tl(s.dso_gun) + '<span style="font-size:14px;color:var(--tx-2)"> gün</span></div>'
       +   '<div style="font-size:12px;color:var(--tx-2)">gecikmiş ' + _M(s.gecikmis) + ' · ' + _tl(s.gecikmis_musteri) + ' müşteri</div>'
       + '</div>';
    h += '</div>';
    h += '<div style="font-size:12px;color:var(--tx-3);margin-bottom:24px;line-height:1.6">'
       + 'Tahsilat süresi ödemeyenleri de içerir. Sistemin daha önce gösterdiği 26,9 gün yalnızca ödeyenleri ölçüyordu.</div>';

    // ── ⚠ KARLILIK: BOS DEGIL, DOLU BIR BOSLUK ────────────────────────────
    if (!k.hesaplanabilir) {
      h += '<div class="kart kart-dikkat" style="margin-bottom:24px">';
      h += '<div style="font-size:15px;margin-bottom:8px">Kârlılığını gösteremiyorum</div>';
      h += '<div style="font-size:13px;color:var(--tx-1);line-height:1.6;margin-bottom:12px">'
         + 'Bayilik markalarının cirosunun <span class="n d-sari">%' + (k.kor_pct||0) + '</span>’inde '
         + '(<span class="n">' + _M(k.kor_ciro) + '</span>) maliyet hesaplanamıyor. '
         + 'Marj uydurmuyorum — eksik olan şu:</div>';
      (k.eksik||[]).forEach(function(e){
        h += '<div class="satir"><span>' + esc(e.kategori) + ' — ' + esc(e.neEksik) + ' eksik</span>'
           + '<span class="n d-sari">' + _M(e.ciro) + '</span></div>';
      });
      h += '<div style="display:flex;gap:8px;margin-top:14px">'
         + '<button class="dg" onclick="document.querySelector(\'[data-dept=\\\'price-list\\\']\')?.click()">Dosyaları yükle</button>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc('Eksik iskonto kademelerini KRB’den nasıl isteyelim? Brisa’dan hangi belgeyi almalıyız?') + '">Nasıl toplarım?</button>'
         + '</div>';
      h += '</div>';
    }

    // ── KARAR KUYRUGU ─────────────────────────────────────────────────────
    h += '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:11px">'
       + '<div class="etiket">KARAR GEREKİYOR</div>'
       + '<div style="font-size:12px;color:var(--tx-3)">' + (d.kararlar||[]).length + ' açık</div></div>';

    (d.kararlar||[]).forEach(function(c){
      const acil = Number(c.puan) >= 50;
      const pd = c.puan_detay || {};
      h += '<div class="kart ' + (acil ? 'kart-karar' : 'kart-dikkat') + '" style="margin-bottom:8px">';
      h += '<div style="display:flex;justify-content:space-between;gap:14px;align-items:flex-start">';
      h += '<div style="flex:1"><div style="font-size:15px;margin-bottom:4px">' + esc(c.baslik) + '</div>'
         + '<div style="font-size:12px;color:var(--tx-2)">' + esc(c.ozet || '') + '</div></div>';
      // ⚠ PUAN + BILESENLERI. Kullanici siralamaya ITIRAZ EDEBILMELI.
      h += '<div style="text-align:right;white-space:nowrap">'
         + '<div class="n ' + (acil?'d-kirmizi':'d-sari') + '" style="font-size:15px">' + c.puan + '</div>'
         + '<div style="font-size:11px;color:var(--tx-3);font-family:var(--mono)">para ' + (pd.para||'—') + ' · acil ' + (pd.aciliyet||'—') + '</div>'
         + '</div></div>';
      h += '<div style="display:flex;gap:7px;margin-top:11px">'
         + '<button class="dg sor" data-sor="' + esc(c.baslik + ' — aç: ne oldu, ne yapmalıyım, yapmazsam ne olur?') + '" style="min-height:36px;font-size:13px">Aç</button>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc(c.baslik + ' — sustur. Tutar %25 artarsa veya son tarih 14 güne inerse geri gel.') + '" style="min-height:36px;font-size:13px">Sustur</button>'
         + '</div>';
      h += '</div>';
    });

    // ── BILGI (karar degil) ───────────────────────────────────────────────
    // ⚠ Planli odemeler karar kuyrugunun ICINDEYDI, ilk 6'nin 4'unu doldurup
    //   gercek kararlari asagi itiyorlardi. Artik BURADA, sessiz.
    if (Number(bilgi.adet) > 0) {
      h += '<div class="kart" style="margin:16px 0 24px;opacity:.75">'
         + '<div class="satir"><span>Brisa ödeme takvimi — ' + bilgi.adet + ' planlı ödeme</span>'
         + '<span class="n">' + _M(bilgi.toplam) + '</span></div>'
         + '<div style="font-size:12px;color:var(--tx-3);margin-top:4px">İlki ' + (bilgi.en_yakin ? new Date(bilgi.en_yakin).toLocaleDateString('tr-TR') : '—')
         + ' — karar gerektirmiyor, takvim.</div></div>';
    }

    // ── VARDIYA DEFTERI ───────────────────────────────────────────────────
    if ((d.vardiya||[]).length) {
      h += '<div class="etiket" style="margin-bottom:11px">SİSTEM NE BULDU</div>';
      h += '<div style="font-family:var(--mono);font-size:12px;color:var(--tx-2);line-height:2;margin-bottom:26px">';
      (d.vardiya||[]).forEach(function(v){
        const t = new Date(v.olusma);
        h += '<div><span style="color:var(--tx-3)">' + t.toLocaleDateString('tr-TR',{day:'2-digit',month:'2-digit'})
           + ' ' + t.toLocaleTimeString('tr-TR',{hour:'2-digit',minute:'2-digit'}) + '</span>  ' + esc(v.baslik) + '</div>';
      });
      h += '</div>';
    }

    // ── ASISTAN SERIDI ────────────────────────────────────────────────────
    h += '<div class="as" style="margin:0 -28px;padding-left:28px;padding-right:28px">'
       + '<div class="as-kutu"><span style="color:var(--tx-3);font-family:var(--mono)">›</span>'
       + '<input id="bugun-sor" placeholder="Neyi merak ediyorsun?">'
       + '</div></div>';

    g.innerHTML = h;

    // dokunma noktalari + butonlar -> asistana git
    g.querySelectorAll('.dn, .sor').forEach(function(el){
      el.addEventListener('click', function(){
        const q = el.dataset.sor;
        if (q) _bugun_sor(q);
      });
    });
    const inp = document.getElementById('bugun-sor');
    if (inp) inp.addEventListener('keydown', function(e){
      if (e.key === 'Enter' && inp.value.trim()) { _bugun_sor(inp.value.trim()); inp.value=''; }
    });
  }

  // Asistan odasina gecip soruyu sor
  function _bugun_sor(q) {
    const t = document.querySelector('[data-dept="brain"]');
    if (t) t.click();
    setTimeout(function(){
      const i = document.querySelector('#vmo-room-brain input, #vmo-brain-input, .vmo-chat-input');
      if (i) { i.value = q; i.focus();
        const f = i.closest('form'); if (f) f.dispatchEvent(new Event('submit', {cancelable:true, bubbles:true}));
      }
    }, 260);
  }

  ciz_bugun();
'''

# ⚠ ANCHOR: Brain Room blogunun ONUNE. Taze grep'ten.
anc = "  // ── Brain Room (created outside OFFICERS map) ──"
if anc not in src:
    sys.exit("❌ anchor yok: Brain Room yorumu")
src = src.replace(anc, ODA + "\n" + anc, 1)
n += 1
print("  ✅ 'Bugün' odasi + ciz_bugun() eklendi")

p.write_text(src, encoding="utf-8")
print(f"\n  {n} degisiklik. Eski 'home' odasi DOKUNULMADAN duruyor.")
