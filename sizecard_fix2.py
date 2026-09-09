#!/usr/bin/env python3
# SIZECARD fix2 — live as-you-type search, full product name (SKU/kalem_kodu keyed).
# Replaces the ebat-ara/ebat-kart endpoints and the vEbatKart room. Idempotent. Run in /opt/krb-assessment.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

# ================= server_container.mjs: replace both endpoints =================
SP = "server_container.mjs"
s = read(SP)
new_srv = r'''    if (request.method === "GET" && url.pathname === "/api/bi/ebat-ara") {
      // EBAT_ARA_V2 — canli arama, tam urun adi, SKU (kalem_kodu) bazli.
      let s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let ss = s ? null : await requireSahaAccess(request).catch(() => null);
      const sess = s || ss;
      if (!sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));
      if (!ok && ss) { try { const g = await query("SELECT 1 FROM bi_arac_yetki WHERE tenant_id::text=$1 AND user_id=$2 AND arac_kod='ebat_kart' AND aktif=true LIMIT 1", [ss.tenantId, ss.userId]); ok = g.rowCount > 0; } catch (e) {} }
      if (!ok) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = sess.tenantId;
      const q = (url.searchParams.get("q") || "").replace(/[^0-9]/g, "");
      if (q.length < 2) { sendJson(response, 200, { sonuclar: [] }); return; }
      try {
        const rows = (await query("SELECT a.kalem_kodu, (SELECT sf.kalem_tanimi FROM bi_satis_faturalari sf WHERE sf.tenant_id::text=$1 AND sf.kalem_kodu=a.kalem_kodu AND sf.kalem_tanimi IS NOT NULL ORDER BY sf.fatura_tarihi DESC LIMIT 1) ad, max(a.marka) marka, max(a.ebat) ebat, sum(a.adet) adet FROM bi_marj_atom a WHERE a.tenant_id::text=$1 AND a.kalem_kodu IS NOT NULL AND regexp_replace(coalesce(a.ebat,''), '[^0-9]', '', 'g') LIKE $2 || '%' GROUP BY a.kalem_kodu HAVING sum(a.adet) > 0 ORDER BY sum(a.ciro) DESC NULLS LAST LIMIT 40", [T, q])).rows;
        sendJson(response, 200, { sonuclar: rows.map(r => ({ kalem_kodu: r.kalem_kodu, ad: (r.ad || [r.marka, r.ebat].filter(Boolean).join(" ") || r.kalem_kodu), adet: r.adet != null ? Number(r.adet) : null })) });
      } catch (e) { sendJson(response, 500, { error: "arama hatasi" }); }
      return;
    }
    if (request.method === "GET" && url.pathname === "/api/bi/ebat-kart") {
      let s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let ss = s ? null : await requireSahaAccess(request).catch(() => null);
      const sess = s || ss;
      if (!sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));
      if (!ok && ss) { try { const g = await query("SELECT 1 FROM bi_arac_yetki WHERE tenant_id::text=$1 AND user_id=$2 AND arac_kod='ebat_kart' AND aktif=true LIMIT 1", [ss.tenantId, ss.userId]); ok = g.rowCount > 0; } catch (e) {} }
      if (!ok) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = sess.tenantId;
      const kalem = (url.searchParams.get("kalem") || "").trim();
      const ay = Math.min(24, Math.max(1, parseInt(url.searchParams.get("ay") || "12", 10)));
      if (!kalem) { sendJson(response, 400, { error: "kalem zorunlu" }); return; }
      const out = { satis_adet: null, alis_adet: null, ag_satis_fiyat: null, ag_maliyet: null, marj_tl: null, marj_pct: null, min_fiyat: null, med_fiyat: null, max_fiyat: null, alis_vade: null, satis_vade: null, alicilar: [] };
      try {
        const mj = (await query("SELECT sum(adet) adet, sum(ciro) ciro, sum(brut_kar) kar FROM bi_marj_atom WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND ay >= (CURRENT_DATE - ($3::int * INTERVAL '1 month'))", [T, kalem, ay])).rows[0];
        if (mj && mj.adet) {
          out.satis_adet = Number(mj.adet);
          out.marj_tl = mj.kar != null ? Number(mj.kar) : null;
          out.ag_satis_fiyat = (mj.ciro != null && Number(mj.adet)) ? Number(mj.ciro) / Number(mj.adet) : null;
          out.ag_maliyet = (mj.ciro != null && mj.kar != null && Number(mj.adet)) ? (Number(mj.ciro) - Number(mj.kar)) / Number(mj.adet) : null;
          out.marj_pct = (mj.kar != null && Number(mj.ciro)) ? Number(mj.kar) / Number(mj.ciro) * 100 : null;
        }
      } catch (e) {}
      try {
        const st = (await query("SELECT min(birim_fiyat) mn, max(birim_fiyat) mx, percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat) med, sum((vade_tarihi - fatura_tarihi)::numeric * satir_tutar)/nullif(sum(satir_tutar),0) vade_w FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND fatura_tarihi >= (CURRENT_DATE - ($3::int * INTERVAL '1 month')) AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))", [T, kalem, ay])).rows[0];
        if (st) { out.min_fiyat = st.mn != null ? Number(st.mn) : null; out.med_fiyat = st.med != null ? Number(st.med) : null; out.max_fiyat = st.mx != null ? Number(st.mx) : null; out.satis_vade = st.vade_w != null ? Number(st.vade_w) : null; }
      } catch (e) {}
      try {
        const al = (await query("SELECT * FROM (SELECT DISTINCT ON (musteri_kodu) musteri_kodu, musteri_adi, birim_fiyat, (vade_tarihi - fatura_tarihi) vade_gun, odeme_kosulu, fatura_tarihi FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND fatura_tarihi >= (CURRENT_DATE - ($3::int * INTERVAL '1 month')) ORDER BY musteri_kodu, fatura_tarihi DESC) x ORDER BY fatura_tarihi DESC LIMIT 10", [T, kalem, ay])).rows;
        out.alicilar = al.map(r => ({ musteri: r.musteri_adi, fiyat: r.birim_fiyat != null ? Number(r.birim_fiyat) : null, vade: r.vade_gun != null ? Number(r.vade_gun) : null, odeme: r.odeme_kosulu || null }));
      } catch (e) {}
      try {
        const pu = (await query("SELECT sum(miktar) adet, sum(vade_gun::numeric * satir_kdv_haric)/nullif(sum(satir_kdv_haric),0) vade_w FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND kalem_kodu=$2 AND fatura_tarihi >= (CURRENT_DATE - ($3::int * INTERVAL '1 month'))", [T, kalem, ay])).rows[0];
        if (pu) { out.alis_adet = pu.adet != null ? Number(pu.adet) : null; out.alis_vade = pu.vade_w != null ? Number(pu.vade_w) : null; }
      } catch (e) {}
      sendJson(response, 200, out);
      return;
    }
'''
if "EBAT_ARA_V2" in s:
    print("SERVER: already V2, skip")
