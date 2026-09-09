#!/usr/bin/env python3
# ZIYARET_EK_V1 (client) — Ziyarete DOSYA eki (Yildiray Bilen 25 Agu; Fatih onayli).
#   Foto ile ayni 3 yer: yeni ziyaret formu (zf), ziyaret duzenleme (zd), ziyaret tamamlama (pt) + ziyaret detayinda indirilebilir liste.
#   Her tip dosya, 8MB. DUYURU_EK desenini yansitir. Anchorlar FOTO_DECODE_SAGLAM_V1'in DEGISTIRMEDIGI bolgelerde.
#   Idempotent (marker: ZIYARET_EK_V1).
import sys
path = sys.argv[1] if len(sys.argv) > 1 else "shells/saha.js"
with open(path, "r", encoding="utf-8") as f: src = f.read()
orig = src
MARK = "ZIYARET_EK_V1"
if MARK in src:
    print("[=] zaten mevcut (idempotent)"); sys.exit(0)

edits = []  # (ad, old, new)

# ── 0) Yardimcilar — fotoUrl fonksiyonundan sonra ──
anchor_help = '''async function fotoUrl(id) {
  if (S.fotoUrls.has(id)) return S.fotoUrls.get(id);
  const res = await fetch(`/api/saha/foto/${id}`, { headers: S.headers() });
  if (!res.ok) return "";
  const url = URL.createObjectURL(await res.blob());
  S.fotoUrls.set(id, url);
  return url;
}'''
help_new = anchor_help + '''

/* ''' + MARK + ''' — ziyaret dosya eki yardimcilari */
function _dosyaOku(file) {  // dosya → {dosya_adi, mime, veri(ham base64), boyut}
  return new Promise(resolve => {
    const r = new FileReader();
    r.onload = () => { const s = String(r.result || ""); const i = s.indexOf("base64,"); resolve({ dosya_adi: file.name || "dosya", mime: file.type || "application/octet-stream", veri: i >= 0 ? s.slice(i + 7) : s, boyut: file.size }); };
    r.onerror = () => resolve(null);
    try { r.readAsDataURL(file); } catch (e) { resolve(null); }
  });
}
async function _dosyaEkle(ev, hedef, listeId) {  // input change → hedef[] doldur + cip render
  const files = Array.from(ev.target.files || []);
  ev.target.value = "";
  let buyuk = 0, hata = 0;
  for (const file of files) {
    if (file.size > 8 * 1024 * 1024) { buyuk++; continue; }
    const d = await _dosyaOku(file);
    if (!d || !d.veri) { hata++; continue; }
    hedef.push(d);
    const el = document.getElementById(listeId);
    if (el) el.insertAdjacentHTML("beforeend", _dosyaCip(d));
  }
  if (buyuk) uyari(buyuk + " dosya 8MB sınırını aşıyor, eklenmedi.");
  if (hata) uyari(hata + " dosya okunamadı.");
}
function _dosyaBoyut(b) { b = Number(b) || 0; return b >= 1048576 ? (b / 1048576).toFixed(1) + " MB" : Math.max(1, Math.round(b / 1024)) + " KB"; }
function _dosyaIkon(mime, ad) { const mm = String(mime || "").toLowerCase(), aa = String(ad || "").toLowerCase(); if (mm.indexOf("pdf") >= 0 || aa.endsWith(".pdf")) return "📕"; if (mm.indexOf("image") >= 0) return "🖼"; if (mm.indexOf("sheet") >= 0 || mm.indexOf("excel") >= 0 || /\\.(xls|xlsx|csv)$/.test(aa)) return "📊"; if (mm.indexOf("word") >= 0 || /\\.(docx?|rtf)$/.test(aa)) return "📝"; if (mm.indexOf("zip") >= 0 || mm.indexOf("compress") >= 0 || /\\.(zip|rar|7z)$/.test(aa)) return "🗜"; return "📎"; }
function _dosyaCip(d) { return '<span class="dosya-cip" style="display:inline-flex;align-items:center;gap:6px;background:#f1f5f9;border:1px solid #e2e8f0;border-radius:8px;padding:5px 9px;margin:4px 4px 0 0;font-size:12px;color:#334155;max-width:230px;vertical-align:top">' + _dosyaIkon(d.mime, d.dosya_adi) + '<span style="overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + esc(d.dosya_adi || "dosya") + '</span><span style="color:#94a3b8;flex-shrink:0">' + _dosyaBoyut(d.boyut) + '</span></span>'; }
async function ziyEkAc(zid, ek) {  // auth'lu indir → blob → indir
  try {
    const res = await fetch(`/api/saha/ziyaretler/${zid}/ek/${ek.id}`, { headers: S.headers() });
    if (!res.ok) { uyari("Dosya açılamadı."); return; }
    const url = URL.createObjectURL(await res.blob());
    const a = document.createElement("a"); a.href = url; a.download = ek.dosya_adi || "dosya";
    document.body.appendChild(a); a.click(); a.remove();
    setTimeout(() => { try { URL.revokeObjectURL(url); } catch (e) {} }, 30000);
  } catch (e) { uyari("Dosya açılamadı: " + (e.message || "")); }
}
function ziyEklerRender(zid, ekler, kap, silSet) {  // detay (silSet yok) + duzenleme (silSet var: isaretle)
  const g = typeof kap === "string" ? document.getElementById(kap) : kap;
  if (!g) return;
  const duzenle = !!silSet;
  if (!ekler || !ekler.length) { g.innerHTML = duzenle ? '<span style="font-size:12px;color:#94a3b8">dosya yok</span>' : ""; return; }
  g.innerHTML = "";
  for (const ek of ekler) {
    const row = document.createElement("div");
    row.style.cssText = "display:flex;align-items:center;gap:8px;background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:8px 10px;margin-top:6px";
    row.innerHTML = '<span style="font-size:18px">' + _dosyaIkon(ek.mime, ek.dosya_adi) + '</span><span style="flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:13px;color:#1e293b">' + esc(ek.dosya_adi || "dosya") + '</span><span style="font-size:11px;color:#94a3b8;flex-shrink:0">' + _dosyaBoyut(ek.boyut) + '</span><button type="button" class="ek-ac" style="border:none;background:#0ea5e9;color:#fff;border-radius:6px;padding:4px 10px;font-size:12px;cursor:pointer;flex-shrink:0">Aç</button>' + (duzenle ? '<button type="button" class="ek-sil" title="Sil" style="border:none;background:#dc2626;color:#fff;border-radius:6px;padding:4px 9px;font-size:13px;line-height:1;cursor:pointer;flex-shrink:0">×</button>' : '');
    row.querySelector(".ek-ac").addEventListener("click", () => ziyEkAc(zid, ek));
    if (duzenle) { const sb = row.querySelector(".ek-sil"); sb.addEventListener("click", () => { if (silSet.has(ek.id)) { silSet.delete(ek.id); row.style.opacity = "1"; sb.style.background = "#dc2626"; } else { silSet.add(ek.id); row.style.opacity = "0.4"; sb.style.background = "#64748b"; } }); }
    g.appendChild(row);
  }
}'''
edits.append(("yardimcilar", anchor_help, help_new))

