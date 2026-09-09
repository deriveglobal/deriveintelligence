import sys, io
p=sys.argv[1]; s=io.open(p,encoding="utf-8").read()
if "KATILIMCI_V1" in s:
    print("[katilimci_saha] zaten uygulanmis, atlaniyor."); sys.exit(0)
E=[
# C1 — kullanici listesini cek (ziyaretFormModal)
("""  try { lokasyonlar = (await api(`/api/saha/musteriler/${mus.id}/lokasyonlar`)).lokasyonlar || []; } catch { /* yok */ }""",
"""  try { lokasyonlar = (await api(`/api/saha/musteriler/${mus.id}/lokasyonlar`)).lokasyonlar || []; } catch { /* yok */ }
  let _katilimciAdaylar = []; try { _katilimciAdaylar = (await api("/api/saha/saha-kullanicilar")).kullanicilar || []; } catch {} // KATILIMCI_V1"""),
# C2 — form bolumu (zf-katilimci'den sonra)
("""    <label>Görüşülen kişi / ünvan<input class="giris" id="zf-katilimci" placeholder="Ahmet Bey — Satınalma"></label>""",
"""    <label>Görüşülen kişi / ünvan<input class="giris" id="zf-katilimci" placeholder="Ahmet Bey — Satınalma"></label>
    <label>Katılımcılar (ekip)<div style="font-size:11px;color:#94a3b8;font-weight:400;margin:1px 0 4px">Ziyarete katılanları seç; listede yoksa "+ diğer" ile elle ekle</div>${cipSecici("zf-katilimcilar", _katilimciAdaylar.map(u => u.ad))}</label>"""),
# C3 — detay.katilimcilar (yeni ziyaret kaydet)
("""      tedarikci_markalar: tedarikSecim, yillik_potansiyel: n("zf-potansiyel")
    };
    try {""",
"""      tedarikci_markalar: tedarikSecim, yillik_potansiyel: n("zf-potansiyel")
    };
    detay.katilimcilar = cipDegerler("zf-katilimcilar"); // KATILIMCI_V1
    try {"""),
# D1 — detay ekraninda goster
("""    ${satir("Katılımcı", z.katilimci)}""",
"""    ${satir("Katılımcı", z.katilimci)}
    ${dizi("Katılımcılar (ekip)", d.katilimcilar)}"""),
# E1 — duzenle modal: katilimcilari koru (detay tam-degistirme kaybini onle)
("""      tedarikci_markalar: cipDegerler("zd-tedarikci"), yillik_potansiyel: n("zd-potansiyel")
    };
    const btn = document.getElementById("zd-kaydet");""",
"""      tedarikci_markalar: cipDegerler("zd-tedarikci"), yillik_potansiyel: n("zd-potansiyel")
    };
    if (z.detay && z.detay.katilimcilar) detay.katilimcilar = z.detay.katilimcilar; // KATILIMCI_V1 koru
    const btn = document.getElementById("zd-kaydet");"""),
# P1 — plan-tamamla: katilimcilari koru
("""          yillik_potansiyel: n("pt-potansiyel") };
    try {""",
"""          yillik_potansiyel: n("pt-potansiyel") };
    if (z.detay && z.detay.katilimcilar) detay.katilimcilar = z.detay.katilimcilar; // KATILIMCI_V1 koru
    try {"""),
]
for i,(o,n) in enumerate(E):
    if s.count(o)!=1:
        sys.stderr.write("[saha] HATA edit %d anchor=%d\n"%(i,s.count(o))); sys.exit(2)
    s=s.replace(o,n,1)
io.open(p,"w",encoding="utf-8").write(s)
print("[katilimci_saha] uygulandi (6 edit).")
