# -*- coding: utf-8 -*-
# SABAH_ROTAM_DK_V3 (masaüstü) — yönetici panosuna KATLANIR "Nasıl çalışıyor?" paneli:
#   öneri sayıları nereden geliyor + skor (Risk+İhmal+Değer+Fırsat) tüm formül/kaynak/eşiklerle.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "shells/saha_desktop.js"
s = open(F, encoding="utf-8").read()
if "SABAH_ROTAM_DK_V3" in s:
    print("[skip] zaten yamali"); sys.exit(0)
assert "SABAH_ROTAM_DK_V2" in s, "HATA: once SABAH_ROTAM_DK_V2 (pano) olmali"

# 1) CSS — katlanır panel stilleri (board .rt-empty'den sonra)
css_old = ".rt-empty{color:var(--tx-2);text-align:center;padding:22px;font-size:13px}"
css_new = css_old + ("\n      .rt-how{border:1px solid var(--cizgi);border-radius:14px;background:var(--zemin-1);margin-bottom:14px;overflow:hidden}"  # SABAH_ROTAM_DK_V3
                     ".rt-how>summary{cursor:pointer;list-style:none;padding:13px 16px;font-size:13px;font-weight:800;color:var(--tx-0);display:flex;align-items:center;gap:8px;user-select:none}"
                     ".rt-how>summary::-webkit-details-marker{display:none}"
                     ".rt-how>summary:after{content:'▾';margin-left:auto;color:var(--tx-2);transition:transform .2s}"
                     ".rt-how[open]>summary:after{transform:rotate(180deg)}"
                     ".rt-how-b{padding:2px 16px 15px;font-size:12.5px;color:var(--tx-1);line-height:1.6}"
                     ".rt-how-b p{margin:0 0 10px}.rt-how-b b{color:var(--tx-0)}"
                     ".rt-how-b table{width:100%;border-collapse:collapse;margin:10px 0;font-size:11.5px}"
                     ".rt-how-b th{text-align:left;color:var(--tx-2);font-weight:700;padding:6px 8px;border-bottom:1px solid var(--cizgi);font-size:10px;text-transform:uppercase;letter-spacing:.03em}"
                     ".rt-how-b td{padding:6px 8px;border-bottom:1px solid var(--cizgi);color:var(--tx-0);vertical-align:top}"
                     ".rt-how-b td:first-child{font-weight:700;white-space:nowrap}"
                     ".rt-how-b code{background:var(--zemin-2);padding:1px 5px;border-radius:4px;font-size:11px}"
                     ".rt-how-defs{display:flex;flex-direction:column;gap:7px;margin:10px 0;padding:11px 13px;background:var(--zemin-2);border-radius:10px}.rt-how-defs div{font-size:12px;line-height:1.5}"
                     ".rt-how-note{font-size:11.5px;color:var(--tx-2);font-style:italic;margin-top:8px}")
assert s.count(css_old) == 1, "css anchor=%d" % s.count(css_old)
s = s.replace(css_old, css_new, 1)