# ── FORM (zf) ──
# UI: Galeri label'inden sonra Dosya label
edits.append(("zf-ui-buton",
  '''        <label class="btn cizgili dosya-btn">🖼 Galeri<input type="file" id="zf-foto" accept="image/*" multiple hidden></label>''',
  '''        <label class="btn cizgili dosya-btn">🖼 Galeri<input type="file" id="zf-foto" accept="image/*" multiple hidden></label>
        <label class="btn cizgili dosya-btn">📎 Dosya<input type="file" id="zf-dosya" multiple hidden></label><!-- ''' + MARK + ''' -->'''))
# UI: foto-liste sonrasi dosya-liste
edits.append(("zf-ui-liste",
  '''      <div id="zf-foto-liste" class="foto-izgara"></div>''',
  '''      <div id="zf-foto-liste" class="foto-izgara"></div>
      <div id="zf-dosya-liste"></div><!-- ''' + MARK + ''' -->'''))
# collector: zf fotolar sonrasi dosyalar
edits.append(("zf-collector",
  '''  const konum = { lat: null, lng: null };
  const fotolar = [];
  document.getElementById("zf-konum")?.addEventListener("click", () => {''',
  '''  const konum = { lat: null, lng: null };
  const fotolar = [];
  const dosyalar = [];  /* ''' + MARK + ''' */
  document.getElementById("zf-konum")?.addEventListener("click", () => {'''))
