#!/usr/bin/env python3
# SIZECARD + ARAC_YETKI patch — server_container.mjs (3 endpoints) + shells/saha.js (tiles, room, UI).
# Idempotent: re-running skips already-applied blocks. Run in /opt/krb-assessment.
import io, sys

def read(p):  return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

# ============================ server_container.mjs ============================
SP = "server_container.mjs"
s = read(SP)

# ---- 1) /api/bi/ebat-ara + /api/bi/ebat-kart  (management/matrix gated) ----
srv_bi_anchor = '  if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {'
srv_bi_block = r'''    if (request.method === "GET" && url.pathname === "/api/bi/ebat-ara") {
      let s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let ss = s ? null : await requireSahaAccess(request).catch(() => null);
      const sess = s || ss;
      if (!sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      let ok = s ? true : (ss && ["manager", "admin"].includes(ss.sahaRole));
      if (!ok && ss) { try { const g = await query("SELECT 1 FROM bi_arac_yetki WHERE tenant_id::text=$1 AND user_id=$2 AND arac_kod='ebat_kart' AND aktif=true LIMIT 1", [ss.tenantId, ss.userId]); ok = g.rowCount > 0; } catch (e) {} }
      if (!ok) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = sess.tenantId;
      const q = (url.searchParams.get("q") || "").replace(/[^0-9]/g, "");
      if (q.length < 4) { sendJson(response, 200, { sonuclar: [] }); return; }
      try {
        const rows = (await query("SELECT marka, ebat, sum(adet)::bigint adet FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka IS NOT NULL AND ebat IS NOT NULL AND regexp_replace(ebat, '[^0-9]', '', 'g') LIKE $2 || '%' GROUP BY marka, ebat HAVING sum(adet) > 0 ORDER BY sum(ciro) DESC NULLS LAST LIMIT 40", [T, q])).rows;
        sendJson(response, 200, { sonuclar: rows.map(r => ({ marka: r.marka, ebat: r.ebat, adet: r.adet != null ? Number(r.adet) : null })) });
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
      const marka = (url.searchParams.get("marka") || "").trim();
      const ebat = (url.searchParams.get("ebat") || "").trim();
      const ay = Math.min(24, Math.max(1, parseInt(url.searchParams.get("ay") || "12", 10)));
      if (!marka || !ebat) { sendJson(response, 400, { error: "marka ve ebat zorunlu" }); return; }
      const out = { satis_adet: null, alis_adet: null, ag_satis_fiyat: null, ag_maliyet: null, marj_tl: null, marj_pct: null, min_fiyat: null, med_fiyat: null, max_fiyat: null, alis_vade: null, satis_vade: null, alicilar: [] };
      try {
        const mj = (await query("SELECT sum(adet) adet, sum(ciro) ciro, sum(brut_kar) kar FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3 AND ay >= (CURRENT_DATE - ($4::int * INTERVAL '1 month'))", [T, marka, ebat, ay])).rows[0];
        if (mj && mj.adet) {
          out.satis_adet = Number(mj.adet);
          out.marj_tl = mj.kar != null ? Number(mj.kar) : null;
          out.ag_satis_fiyat = (mj.ciro != null && Number(mj.adet)) ? Number(mj.ciro) / Number(mj.adet) : null;
          out.ag_maliyet = (mj.ciro != null && mj.kar != null && Number(mj.adet)) ? (Number(mj.ciro) - Number(mj.kar)) / Number(mj.adet) : null;
          out.marj_pct = (mj.kar != null && Number(mj.ciro)) ? Number(mj.kar) / Number(mj.ciro) * 100 : null;
        }
      } catch (e) {}
      try {
        const st = (await query("SELECT min(birim_fiyat) mn, max(birim_fiyat) mx, percentile_cont(0.5) WITHIN GROUP (ORDER BY birim_fiyat) med, sum((vade_tarihi - fatura_tarihi)::numeric * satir_tutar)/nullif(sum(satir_tutar),0) vade_w FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3 AND fatura_tarihi >= (CURRENT_DATE - ($4::int * INTERVAL '1 month')) AND (para_birimi IS NULL OR upper(para_birimi) IN ('TRY','TL'))", [T, marka, ebat, ay])).rows[0];
        if (st) { out.min_fiyat = st.mn != null ? Number(st.mn) : null; out.med_fiyat = st.med != null ? Number(st.med) : null; out.max_fiyat = st.mx != null ? Number(st.mx) : null; out.satis_vade = st.vade_w != null ? Number(st.vade_w) : null; }
      } catch (e) {}
      try {
        const al = (await query("SELECT * FROM (SELECT DISTINCT ON (musteri_kodu) musteri_kodu, musteri_adi, birim_fiyat, (vade_tarihi - fatura_tarihi) vade_gun, odeme_kosulu, fatura_tarihi FROM bi_satis_faturalari WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3 AND fatura_tarihi >= (CURRENT_DATE - ($4::int * INTERVAL '1 month')) ORDER BY musteri_kodu, fatura_tarihi DESC) x ORDER BY fatura_tarihi DESC LIMIT 10", [T, marka, ebat, ay])).rows;
        out.alicilar = al.map(r => ({ musteri: r.musteri_adi, fiyat: r.birim_fiyat != null ? Number(r.birim_fiyat) : null, vade: r.vade_gun != null ? Number(r.vade_gun) : null, odeme: r.odeme_kosulu || null }));
      } catch (e) {}
      try {
        const pu = (await query("WITH ks AS (SELECT DISTINCT kalem_kodu FROM bi_marj_atom WHERE tenant_id::text=$1 AND marka=$2 AND ebat=$3 AND kalem_kodu IS NOT NULL) SELECT sum(miktar) adet, sum(vade_gun::numeric * satir_kdv_haric)/nullif(sum(satir_kdv_haric),0) vade_w FROM bi_tedarikci_faturalari WHERE tenant_id::text=$1 AND kalem_kodu IN (SELECT kalem_kodu FROM ks) AND fatura_tarihi >= (CURRENT_DATE - ($4::int * INTERVAL '1 month'))", [T, marka, ebat, ay])).rows[0];
        if (pu) { out.alis_adet = pu.adet != null ? Number(pu.adet) : null; out.alis_vade = pu.vade_w != null ? Number(pu.vade_w) : null; }
      } catch (e) {}
      sendJson(response, 200, out);
      return;
    }
'''
if "/api/bi/ebat-kart" in s:
    print("SERVER bi: already patched, skip")