# 2) HTML — katlanır paneli ekip bölümünden önce ekle
h_old = '      <div class="rt-sech">Ekip · bugünkü dağılım & öncelik uyumu</div>'
PANEL = ('      <details class="rt-how"><summary>🔍 Nasıl çalışıyor? — öneri sayıları ve skor nasıl hesaplanıyor</summary>'
         '<div class="rt-how-b">'
         '<p>Motor her müşteriyi <b>0–100 arası bir öncelik skoruyla</b> puanlar; bu skor hem bu yönetici panosunu hem de temsilcinin kişisel rotasını besler (birebir aynı hesap). Skor dört bileşenin toplamıdır:</p>'
         '<table><tr><th>Bileşen</th><th>Neyi ölçer</th><th>Formül (tavan)</th><th>Kaynak</th></tr>'
         '<tr><td>🔴 Risk</td><td>vadesi geçmiş alacak</td><td>min(35, gecikmiş₺ / 1M × 1.6)</td><td><code>bi_musteri_risk.vadesi_gecmis</code></td></tr>'
         '<tr><td>🥶 İhmal</td><td>son ziyaretten bu yana gün</td><td>min(28, gün / 2.2)</td><td><code>saha_ziyaret</code> son TAMAMLANDI</td></tr>'
         '<tr><td>💰 Değer</td><td>yıllık ERP cirosu</td><td>min(22, ciro₺ / 1M × 0.28)</td><td><code>bi_satis_faturalari</code> (12 ay)</td></tr>'
         '<tr><td>📋 Fırsat</td><td>açık teklif sayısı</td><td>min(15, teklif × 6)</td><td><code>saha_teklif</code> (açık)</td></tr></table>'
         '<p><b>Örnek:</b> ₺16M gecikmiş → 35 (tavan) &nbsp;+&nbsp; 48 gün ihmal → 22 &nbsp;+&nbsp; ₺54M ciro → 22 (tavan) &nbsp;+&nbsp; 0 teklif → 0 &nbsp;=&nbsp; <b>skor 79</b>.</p>'
         '<div class="rt-how-defs">'
         '<div><b>Öncelikli öneri</b> (her rep için sayı) = o temsilcinin kitabında <b>skor ≥ 40</b> olan müşteri sayısı — "bugün ilgilenilmeye değer" eşiği.</div>'
         '<div><b>Atladığı en yüksek</b> = temsilcinin bugün <code>PLANLANDI</code>\'ya almadığı <b>en yüksek skorlu</b> müşterisi (kolay durak yapıp riskliyi atlıyor mu?).</div>'
         '<div><b>Sahipsiz / atlanan kritik</b> = <b>skor ≥ 55</b> olup bugün <b>kimsenin</b> planında olmayan hesaplar; "sahipsiz" = sorumlu temsilci atanmamış.</div>'
         '<div><b>Planlı</b> = bugüne PLANLANDI ziyaret &nbsp;·&nbsp; <b>Yapılan</b> = bugün TAMAMLANDI (canlı) — ikisi de <code>saha_ziyaret</code>\'ten.</div>'
         '<div><b>Neden ERP eşleşmesi önemli:</b> Risk ve Değer yalnız ERP\'ye bağlı (<code>musteri_kodu</code>\'lu) müşteride görünür → eşleşmemiş müşteri düşük skorlanır, bu da eşleştirmeyi teşvik eder.</div>'
         '</div>'
         '<p style="font-size:13px;font-weight:800;color:var(--tx-0);margin:14px 0 6px">📈 Nasıl öğreniyor & nereye gidiyor?</p>'
         '<div class="rt-how-defs" style="background:var(--yesil-z,#EAF7F1)">'
         '<div><b>1) Kayıt (✅ canlı).</b> Her sabah üretilen öneriler <code>saha_rota_log</code> tablosuna yazılır — bugün başladı. Böylece "ne önerdik" ile "ne yapıldı" kıyaslanabilir hale gelir.</div>'
         '<div><b>2) Gece uzlaştırma (⏳ sıradaki adım).</b> Her akşam o günün önerileri gerçekleşen ziyaretlerle (<code>TAMAMLANDI</code>) karşılaştırılır ve her temsilci için şunlar öğrenilir: gerçek <b>gün-kapasitesi</b> (kaç durak yapıyor), ort. <b>görüşme süresi</b>, hangi <b>nedenlere</b> (risk/ihmal/değer/fırsat) gidip hangilerini atlıyor, ve <b>öneri→gerçekleşme oranı (%)</b>.</div>'
         '<div><b>3) Kendini ayarlama.</b> Öğrenilenlerle skor <b>ağırlıkları temsilciye göre kayar</b> (ör. hep riske gidip değeri atlayan repte risk ağırlığı artar), günlük durak sayısı sabit 10 değil <b>o repin gerçek temposuna</b> oturur.</div>'
         '<div><b>4) Tahmin — nereye gidiyor (🔮 hedef).</b> Yeterli veri birikince: her rep için <b>gerçekçi günlük rota + bitiş saati tahmini</b>; başlangıç noktasına göre <b>yakınlık-optimize sıralama</b>; ve en önemlisi bir hesabın <b>Aktif→Pasif kayacağını önceden</b> işaretleyip "geç kalmadan git" uyarısı (reaktif değil <b>proaktif</b>).</div>'
         '</div>'
         '<p class="rt-how-note">Bugün skor <b>deterministik ve şeffaf</b> (ağırlıklar 35/28/22/15 sabit başlangıç). Öğrenme + tahmin katmanı üstüne gelecek; kayıt bugün başladığı için ilk uzlaştırmalar birkaç gün veri sonrası anlam kazanır.</p>'
         '</div></details>\n')
h_new = PANEL + h_old
assert s.count(h_old) == 1, "html anchor=%d" % s.count(h_old)
s = s.replace(h_old, h_new, 1)

# 3) sekme etiketi — masaüstü yönetici görünümü: "Rotam" (benim rotam) yerine "Bugün Sahada"
tab_old = '    ["rotam", "🌅 Rotam"],  /* SABAH_ROTAM_DK_V1 */'
tab_new = '    ["rotam", "🌅 Bugün Sahada"],  /* SABAH_ROTAM_DK_V1 SABAH_ROTAM_DK_V3 */'
assert s.count(tab_old) == 1, "tab label anchor=%d" % s.count(tab_old)
s = s.replace(tab_old, tab_new, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] SABAH_ROTAM_DK_V3 (masaüstü) — katlanır 'Nasıl çalışıyor' paneli")