# handler wiring: zf-foto-cam wiring'inden sonra zf-dosya wiring
edits.append(("zf-handler",
  '''  document.getElementById("zf-foto")?.addEventListener("change", _zfFotoEkle);
  document.getElementById("zf-foto-cam")?.addEventListener("change", _zfFotoEkle);''',
  '''  document.getElementById("zf-foto")?.addEventListener("change", _zfFotoEkle);
  document.getElementById("zf-foto-cam")?.addEventListener("change", _zfFotoEkle);
  document.getElementById("zf-dosya")?.addEventListener("change", ev => _dosyaEkle(ev, dosyalar, "zf-dosya-liste"));  /* ''' + MARK + ''' */'''))
# save: foto POST dongusunden sonra dosya POST
edits.append(("zf-save",
  '''      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${ziyaret.id}/foto`, {
          method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" })
        }).catch(() => {});
      }''',
  '''      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${ziyaret.id}/foto`, {
          method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" })
        }).catch(() => {});
      }
      for (const dz of dosyalar) {  /* ''' + MARK + ''' */
        await api(`/api/saha/ziyaretler/${ziyaret.id}/ek`, { method: "POST", body: JSON.stringify(dz) }).catch(() => {});
      }'''))

# ── DETAY ──
edits.append(("detay-html",
  '''    <div id="det-fotolar" class="foto-izgara"></div>''',
  '''    <div id="det-fotolar" class="foto-izgara"></div>
    <div id="det-ekler"></div><!-- ''' + MARK + ''' -->'''))
edits.append(("detay-load",
  '''      if (g && !g._buyutBound) { g._buyutBound = true; g.addEventListener("click", ev => { const im = ev.target.closest("img"); if (im) fotoBuyut(im.src); }); }  /* FOTO_BUYUT_V1 */
    } catch { /* foto yüklenemedi */ }
  }''',
  '''      if (g && !g._buyutBound) { g._buyutBound = true; g.addEventListener("click", ev => { const im = ev.target.closest("img"); if (im) fotoBuyut(im.src); }); }  /* FOTO_BUYUT_V1 */
    } catch { /* foto yüklenemedi */ }
  }
  try {  /* ''' + MARK + ''' — ziyaret dosya ekleri */
    const _er = await api(`/api/saha/ziyaretler/${zid}/ekler`);
    ziyEklerRender(zid, (_er && _er.ekler) || [], "det-ekler", null);
  } catch (e) { /* ek yüklenemedi */ }'''))

# ── DUZENLE (zd) ──
# UI: zd-foto-yeni sonrasi Dosyalar grubu
edits.append(("zd-ui",
  '''      <div id="zd-foto-yeni" class="foto-izgara"></div>
    </div>''',
  '''      <div id="zd-foto-yeni" class="foto-izgara"></div>
    </div>
    <div class="alan-grup"><span class="alan-baslik">Dosyalar</span><!-- ''' + MARK + ''' -->
      <div id="zd-ek-mevcut"><span style="font-size:12px;color:#94a3b8">yükleniyor…</span></div>
      <label class="btn cizgili dosya-btn" style="display:inline-block;margin-top:6px">📎 Dosya Ekle<input type="file" id="zd-dosya" multiple hidden></label>
      <div id="zd-dosya-yeni"></div>
    </div>'''))
