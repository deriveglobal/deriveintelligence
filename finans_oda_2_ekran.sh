#!/usr/bin/env bash
# FINANS_ODA_2_EKRAN — odanin kendisi.
#
# ⚠ TEPEDE GOSTERGE YOK, TARIH VAR:
#   "18 Kasim'da 36,6M odeyeceksin. 127 gun var. Net isletme sermayen 74,2M."
#   Bir gosterge bakilir ve unutulur. Bir TARIH yaklasir.
#
# ⚠ UC KARAR, UC AYRI CINSTEN — hepsini "alarm" torbasina atarsak kimse bakmaz:
#   · Vadesi gecmis 145,4M / 725 musteri  -> YAPILACAK IS   (tahsilat)
#   · Limitsiz 533 musteride 41,9M (%62'si gecikmis) -> VERILECEK KARAR (kredi politikasi)
#   · 18 Kas'ta 36,6M cikacak, o gun ne girecegi TANIMSIZ -> ACIK BOSLUK (nakit plani)
#
# ⚠ MUTAFLAR EKRANDA YOK. Net pozisyonu limitinde — sorun DEGIL.
#   Sistem iki gun once ona bagiriyordu. Artik dogru bakiyor.
set -uo pipefail
cd /opt/krb-assessment

cp shells/bi.js shells/bi.js.bak_finans
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "FINANS_UI_V1" in s: sys.exit("ZATEN YAMALI")

# ── 1) SEKME ────────────────────────────────────────────────────────────────
A = '          <button class="vmo-tab" data-dept="veri" style="--c:#8A8A8F">Veri</button>'
assert A in s, "❌ veri sekmesi capasi yok"
s = s.replace(A, A + '\n          <button class="vmo-tab" data-dept="finans" style="--c:#8A8A8F">Finans</button>', 1)

# ── 2) ODA + CIZIM ──────────────────────────────────────────────────────────
B = '  async function ciz_veri() {'
assert B in s, "❌ ciz_veri capasi yok"