else:
    assert srv_bi_anchor in s, "bi anchor NOT found"
    s = s.replace(srv_bi_anchor, srv_bi_block + srv_bi_anchor, 1)
    print("SERVER bi: ebat-ara + ebat-kart added")

# ---- 2) /api/saha/araclarim  (which tool tiles this user may see) ----
srv_saha_anchor = '    if (method === "GET" && path === "/api/saha/recep-selam") {'
srv_saha_block = r'''    if (method === "GET" && path === "/api/saha/araclarim") {
      const session = await requireSahaAccess(request);
      const mgmt = ["manager", "admin"].includes(session.sahaRole);
      let araclar = [];
      if (mgmt) { araclar = ["musteri_kart", "ebat_kart"]; }
      else {
        try {
          const g = await pool.query("SELECT arac_kod FROM bi_arac_yetki WHERE tenant_id::text=$1 AND user_id=$2 AND aktif=true", [session.tenantId, session.userId]);
          araclar = g.rows.map(r => r.arac_kod);
        } catch (e) {}
      }
      sendJson(response, 200, { araclar });
      return;
    }
'''
if "/api/saha/araclarim" in s:
    print("SERVER saha: already patched, skip")
else:
    assert srv_saha_anchor in s, "saha anchor NOT found"
    s = s.replace(srv_saha_anchor, srv_saha_block + srv_saha_anchor, 1)
    print("SERVER saha: araclarim added")

