#!/usr/bin/env python3
# MARJALARM_UI_V1 — Kokpit'e "Marj Alarmı" bölümü (Seviye 1). /api/bi/marj-alarm tüketir.
# Toplam yıllık sızıntı başlığı + SKU tablosu (marj%, ort satış, yenileme maliyeti, önerilen taban,
# sızıntı; maliyet-altı satır kırmızı). Kaynak dosya shells/kokpit.html (kokpit_new.html içeriği).
# Idempotent.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "shells/kokpit.html"
s = read(FP)
if "MARJALARM_UI_V1" in s:
    print("marjalarm: already present, skip"); print("DONE."); raise SystemExit

# (1) CSS — </style> öncesi
A1 = "  .empty{color:var(--mut);font-size:11.5px;font-family:var(--mono)}\n</style>"
assert s.count(A1) == 1, "css anchor"
CSS = """  .empty{color:var(--mut);font-size:11.5px;font-family:var(--mono)}
  /* MARJALARM_UI_V1 */
  .ma-head{display:flex;gap:28px;margin-bottom:12px;flex-wrap:wrap}
  .ma-head .l{font-size:10px;text-transform:uppercase;letter-spacing:.4px;color:var(--ink2)}
  .ma-head .v{font-family:var(--mono);font-size:22px;font-weight:600;margin-top:2px}
  .ma-scroll{max-height:430px;overflow:auto}
  .ma-scroll::-webkit-scrollbar{width:6px;height:6px}.ma-scroll::-webkit-scrollbar-thumb{background:var(--hair2);border-radius:6px}
  table.mtab{width:100%;border-collapse:collapse;font-size:12px}
  table.mtab th{position:sticky;top:0;background:var(--card);text-align:right;font-weight:500;color:var(--mut);font-size:10px;text-transform:uppercase;letter-spacing:.4px;padding:7px 10px;border-bottom:1px solid var(--hair2);white-space:nowrap}
  table.mtab th:first-child{text-align:left}
  table.mtab td{padding:6px 10px;border-bottom:1px solid var(--hair);text-align:right;white-space:nowrap;font-family:var(--mono)}
  table.mtab td.ma-nm{text-align:left;font-family:var(--font);max-width:230px;overflow:hidden;text-overflow:ellipsis}
  table.mtab tr.ma-neg td{background:rgba(248,113,113,.07)}
  table.mtab tbody tr:hover td{background:rgba(255,255,255,.035)}
</style>"""
s = s.replace(A1, CSS, 1)

# (2) HTML — breakdowns grid'inden SONRA
A2 = '  <div class="grid" id="breakdowns"></div>\n'
assert s.count(A2) == 1, "breakdowns anchor"
HTML = A2 + '''
  <div class="grid"><!-- MARJALARM_UI_V1 -->
    <div class="card" style="grid-column:span 12"><h3>🩸 Marj Alarmı <span class="tag">maliyet fiyatı geçti · yenileme maliyeti tabanı</span></h3><div id="marjalarm"><div class="empty">yükleniyor…</div></div></div>
  </div>
'''
s = s.replace(A2, HTML, 1)

# (3) JS render fonksiyonu — load bloğundan ÖNCE
A3 = "/* ---------- load ---------- */"
assert s.count(A3) == 1, "load anchor"
FN = '''/* MARJALARM_UI_V1 */
function renderMarjAlarm(d){
  const el=$("marjalarm");if(!el)return;
  if(!d||d.error||!Array.isArray(d.skular)||!d.skular.length){el.innerHTML=`<div class="empty">Marj alarmı verisi yok${d&&d.error?': '+esc(d.error):''}.</div>`;return;}
  const head=`<div class="ma-head">
    <div><div class="l">Toplam yıllık sızıntı</div><div class="v" style="color:var(--risk)">${MM(d.toplam_sizinti)}</div></div>
    <div><div class="l">Alarmlı SKU</div><div class="v">${d.sku_sayisi}</div></div>
    <div><div class="l">Hedef marj</div><div class="v">%${M(d.hedef*100)}</div></div>
  </div>`;
  const rows=d.skular.slice(0,50).map(x=>`<tr class="${x.maliyet_alti?'ma-neg':''}">
    <td class="ma-nm" title="${esc(x.marka)} ${esc(x.ebat)}">${esc(x.marka)} <span style="color:var(--ink2)">${esc(x.ebat)}</span></td>
    <td>${M(x.adet)}</td>
    <td>${M(x.ciro/1e6)}M</td>
    <td style="color:${mcol(x.marj_pct)}">%${M(x.marj_pct)}</td>
    <td>${M(x.avg_satis)}</td>
    <td>${x.repl_cost!=null?M(x.repl_cost):'—'}</td>
    <td style="color:var(--accent)">${x.onerilen_taban!=null?M(x.onerilen_taban):'—'}</td>
    <td style="color:var(--risk);font-weight:600">${MM(x.leak)}</td>
  </tr>`).join("");
  el.innerHTML=head+`<div class="ma-scroll"><table class="mtab">
    <thead><tr><th>SKU</th><th>adet</th><th>ciro</th><th>marj</th><th>ort satış</th><th>yenileme mal.</th><th>önerilen taban</th><th>sızıntı/yıl</th></tr></thead>
    <tbody>${rows}</tbody></table></div>
    <div class="cardfoot">Kırmızı = ort. satış yenileme maliyetinin ALTINDA. Önerilen taban = yenileme ÷ (1−hedef). Kaynak: bi_marj_atom × bi_tedarikci_faturalari × bi_satis_faturalari.</div>`;
}

'''
s = s.replace(A3, FN + A3, 1)

# (4) fetch — renderAI'dan sonra
A4 = ("  try{ FI=await jget('/api/bi/finansal-icgoru'); if(FI&&FI.error)FI=null; }catch(e){FI=null;}\n"
      "  renderKpis();renderChips();renderHero();renderAI();")
assert s.count(A4) == 1, "fetch anchor"
N4 = A4 + "\n  try{ const MA=await jget('/api/bi/marj-alarm'); renderMarjAlarm(MA); }catch(e){ renderMarjAlarm({error:e.message}); } /* MARJALARM_UI_V1 */"
s = s.replace(A4, N4, 1)

write(FP, s)
print("marjalarm: CSS + HTML + renderMarjAlarm + fetch eklendi")
print("marker count:", s.count("MARJALARM_UI_V1"))
print("DONE.")