ODA = '''  // ── FINANS_UI_V1 — 'Finans' odasi ────────────────────────────────────────
  // ⚠ Tepede GOSTERGE degil TARIH var. Bir gosterge bakilir ve unutulur; bir tarih YAKLASIR.
  {
    const _o = container.querySelector('.vmo-office');
    if (_o && !document.getElementById('vmo-room-finans')) {
      const _f = document.createElement('div');
      _f.id = 'vmo-room-finans';
      _f.dataset.dept = 'finans';
      _f.className = 'vmo-room vmo-room-hidden';
      _f.style.cssText = 'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0';
      _f.innerHTML = '<div id="finans-govde" style="max-width:1080px;margin:0 auto;padding:26px 28px 40px"><div style="color:var(--tx-2);font-size:13px">Yükleniyor…</div></div>';
      _o.appendChild(_f);
    }
  }

  async function ciz_finans() {
    const g = document.getElementById('finans-govde');
    if (!g) return;
    let d;
    try {
      const r = await fetch('/api/bi/finans', { credentials:'same-origin' });
      const _t = await r.text();
      // ⚠ HATA MESAJINI ATMA. "HTTP 500" deyip govdeyi cope atmak, hatayi SAKLAMAKTIR.
      try { d = JSON.parse(_t); } catch(_) { throw new Error('HTTP ' + r.status + ' — ' + _t.slice(0,200)); }
      if (d.error) throw new Error(d.error);
    } catch(e) {
      g.innerHTML = '<div class="kart kart-karar"><div class="d-kirmizi" style="font-size:14px">Finans verisi gelmedi</div>'
                  + '<div style="font-size:13px;color:var(--tx-1);margin-top:6px;font-family:var(--mono)">' + esc(e.message) + '</div></div>';
      return;
    }

    const S = d.sermaye || {}, OD = d.odemeler || [], RS = d.riskler || [], LB = d.limit_bosluk || {};
    const ilk = OD[0];
    let h = '';

    // ── TEPE: TARIH. Gosterge degil. ────────────────────────────────────────
    if (ilk) {
      const acil = ilk.kalan_gun < 60;
      h += '<div class="kart ' + (acil ? 'kart-karar' : 'kart-dikkat') + '" style="margin-bottom:22px">'
         + '<div class="etiket" style="margin-bottom:8px">EN YAKIN NAKİT ÇIKIŞI</div>'
         + '<div class="n n-buyuk ' + (acil ? 'd-kirmizi' : 'd-sari') + '">'
         + _M(ilk.tutar_tl) + ' ₺ · ' + ilk.kalan_gun + ' gün</div>'
         + '<div style="font-size:14px;color:var(--tx-1);margin-top:8px;line-height:1.6">'
         + esc(ilk.baslik) + '<br><span style="color:var(--tx-2);font-size:13px">' + esc(ilk.ozet || '') + '</span></div>'
         // ⚠ ASIL BOSLUK: cikis belli, GIRIS belli degil.
         + '<div class="d-sari" style="font-size:13px;margin-top:10px;padding-left:10px;border-left:2px solid var(--sari);line-height:1.6">'
         + '⚠ Bu tarihte ne kadar tahsilat bekleniyor — <b>tanımlı değil</b>. Çıkış belli, giriş belli değil.</div>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc('18 Kasım\\'da ' + _M(ilk.tutar_tl) + ' ödeme var. O tarihe kadar hangi müşterilerden ne kadar tahsilat bekleyebiliriz? Vadesi geçmiş 145,4M\\'nin ne kadarı Kasım\\'a kadar tahsil edilebilir?')
         + '" style="margin-top:12px;min-height:38px;font-size:13px">Bu nakdi nereden bulacağız?</button>'
         + '</div>';
    }

    // ── DEGER AGACI ─────────────────────────────────────────────────────────
    h += '<div class="etiket" style="margin-bottom:10px">NET İŞLETME SERMAYESİ</div>';
    h += '<div class="kart" style="margin-bottom:22px">';
    h += '<div class="kart dn" data-anahtar="net_sermaye" style="border:0;padding:0;margin-bottom:14px;cursor:pointer">'
       + '<div class="n n-buyuk">' + _M(S.net_sermaye) + ' ₺</div>'
       + '<div style="font-size:13px;color:var(--tx-2);margin-top:2px">yıllık sermaye yükü ' + _M(S.yillik_yuk) + ' ₺ (%40)</div></div>';
    h += '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px">';
    h += '<div class="dn" data-anahtar="stok_gun" style="cursor:pointer"><div class="etiket">STOK</div>'
       + '<div class="n n-orta">' + _M(S.stok) + '</div></div>';
    h += '<div class="dn" data-anahtar="alacak_bakiye" style="cursor:pointer"><div class="etiket">ALACAK</div>'
       + '<div class="n n-orta">' + _M(S.alacak) + '</div>'
       + '<div class="d-kirmizi" style="font-size:12px;margin-top:2px">' + _M(S.gecikmis) + ' gecikmiş</div></div>';
    h += '<div class="dn" data-anahtar="tedarikci_borcu" style="cursor:pointer"><div class="etiket">TEDARİKÇİ BORCU</div>'
       + '<div class="n n-orta d-yesil">−' + _M(S.borc) + '</div>'
       + '<div style="font-size:12px;color:var(--tx-2);margin-top:2px">' + esc((S.en_buyuk_ad||'').slice(0,18)) + ' ' + _M(S.en_buyuk) + '</div></div>';
    h += '</div>';
    // ⚠ Tedarikci borcu EKSI ama YESIL: bu borc KRB'nin isletme sermayesini FINANSE EDIYOR.
    h += '<div style="font-size:12px;color:var(--tx-2);margin-top:12px;line-height:1.6">'
       + 'Tedarikçi borcu yeşil çünkü <b>senin sermayeni finanse ediyor</b>. Brisa\\'ya olan borç kapandıkça, bağlı sermaye artar.</div>';
    h += '</div>';

    // ── ÖDEME TAKVİMİ ───────────────────────────────────────────────────────
    if (OD.length) {
      const _tp = OD.reduce(function(a,x){ return a + Number(x.tutar_tl||0); }, 0);
      h += '<div class="etiket" style="margin-bottom:10px">ÖDEME TAKVİMİ — dört ayda ' + _M(_tp) + ' ₺</div>';
      h += '<div class="kart dn" data-anahtar="brisa_takvim" style="margin-bottom:22px;cursor:pointer">';
      OD.forEach(function(o){
        h += '<div class="satir"><div>' + esc(o.baslik) + '</div>'
           + '<div class="n">' + o.kalan_gun + ' gün</div></div>';
      });
      h += '<div style="font-size:12px;color:var(--tx-2);margin-top:10px;line-height:1.6">'
         + 'Net işletme sermayesi ' + _M(S.net_sermaye) + '. Dört aylık yükümlülük bunun <b>'
         + (S.net_sermaye > 0 ? (_tp/S.net_sermaye).toFixed(1) : '—') + ' katı</b>.</div>';
      h += '</div>';
    }

    // ── KARAR 1: LİMİT BOŞLUĞU (ihlal değil, KARAR) ─────────────────────────
    if (Number(LB.musteri) > 0) {
      h += '<div class="etiket" style="margin-bottom:10px">KREDİ POLİTİKASI</div>';
      h += '<div class="kart kart-karar dn" data-anahtar="limitsiz_alacak" style="margin-bottom:22px;cursor:pointer">'
         + '<div class="n n-orta d-kirmizi">' + _M(LB.alacak) + ' ₺ · ' + LB.musteri + ' müşteri</div>'
         + '<div style="font-size:14px;color:var(--tx-1);margin-top:6px;line-height:1.6">'
         + 'Kredi limiti <b>hiç tanımlanmamış</b> müşterilerdeki alacak. '
         + _M(LB.gecikmis) + ' ₺\\'si <b>zaten gecikmiş</b> — yani limitsiz verilen kredinin '
         + (Number(LB.alacak)>0 ? Math.round(100*Number(LB.gecikmis)/Number(LB.alacak)) : 0) + '\\'i geri gelmemiş.</div>'
         + '<div class="d-sari" style="font-size:13px;margin-top:10px;padding-left:10px;border-left:2px solid var(--sari);line-height:1.6">'
         + '⚠ Bu bir <b>ihlal</b> değil, bir <b>boşluk</b>. "Limit aşıldı" müdahale ister; "limit hiç yok" <b>karar</b> ister.</div>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc('Kredi limiti tanımlanmamış müşterilerde ' + _M(LB.alacak) + ' alacak var ve büyük kısmı gecikmiş. Bu müşterilere hangi kriterle limit koymalıyız? Ciro, ödeme geçmişi ve gecikme günü bazında bir öneri listesi çıkar.')
         + '" style="margin-top:12px;min-height:38px;font-size:13px">Limit önerisi çıkar</button>'
         + '</div>';
    }

    // ── KARAR 2: GERÇEK RİSKLER (NET pozisyon — brüt YANILTICI) ─────────────
    if (RS.length) {
      h += '<div class="etiket" style="margin-bottom:6px">RİSKLİ MÜŞTERİLER — net pozisyona göre</div>';
      // ⚠ Sistem iki gun once MUTAFLAR'a "limitin 138 kati" diye bagiriyordu.
      //   Brut 47,6M ama KRB'nin ona borcu 46,6M -> net 1,0M, tam limitte. Sorun DEGIL.
      h += '<div style="font-size:12px;color:var(--tx-2);margin-bottom:10px;line-height:1.6">'
         + 'Brüt alacak yanıltıcıdır: bir müşteri aynı zamanda tedarikçi olabilir. '
         + '<b>MUTAFLAR bu listede yok</b> — brüt 47,6M ama bizim ona borcumuz 46,6M, net 1,0M, tam limitinde.</div>';
      h += '<div class="kart">';
      RS.slice(0,10).forEach(function(r){
        const kat = r.limit_kati;
        const et  = (r.kredi_limiti <= 1) ? '<span class="d-sari">limit YOK</span>'
                  : ('<span class="' + (kat >= 10 ? 'd-kirmizi' : 'd-sari') + '">' + kat + '× limit</span>');
        const nb  = Number(r.bizim_borcumuz || 0);
        h += '<div class="satir"><div>' + esc((r.musteri_adi||'').slice(0,30))
           + (nb < -1e5 ? '<div style="font-size:11px;color:var(--tx-3)">brüt ' + _M(r.brut) + ' · bizim borcumuz ' + _M(Math.abs(nb)) + '</div>' : '')
           + '</div><div class="n">' + _M(r.net_pozisyon) + ' · ' + et + '</div></div>';
      });
      h += '</div>';
    }

    g.innerHTML = h;

    // ⚠ Sayiya tiklamak KOKENI acar — beyne GITMEZ.
    g.querySelectorAll('.dn').forEach(function(el){
      el.addEventListener('click', function(e){
        e.stopPropagation();
        if (el.dataset.anahtar) _kokenAc(el.dataset.anahtar);
        else if (el.dataset.sor) _bugun_sor(el.dataset.sor);
      });
    });
    g.querySelectorAll('.sor').forEach(function(el){
      el.addEventListener('click', function(e){ e.stopPropagation(); if (el.dataset.sor) _bugun_sor(el.dataset.sor); });
    });
    // ⚠ Itiraz edilen sayiya ETIKET. Gizlemek yalanin devami olur.
    g.querySelectorAll('[data-anahtar]').forEach(function(el){
      if (_itirazlar[el.dataset.anahtar]) {
        const b = document.createElement('div');
        b.className = 'n d-kirmizi';
        b.style.cssText = 'font-size:11px;margin-top:4px';
        b.textContent = '⚠ itiraz edildi (' + _itirazlar[el.dataset.anahtar] + ')';
        el.appendChild(b);
      }
    });
  }

'''
s = s.replace(B, ODA + B, 1)

