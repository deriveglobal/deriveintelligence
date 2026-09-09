import sys
F=sys.argv[1] if len(sys.argv)>1 else "shells/saha.js"
s=open(F,encoding="utf-8").read()
if "KONTROL_BIRLESTIR_V1" in s: print("[skip] zaten var"); sys.exit(0)
def rep(old,new,tag):
    global s
    assert s.count(old)==1, "anchor %s count=%d"%(tag,s.count(old))
    s=s.replace(old,new,1); print("[ok]",tag)
# 1) Olası eş bloğuna tek-tık "Bununla birleştir" butonu (skor>=0.6)
rep(
'''<span style="color:#94a3b8">(benzerlik ${m.oneri_skor ?? "-"})</span></div>`''',
'''<span style="color:#94a3b8">(benzerlik ${m.oneri_skor ?? "-"})</span>${(m.oneri_id && Number(m.oneri_skor) >= 0.6) ? ` <button class="btn" data-kbo="${m.id}" data-hedef="${m.oneri_id}" data-hadi="${esc(m.oneri_firma)}" style="font-size:11px;padding:4px 9px;background:#16a34a;color:#fff;margin-top:4px">🔗 Bununla birleştir</button>` : ``}</div>` /* KONTROL_BIRLESTIR_V1 */''',
"oneri-buton")
# 2) data-kbo wiring (data-ke wiring'inden hemen sonra)
rep(
'''  box.querySelectorAll("[data-ke]").forEach(b => b.addEventListener("click", () => erpEslesModal(b.dataset.ke)));''',
'''  box.querySelectorAll("[data-ke]").forEach(b => b.addEventListener("click", () => erpEslesModal(b.dataset.ke)));
  box.querySelectorAll("[data-kbo]").forEach(b => b.addEventListener("click", async () => { /* KONTROL_BIRLESTIR_V1 */
    if (!confirm(`Bu kayıt "${b.dataset.hadi}" ile birleştirilsin mi? Ziyaretler o müşteriye taşınır.`)) return;
    try { await api("/api/saha/kontrol-musteri-karar", { method: "POST", body: JSON.stringify({ id: b.dataset.kbo, karar: "BIRLESTIR", hedef_id: b.dataset.hedef }) }); uyari("✓ Birleştirildi.", true); kontrolPaneliYukle(); }
    catch (e) { uyari(e.message); }
  }));''',
"kbo-wire")
open(F,"w",encoding="utf-8").write(s); print("[done] KONTROL_BIRLESTIR_V1")
