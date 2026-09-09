#!/usr/bin/env python3
# SMARTKIYAS_CARD_UI_V1 — Musteri kartina "KRB Kiyas" verdict bolumu (skor kartinin altina).
# Baslik (kac metrikte dusuruyor) + metrik satirlari (deger vs KRB ort + aksiyon; kotu kirmizi/iyi yesil).
# /api/bi/musteri-kiyas. saha.js. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/saha.js"
s = read(FP)
if "SMARTKIYAS_CARD_UI_V1" in s:
    print("kiyas-card: already present, skip"); print("DONE."); raise SystemExit
assert "SMARTFIYAT_UI_V1" in s, "once SMARTFIYAT_UI_V1 uygulanmali"

# (1) Fonksiyon — musteriDetayModal'dan once
A_fn = "function musteriDetayModal(m) {\n  const [dl, dc] = DURUM_ETIKET[m.durum] || [\"\", \"#999\"];"
assert s.count(A_fn) == 1, "musteriDetayModal anchor"
FN = r'''/* SMARTKIYAS_CARD_UI_V1 */
async function _foKiyas(m){
  const el=document.getElementById("mus-kiyas"); if(!el||!m||!m.musteri_kodu) return;
  try{
    const d=await api("/api/bi/musteri-kiyas?musteri="+encodeURIComponent(m.musteri_kodu));
    if(d.yok||!d.metrikler||!d.metrikler.length){ el.innerHTML=""; return; }
    const hc=d.drag_sayisi>0?"#dc2626":"#16a34a";
    const rows=d.metrikler.map(function(x){
      var c=x.durum==="kotu"?"#dc2626":(x.durum==="iyi"?"#16a34a":"#94a3b8");
      var ic=x.durum==="kotu"?"⚠":(x.durum==="iyi"?"✓":"·");
      return '<div style="display:flex;align-items:flex-start;gap:8px;padding:5px 0;border-top:1px solid #f1f5f9"><span style="flex:0 0 auto;color:'+c+';font-weight:700">'+ic+'</span><div style="flex:1;min-width:0"><div style="font-size:12px"><b>'+esc(x.ad)+':</b> '+esc(x.deger)+' <span style="color:#94a3b8">· KRB '+esc(x.krb)+'</span></div>'+(x.aksiyon?'<div style="font-size:11px;color:'+c+'">→ '+esc(x.aksiyon)+'</div>':'')+'</div></div>';
    }).join("");
    el.innerHTML='<div style="border:1px solid '+(d.drag_sayisi>0?"#fecaca":"#bbf7d0")+';border-radius:12px;padding:10px 12px;background:'+(d.drag_sayisi>0?"#fef2f2":"#f0fdf4")+'"><div style="font-weight:700;color:'+hc+';font-size:12px">📊 '+esc(d.headline)+'</div>'+rows+'</div>';
  }catch(e){ el.innerHTML=""; }
}
'''
s = s.replace(A_fn, FN + A_fn, 1)

# (2) Kiyas konteyneri — skor konteynerinden sonra
A_c = '\'<div id="mus-skor" style="margin:6px 0 10px"></div>\' : ""}'
assert s.count(A_c) == 1, "mus-skor konteyner anchor"
N_c = A_c + '\n    ${(["manager","admin"].includes(S.role) && m.musteri_kodu) ? \'<div id="mus-kiyas" style="margin:0 0 10px"></div>\' : ""}'
s = s.replace(A_c, N_c, 1)

# (3) Init cagrisi
A_call = "  _foSkor(m); _foFiyatInit(m); /* SMARTFIYAT_UI_V1 */"
assert s.count(A_call) == 1, "init anchor"
s = s.replace(A_call, A_call + "\n  _foKiyas(m); /* SMARTKIYAS_CARD_UI_V1 */", 1)

write(FP, s)
print("kiyas-card: verdict bolumu eklendi")
print("marker count:", s.count("SMARTKIYAS_CARD_UI_V1"))
print("DONE.")
