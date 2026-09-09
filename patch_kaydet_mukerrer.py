import sys, io
path = sys.argv[1]
with io.open(path, encoding="utf-8") as f: src = f.read()
if "MUKERRER_GUN_UI_V1" in src:
    print("[patch_kaydet_mukerrer] zaten uygulanmis, atlaniyor."); sys.exit(0)

HELPER = '''// MUKERRER_GUN_UI_V1 — soz veren onay kutusu (body-append; modal sistemine dokunmaz).
function _mukConfirm() {
  return new Promise(resolve => {
    const eski = document.getElementById("muk-onay"); if (eski) eski.remove();
    const el = document.createElement("div");
    el.id = "muk-onay";
    el.style.cssText = "position:fixed;inset:0;z-index:100000;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;padding:24px";
    el.innerHTML = '<div style="background:#fff;border-radius:16px;max-width:340px;width:100%;padding:20px;box-shadow:0 20px 60px rgba(0,0,0,.4)">'
      + '<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:8px">Bu musteride bugun kayit var</div>'
      + '<div style="font-size:13px;color:#475569;line-height:1.5;margin-bottom:16px">Bugun bu musteri icin tamamlanmis bir ziyaret zaten var. Mevcut kaydi duzenlemek mi istersin, yoksa yeni bir kayit mi acalim?</div>'
      + '<div style="display:flex;gap:8px">'
      + '<button id="muk-duzenle" style="flex:1;padding:11px;border:1.5px solid #cbd5e1;background:#fff;color:#0f172a;border-radius:10px;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer">Mevcudu duzenle</button>'
      + '<button id="muk-yeni" style="flex:1;padding:11px;border:none;background:#0284c7;color:#fff;border-radius:10px;font-size:13px;font-weight:700;font-family:inherit;cursor:pointer">Yeni kayit ac</button>'
      + '</div></div>';
    document.body.appendChild(el);
    const bitir = v => { el.remove(); resolve(v); };
    el.querySelector("#muk-duzenle").addEventListener("click", () => bitir(false));
    el.querySelector("#muk-yeni").addEventListener("click", () => bitir(true));
    el.addEventListener("click", ev => { if (ev.target === el) bitir(false); });
  });
}
'''

ANCHOR = 'async function ziyaretFormModal(mus, mod, presetDate = null) {'
if src.count(ANCHOR) != 1:
    sys.stderr.write("[patch_kaydet_mukerrer] HATA: ziyaretFormModal anchor tekil degil.\n"); sys.exit(2)
src = src.replace(ANCHOR, HELPER + ANCHOR, 1)

OLD = '''    try {
      const { ziyaret } = await api("/api/saha/ziyaretler", {
        method: "POST",
        body: JSON.stringify({
          musteri_id: mus.id, tip,
          lokasyon_id: document.getElementById("zf-lokasyon")?.value || null,
          tamamla: !planla,
          ziyaret_tarihi: planla ? null : g("zf-tarih"),
          planlanan_tarih: planla ? g("zf-tarih") : null,
          katilimci: g("zf-katilimci") || null, notlar: g("zf-not") || null, detay
        })
      });'''

NEW = '''    try {
      // MUKERRER_GUN_UI_V1 — ayni gun ikinci "tamamlandi" kaydinda sor
      const _zfBody = force => JSON.stringify({
        musteri_id: mus.id, tip,
        lokasyon_id: document.getElementById("zf-lokasyon")?.value || null,
        tamamla: !planla,
        ziyaret_tarihi: planla ? null : g("zf-tarih"),
        planlanan_tarih: planla ? g("zf-tarih") : null,
        katilimci: g("zf-katilimci") || null, notlar: g("zf-not") || null, detay,
        force_yeni: force === true
      });
      let _resp = await api("/api/saha/ziyaretler", { method: "POST", body: _zfBody(false) });
      if (_resp && _resp.mukerrer_gun) {
        const _mev = _resp.mevcut || {};
        const _yeni = await _mukConfirm();
        if (_yeni) {
          _resp = await api("/api/saha/ziyaretler", { method: "POST", body: _zfBody(true) });
        } else {
          kapatModal();
          await loadView("ziyaretler");
          if (_mev.id) ziyaretDetayModal(_mev.id);
          return;
        }
      }
      const ziyaret = _resp.ziyaret;'''

if src.count(OLD) != 1:
    sys.stderr.write("[patch_kaydet_mukerrer] HATA: kaydet POST blogu tekil degil.\n"); sys.exit(2)
src = src.replace(OLD, NEW, 1)
with io.open(path, "w", encoding="utf-8") as f: f.write(src)
print("[patch_kaydet_mukerrer] uygulandi.")
