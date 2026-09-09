#!/usr/bin/env python3
# RAKIPWATCH_UI_V1 — musteri kartinda RAKIP durumu + rakip fiyat satiri. saha.js. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "RAKIPWATCH_UI_V1" in s:
    print("rakipwatch-ui: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTFIYAT_UI_V1" in s, "once SMARTFIYAT_UI_V1 gerekli"

# (1) _foLoad DUR haritasi
A1 = 'const DUR={LIFT:["⬆ Yükselt","#16a34a","#dcfce7"],WATCH:["👁 İzle","#b45309","#fef9c3"],UYGUN:["✓ Uygun","#0369a1","#e0f2fe"],YENI:["✦ Yeni","#7c3aed","#f3e8ff"]};'
assert s.count(A1) == 1, "DUR map anchor"
N1 = 'const DUR={LIFT:["⬆ Yükselt","#16a34a","#dcfce7"],WATCH:["👁 İzle","#b45309","#fef9c3"],UYGUN:["✓ Uygun","#0369a1","#e0f2fe"],YENI:["✦ Yeni","#7c3aed","#f3e8ff"],RAKIP:["⚔ Rakip savun","#dc2626","#fee2e2"],RAKIP_MALIYET:["⚔ Maliyet sınırı","#b45309","#fef3c7"]}; /* RAKIPWATCH_UI_V1 */'
s = s.replace(A1, N1, 1)

# (2) _foLoad kart sonu — rakip satiri
A2 = ("      +'<div style=\"font-size:10px;color:#64748b;text-transform:uppercase;margin:2px 0 3px\">Vade–fiyat menüsü</div><div style=\"display:flex;gap:4px\">'+vm+'</div>'\n"
      "      +'</div>';")
assert s.count(A2) == 1, "_foLoad kart sonu anchor"
N2 = ("      +'<div style=\"font-size:10px;color:#64748b;text-transform:uppercase;margin:2px 0 3px\">Vade–fiyat menüsü</div><div style=\"display:flex;gap:4px\">'+vm+'</div>'\n"
      "      +(r.rakip?'<div style=\"font-size:11px;color:#dc2626;margin-top:6px;border-top:1px solid #f1f5f9;padding-top:6px\">⚔ Rakip: <b>'+esc(r.rakip.marka||\"?\")+'</b> '+Number(r.rakip.fiyat).toLocaleString(\"tr-TR\")+' ₺'+(r.rakip.neden?' · '+esc(r.rakip.neden):'')+(r.rakip.tarih?' · '+esc(r.rakip.tarih):'')+'</div>':'') /* RAKIPWATCH_UI_V1 */\n"
      "      +'</div>';")
s = s.replace(A2, N2, 1)

# (3) _foRecent DURc renk haritasi
A3 = 'const DURc={LIFT:"#16a34a",WATCH:"#b45309",UYGUN:"#0369a1",YENI:"#7c3aed"};'
assert s.count(A3) == 1, "DURc map anchor"
N3 = 'const DURc={LIFT:"#16a34a",WATCH:"#b45309",UYGUN:"#0369a1",YENI:"#7c3aed",RAKIP:"#dc2626",RAKIP_MALIYET:"#b45309"}; /* RAKIPWATCH_UI_V1 */'
s = s.replace(A3, N3, 1)

write(FP, s)
print("rakipwatch-ui: RAKIP durumu + rakip fiyat satiri eklendi")
print("marker count:", s.count("RAKIPWATCH_UI_V1"))
print("DONE.")