write(SP, s)

# ============================ shells/saha.js ============================
FP = "shells/saha.js"
t = read(FP)

# ---- A) setRoom dispatch: musterikart + ebatkart ----
room_anchor = "vCeoMobil(); return; }"
room_add = 'vCeoMobil(); return; }\n  if (room === "musterikart") { musteriSecModal(x => musteriDetayModal(x)); return; }\n  if (room === "ebatkart") { m.style.padding = "0"; vEbatKart(); return; }'
if 'room === "ebatkart"' in t:
    print("SAHA setRoom: already patched, skip")
else:
    assert room_anchor in t, "setRoom anchor NOT found"
    t = t.replace(room_anchor, room_add, 1)
    print("SAHA setRoom: musterikart + ebatkart added")

# ---- B) reception: append tool tiles from the authorization matrix ----
rec_anchor = "  // PUSH_KAYIT_V1"
rec_block = r'''  // ARAC_YETKI_V1 — matris-tabanli yonetim araclari (mobil, yetkiye gore).
  (async () => {
    try {
      const { araclar = [] } = await api("/api/saha/araclarim");
      const tanim = {
        musteri_kart: ["musterikart", "🧾", "Musteri Karti", "Musteri finansal & alim karti", "#0d9488"],
        ebat_kart: ["ebatkart", "📐", "Ebat Karti", "Ebat/urun alim-satim & marj karti", "#7c3aed"]
      };
      const wrap = m.querySelector(".rec-tiles");
      if (!wrap) return;
      araclar.forEach(kod => {
        const d = tanim[kod]; if (!d || wrap.querySelector('[data-room="' + d[0] + '"]')) return;
        const b = document.createElement("button");
        b.className = "rec-tile"; b.dataset.room = d[0]; b.style.setProperty("--rc", d[4]);
        b.innerHTML = '<span class="rec-ico">' + d[1] + '</span><span class="rec-txt"><b>' + d[2] + '</b><small>' + d[3] + '</small></span><span class="rec-arrow">›</span>';
        b.addEventListener("click", () => setRoom(d[0]));
        wrap.appendChild(b);
      });
    } catch (e) {}
  })();
'''
if "ARAC_YETKI_V1" in t:
    print("SAHA reception: already patched, skip")
else:
    assert rec_anchor in t, "reception anchor NOT found"
    t = t.replace(rec_anchor, rec_block + rec_anchor, 1)
    print("SAHA reception: tool tiles added")

