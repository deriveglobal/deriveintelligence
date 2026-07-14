#!/usr/bin/env bash
# DUZELT3 — ekranin KENDI KENDIYLE CELISKISINI bitir.
#
# ⚠ EKRAN SU AN CELISIYOR:
#   Ustte : "MUTAFLAR net 1,0M, tam limitte — yonetilen mahsuplasma"
#   Altta : "MUTAFLAR sevkiyati kredi limitini 138 KAT ASIYOR"  (puan 66,9, BIRINCI)
#   Ayni sayfada iki zit cumle. Bu, bir sayinin yanlis olmasindan BETER:
#   sistem KENDI DUZELTMESINE INANMIYOR.
#   Sebep: bi_sinyal dun gece BRUT alacakla hesaplandi; net blogu ekledim ama
#   sinyalleri YENIDEN URETMEDIM.
#
# ⚠ MARJ EKRANDAN KALKIYOR:
#   %8,3 arkasinda TEK kaynak var (ERP hareket maliyeti) ve o kaynak alis
#   faturasiyla CELISIYOR: markadan markaya -%40 (Sailun) ile +%48 (Dayton).
#   Bir sayiyi IKI BAGIMSIZ yoldan dogrulayamiyorsam, EKRANDA DURMAMALI.
#   Yerine: "dogrulanmadi" + neyin eksik oldugu.
set -uo pipefail
cd /opt/krb-assessment
PSQL="docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform"
TEN="f8a5d20f-ecf8-4ce2-a492-69268fbb03fa"

echo "############ 1) SINYALLERI NET POZISYONLA YENIDEN URET ############"
$PSQL -v ON_ERROR_STOP=1 <<SQL
BEGIN;
SET LOCAL app.current_tenant_id = '$TEN';

\echo '--- ONCE: brut alacakla uretilmis kredi sinyalleri ---'
SELECT baslik, round(tutar_tl/1e6,1) AS M FROM bi_sinyal
 WHERE tenant_id='$TEN'::uuid AND tur='kredi_asimi' AND durum='acik';

-- ⚠ ESKI KREDI SINYALLERI SILINIYOR — brut alacaga dayaniyorlardi.
DELETE FROM bi_sinyal
 WHERE tenant_id='$TEN'::uuid AND tur='kredi_asimi';

-- ✅ YENI: NET POZISYONA gore. Karsilikli alim yapan musteride brut YANILTICI.
INSERT INTO bi_sinyal (tenant_id, tur, anahtar, baslik, ozet, tutar_tl, son_tarih, oda, eylem_var, detay, durum)
SELECT '$TEN'::uuid, 'kredi_asimi',
       'net_limit:' || b.musteri_kodu,
       upper(split_part(b.tedarikci_adi, ' ', 1)) || ' net riski limitin ' ||
         round(b.net_pozisyon / NULLIF(r.kredi_limiti,0), 1) || ' katı',
       'net ' || round(b.net_pozisyon/1e6,1) || 'M · limit ' || round(r.kredi_limiti/1e6,1) ||
         'M · brüt alacak ' || round(b.musteri_bakiye/1e6,1) || 'M' ||
         CASE WHEN b.tedarikci_bakiye < -1e5
              THEN ' · KRB borcu ' || round(b.tedarikci_bakiye/1e6,1) || 'M' ELSE '' END,
       b.net_pozisyon, NULL, 'nakit', true,
       jsonb_build_object('musteri', b.tedarikci_adi, 'net', b.net_pozisyon,
                          'brut', b.musteri_bakiye, 'borc', b.tedarikci_bakiye,
                          'limit', r.kredi_limiti),
       'acik'
  FROM bi_cari_bakiye b
  JOIN bi_musteri_risk r ON r.tenant_id=b.tenant_id AND r.muhatap_kodu=b.musteri_kodu
 WHERE b.tenant_id='$TEN'::uuid
   AND r.kredi_limiti > 0
   AND b.net_pozisyon > r.kredi_limiti * 1.5    -- ⚠ NET, brut degil
   AND b.net_pozisyon > 2e6;

\echo ''
\echo '--- SONRA: net pozisyonla uretilmis ---'
SELECT baslik, ozet, round(tutar_tl/1e6,1) AS net_M FROM bi_sinyal
 WHERE tenant_id='$TEN'::uuid AND tur='kredi_asimi' AND durum='acik'
 ORDER BY tutar_tl DESC;

\echo ''
\echo '=== KAPI: MUTAFLAR sinyali KALMAMALI (net 1,0M = limitte) ==='
SELECT count(*) AS mutaflar FROM bi_sinyal
 WHERE tenant_id='$TEN'::uuid AND durum='acik' AND baslik ILIKE '%MUTAF%' \gset
