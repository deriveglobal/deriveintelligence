#!/usr/bin/env python3
# MARJDESEN_UI_V1 — Marj Alarmi satirlarini tiklayinca DESEN kirilimine ac (ac/kapa).
# Boyut (marka×ebat) ozet kalir; tiklayinca altina o ebatteki desenler (kalem) eklenir. kokpit.html.
# /api/bi/marj-alarm-desen tuketir. Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/kokpit.html"
s = read(FP)
if "MARJDESEN_UI_V1" in s:
    print("marjdesen-ui: already present, skip"); print("DONE."); raise SystemExit
assert "MARJALARM_UI_V1" in s, "once MARJALARM_UI_V1 uygulanmali"

# (1) Toggle fonksiyonu — renderMarjAlarm'dan once
A_fn = "function renderMarjAlarm(d){"
assert s.count(A_fn) == 1, "renderMarjAlarm anchor"
FN = '''/* MARJDESEN_UI_V1 */
async function _marjDesenToggle(tr, hedef, ay){
  const marka=tr.getAttribute("data-marka"), ebat=tr.getAttribute("data-ebat");
  const cr=tr.querySelector(".ma-caret");
  let nx=tr.nextElementSibling;
  if(nx && nx.classList.contains("desen-sub")){
    while(nx && nx.classList.contains("desen-sub")){ const rem=nx; nx=nx.nextElementSibling; rem.remove(); }
    if(cr)cr.textContent="\\u25B8"; return;
  }
  if(cr)cr.textContent="\\u25BE";
  let d; try{ d=await jget("/api/bi/marj-alarm-desen?marka="+encodeURIComponent(marka)+"&ebat="+encodeURIComponent(ebat)+"&hedef="+hedef+"&ay="+ay); }catch(e){ if(cr)cr.textContent="\\u25B8"; return; }
  const list=(d&&d.desenler)||[];
  const html=list.length? list.map(x=>`<tr class="desen-sub">
    <td class="ma-nm" style="padding-left:28px;color:var(--ink2)" title="${esc(x.desen)}">${esc(x.desen)}</td>
    <td>${M(x.adet)}</td><td>${M(x.ciro/1e6)}M</td>
    <td style="color:${mcol(x.marj_pct)}">%${M(x.marj_pct)}</td>
    <td>${M(x.avg_satis)}</td><td>${x.repl_cost!=null?M(x.repl_cost):"\\u2014"}</td>
    <td style="color:var(--accent)">${x.onerilen_taban!=null?M(x.onerilen_taban):"\\u2014"}</td>
    <td style="color:var(--risk)">${MM(x.leak)}</td></tr>`).join("")
    : `<tr class="desen-sub"><td colspan="8" style="padding-left:28px;color:var(--mut)">desen verisi yok</td></tr>`;
  tr.insertAdjacentHTML("afterend", html);
}
'''
s = s.replace(A_fn, FN + A_fn, 1)

# (2) tr'yi tiklanabilir yap + data-marka/ebat
A_tr = '<tr class="${x.maliyet_alti?\'ma-neg\':\'\'}">'
assert s.count(A_tr) == 1, "marjalarm tr anchor"
N_tr = '<tr class="ma-row ${x.maliyet_alti?\'ma-neg\':\'\'}" data-marka="${esc(x.marka)}" data-ebat="${esc(x.ebat)}" style="cursor:pointer">'
s = s.replace(A_tr, N_tr, 1)

# (3) ma-nm hucresine caret
A_nm = '<td class="ma-nm" title="${esc(x.marka)} ${esc(x.ebat)}">${esc(x.marka)} <span style="color:var(--ink2)">${esc(x.ebat)}</span></td>'
assert s.count(A_nm) == 1, "ma-nm anchor"
N_nm = '<td class="ma-nm" title="${esc(x.marka)} ${esc(x.ebat)}"><span class="ma-caret" style="color:var(--mut);font-size:9px">\\u25B8</span> ${esc(x.marka)} <span style="color:var(--ink2)">${esc(x.ebat)}</span></td>'
s = s.replace(A_nm, N_nm, 1)

# (4) render sonrasi satirlara click bagla
A_end = 'Kaynak: bi_marj_atom × bi_tedarikci_faturalari × bi_satis_faturalari.</div>`;'
assert s.count(A_end) == 1, "marjalarm cardfoot anchor"
N_end = A_end + '\n  el.querySelectorAll("tr.ma-row").forEach(function(tr){ tr.addEventListener("click", function(){ _marjDesenToggle(tr, d.hedef, d.ay); }); }); /* MARJDESEN_UI_V1 */'
s = s.replace(A_end, N_end, 1)

write(FP, s)
print("marjdesen-ui: satir-ac/kapa + desen alt-satirlari eklendi")
print("marker count:", s.count("MARJDESEN_UI_V1"))
print("DONE.")
