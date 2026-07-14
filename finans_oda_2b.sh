#!/usr/bin/env bash
# FINANS_ODA_2B — yamayi KENDI KAPIM geri aldi ve KAPI YANLISTI.
#
# ⚠ NE OLDU:
#   node --check GECTI (✅ bi.js sozdizimi) -> kod SAGLAM.
#   Sonra benim yazdigim KABA parantez sayaci 7110 vs 7115 deyip her seyi geri aldi.
#   O sayac STRING ICINDEKI parantezleri de sayiyor: "(%40)", "(bakiye)", "(12 Tem)"...
#   Yani dosya YAMADAN ONCE DE dengesiz gorunuyordu.
#
# ⚠ GERCEK denetci: node --check. Ben onun ustune ISE YARAMAZ bir kapi koydum
#   ve KENDI CALISAN YAMAMI cope attirdim.
#   Ders: kapi, olcmesi gereken seyi olcmuyorsa, kapi degil ENGELDIR.
set -uo pipefail
cd /opt/krb-assessment

echo "############ 0) ⚠ IDDIAMI KANITLA — orijinal dosya da 'dengesiz' mi? ############"
python3 -c "
s = open('shells/bi.js', encoding='utf-8').read()
print('  YAMASIZ dosyada: ( =', s.count('('), '·  ) =', s.count(')'), '-> fark', s.count(')')-s.count('('))
print('  ⚠ Fark 0 DEGILSE, sayacim BASTAN BOZUKTU: string icindeki parantezleri sayiyor.')
"
node --check shells/bi.js && echo "  ✅ ve node --check YAMASIZ dosyada da geciyor — gercek denetci BU"

echo
echo "############ 1) YAMA — bu sefer DOGRU kapiyla ############"
cp shells/bi.js shells/bi.js.bak_finans2
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "FINANS_UI_V1" in s: sys.exit("ZATEN YAMALI")