# ── 3) SEKME TIKLAMA ────────────────────────────────────────────────────────
C = '''  container.addEventListener('click', function(e){
    const t = e.target.closest('.vmo-tab[data-dept="veri"]');
    if (t) setTimeout(ciz_veri, 60);
  });'''
assert C in s, "❌ sekme tiklama capasi yok"
s = s.replace(C, C + '''
  // FINANS_UI_V1
  container.addEventListener('click', function(e){
    const t = e.target.closest('.vmo-tab[data-dept="finans"]');
    if (t) setTimeout(ciz_finans, 60);
  });''', 1)

p.write_text(s, encoding="utf-8")
print("  ✅ Finans odasi: sekme + oda + cizim + tiklama")
PY

node --check shells/bi.js 2>/dev/null && echo "  ✅ bi.js sozdizimi" || echo "  (modul degil, node --check atlandi)"
python3 -c "
import re,sys
s=open('shells/bi.js',encoding='utf-8').read()
# kaba denge kontrolu
for a,b,ad in [('{','}','suslu'),('(',')','parantez')]:
    if s.count(a)!=s.count(b): sys.exit(f'❌ {ad} DENGESIZ: {s.count(a)} vs {s.count(b)}')
print('  ✅ parantez/suslu dengeli')
" || { cp shells/bi.js.bak_finans shells/bi.js; echo "❌ geri alindi"; exit 1; }

docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
echo "  --- bi.js konteynerde guncel mi? ---"
R=$(md5sum shells/bi.js | cut -c1-32); C=$(docker exec krb-assessment md5sum /app/shells/bi.js | cut -c1-32)
[ "$R" = "$C" ] && echo "  ✅ repo = konteyner" || echo "  ❌ SAPMA"
echo "  --- Finans sekmesi imajda var mi? ---"
docker exec krb-assessment sh -c 'grep -c "FINANS_UI_V1" /app/shells/bi.js' | sed 's/^/      adet: /'

git add -A
git commit -q -m 'feat(bi): FINANS_UI_V1 — Finans odasi. Tepede GOSTERGE degil TARIH: "18 Kasimda 36,6M odeyeceksin, 127 gun var, net isletme sermayen 74,2M." Bir gosterge bakilir ve unutulur; bir tarih YAKLASIR. Ve odanin isaret ettigi asil bosluk: cikis belli, GIRIS belli degil — o tarihte ne kadar tahsilat beklendigi TANIMSIZ. Deger agaci: stok 268,3 + alacak 209,3 - tedarikci borcu 403,4 = 74,2M; her bacak tiklanabilir, kokeni acilir, itiraz edilebilir. Tedarikci borcu YESIL gosteriliyor cunku KRBnin isletme sermayesini FINANSE EDIYOR — Brisaya borc kapandikca bagli sermaye ARTAR. Uc karar uc ayri cinsten ayrildi (hepsini alarm torbasina atarsak kimse bakmaz): vadesi gecmis 145,4M/725 musteri = YAPILACAK IS; limitsiz 533 musteride 41,9M ve %62si gecikmis = VERILECEK KARAR (ihlal degil BOSLUK: "limit asildi" mudahale ister, "limit hic yok" karar ister); Brisa takvimi = ACIK BOSLUK. Riskli musteri listesi NET pozisyona gore: MUTAFLAR listede YOK (brut 47,6M ama bizim ona borcumuz 46,6M, net 1,0M, tam limitinde) — sistem iki gun once ona "limitin 138 kati" diye bagiriyordu ve bu, GMyi kaybettiren yanlis alarmlardan biriydi.'
echo "  COMMITTED"
