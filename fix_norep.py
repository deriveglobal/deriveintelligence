#!/usr/bin/env python3
# NOREP_V1 — köken'den temsilci/rep kırılımını kaldır: koken.top'ta rep yok, by_rep yok, prompt rep istemiyor.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "NOREP_V1" in s:
    print("norep: already present, skip"); print("DONE."); raise SystemExit

# (1) koken.top: rep alanını çıkar
old1 = "    top: _topRows.map(r => ({ kod: r.kod, ad: r.ad, rep: r.rep, vade: r.vade, overdue: Math.round(r.net), brut: Math.round(r.brut), krb_borc: Math.round(r.borc), pct: _pctOv(r.net) })),"
new1 = "    top: _topRows.map(r => ({ kod: r.kod, ad: r.ad, vade: r.vade, overdue: Math.round(r.net), brut: Math.round(r.brut), krb_borc: Math.round(r.borc), pct: _pctOv(r.net) })), // NOREP_V1"
assert s.count(old1) == 1, "koken.top anchor"
s = s.replace(old1, new1, 1)

# (2) by_rep satırını tamamen kaldır
old2 = "    by_rep: _repRows.map(r => ({ rep: r.rep, overdue: Math.round(r.tut), adet: r.adet, pct: _pctOv(r.tut) })),\n"
assert s.count(old2) == 1, "by_rep anchor"
s = s.replace(old2, "", 1)

# (3) prompt: temsilci/rep kırılımını çıkar, müşteri odağı
old3 = '- "koken" verisi KİM/NEREDEN sorusunu yanıtlar: en büyük gecikmiş hesaplar (top), temsilci kırılımı (by_rep), vade kırılımı (by_vade). En az bir içgörü gecikmenin KAYNAĞINI (hangi müşteri/temsilci/vade tipi en çok pay alıyor) somut isim/rakamla göstersin.'
new3 = '- "koken" verisi KİM/NEREDEN sorusunu yanıtlar: en büyük gecikmiş MÜŞTERİ hesapları (top) ve vade kırılımı (by_vade). En az bir içgörü gecikmenin KAYNAĞINI (hangi MÜŞTERİ / vade tipi en çok pay alıyor) somut müşteri isim/rakamıyla göstersin. Satış temsilcisi/rep kırılımı İSTENMİYOR — temsilci bazlı içgörü ÜRETME, sadece müşteri.'
assert s.count(old3) == 1, "prompt koken rule anchor"
s = s.replace(old3, new3, 1)

write(FP, s)
print("norep: koken.top rep kaldırıldı, by_rep kaldırıldı, prompt müşteri-odaklı")
print("DONE.")
