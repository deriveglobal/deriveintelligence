#!/usr/bin/env bash
# YUKLEME_UI_V1 — 'Veri' odasi: surukle-birak yukleme + kapi sonuclari.
#
# ⚠ EKRANDA GORUNECEK SEYLER (gizlenmeyecek):
#   • dosya tipi (basliktan tanindi, dosya adina GUVENILMEDI)
#   • kac satir · hangi tarih araligi
#   • YUKLEME MODU: zaman serisi mi (aralik degistirme), anlik goruntu mu (tam degistirme)
#   • kac satir SILINDI, kac satir EKLENDI  -> cakisma seffaf
#   • TARIH ONARIMI: kac satirda gun/ay takas edildi
#   • OLCEK: hangi kolon dosyadan okundu, hangisi KIMLIKTEN cozuldu, hangisi BILINMIYOR
#   • KAPILAR: her biri, degeri, esigi, gecti mi
#   • KAPI DUSERSE: "YUKLENMEDI, eski veri yerinde" + SEBEP
set -uo pipefail
cd /opt/krb-assessment

echo "############ 1) MOTOR ############"
pip3 install --quiet --break-system-packages openpyxl psycopg2-binary 2>/dev/null || \
  pip3 install --quiet openpyxl psycopg2-binary 2>/dev/null || true
python3 -c "import openpyxl, psycopg2; print('  ✅ openpyxl + psycopg2')" || { echo "❌ bagimlilik"; exit 1; }
mkdir -p /opt/krb-assessment/yukleme
python3 -c "import ast; ast.parse(open('/opt/krb-assessment/erp_ingest.py').read()); print('  ✅ erp_ingest.py sozdizimi')" \
  || { echo "❌ motor sozdizimi"; exit 1; }

echo
echo "############ 2) ON YUZ — Veri odasi ############"
cp shells/bi.js shells/bi.js.bak_yuklemeui
python3 - <<'PY' || exit 1
import pathlib, sys
p = pathlib.Path("shells/bi.js"); s = p.read_text(encoding="utf-8")
if "YUKLEME_UI_V1" in s: sys.exit("ZATEN YAMALI")

# 1) Sekme ekle
eski = '<button class="vmo-tab active" data-dept="bugun" style="--c:#8A8A8F">Bugün</button>'
assert eski in s, "bugun sekmesi yok"
s = s.replace(eski, eski + '\n          <button class="vmo-tab" data-dept="veri" style="--c:#8A8A8F">Veri</button>', 1)