# existing ek load + yeniDosyalar + zd-dosya wiring — "Yeni foto ekleme" oncesi/etrafi
edits.append(("zd-load-collector",
  '''  // Yeni foto ekleme
  const yeniFotolar = [];''',
  '''  // Yeni dosya ekleme (''' + MARK + ''')
  const ekSilinecek = new Set();
  const yeniDosyalar = [];
  (async () => {
    try { const _er = await api(`/api/saha/ziyaretler/${z.id}/ekler`); ziyEklerRender(z.id, (_er && _er.ekler) || [], "zd-ek-mevcut", ekSilinecek); }
    catch (e) { const _g = document.getElementById("zd-ek-mevcut"); if (_g) _g.innerHTML = '<span style="font-size:12px;color:#94a3b8">dosyalar yüklenemedi</span>'; }
  })();
  document.getElementById("zd-dosya")?.addEventListener("change", ev => _dosyaEkle(ev, yeniDosyalar, "zd-dosya-yeni"));

  // Yeni foto ekleme
  const yeniFotolar = [];'''))
# save: yeniFotolar POST'undan sonra ek sil + ek yukle
edits.append(("zd-save",
  '''      for (const f of yeniFotolar) {
        await api(`/api/saha/ziyaretler/${z.id}/foto`, { method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" }) }).catch(() => {});
      }''',
  '''      for (const f of yeniFotolar) {
        await api(`/api/saha/ziyaretler/${z.id}/foto`, { method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" }) }).catch(() => {});
      }
      for (const eid of ekSilinecek) {  /* ''' + MARK + ''' */
        await api(`/api/saha/ziyaretler/${z.id}/ek/${eid}`, { method: "DELETE" }).catch(() => {});
      }
      for (const dz of yeniDosyalar) {
        await api(`/api/saha/ziyaretler/${z.id}/ek`, { method: "POST", body: JSON.stringify(dz) }).catch(() => {});
      }'''))

# ── TAMAMLA (pt) ──
edits.append(("pt-ui-buton",
  '''      <label class="btn cizgili dosya-btn">📷 Foto<input type="file" id="pt-foto" accept="image/*" multiple hidden></label>''',
  '''      <label class="btn cizgili dosya-btn">📷 Foto<input type="file" id="pt-foto" accept="image/*" multiple hidden></label>
      <label class="btn cizgili dosya-btn">📎 Dosya<input type="file" id="pt-dosya" multiple hidden></label><!-- ''' + MARK + ''' -->'''))
edits.append(("pt-ui-liste",
  '''    <div id="pt-foto-liste" class="foto-izgara"></div>''',
  '''    <div id="pt-foto-liste" class="foto-izgara"></div>
    <div id="pt-dosya-liste"></div><!-- ''' + MARK + ''' -->'''))
edits.append(("pt-collector",
  '''  const konum = { lat: null, lng: null };
  const fotolar = [];
  document.getElementById("pt-konum")?.addEventListener("click", () => {''',
  '''  const konum = { lat: null, lng: null };
  const fotolar = [];
  const dosyalar = [];  /* ''' + MARK + ''' */
  document.getElementById("pt-dosya")?.addEventListener("change", ev => _dosyaEkle(ev, dosyalar, "pt-dosya-liste"));
  document.getElementById("pt-konum")?.addEventListener("click", () => {'''))
edits.append(("pt-save",
  '''      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${z.id}/foto`, { method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" }) }).catch(() => {});
      }''',
  '''      for (const f of fotolar) {
        await api(`/api/saha/ziyaretler/${z.id}/foto`, { method: "POST", body: JSON.stringify({ data: f, mime: "image/jpeg" }) }).catch(() => {});
      }
      for (const dz of dosyalar) {  /* ''' + MARK + ''' */
        await api(`/api/saha/ziyaretler/${z.id}/ek`, { method: "POST", body: JSON.stringify(dz) }).catch(() => {});
      }'''))

# ── uygula ──
for ad, old, new in edits:
    c = src.count(old)
    if c != 1:
        print("HATA: anchor '" + ad + "' " + str(c) + " kez bulundu (1 bekleniyor)"); sys.exit(1)
    src = src.replace(old, new, 1)
    print("[+] " + ad)

if src == orig:
    print("[=] Degisiklik yok"); sys.exit(1)
with open(path, "w", encoding="utf-8") as f: f.write(src)
print("[ok] yazildi:", path, "(", len(edits), "blok )")