SELECT CASE WHEN :mutaflar > 0 THEN (SELECT 1/0) ELSE 1 END AS kapi;
COMMIT;
SQL
if [ $? -ne 0 ]; then echo "❌ KAPI DUSTU"; exit 1; fi
echo "  ✅ sinyaller net pozisyonla yeniden uretildi"

echo
echo "############ 2) MARJ EKRANDAN KALK + ITIRAZ ARAYUZU ############"
cp shells/bi.js shells/bi.js.bak_d3
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "DUZELT3" in s: sys.exit("ZATEN YAMALI")

# ── A) MARJ KUTUSU -> "DOGRULANMADI" ──────────────────────────────────────
eski = """    const mj = d.marj || {};
    if (mj.ciro) {"""
assert eski in s, "marj anchor yok"
yeni = """    /* DUZELT3 — ⚠ MARJ EKRANDAN KALKTI.
       %8,3'un arkasinda TEK kaynak var (ERP hareket maliyeti) ve o kaynak
       ALIS FATURASIYLA CELISIYOR: markadan markaya -%40 (Sailun) / +%48 (Dayton).
       Bir sayiyi IKI BAGIMSIZ yoldan dogrulayamiyorsam, EKRANDA DURMAMALI. */
    const mj = d.marj || {};
    if (mj.ciro) {
      h += '<div class="kart kart-dikkat" style="margin-bottom:24px">';
      h += '<div style="font-size:15px;margin-bottom:8px">Brüt marjı henüz gösteremiyorum</div>';
      h += '<div style="font-size:13px;color:var(--tx-1);line-height:1.7;margin-bottom:12px">'
         + 'ERP’nin kaydettiği maliyet, alış faturasıyla <span class="d-sari">çelişiyor</span>. '
         + 'Sapma markadan markaya değişiyor: Sailun −%40, Dayton +%48, Continental %1.<br>'
         + 'Tek kaynağa dayanan bir marj rakamı yanlış olur — ve bir bayiliği bıraktırabilir.</div>';
      h += '<div class="satir"><span>ciro (lastik ticareti)</span><span class="n">' + _M(mj.ciro) + '</span></div>';
      h += '<div class="satir"><span>prim hakedişi</span><span class="n d-yesil">' + _M(mj.prim) + '</span></div>';
      h += '<div style="font-size:12px;color:var(--tx-2);margin-top:12px;line-height:1.6">'
         + 'Doğrulamak için üçüncü bir yol gerekiyor: <span class="d-sari">stok denkliği</span> — '
         + 'açılış stoğu + alışlar − SMM = kapanış stoğu. Kapanış biliniyor (268,5M).</div>';
      h += '<div style="margin-top:12px"><button class="dg sor" data-sor="'
         + esc('Stok denkliğiyle SMM’yi doğrula: açılış stoğu + alışlar − SMM = kapanış stoğu (268,5M). ERP maliyeti mi doğru, alış faturası mı?')
         + '" style="min-height:38px;font-size:13px">Doğrulamayı başlat</button></div>';
      h += '</div>';
    }
    if (false) {"""
s = s.replace(eski, yeni, 1)
print("  ✅ marj -> 'dogrulanmadi'")

# ── B) ITIRAZ: sayilara anahtar ───────────────────────────────────────────
for a, k in [
  ("esc('Net işletme sermayesi 104M. Brisa 319M borcu Kasım-Şubat ödenecek. Bu nakdi nereden bulacağız?')", "net_sermaye"),
  ("esc('Stok 131 günden 90 güne inerse ne kadar sermaye serbest kalır? Hangi ürünler?')", "stok_gun"),
  ("esc('Gerçek DSO 116 gün. Neden tahsilat tablosu 26,9 gösteriyor? Gecikmiş alacağı müşteri bazında sırala.')", "dso_gun"),
]:
    old = '<div class="kart dn" data-sor="\' + ' + a + ' + \'">'
    if old in s:
        s = s.replace(old, '<div class="kart dn" data-anahtar="' + k + '" data-sor="\' + ' + a + ' + \'">', 1)
        print(f"     anahtar: {k}")