else:
    i = s.index('    if (request.method === "GET" && url.pathname === "/api/bi/ebat-ara") {')
    j = s.index('  if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {', i)
    s = s[:i] + new_srv + s[j:]
    write(SP, s)
    print("SERVER: endpoints -> V2 (kalem-keyed, full name)")

# ================= shells/saha.js: replace vEbatKart room =================
FP = "shells/saha.js"
t = read(FP)
new_ek = r'''// EBAT_KART_V2 — yonetim araci: canli arama, tam urun adi, SKU marj + son 10 alici.
let _ekState = { kalem: null, ad: null, ay: 12 };
async function vEbatKart() {
  const m = main();
  m.innerHTML = '<div class="ek-wrap" style="padding:14px;max-width:720px;margin:0 auto;color:#0f172a">'
    + '<div style="display:flex;align-items:center;gap:8px;margin-bottom:12px"><button id="ek-geri" class="btn" style="padding:6px 10px">‹ Geri</button><b style="font-size:16px">📐 Ebat Karti</b></div>'
    + '<input id="ek-q" placeholder="Ebat / urun ara: 385 65 22.5" autocomplete="off" style="width:100%;box-sizing:border-box;padding:11px;border:1px solid #cbd5e1;border-radius:8px;font-size:14px;background:#fff;color:#0f172a">'
    + '<div id="ek-sonuc" style="margin-top:6px"></div><div id="ek-kart" style="margin-top:12px"></div></div>';
  m.querySelector("#ek-geri").addEventListener("click", () => renderReception());
  const inp = m.querySelector("#ek-q");
  let _t = null;
  const run = async () => {
    const q = inp.value.trim();
    const box = m.querySelector("#ek-sonuc");
    if (q.replace(/[^0-9]/g, "").length < 2) { box.innerHTML = ""; return; }
    try {
      const { sonuclar = [] } = await api("/api/bi/ebat-ara?q=" + encodeURIComponent(q));
      if (!sonuclar.length) { box.innerHTML = '<div style="color:#94a3b8;font-size:13px;padding:6px">Sonuc yok.</div>'; return; }
      box.innerHTML = sonuclar.map(x => '<button class="ek-pick" data-kalem="' + esc(x.kalem_kodu || "") + '" data-ad="' + esc(x.ad || "") + '" style="display:flex;justify-content:space-between;gap:8px;width:100%;text-align:left;padding:10px;margin-bottom:4px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;color:#0f172a;cursor:pointer"><span>' + esc(x.ad || "") + '</span><span style="color:#64748b;font-size:12px;white-space:nowrap">' + (x.adet != null ? Number(x.adet).toLocaleString("tr-TR") + " ad" : "") + '</span></button>').join("");
      box.querySelectorAll(".ek-pick").forEach(b => b.addEventListener("click", () => {
        _ekState.kalem = b.dataset.kalem; _ekState.ad = b.dataset.ad;
        inp.value = b.dataset.ad; box.innerHTML = ""; _ekLoad();
      }));
    } catch (e) { box.innerHTML = '<div style="color:#dc2626;font-size:13px;padding:6px">Arama hatasi.</div>'; }
  };
  inp.addEventListener("input", () => { clearTimeout(_t); _t = setTimeout(run, 220); });
  setTimeout(() => inp.focus(), 60);
}
async function _ekLoad() {
  const m = main(); const kart = m.querySelector("#ek-kart");
  if (!kart || !_ekState.kalem) return;
  const money = v => v == null ? "—" : Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const num = v => v == null ? "—" : Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 0 });
  const pct = v => v == null ? "—" : "%" + Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 1 });
  const P = [3, 6, 9, 12];
  kart.innerHTML = '<div style="font-weight:700;font-size:14px;margin-bottom:8px">' + esc(_ekState.ad || "") + '</div>'
    + '<div style="display:flex;gap:6px;margin-bottom:10px">' + P.map(p => '<button class="ek-ay" data-ay="' + p + '" style="flex:1;padding:8px;border:1px solid ' + (p === _ekState.ay ? "#7c3aed" : "#cbd5e1") + ';background:' + (p === _ekState.ay ? "#7c3aed" : "#fff") + ';color:' + (p === _ekState.ay ? "#fff" : "#334155") + ';border-radius:8px;font-size:13px">' + p + ' ay</button>').join("") + '</div>'
    + '<div id="ek-metrik"><div style="color:#94a3b8;font-size:13px">Yukleniyor...</div></div>';
  kart.querySelectorAll(".ek-ay").forEach(b => b.addEventListener("click", () => { _ekState.ay = Number(b.dataset.ay); _ekLoad(); }));
  try {
    const d = await api("/api/bi/ebat-kart?kalem=" + encodeURIComponent(_ekState.kalem) + "&ay=" + _ekState.ay);
    const met = m.querySelector("#ek-metrik");
    const row = (l, v) => '<div style="display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid #f1f5f9;font-size:13px"><span style="color:#64748b">' + l + '</span><b>' + v + '</b></div>';
    let h = "";
    h += row("Satis adedi", num(d.satis_adet));
    h += row("Alis adedi", num(d.alis_adet));
    h += row("Agirlikli satis fiyati", money(d.ag_satis_fiyat));
    h += row("Agirlikli maliyet", money(d.ag_maliyet));
    h += row("Agirlikli marj", money(d.marj_tl) + " (" + pct(d.marj_pct) + ")");
    h += row("Min / Medyan / Max satis", money(d.min_fiyat) + " / " + money(d.med_fiyat) + " / " + money(d.max_fiyat));
    h += row("Alis vadesi (agirlikli)", d.alis_vade != null ? Math.round(d.alis_vade) + " gun" : "—");
    h += row("Satis vadesi (agirlikli)", d.satis_vade != null ? Math.round(d.satis_vade) + " gun" : "—");
    if (d.alicilar && d.alicilar.length) {
      h += '<div style="font-weight:700;color:#475569;font-size:12px;text-transform:uppercase;margin:12px 0 4px">Son ' + d.alicilar.length + ' alici (fiyat + vade)</div>';
      h += d.alicilar.map(a => '<div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid #f8fafc;font-size:12px"><span>' + esc(a.musteri || "—") + '</span><b>' + money(a.fiyat) + ' <span style="color:#94a3b8;font-weight:400">' + (a.vade != null ? "· " + a.vade + " gun" : (a.odeme ? "· " + esc(a.odeme) : "")) + '</span></b></div>').join("");
    }
    met.innerHTML = h || '<div style="color:#94a3b8;font-size:13px">Bu donemde veri yok.</div>';
  } catch (e) { const met = m.querySelector("#ek-metrik"); if (met) met.innerHTML = '<div style="color:#dc2626;font-size:13px">Kart yuklenemedi.</div>'; }
}
'''
if "EBAT_KART_V2" in t:
    print("SAHA: already V2, skip")
else:
    i = t.index("// EBAT_KART_V1")
    j = t.index("// KOKPIT_MOBIL_V1", i)
    t = t[:i] + new_ek + t[j:]
    write(FP, t)
    print("SAHA: vEbatKart -> V2 (live search, full name)")
print("DONE.")