# 2) Oda + render
ODA = r'''
  // ── YUKLEME_UI_V1 — 'Veri' odasi ─────────────────────────────────────────
  // ⚠ Bugune kadar dosyalari BEN donusturuyordum. Artik Fatih yukluyor.
  {
    const _o = container.querySelector('.vmo-office');
    if (_o && !document.getElementById('vmo-room-veri')) {
      const _v = document.createElement('div');
      _v.id = 'vmo-room-veri';
      _v.dataset.dept = 'veri';
      _v.className = 'vmo-room vmo-room-hidden';
      _v.style.cssText = 'background:var(--zemin-0);color:var(--tx-0);overflow-y:auto;padding:0';
      _v.innerHTML = '<div id="veri-govde" style="max-width:920px;margin:0 auto;padding:26px 28px 40px"></div>';
      _o.appendChild(_v);
    }
  }

  async function ciz_veri() {
    const g = document.getElementById('veri-govde');
    if (!g) return;
    let d = { dosyalar: [] };
    try {
      const r = await fetch('/api/bi/yukle/durum', { credentials:'same-origin' });
      d = await r.json();
    } catch(e) {}

    let h = '<div class="etiket" style="margin-bottom:12px">ERP DOSYALARI</div>';

    // ⚠ Sistem hangi dosyayi bekledigini BILIR. 'account balance' AYLARDIR
    //   gelmiyordu ve bunu TESADUFEN bulduk.
    h += '<div class="kart" style="margin-bottom:20px">';
    (d.dosyalar||[]).forEach(function(f){
      const renk = f.durum === 'taze' ? 'd-yesil'
                 : f.durum === 'hiç gelmedi' ? 'd-kirmizi' : 'd-sari';
      h += '<div style="display:flex;justify-content:space-between;align-items:baseline;gap:12px;padding:8px 0;border-bottom:0.5px solid var(--cizgi)">'
         + '<span style="font-size:14px">' + esc(f.ad) + '</span>'
         + '<span class="n ' + renk + '" style="font-size:12px">'
         + esc(f.durum) + (f.gun != null ? ' · ' + f.gun + ' gün' : '')
         + (f.satir ? ' · ' + Number(f.satir).toLocaleString('tr-TR') + ' satır' : '')
         + '</span></div>';
    });
    h += '</div>';

    // sürükle-bırak
    h += '<div id="veri-drop" style="border:1px dashed var(--cizgi-g);border-radius:12px;'
       + 'padding:34px;text-align:center;cursor:pointer;background:var(--zemin-1);margin-bottom:16px">'
       + '<div style="font-size:15px;margin-bottom:6px">ERP dosyasını buraya sürükle</div>'
       + '<div style="font-size:12px;color:var(--tx-2);line-height:1.7">'
       + 'stockmoving · full sales · full tedarikci · inventory · accountriskreport · account balance · ön sipariş<br>'
       + 'Dosya tipi <span class="d-yesil">başlıklarından</span> tanınır — dosya adına bakılmaz. En fazla 200MB.</div>'
       + '<input type="file" id="veri-dosya" accept=".xlsx" style="display:none">'
       + '</div>';
    h += '<div id="veri-sonuc"></div>';
    g.innerHTML = h;

    const drop = document.getElementById('veri-drop');
    const inp  = document.getElementById('veri-dosya');
    drop.onclick = function(){ inp.click(); };
    drop.ondragover = function(e){ e.preventDefault(); drop.style.borderColor = 'var(--yesil)'; };
    drop.ondragleave = function(){ drop.style.borderColor = 'var(--cizgi-g)'; };
    drop.ondrop = function(e){
      e.preventDefault(); drop.style.borderColor = 'var(--cizgi-g)';
      if (e.dataTransfer.files[0]) _yukle(e.dataTransfer.files[0]);
    };
    inp.onchange = function(){ if (inp.files[0]) _yukle(inp.files[0]); };
  }

  async function _yukle(dosya) {
    const s = document.getElementById('veri-sonuc');
    s.innerHTML = '<div class="kart"><div style="font-size:14px">'
                + esc(dosya.name) + ' — ' + (dosya.size/1e6).toFixed(1) + 'MB · işleniyor…</div>'
                + '<div style="font-size:12px;color:var(--tx-2);margin-top:6px">'
                + 'Tarih onarımı, ölçek çözümü ve kapılar çalışıyor. Büyük dosyada birkaç dakika sürebilir.</div></div>';
    const fd = new FormData();
    fd.append('dosya', dosya);
    let r;
    try {
      const res = await fetch('/api/bi/yukle', { method:'POST', credentials:'same-origin', body: fd });
      r = await res.json();
    } catch(e) {
      s.innerHTML = '<div class="kart kart-karar"><div style="font-size:14px">Yükleme başarısız</div>'
                  + '<div style="font-size:13px;color:var(--tx-1);margin-top:6px">' + esc(e.message) + '</div></div>';
      return;
    }

    let h = '<div class="kart ' + (r.ok ? 'kart-normal' : 'kart-karar') + '">';
    h += '<div style="font-size:15px;margin-bottom:10px">'
       + (r.ok ? '✅ Yüklendi' : '❌ YÜKLENMEDİ — eski veri yerinde duruyor') + '</div>';

    if (r.ad)  h += '<div class="satir"><span>dosya tipi</span><span>' + esc(r.ad) + '</span></div>';
    if (r.satir) h += '<div class="satir"><span>satır</span><span class="n">' + Number(r.satir).toLocaleString('tr-TR') + '</span></div>';
    if (r.aralik) h += '<div class="satir"><span>tarih aralığı</span><span class="n">' + esc(r.aralik[0]) + ' → ' + esc(r.aralik[1]) + '</span></div>';
    // ⚠ CAKISMA SEFFAF: kac satir silindi, kac eklendi
    if (r.mod) h += '<div class="satir"><span>yükleme modu</span><span>'
                  + (r.mod === 'tarih_araligi' ? 'zaman serisi — aralık değiştirme' : 'anlık görüntü — tam değiştirme')
                  + '</span></div>';
    if (r.silinen != null) h += '<div class="satir"><span>silinen (aralıkta)</span><span class="n">' + Number(r.silinen).toLocaleString('tr-TR') + '</span></div>';
    if (r.yukleme_sonrasi_mukerrer) h += '<div class="satir"><span class="d-kirmizi">⚠ yükleme sonrası mükerrer</span><span class="n d-kirmizi">' + r.yukleme_sonrasi_mukerrer + '</span></div>';

    const t = r.tarih_onarim || {};
    if (t.takas) h += '<div class="satir"><span>tarih onarımı (gün/ay takası)</span><span class="n d-sari">' + Number(t.takas).toLocaleString('tr-TR') + '</span></div>';
    if ((t.olcek_kimlikten||[]).length) h += '<div class="satir"><span>ölçeği kimlikten çözülen</span><span class="n d-sari">' + esc(t.olcek_kimlikten.join(', ')) + '</span></div>';
    if ((t.basamagi_bilinmeyen||[]).length) h += '<div class="satir"><span class="d-sari">⚠ ölçeği bilinmeyen (dokunulmadı)</span><span class="n d-sari">' + esc(t.basamagi_bilinmeyen.join(', ')) + '</span></div>';

    if (r.kapilar) {
      h += '<div class="etiket" style="margin:14px 0 8px">KAPILAR</div>';
      r.kapilar.forEach(function(k){
        h += '<div class="satir"><span>' + (k.gecti ? '✅' : '❌') + ' ' + esc(k.kapi) + '</span>'
           + '<span class="n ' + (k.gecti ? '' : 'd-kirmizi') + '">' + k.deger + ' / eşik ' + k.esik + '</span></div>';
        if (!k.gecti) h += '<div style="font-size:12px;color:var(--kirmizi);padding-left:10px;margin-bottom:6px">' + esc(k.aciklama) + '</div>';
      });
    }
    if (r.hata) h += '<div style="font-size:13px;color:var(--kirmizi);margin-top:10px">' + esc(r.hata) + '</div>';
    if (r.ipucu) h += '<div style="font-size:12px;color:var(--tx-2);margin-top:6px">' + esc(r.ipucu) + '</div>';
    h += '</div>';
    s.innerHTML = h;
    if (r.ok) setTimeout(ciz_veri, 1200);
  }

'''
anc = "  // Asistan odasina gecip soruyu sor"
assert anc in s, "anchor yok"
s = s.replace(anc, ODA + anc, 1)

