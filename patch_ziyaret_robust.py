import sys, io
p = sys.argv[1]
s = io.open(p, encoding="utf-8").read()
if "ZIYARET_ROBUST_V1" in s:
    print("[patch_ziyaret_robust] zaten uygulanmis, atlaniyor."); sys.exit(0)

OLD1 = '''  try {
    const { ziyaretler } = await api(`/api/saha/ziyaretler?durum=TAMAMLANDI${tipQS()}`);
    S.ziyaretler = ziyaretler;'''
NEW1 = '''  try {
    // ZIYARET_ROBUST_V1 — yavas/kesik yanitta cokme yerine "yeniden dene"
    const _zr = await api(`/api/saha/ziyaretler?durum=TAMAMLANDI${tipQS()}`);
    const ziyaretler = (_zr && Array.isArray(_zr.ziyaretler)) ? _zr.ziyaretler : null;
    if (ziyaretler === null) {
      main().innerHTML = `<div class="saha-bos">Ziyaretler yuklenemedi (baglanti yavas olabilir).<br><button class="btn" id="ziy-retry" style="margin-top:10px">Yeniden dene</button></div>`;
      document.getElementById("ziy-retry")?.addEventListener("click", () => loadView("ziyaretler"));
      return;
    }
    S.ziyaretler = ziyaretler;'''

OLD2 = '''async function ziyaretDetayModal(zid) {
  let z = (S.ziyaretler || []).find(x => x.id === zid);
  if (!z) {
    try { z = (await api(`/api/saha/ziyaretler/${zid}`)).ziyaret; } catch {}
  }
  z = z || {};'''
NEW2 = '''async function ziyaretDetayModal(zid) {
  // ZIYARET_ROBUST_V1 — liste notu kisaltildi; detay icin tam kaydi cek (yoksa cache)
  let z = null;
  try { z = (await api(`/api/saha/ziyaretler/${zid}`)).ziyaret; } catch {}
  if (!z) z = (S.ziyaretler || []).find(x => x.id === zid);
  z = z || {};'''

for i,(o,n) in enumerate([(OLD1,NEW1),(OLD2,NEW2)]):
    if s.count(o) != 1:
        sys.stderr.write("[patch_ziyaret_robust] HATA: anchor %d = %d (1 bekleniyordu)\n" % (i,s.count(o))); sys.exit(2)
    s = s.replace(o,n,1)
io.open(p,"w",encoding="utf-8").write(s)
print("[patch_ziyaret_robust] uygulandi (2 edit).")
