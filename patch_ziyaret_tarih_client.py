import sys, io
p = sys.argv[1]; s = io.open(p, encoding="utf-8").read()
if "ZIYARET_TARIH_GUARD_V1" in s:
    print("[patch_ziyaret_tarih_client] zaten uygulanmis, atlaniyor."); sys.exit(0)

HELPER = '''// ZIYARET_TARIH_GUARD_V1 — geç-tarih onay kutusu (body-append)
function _tarihOnay(mesaj) {
  return new Promise(resolve => {
    const eski = document.getElementById("tarih-onay"); if (eski) eski.remove();
    const el = document.createElement("div");
    el.id = "tarih-onay";
    el.style.cssText = "position:fixed;inset:0;z-index:100002;background:rgba(0,0,0,.5);display:flex;align-items:center;justify-content:center;padding:24px";
    el.innerHTML = '<div style="background:#fff;border-radius:16px;max-width:340px;width:100%;padding:20px;box-shadow:0 20px 60px rgba(0,0,0,.4)">'
      + '<div style="font-size:15px;font-weight:700;color:#0f172a;margin-bottom:8px">Tarihi dogrula</div>'
      + '<div style="font-size:13px;color:#475569;line-height:1.5;margin-bottom:16px">' + String(mesaj).replace(/</g,"&lt;") + '</div>'
      + '<div style="display:flex;gap:8px">'
      + '<button id="to-vazgec" style="flex:1;padding:11px;border:1.5px solid #cbd5e1;background:#fff;color:#0f172a;border-radius:10px;font-size:13px;font-weight:600;font-family:inherit;cursor:pointer">Duzelt</button>'
      + '<button id="to-evet" style="flex:1;padding:11px;border:none;background:#0284c7;color:#fff;border-radius:10px;font-size:13px;font-weight:700;font-family:inherit;cursor:pointer">Evet, dogru</button>'
      + '</div></div>';
    document.body.appendChild(el);
    const bitir = v => { el.remove(); resolve(v); };
    el.querySelector("#to-evet").addEventListener("click", () => bitir(true));
    el.querySelector("#to-vazgec").addEventListener("click", () => bitir(false));
    el.addEventListener("click", ev => { if (ev.target === el) bitir(false); });
  });
}
'''
A_OLD = 'async function ziyaretFormModal(mus, mod, presetDate = null) {'
A_NEW = HELPER + A_OLD

B_OLD = '  const tarihDeger = presetDate || bugun;'
B_NEW = B_OLD + '\n  const enEski = new Date(Date.now() - 400 * 86400000).toLocaleDateString(\'en-CA\', { timeZone: \'Europe/Istanbul\' }); // ZIYARET_TARIH_GUARD_V1 taban (~13 ay)'

C_OLD = '    <label>Tarih<input type="date" class="giris" id="zf-tarih" value="${tarihDeger}"></label>'
C_NEW = '    <label>Tarih<input type="date" class="giris" id="zf-tarih" value="${tarihDeger}" ${mod === "planla" ? `min="${bugun}"` : `max="${bugun}" min="${enEski}"`}></label>'

D_OLD = '''  const kaydet = async (planla) => {
    const g = id => document.getElementById(id)?.value.trim() || "";
    const n = id => { const v = g(id); return v ? Number(v) : null; };'''
D_NEW = D_OLD + '''
    // ZIYARET_TARIH_GUARD_V1 — kirli tarih onle: gelecek yok, cok eski yok, gec-tarih onayi
    {
      const _t = g("zf-tarih");
      if (!planla && _t) {
        if (_t > bugun) { uyari("Tamamlanan ziyaret ileri (gelecek) tarihli olamaz."); return; }
        if (_t < enEski) { uyari("Tarih cok eski gorunuyor — lutfen yili kontrol edin."); return; }
        if (_t < bugun) {
          const _gun = Math.round((new Date(bugun) - new Date(_t)) / 86400000);
          if (_gun > 7 && !(await _tarihOnay(`Bu ziyaret ${_gun} gun onceye (${_t}) tarihli. Dogru mu?`))) return;
        }
      } else if (planla && _t && _t < bugun) {
        uyari("Planlanan ziyaret gecmis tarihe olamaz."); return;
      }
    }'''

for i,(o,n) in enumerate([(A_OLD,A_NEW),(B_OLD,B_NEW),(C_OLD,C_NEW),(D_OLD,D_NEW)]):
    if s.count(o) != 1:
        sys.stderr.write("[client] HATA edit %d anchor=%d (1 bekleniyordu)\n" % (i,s.count(o))); sys.exit(2)
    s = s.replace(o,n,1)
io.open(p,"w",encoding="utf-8").write(s)
print("[patch_ziyaret_tarih_client] uygulandi (4 edit).")