PANEL = r'''  // ── DUZELT3 / ITIRAZ_UI ──────────────────────────────────────────────────
  // ⚠ Sayiya tiklamak KOKENI acar — beyne GITMEZ. Beyne gitmek hicbir sey ifade etmiyordu.
  let _itirazlar = {};
  async function _itirazlariYukle() {
    try {
      const r = await fetch('/api/bi/itiraz/acik', { credentials:'same-origin' });
      const d = await r.json();
      (d.itirazlar||[]).forEach(function(x){ _itirazlar[x.anahtar] = x.adet; });
    } catch(e) {}
  }
  async function _kokenAc(anahtar) {
    let d;
    try {
      const r = await fetch('/api/bi/koken?anahtar=' + encodeURIComponent(anahtar), { credentials:'same-origin' });
      d = await r.json();
    } catch(e) { return; }
    const k = d.koken;
    const eski = document.getElementById('koken-panel');
    if (eski) eski.remove();
    const el = document.createElement('div');
    el.id = 'koken-panel';
    el.style.cssText = 'position:fixed;inset:0;z-index:9999;background:rgba(0,0,0,.6);display:flex;align-items:center;justify-content:center;padding:20px';
    let h = '<div class="kart" style="max-width:560px;width:100%;max-height:82vh;overflow-y:auto;background:var(--zemin-1);border-color:var(--cizgi-g)" onclick="event.stopPropagation()">';
    if (!k) {
      h += '<div style="font-size:15px;margin-bottom:8px" class="d-sari">Bu sayının kökeni kayıtlı değil</div>'
         + '<div style="font-size:13px;color:var(--tx-1);line-height:1.6">Kaynağını söylemeyen bir sayı, uydurulmuş bir sayıdır.</div>';
    } else {
      const gR = k.guven === 'yuksek' ? 'd-yesil' : (k.guven === 'dusuk' || k.guven === 'yok' ? 'd-kirmizi' : 'd-sari');
      h += '<div style="display:flex;justify-content:space-between;align-items:baseline;margin-bottom:14px">'
         + '<div style="font-size:16px">' + esc(k.baslik) + '</div>'
         + '<div class="n ' + gR + '" style="font-size:12px">güven: ' + esc(k.guven) + '</div></div>';
      h += '<div class="etiket" style="margin-bottom:6px">KAYNAK</div><div style="font-family:var(--mono);font-size:12px;color:var(--tx-1);margin-bottom:14px;line-height:1.6">' + esc(k.kaynak) + '</div>';
      if (k.formul)   h += '<div class="etiket" style="margin-bottom:6px">FORMÜL</div><div style="font-family:var(--mono);font-size:12px;color:var(--tx-1);margin-bottom:14px">' + esc(k.formul) + '</div>';
      if (k.varsayim) h += '<div class="etiket" style="margin-bottom:6px">VARSAYIM</div><div style="font-size:13px;color:var(--tx-1);margin-bottom:14px;line-height:1.6">' + esc(k.varsayim) + '</div>';
      // ⚠ EN ONEMLI ALAN: bu sayi NEYI ICERMIYOR. Bugun her hata bir SINIR bilinmedigi icin olustu.
      if (k.sinir) h += '<div class="etiket d-sari" style="margin-bottom:6px">SINIR — bu sayı neyi içermiyor</div>'
                      + '<div style="font-size:13px;color:var(--sari);margin-bottom:16px;line-height:1.7;padding-left:10px;border-left:2px solid var(--sari)">'
                      + esc(k.sinir).replace(/\n/g,'<br>') + '</div>';
    }
    if ((d.acik_itiraz||[]).length) {
      h += '<div class="etiket d-kirmizi" style="margin-bottom:6px">AÇIK İTİRAZ</div>';
      (d.acik_itiraz||[]).forEach(function(i){
        h += '<div style="font-size:13px;color:var(--tx-1);margin-bottom:8px;padding-left:10px;border-left:2px solid var(--kirmizi);line-height:1.6">'
           + esc(i.gerekce) + '<div style="font-size:11px;color:var(--tx-3);margin-top:2px">' + esc(i.kullanici||'') + '</div></div>';
      });
    }
    h += '<div style="border-top:0.5px solid var(--cizgi);padding-top:14px;margin-top:8px">'
       + '<div class="etiket" style="margin-bottom:8px">BU SAYI YANLIŞ MI?</div>'
       + '<textarea id="itiraz-metin" rows="3" placeholder="Neyi kaçırıyorum? Örnek: “Mutaflar’a bizim de borcumuz var.”" style="width:100%;box-sizing:border-box;background:var(--zemin-2);border:0.5px solid var(--cizgi-g);border-radius:8px;padding:10px;color:var(--tx-0);font-size:14px;font-family:var(--sans);resize:vertical;outline:none"></textarea>'
       + '<div style="display:flex;gap:8px;margin-top:10px">'
       + '<button class="dg" id="itiraz-gonder" style="min-height:38px;font-size:13px">İtiraz et</button>'
       + '<button class="dg dg-sessiz" id="koken-kapat" style="min-height:38px;font-size:13px">Kapat</button></div>'
       + '<div id="itiraz-sonuc" style="font-size:13px;color:var(--yesil);margin-top:10px"></div></div></div>';
    el.innerHTML = h;
    el.addEventListener('click', function(e){ if (e.target === el) el.remove(); });
    document.body.appendChild(el);
    document.getElementById('koken-kapat').onclick = function(){ el.remove(); };
    document.getElementById('itiraz-gonder').onclick = async function(){
      const t = document.getElementById('itiraz-metin').value.trim();
      if (!t) { document.getElementById('itiraz-metin').focus(); return; }
      try {
        const r = await fetch('/api/bi/itiraz', { method:'POST', credentials:'same-origin',
          headers:{'Content-Type':'application/json'},
          body: JSON.stringify({ anahtar: anahtar, gerekce: t }) });
        const j = await r.json();
        document.getElementById('itiraz-sonuc').textContent = j.mesaj || 'Not aldım.';
        _itirazlar[anahtar] = (_itirazlar[anahtar]||0) + 1;
        setTimeout(function(){ el.remove(); _itirazlariYukle().then(ciz_bugun); }, 1600);
      } catch(e) { document.getElementById('itiraz-sonuc').textContent = 'Gönderilemedi.'; }
    };
  }

'''
anc = "  // Asistan odasina gecip soruyu sor"
assert anc in s, "asistan anchor yok"
s = s.replace(anc, PANEL + anc, 1)

