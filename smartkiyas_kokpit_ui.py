#!/usr/bin/env python3
# SMARTKIYAS_KOKPIT_UI_V1 — Kokpit'e "İyileştirme Hedefleri" bolumu.
# KRB ort.'sini en cok dusuren musteriler (marj kaybi ₺ sirali) + bayraklar (marj/tahsilat/gecikme/buyume).
# /api/bi/iyilestirme-hedefleri. .mtab/.ma-head/.ma-scroll stilleri MARJALARM_UI_V1'den geliyor. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/kokpit.html"
s = read(FP)
if "SMARTKIYAS_KOKPIT_UI_V1" in s:
    print("kiyas-kokpit: already present, skip"); print("DONE."); raise SystemExit
assert "MARJALARM_UI_V1" in s, "once MARJALARM_UI_V1 uygulanmali"

# (1) HTML konteyner — Trend grid'inden ONCE
A_html = '  <div class="grid">\n    <div class="card col8"><h3>Trend · Şirket'
assert s.count(A_html) == 1, "trend grid anchor"
H = ('  <div class="grid"><!-- SMARTKIYAS_KOKPIT_UI_V1 -->\n'
     '    <div class="card" style="grid-column:span 12"><h3>\U0001f3af İyileştirme Hedefleri <span class="tag">KRB ort. altı · marj kaybı ₺</span></h3><div id="kiyasbox"><div class="empty">yükleniyor…</div></div></div>\n'
     '  </div>\n\n' + A_html)
s = s.replace(A_html, H, 1)

# (2) render fonksiyonu — load bloğundan once
A_fn = "/* ---------- load ---------- */"
assert s.count(A_fn) == 1, "load anchor"
FN = '''/* SMARTKIYAS_KOKPIT_UI_V1 */
function renderKiyas(d){
  const el=$("kiyasbox"); if(!el)return;
  if(!d||d.error||!Array.isArray(d.hedefler)||!d.hedefler.length){el.innerHTML=`<div class="empty">İyileştirme hedefi yok${d&&d.error?': '+esc(d.error):''}.</div>`;return;}
  const BJ={marj:"marj",tahsilat:"tahsilat",gecikme:"gecikme",buyume:"büyüme"};
  const head=`<div class="ma-head">
    <div><div class="l">Toplam marj kaybı (KRB ort. altı)</div><div class="v" style="color:var(--risk)">${MM(d.toplam_marj_drag)}</div></div>
    <div><div class="l">Hedef müşteri</div><div class="v">${d.musteri_sayisi}</div></div></div>`;
  const rows=d.hedefler.slice(0,40).map(h=>`<tr>
    <td class="ma-nm" title="${esc(h.musteri_adi)}">${esc(h.musteri_adi)}</td>
    <td>${M(h.ciro/1e6)}M</td>
    <td style="color:${mcol(h.marj)}">%${M(h.marj)}<span style="color:var(--mut)"> /${M(h.krb_marj)}</span></td>
    <td>${h.vade!=null?M(h.vade)+"g":"—"}<span style="color:var(--mut)"> /${M(h.krb_vade)}g</span></td>
    <td>${h.overdue?MM(h.overdue):"—"}</td>
    <td style="white-space:normal">${(h.bayraklar||[]).map(b=>`<span style="display:inline-block;background:rgba(248,113,113,.13);color:var(--risk);border-radius:4px;padding:1px 5px;margin:1px;font-size:9.5px">${esc(BJ[b]||b)}</span>`).join("")}</td>
    <td style="color:var(--risk);font-weight:600">${MM(h.marj_drag)}</td>
  </tr>`).join("");
  el.innerHTML=head+`<div class="ma-scroll"><table class="mtab">
    <thead><tr><th>Müşteri</th><th>ciro</th><th>marj /KRB</th><th>vade /KRB</th><th>gecikmiş</th><th>bayrak</th><th>marj kaybı</th></tr></thead>
    <tbody>${rows}</tbody></table></div>
    <div class="cardfoot">KRB ortalamasını en çok düşüren müşteriler. Birini KRB ort.'a çekmek KRB metriğini yukarı çeker (ort. = müşterilerin hacim-ağırlıklı toplamı). Kaynak: bi_satis_faturalari × bi_marj_atom × bi_musteri_risk.</div>`;
}

'''
s = s.replace(A_fn, FN + A_fn, 1)

# (3) fetch — marj alarm fetch'inden sonra
A_fetch = "  try{ const MA=await jget('/api/bi/marj-alarm'); renderMarjAlarm(MA); }catch(e){ renderMarjAlarm({error:e.message}); } /* MARJALARM_UI_V1 */"
assert s.count(A_fetch) == 1, "marj-alarm fetch anchor"
s = s.replace(A_fetch, A_fetch + "\n  try{ const KY=await jget('/api/bi/iyilestirme-hedefleri'); renderKiyas(KY); }catch(e){ renderKiyas({error:e.message}); } /* SMARTKIYAS_KOKPIT_UI_V1 */", 1)

write(FP, s)
print("kiyas-kokpit: İyileştirme Hedefleri bölümü eklendi")
print("marker count:", s.count("SMARTKIYAS_KOKPIT_UI_V1"))
print("DONE.")
