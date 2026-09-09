#!/usr/bin/env python3
# SMARTKIYAS_V2 — gecikme + buyume metrik temizligi.
#  Gecikme: overdue/bakiye (net bakiye kucukse patlar) YERINE overdue/ciro (sinirli, anlamli). Bayrak:
#    overdue > ciro*0.10 (yillik cironun %10'undan fazlasi gecikmis). Karti/kokpiti birlikte gunceller.
#  Buyume: kucuk tabanda %7000 gibi patlamayi kirp (>300 -> ">%300", <-95 -> "<-%95").
# Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "SMARTKIYAS_V2" in s:
    print("smartkiyas2: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTKIYAS_V1" in s, "once SMARTKIYAS_V1 uygulanmali"

# (1) Kart gecikme metrigi
OLD_G = '''        { const kotu = odPct != null && krbOd != null && odPct > krbOd * 1.2 && overdue > 50000;
          M.push({ anahtar: "gecikme", ad: "Gecikme", deger: overdue != null ? Math.round(overdue).toLocaleString("tr-TR") + " ₺ (%" + odPct + ")" : "—",
            krb: krbOd != null ? "%" + krbOd + " ort" : "—", durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Tahsilat planı / kredi limitini gözden geçir" : null }); }'''
NEW_G = '''        { const _ciro = n(x.ciro) || 0; const odCiro = (_ciro > 0 && overdue != null) ? overdue / _ciro * 100 : null; /* SMARTKIYAS_V2 */
          const kotu = overdue != null && _ciro > 0 && overdue > _ciro * 0.10 && overdue > 50000;
          M.push({ anahtar: "gecikme", ad: "Gecikme", deger: overdue != null ? Math.round(overdue).toLocaleString("tr-TR") + " ₺" + (odCiro != null ? " · cironun %" + Math.round(odCiro) + "'i" : "") : "—",
            krb: "sağlıklı < %10", durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Tahsilat planı / kredi limitini gözden geçir" : null }); }'''
assert s.count(OLD_G) == 1, "kart gecikme anchor"
s = s.replace(OLD_G, NEW_G, 1)

# (2) Kart buyume metrigi (kirpma)
OLD_B = '''        { const kotu = buyume != null && buyume < -5;
          M.push({ anahtar: "buyume", ad: "Büyüme", deger: buyume != null ? "%" + buyume : "—", krb: "0 (düz)",
            durum: kotu ? "kotu" : (buyume != null && buyume > 5 ? "iyi" : "notr"), aksiyon: kotu ? "Kampanya / ziyaret sıklığını artır" : null }); }'''
NEW_B = '''        { const kotu = buyume != null && buyume < -5; /* SMARTKIYAS_V2 */
          const bStr = buyume == null ? "—" : (buyume > 300 ? ">%300" : (buyume < -95 ? "<-%95" : "%" + buyume));
          M.push({ anahtar: "buyume", ad: "Büyüme", deger: bStr, krb: "0 (düz)",
            durum: kotu ? "kotu" : (buyume != null && buyume > 5 ? "iyi" : "notr"), aksiyon: kotu ? "Kampanya / ziyaret sıklığını artır" : null }); }'''
assert s.count(OLD_B) == 1, "kart buyume anchor"
s = s.replace(OLD_B, NEW_B, 1)

# (3) Kokpit hedef gecikme bayragi
OLD_KG = '          if (odPct != null && krbOd != null && odPct > krbOd * 1.2 && overdue > 50000) bayrak.push("gecikme");'
NEW_KG = '          if (overdue != null && n(x.ciro) > 0 && overdue > n(x.ciro) * 0.10 && overdue > 50000) bayrak.push("gecikme"); /* SMARTKIYAS_V2 */'
assert s.count(OLD_KG) == 1, "kokpit gecikme bayrak anchor"
s = s.replace(OLD_KG, NEW_KG, 1)

write(FP, s)
print("smartkiyas2: gecikme=overdue/ciro, buyume kirpildi")
print("marker count:", s.count("SMARTKIYAS_V2"))
print("DONE.")