# ── C) .dn tiklamasi -> KOKEN (beyne DEGIL) ───────────────────────────────
eski2 = """    g.querySelectorAll('.dn, .sor').forEach(function(el){
      el.addEventListener('click', function(){
        const q = el.dataset.sor;
        if (q) _bugun_sor(q);
      });
    });"""
assert eski2 in s, "dn handler anchor yok"
yeni2 = """    // ⚠ DUZELT3 — sayiya tiklamak KOKENI acar. Beyne gitmek HICBIR SEY ifade etmiyordu.
    g.querySelectorAll('.dn').forEach(function(el){
      el.addEventListener('click', function(e){
        e.stopPropagation();
        if (el.dataset.anahtar) _kokenAc(el.dataset.anahtar);
        else if (el.dataset.sor) _bugun_sor(el.dataset.sor);
      });
    });
    g.querySelectorAll('.sor').forEach(function(el){
      el.addEventListener('click', function(){ if (el.dataset.sor) _bugun_sor(el.dataset.sor); });
    });
    // itiraz edilen sayiya ETIKET — gizlemek yalanin devami olur
    g.querySelectorAll('[data-anahtar]').forEach(function(el){
      if (_itirazlar[el.dataset.anahtar]) {
        const b = document.createElement('div');
        b.className = 'n d-kirmizi';
        b.style.cssText = 'font-size:11px;margin-top:4px';
        b.textContent = '⚠ itiraz edildi (' + _itirazlar[el.dataset.anahtar] + ')';
        el.appendChild(b);
      }
    });"""
s = s.replace(eski2, yeni2, 1)
s = s.replace("  ciz_bugun();", "  _itirazlariYukle().then(ciz_bugun);", 1)
s = s.replace("  // ── ANA_UI_V1 + MARJ_GERCEK_V1 + NET_UI_V1", "  // ── ANA_UI_V1 + MARJ_GERCEK_V1 + NET_UI_V1 + DUZELT3", 1)
p.write_text(s, encoding="utf-8")
print("  ✅ tiklama -> koken paneli · itiraz kutusu · itiraz etiketi")
PY

node --check shells/bi.js || { cp shells/bi.js.bak_d3 shells/bi.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"
docker cp shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:8080/

git add -A
git commit -q -m 'fix: DUZELT3 — ekranin KENDI KENDIYLE CELISKISI bitti. (1) Ustte "MUTAFLAR net 1,0M tam limitte", altta "MUTAFLAR limitin 138 KATI" yaziyordu — ayni sayfada iki zit cumle. Bir sayinin yanlis olmasindan BETER: sistem kendi duzeltmesine inanmiyordu. bi_sinyal dun gece BRUT alacakla hesaplanmisti; net blogunu ekleyip sinyalleri yeniden uretmeyi unutmusum. Kredi sinyalleri NET POZISYONLA yeniden uretildi; kapi MUTAFLAR sinyali kalmadigini dogruluyor. (2) MARJ EKRANDAN KALKTI: %8,3 un arkasinda TEK kaynak var (ERP hareket maliyeti) ve o kaynak alis faturasiyla CELISIYOR — markadan markaya -%40 (Sailun) / +%48 (Dayton). Bir sayiyi iki bagimsiz yoldan dogrulayamiyorsam ekranda durmamali; bir bayiligi biraktirabilir. Yerine "dogrulanmadi" + ucuncu yol (stok denkligi: acilis + alislar - SMM = kapanis 268,5M). (3) Sayiya tiklamak artik BEYNE degil KOKEN PANELINE gidiyor: kaynak, formul, varsayim, ve en onemlisi SINIR (bu sayi neyi ICERMIYOR) + itiraz kutusu.'
echo "  COMMITTED"