# ---- C) vEbatKart room (full-screen, light theme) ----
ek_anchor = "// KOKPIT_MOBIL_V1"
ek_block = r'''// EBAT_KART_V1 — yonetim araci: urun (ebat+marka) alim-satim, marj, son 10 alici.
let _ekState = { marka: null, ebat: null, ay: 12 };
async function vEbatKart() {
  const m = main();
  m.innerHTML = '<div class="ek-wrap" style="padding:14px;max-width:720px;margin:0 auto;color:#0f172a">'
    + '<div style="display:flex;align-items:center;gap:8px;margin-bottom:12px">'
    + '<button id="ek-geri" class="btn" style="padding:6px 10px">‹ Geri</button>'
    + '<b style="font-size:16px">📐 Ebat Karti</b></div>'
    + '<div style="display:flex;gap:6px;margin-bottom:8px">'
    + '<input id="ek-q" placeholder="Ebat ara: 205 55 16" style="flex:1;padding:10px;border:1px solid #cbd5e1;border-radius:8px;font-size:14px">'
    + '<button id="ek-ara" class="btn cizgili" style="padding:8px 12px">Ara</button></div>'
    + '<div id="ek-sonuc"></div><div id="ek-kart" style="margin-top:12px"></div></div>';
  m.querySelector("#ek-geri").addEventListener("click", () => renderReception());
  const doSearch = async () => {
    const q = m.querySelector("#ek-q").value.trim();
    if (q.replace(/[^0-9]/g, "").length < 4) return;
    const box = m.querySelector("#ek-sonuc");
    box.innerHTML = '<div style="color:#94a3b8;font-size:13px;padding:6px">Araniyor...</div>';
    try {
      const { sonuclar = [] } = await api("/api/bi/ebat-ara?q=" + encodeURIComponent(q));
      if (!sonuclar.length) { box.innerHTML = '<div style="color:#94a3b8;font-size:13px;padding:6px">Sonuc yok.</div>'; return; }
      box.innerHTML = sonuclar.map(x => '<button class="ek-pick" data-marka="' + esc(x.marka || "") + '" data-ebat="' + esc(x.ebat || "") + '" style="display:flex;justify-content:space-between;width:100%;text-align:left;padding:10px;margin-bottom:4px;border:1px solid #e2e8f0;border-radius:8px;background:#fff;cursor:pointer"><span><b>' + esc(x.marka || "") + '</b> · ' + esc(x.ebat || "") + '</span><span style="color:#64748b;font-size:12px">' + (x.adet != null ? Number(x.adet).toLocaleString("tr-TR") + " adet" : "") + '</span></button>').join("");
      box.querySelectorAll(".ek-pick").forEach(b => b.addEventListener("click", () => {
        _ekState.marka = b.dataset.marka; _ekState.ebat = b.dataset.ebat;
        box.innerHTML = '<div style="font-size:13px;padding:4px">Secili: <b>' + esc(_ekState.marka) + " " + esc(_ekState.ebat) + '</b></div>';
        _ekLoad();
      }));
    } catch (e) { box.innerHTML = '<div style="color:#dc2626;font-size:13px;padding:6px">Arama hatasi.</div>'; }
  };
  m.querySelector("#ek-ara").addEventListener("click", doSearch);
  m.querySelector("#ek-q").addEventListener("keydown", e => { if (e.key === "Enter") doSearch(); });
}
async function _ekLoad() {
  const m = main(); const kart = m.querySelector("#ek-kart");
  if (!kart || !_ekState.marka) return;
  const money = v => v == null ? "—" : Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 0 }) + " ₺";
  const num = v => v == null ? "—" : Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 0 });
  const pct = v => v == null ? "—" : "%" + Number(v).toLocaleString("tr-TR", { maximumFractionDigits: 1 });
  const P = [3, 6, 9, 12];
  kart.innerHTML = '<div style="display:flex;gap:6px;margin-bottom:10px">' + P.map(p => '<button class="ek-ay" data-ay="' + p + '" style="flex:1;padding:8px;border:1px solid ' + (p === _ekState.ay ? "#7c3aed" : "#cbd5e1") + ';background:' + (p === _ekState.ay ? "#7c3aed" : "#fff") + ';color:' + (p === _ekState.ay ? "#fff" : "#334155") + ';border-radius:8px;font-size:13px">' + p + ' ay</button>').join("") + '</div><div id="ek-metrik"><div style="color:#94a3b8;font-size:13px">Yukleniyor...</div></div>';
  kart.querySelectorAll(".ek-ay").forEach(b => b.addEventListener("click", () => { _ekState.ay = Number(b.dataset.ay); _ekLoad(); }));
  try {
    const d = await api("/api/bi/ebat-kart?marka=" + encodeURIComponent(_ekState.marka) + "&ebat=" + encodeURIComponent(_ekState.ebat) + "&ay=" + _ekState.ay);
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
if "EBAT_KART_V1" in t:
    print("SAHA vEbatKart: already patched, skip")
else:
    assert ek_anchor in t, "vEbatKart anchor NOT found"
    t = t.replace(ek_anchor, ek_block + ek_anchor, 1)
    print("SAHA vEbatKart: room added")

write(FP, t)
print("DONE.")
