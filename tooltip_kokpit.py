#!/usr/bin/env python3
# TOOLTIP_KOKPIT_V1 — Kokpit'te her KART basligina ⓘ ipucu ekle (mevcut DEFS/#pop altyapisi).
# DEFS'e kart tanimlari + statik/JS basliklara <span class="i" data-def=...> eklenir. kokpit.html. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/kokpit.html"
s = read(FP)
if "TOOLTIP_KOKPIT_V1" in s:
    print("tooltip-kokpit: already present, skip"); print("DONE."); raise SystemExit

# (1) DEFS'e kart tanimlari
A_defs = '  stok:{ad:"Stok Değeri",tanim:"Eldeki stoğun alış maliyeti değeri.",kaynak:"bi_stok_anlik"}\n};'
assert s.count(A_defs) == 1, "DEFS stok anchor"
N_defs = ('  stok:{ad:"Stok Değeri",tanim:"Eldeki stoğun alış maliyeti değeri.",kaynak:"bi_stok_anlik"},\n'
          '  /* TOOLTIP_KOKPIT_V1 */\n'
          '  nakit:{ad:"Nakit & Tahsilat",tanim:"Şirketin bugünkü para durumu: gecikmiş alacak (brüt→net), tahsilat süresi (DSO) ve parayı en çok bekleten müşteriler. Alacağın ne kadarı gerçek risk.",kaynak:"bi_musteri_risk × bi_cari_bakiye"},\n'
          '  ai:{ad:"Finansal İçgörü (AI)",tanim:"Yapay zekânın her gün ürettiği finansal içgörüler, ₺ etkisi ve \\"şunu yaparsak şu kadar tasarruf\\" simülasyonu. Okuyup aksiyona çevir.",kaynak:"günlük AI analizi"},\n'
          '  kanal:{ad:"Satış Kanalı",tanim:"Cironun hangi kanaldan geldiği ve o kanalın marjı. Kırmızı = zararda kanal.",kaynak:"bi_satis_faturalari"},\n'
          '  segment:{ad:"Segment",tanim:"Ürün segmentlerine göre ciro ve marj. Kırmızı segment ilk bakılacak yerdir.",kaynak:"bi_marj_atom"},\n'
          '  markab:{ad:"Marka",tanim:"Marka bazında ciro ve marj. Zararda markalar burada görünür.",kaynak:"bi_marj_atom"},\n'
          '  sezon:{ad:"Sezon",tanim:"Yaz / kış / 4 mevsim kırılımında ciro ve marj.",kaynak:"bi_marj_atom"},\n'
          '  trend:{ad:"Trend · Şirket",tanim:"Ciro, stok ve DSO\\u2019nun son 13 aydaki seyri. Kesikli çizgi = geçen yılın aynı dönemi. Bu yıl geçen yıla göre iyi mi?",kaynak:"bi_metrik_gecmis"},\n'
          '  radar:{ad:"Piyasa Radar",tanim:"Rakip / piyasa fiyatlarının canlı takibi. İzlenen ebatlar, son tarama zamanı ve fiyat alarmları.",kaynak:"bi_rakip_fiyat"},\n'
          '  marjalarm:{ad:"Marj Alarmı",tanim:"Maliyetin fiyatı geçtiği, az kârla veya zararla satılan ürünler. Kırmızı satır = ort. satış yeniden-alım maliyetinin ALTINDA. Hedef her markaya özeldir. Satıra tıkla → desen kırılımı.",kaynak:"bi_marj_atom × bi_tedarikci_faturalari"},\n'
          '  kiyas:{ad:"İyileştirme Hedefleri",tanim:"KRB ortalamasını en çok düşüren müşteriler (marj kaybı ₺ sıralı). Birini KRB ortalamasına çekmek ortalamayı yukarı çeker. Bayraklar = hangi metrikte kötü.",kaynak:"bi_satis_faturalari × bi_marj_atom × bi_musteri_risk"}\n'
          '};')
s = s.replace(A_defs, N_defs, 1)

# (2) barCard basligina def-eslemeli ⓘ — once iB'den sonra bDef helper
A_ib = 'const iB=k=>`<span class="i" data-def="${k}">i</span>`;'
assert s.count(A_ib) == 1, "iB anchor"
s = s.replace(A_ib, A_ib + '\nconst bDef=t=>({"Satış Kanalı":"kanal","Segment":"segment","Marka":"markab","Sezon":"sezon"}[t]||""); /* TOOLTIP_KOKPIT_V1 */', 1)

A_bc = '<div class="card col3"><h3>${title} <span class="tag">${tag}</span></h3>'
assert s.count(A_bc) == 1, "barCard header anchor"
N_bc = '<div class="card col3"><h3>${title} ${bDef(title)?iB(bDef(title)):""} <span class="tag">${tag}</span></h3>'
s = s.replace(A_bc, N_bc, 1)

# (3) Statik + eklenen kart basliklari
def add_i(tag_before, key):
    global s
    assert s.count(tag_before) == 1, "baslik anchor: " + key
    s = s.replace(tag_before, '<span class="i" data-def="' + key + '">i</span> ' + tag_before, 1)

add_i('<span class="tag">şirketin bugünkü hikâyesi · net</span>', 'nakit')
add_i('<span class="tag">günlük · ₺ etki</span>', 'ai')
add_i('<span class="tag">13 ay · bu yıl vs geçen yıl</span>', 'trend')
add_i('<span class="tag">canlı</span>', 'radar')
add_i('<span class="tag">maliyet fiyatı geçti · yenileme maliyeti tabanı</span>', 'marjalarm')
add_i('<span class="tag">KRB ort. altı · marj kaybı ₺</span>', 'kiyas')

write(FP, s)
print("tooltip-kokpit: DEFS + kart ⓘ ipuclari eklendi")
print("marker count:", s.count("TOOLTIP_KOKPIT_V1"))
print("DONE.")