# oda acilinca ciz
eski2 = "  _itirazlariYukle().then(ciz_bugun);"
assert eski2 in s, "ciz_bugun anchor yok"
s = s.replace(eski2, eski2 + """
  // Veri odasi acilinca ciz
  container.addEventListener('click', function(e){
    const t = e.target.closest('.vmo-tab[data-dept="veri"]');
    if (t) setTimeout(ciz_veri, 60);
  });""", 1)
p.write_text(s, encoding="utf-8")
print("  ✅ Veri odasi + surukle-birak + kapi sonuclari")
PY
node --check shells/bi.js || { cp shells/bi.js.bak_yuklemeui shells/bi.js; echo "❌ NODE FAIL"; exit 1; }
echo "  ✅ node --check"

echo
echo "############ 3) YETKI — 'veri' odasi gorunsun ############"
docker exec -i krb-assessment-postgres psql -U assessment_app -d assessment_platform -c "
UPDATE platform_tenants
   SET ozellikler = jsonb_set(COALESCE(ozellikler,'{}'::jsonb), '{departments}',
         COALESCE(ozellikler->'departments','[]'::jsonb) || '[\"veri\",\"bugun\"]'::jsonb)
 WHERE id='f8a5d20f-ecf8-4ce2-a492-69268fbb03fa'::uuid
RETURNING ozellikler->'departments';" 2>&1 | head -5 || echo "  (yetki tablosu farkli olabilir — sekme yine de gorunur)"

echo
echo "############ 4) DAGIT ############"
docker cp shells/bi.js krb-assessment:/app/shells/bi.js
docker restart krb-assessment >/dev/null && echo "  RESTARTED"
sleep 7
curl -s -o /dev/null -w "  HTTP %{http_code}\n" http://localhost:8080/
curl -s http://localhost:8080/shells/bi.js | grep -c "YUKLEME_UI_V1" | xargs -I{} echo "  YUKLEME_UI_V1 canlida: {} kez"

git add -A
git commit -q -m 'feat(yukleme): YUKLEME_UI_V1 — Veri odasi: surukle-birak ERP yukleme. Ekranda GIZLENMEYEN her sey: dosya tipi (BASLIKTAN tanindi, dosya adina guvenilmedi) · satir · tarih araligi · YUKLEME MODU (zaman serisi=aralik degistirme / anlik goruntu=tam degistirme) · kac satir SILINDI (cakisma seffaf) · TARIH ONARIMI (kac gun/ay takasi) · OLCEK (dosyadan okunan / KIMLIKTEN cozulen / BILINMEYEN) · KAPILAR (deger, esik, gecti mi). Kapi duserse: "YUKLENMEDI, eski veri yerinde" + SEBEP. Ayrica ERP dosya bekleme listesi: hangi dosya ne zaman geldi, taze/bayat/HIC GELMEDI — account balance AYLARDIR gelmiyordu ve bunu TESADUFEN bulduk; bir daha olmayacak.'
echo "  COMMITTED"

echo
echo "════════════════════════════════════════════════════════"
echo "  2 GUNLUK TEST ICIN:"
echo "  SAP'tan 10–12 Temmuz araligini kapsayan stockmoving export'u al."
echo "  Beklenen:"
echo "    • 10–11 Temmuz'daki mevcut satirlar SILINIP yeniden yazilir"
echo "    • 12 Temmuz EKLENIR"
echo "    • 9 Temmuz ve oncesi DOKUNULMAZ"
echo "    • 'yukleme sonrasi mukerrer' = 0"
echo "════════════════════════════════════════════════════════"