A = '          <button class="vmo-tab" data-dept="veri" style="--c:#8A8A8F">Veri</button>'
assert A in s, "❌ veri sekmesi capasi yok"
s = s.replace(A, A + '\n          <button class="vmo-tab" data-dept="finans" style="--c:#8A8A8F">Finans</button>', 1)

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

    if (ilk) {
      const acil = ilk.kalan_gun < 60;
      h += '<div class="kart ' + (acil ? 'kart-karar' : 'kart-dikkat') + '" style="margin-bottom:22px">'
         + '<div class="etiket" style="margin-bottom:8px">EN YAKIN NAKİT ÇIKIŞI</div>'
         + '<div class="n n-buyuk ' + (acil ? 'd-kirmizi' : 'd-sari') + '">'
         + _M(ilk.tutar_tl) + ' ₺ · ' + ilk.kalan_gun + ' gün</div>'
         + '<div style="font-size:14px;color:var(--tx-1);margin-top:8px;line-height:1.6">'
         + esc(ilk.baslik) + '<br><span style="color:var(--tx-2);font-size:13px">' + esc(ilk.ozet || '') + '</span></div>'
         + '<div class="d-sari" style="font-size:13px;margin-top:10px;padding-left:10px;border-left:2px solid var(--sari);line-height:1.6">'
         + '⚠ Bu tarihte ne kadar tahsilat bekleniyor — <b>tanımlı değil</b>. Çıkış belli, giriş belli değil.</div>'
         + '<button class="dg dg-sessiz sor" data-sor="' + esc(ilk.baslik + ' — o tarihe kadar hangi müşterilerden ne kadar tahsilat bekleyebiliriz? Vadesi geçmiş alacağın ne kadarı bu tarihe kadar tahsil edilebilir?')
         + '" style="margin-top:12px;min-height:38px;font-size:13px">Bu nakdi nereden bulacağız?</button>'
         + '</div>';
    }

    h += '<div class="etiket" style="margin-bottom:10px">NET İŞLETME SERMAYESİ</div>';
    h += '<div class="kart" style="margin-bottom:22px">';
    h += '<div class="dn" data-anahtar="net_sermaye" style="margin-bottom:14px;cursor:pointer">'
       + '<div class="n n-buyuk">' + _M(S.net_sermaye) + ' ₺</div>'
       + '<div style="font-size:13px;color:var(--tx-2);margin-top:2px">yıllık sermaye yükü ' + _M(S.yillik_yuk) + ' ₺</div></div>';
    h += '<div style="display:grid;grid-template-columns:repeat(3,1fr);gap:14px">';
    h += '<div class="dn" data-anahtar="stok_gun" style="cursor:pointer"><div class="etiket">STOK</div>'
       + '<div class="n n-orta">' + _M(S.stok) + '</div></div>';
    h += '<div class="dn" data-anahtar="alacak_bakiye" style="cursor:pointer"><div class="etiket">ALACAK</div>'
       + '<div class="n n-orta">' + _M(S.alacak) + '</div>'
       + '<div class="d-kirmizi" style="font-size:12px;margin-top:2px">' + _M(S.gecikmis) + ' gecikmiş</div></div>';
    h += '<div class="dn" data-anahtar="tedarikci_borcu" style="cursor:pointer"><div class="etiket">TEDARİKÇİ BORCU</div>'
       + '<div class="n n-orta d-yesil">−' + _M(S.borc) + '</div>'
       + '<div style="font-size:12px;color:var(--tx-2);margin-top:2px">' + esc(String(S.en_buyuk_ad || '').slice(0,18)) + ' ' + _M(S.en_buyuk) + '</div></div>';
    h += '</div>';
    h += '<div style="font-size:12px;color:var(--tx-2);margin-top:12px;line-height:1.6">'
       + 'Tedarikçi borcu yeşil çünkü <b>senin sermayeni finanse ediyor</b>. Bu borç kapandıkça bağlı sermaye artar.</div>';
    h += '</div>';

    if (OD.length) {
      var _tp = 0;
      OD.forEach(function(x){ _tp += Number(x.tutar_tl || 0); });
      h += '<div class="etiket" style="margin-bottom:10px">ÖDEME TAKVİMİ — dört ayda ' + _M(_tp) + ' ₺</div>';
      h += '<div class="kart dn" data-anahtar="brisa_takvim" style="margin-bottom:22px;cursor:pointer">';
      OD.forEach(function(o){
        h += '<div class="satir"><div>' + esc(o.baslik) + '</div>'
           + '<div class="n">' + o.kalan_gun + ' gün</div></div>';
      });
      var _kat = Number(S.net_sermaye) > 0 ? (_tp / Number(S.net_sermaye)).toFixed(1) : '—';
      h += '<div style="font-size:12px;color:var(--tx-2);margin-top:10px;line-height:1.6">'
         + 'Net işletme sermayesi ' + _M(S.net_sermaye) + '. Dört aylık yükümlülük bunun <b>' + _kat + ' katı</b>.</div>';
      h += '</div>';
    }

    if (Number(LB.musteri) > 0) {
      var _pct = Number(LB.alacak) > 0 ? Math.round(100 * Number(LB.gecikmis) / Number(LB.alacak)) : 0;
      h += '<div class="etiket" style="margin-bottom:10px">KREDİ POLİTİKASI</div>';
      h += '<div class="kart kart-karar dn" data-anahtar="limitsiz_alacak" style="margin-bottom:22px;cursor:pointer">'
         + '<div class="n n-orta d-kirmizi">' + _M(LB.alacak) + ' ₺ · ' + LB.musteri + ' müşteri</div>'
         + '<div style="font-size:14px;color:var(--tx-1);margin-top:6px;line-height:1.6">'
         + 'Kredi limiti <b>hiç tanımlanmamış</b> müşterilerdeki alacak. '
         + _M(LB.gecikmis) + ' ₺ zaten gecikmiş — limitsiz verilen kredinin <b>%' + _pct + '</b>\\'i geri gelmemiş.</div>'
         + '<div class="d-sari" style="font-size:13px;margin-top:10px;padding-left:10px;border-left:2px solid var(--sari);line-height:1.6">'
         + '⚠ Bu bir <b>ihlal</b> değil, bir <b>boşluk</b>. "Limit aşıldı" müdahale ister; "limit hiç yok" <b>karar</b> ister.</div>'
         + '</div>';
    }

    if (RS.length) {
      h += '<div class="etiket" style="margin-bottom:6px">RİSKLİ MÜŞTERİLER — net pozisyona göre</div>';
      h += '<div style="font-size:12px;color:var(--tx-2);margin-bottom:10px;line-height:1.6">'
         + 'Brüt alacak yanıltıcıdır: bir müşteri aynı zamanda tedarikçi olabilir. '
         + '<b>MUTAFLAR bu listede yok</b> — brüt 47,6M ama bizim ona borcumuz 46,6M, net 1,0M, tam limitinde.</div>';
      h += '<div class="kart">';
      RS.slice(0, 10).forEach(function(r){
        var kat = r.limit_kati;
        var et  = (Number(r.kredi_limiti) <= 1)
                ? '<span class="d-sari">limit YOK</span>'
                : '<span class="' + (Number(kat) >= 10 ? 'd-kirmizi' : 'd-sari') + '">' + kat + '× limit</span>';
        var nb  = Number(r.bizim_borcumuz || 0);
        var alt = nb < -100000
                ? '<div style="font-size:11px;color:var(--tx-3)">brüt ' + _M(r.brut) + ' · bizim borcumuz ' + _M(Math.abs(nb)) + '</div>'
                : '';
        h += '<div class="satir"><div>' + esc(String(r.musteri_adi || '').slice(0,30)) + alt + '</div>'
           + '<div class="n">' + _M(r.net_pozisyon) + ' · ' + et + '</div></div>';
      });
      h += '</div>';
    }

    g.innerHTML = h;

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
    g.querySelectorAll('[data-anahtar]').forEach(function(el){
      if (_itirazlar[el.dataset.anahtar]) {
        var b = document.createElement('div');
        b.className = 'n d-kirmizi';
        b.style.cssText = 'font-size:11px;margin-top:4px';
        b.textContent = '⚠ itiraz edildi (' + _itirazlar[el.dataset.anahtar] + ')';
        el.appendChild(b);
      }
    });
  }

