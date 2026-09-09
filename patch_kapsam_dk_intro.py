# -*- coding: utf-8 -*-
# KAPSAM_DK_INTRO_V1 (saha_desktop.js) — diğer sekmelerle tutarlılık:
#   Ciro/Risk gibi ÜSTTE "ne işe yarar?" intro kartı ekle; alttaki katlanır how-panel'i kaldır.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "KAPSAM_DK_INTRO_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "KAPSAM_DK_V1" in s, "once KAPSAM_DK_V1 olmali"

# 1) CSS — intro stilleri
o1 = '.kap-cd{font-size:11px;color:var(--t2);margin-bottom:11px}'
n1 = ('.kap-cd{font-size:11px;color:var(--t2);margin-bottom:11px}\n'
      '      .kap-intro .kap-ip{font-size:12.5px;color:var(--t1);line-height:1.6;margin-top:2px}  /* KAPSAM_DK_INTRO_V1 */\n'
      '      .kap-intro .kap-idiv{height:1px;background:var(--cz);margin:12px 0 11px}\n'
      '      .kap-intro .kap-il{font-size:12px;color:var(--t1);line-height:1.55;margin-bottom:6px}.kap-intro .kap-il b{color:var(--t0)}.kap-intro code{background:var(--z2);padding:1px 5px;border-radius:5px;font-size:11px}')
assert s.count(o1) == 1, "css anchor=%d" % s.count(o1)
s = s.replace(o1, n1, 1)

# 2) ÜST intro kartı ekle (kpis'ten önce)
o2 = 'el.innerHTML = CSS + `<div class="kap">\n      <div class="kap-kpis">'
n2 = ('el.innerHTML = CSS + `<div class="kap">\n'
      '      <div class="kap-card kap-intro">  <!-- KAPSAM_DK_INTRO_V1 -->\n'
      '        <div class="kap-h">📍 Kapsam & Beyaz Alan — ne işe yarar?</div>\n'
      '        <p class="kap-ip">Saha eforunun <b>hücum tarafı</b>: nereye gidilmiyor ve ne kadar değerli müşteri masada kalıyor — Risk Radarı\'nın (savunma) aynası. Amaç: kapsamı genişletmek ve ERP\'ye bağlı olmayan değerli müşterileri görünür kılıp eşleştirmeye itmek.</p>\n'
      '        <div class="kap-idiv"></div>\n'
      '        <div class="kap-il"><b>Kapsam</b> = son 90 günde ≥1 TAMAMLANDI ziyaretli <b>farklı müşteri</b> ÷ aktif portföy (genişlik ölçer; yalnız uygulamada kayıtlı ziyaret sayılır).</div>\n'
      '        <div class="kap-il"><b>Beyaz alan</b> = son 12 ay cirosu&gt;0, eşleşmiş ama 90 gündür ziyaret yok — dokunulmayan değerli müşteriler.</div>\n'
      '        <div class="kap-il"><b>Eşleşmemiş</b> = <code>musteri_kodu</code> yok → cirosu görünmez; ayrı "kör nokta" bloğu, eşleştirmeye iter.</div>\n'
      '        <div class="kap-il"><b>İki pencere</b>: kapsam <b>son 90 gün</b> · ciro/değer <b>son 12 ay</b> (YTD değil). Her aksiyon loglanır; susturulanları yönetici gerekçesiyle görür.</div>\n'
      '      </div>\n'
      '      <div class="kap-kpis">')
assert s.count(o2) == 1, "intro insert anchor=%d" % s.count(o2)
s = s.replace(o2, n2, 1)

# 3) alttaki katlanır how-panel'i kaldır (artık üstte)
o3 = ('''      <details><summary>🔍 Bu rapor nasıl hesaplanıyor?</summary><div class="kap-db">
        <p><b>⏱ İki pencere:</b> <b>Kapsam</b> = son 90 gün (tarama). <b>Ciro/değer</b> = son 12 ay yuvarlanan (YTD değil), ERP faturaları <code>musteri_kodu</code> eşleşmeli.</p>
        <p><b>Kapsam</b> = 90 günde ≥1 TAMAMLANDI ziyaretli farklı müşteri ÷ portföy. Yalnız uygulamada kayıtlı ziyaret sayılır.</p>
        <p><b>Beyaz alan</b> = cirosu>0, 90 günde ziyaret yok, eşleşmiş. <b>Eşleşmemiş</b> = kod yok → değeri görünmez, ayrı blok.</p>
        <p><b>Aksiyon & öğrenme:</b> her aksiyon <code>saha_musteri_aksiyon</code>'a loglanır; susturulanlar rapordan düşer ama yönetici görür; gerekçeler sinyale döner. Ölü buton yok.</p>
      </div></details>
''')
assert s.count(o3) == 1, "details anchor=%d" % s.count(o3)
s = s.replace(o3, "", 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] KAPSAM_DK_INTRO_V1 (saha_desktop.js) — üst intro + alt panel kaldırıldı")