'''
s = s.replace(B, ODA + B, 1)

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
print("  ✅ sekme + oda + cizim + tiklama")
PY

# ⚠ TEK KAPI: node --check. Kaba sayac YOK.
node --check shells/bi.js || { cp shells/bi.js.bak_finans2 shells/bi.js; echo "❌ NODE FAIL — geri alindi"; exit 1; }
echo "  ✅ node --check"

docker build -q -t krb-assessment:secure . >/dev/null 2>&1 || { echo "❌ derleme"; exit 1; }
docker compose up -d --force-recreate krb-assessment >/dev/null 2>&1
sleep 40
curl -s -o /dev/null -w "  GET / -> HTTP %{http_code}\n" http://localhost:8080/
R=$(md5sum shells/bi.js | cut -c1-32); C=$(docker exec krb-assessment md5sum /app/shells/bi.js | cut -c1-32)
[ "$R" = "$C" ] && echo "  ✅ bi.js repo = konteyner" || echo "  ❌ SAPMA"
docker exec krb-assessment sh -c 'grep -c "FINANS_UI_V1" /app/shells/bi.js' | sed 's/^/  imajda FINANS_UI_V1: /'
docker logs --since 60s krb-assessment 2>&1 | grep -i "error\|throw" | head -3 || echo "  ✅ log temiz"

git add -A
git commit -q -m 'feat(bi): FINANS_UI_V1 — Finans odasi. Onceki denemede yamayi KENDI KAPIM geri aldi ve kapi YANLISTI: node --check GECMISTI (kod saglam), ama yazdigim kaba parantez sayaci string icindeki parantezleri de sayiyordu ("(%40)", "(12 Tem)") ve dosya yamadan ONCE DE dengesiz gorunuyordu. Calisan yamami ise yaramaz bir kapi cope attirdi. Ders: olcmesi gereken seyi olcmeyen kapi, kapi degil ENGELDIR. Tek denetci artik node --check. Oda: tepede gosterge degil TARIH (18 Kasimda 36,6M, 127 gun) ve sistemin kendi bosluk itirafi (o tarihte ne kadar tahsilat beklendigi TANIMSIZ — cikis belli, giris belli degil). Deger agaci stok 268,3 + alacak 209,3 - borc 403,4 = 74,2M; her bacak tiklanir, kokeni acilir, itiraz edilir. Tedarikci borcu YESIL: KRBnin sermayesini finanse ediyor. Kredi politikasi boslugu: limitsiz 533 musteride 41,9M, %62si gecikmis — ihlal degil KARAR. Riskli musteriler NET pozisyona gore, MUTAFLAR listede YOK ve ekran NEDEN olmadigini yaziyor.'
echo "  COMMITTED"
