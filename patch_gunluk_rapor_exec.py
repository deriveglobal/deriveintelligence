# -*- coding: utf-8 -*-
# GUNLUK_RAPOR_EXEC_V1 — Yonetici gunluk raporu (5 bolum): Finance, Sales, Field Voice, Customer, Competitors.
#   Finance/Sales = dun, sert veri (bi_odeme_gecmisi / bi_musteri_risk / bi_satis_faturalari).
#   Field Voice/Customer/Competitors = dunku saha notlarindan AI (Haiku).
#   Teslim: push + inbox + e-posta (GM + manager'lar). Zamanlayici: sabah 08:00, gun-guard'li.
#   Onizleme: GET/POST /api/saha/gunluk-rapor-exec?key=SECRET&dry=1  (force=1 saat/guard bypass).
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "GUNLUK_RAPOR_EXEC_V1" in s:
    print("[skip] zaten yamali"); sys.exit(0)

# ── EDIT 1: fonksiyon blogu (_sahaGunlukOzet kuyrugundan sonra) ──
A1 = """    return { sent: true, to, chars: digest.length };
  } catch (e) { return { sent: false, err: String(e && e.message) }; }
}"""

B1 = A1 + r"""

/* GUNLUK_RAPOR_EXEC_V1 — Yonetici gunluk raporu (5 bolum). */
let _execRaporBusy = false;
async function _ensureRaporLog() {
  try { await pool.query("CREATE TABLE IF NOT EXISTS saha_rapor_gunluk_log (tenant_id uuid NOT NULL, gun date NOT NULL, tur text NOT NULL, sent_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (tenant_id, gun, tur))"); }
  catch (e) { try { console.warn("ensureRaporLog:", e.message); } catch (er) {} }
}
function _rtl(n) { try { return "₺" + Math.round(Number(n) || 0).toLocaleString("tr-TR"); } catch (e) { return "₺" + Math.round(Number(n) || 0); } }
function _radet(n) { try { return (Math.round(Number(n) || 0)).toLocaleString("tr-TR"); } catch (e) { return String(Math.round(Number(n) || 0)); } }
function _rsec(baslik, renk, ic) { return "<div style='margin:0 0 16px'><div style='font-size:13px;font-weight:800;color:" + renk + ";text-transform:uppercase;letter-spacing:.5px;margin-bottom:6px'>" + baslik + "</div>" + ic + "</div>"; }
function _rrow(k, v) { return "<tr><td style='padding:3px 16px 3px 0;color:#475569'>" + k + "</td><td style='padding:3px 0;font-weight:700;text-align:right'>" + v + "</td></tr>"; }

async function _execRaporVeri(tenantId, gun) {
  const V = { gun };
  try { const g = await pool.query("SELECT to_char($1::date,'DD.MM.YYYY') s", [gun]); V.gunStr = g.rows[0].s; } catch (e) { V.gunStr = String(gun); }
  // FINANCE
  try { const r = await pool.query("SELECT COALESCE(SUM(odenen_tutar),0)::numeric tahsil, COUNT(*) adet FROM bi_odeme_gecmisi WHERE tenant_id=$1 AND odeme_tarihi=$2::date", [tenantId, gun]); V.tahsil = Number(r.rows[0].tahsil) || 0; V.tahsil_adet = Number(r.rows[0].adet) || 0; } catch (e) { V.tahsil = 0; V.tahsil_adet = 0; }
  try { const r = await pool.query("SELECT COALESCE(SUM(GREATEST(COALESCE(vadesi_gecmis,0),0)),0)::numeric gecikmis FROM (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, vadesi_gecmis, musteri_mi FROM bi_musteri_risk WHERE tenant_id=$1 ORDER BY muhatap_kodu, export_date DESC) z WHERE musteri_mi", [tenantId]); V.gecikmis = Number(r.rows[0].gecikmis) || 0; } catch (e) { V.gecikmis = 0; }
  try { const r = await pool.query("SELECT grup_adi, ROUND(SUM((vade_tarihi - fatura_tarihi)*satir_tutar)/NULLIF(SUM(satir_tutar),0))::int vade FROM bi_satis_faturalari WHERE tenant_id=$1 AND fatura_tarihi=$2::date AND grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI') AND vade_tarihi IS NOT NULL AND satir_tutar>0 GROUP BY 1", [tenantId, gun]); V.vade = { tuk: null, tic: null }; for (const x of r.rows) { if (x.grup_adi === 'LASTIK TUKETICI') V.vade.tuk = Number(x.vade); else if (x.grup_adi === 'LASTIK TICARI') V.vade.tic = Number(x.vade); } } catch (e) { V.vade = { tuk: null, tic: null }; }
  // SALES
  try { const r = await pool.query("SELECT COALESCE(SUM(miktar) FILTER (WHERE grup_adi='LASTIK TUKETICI'),0)::numeric tuk, COALESCE(SUM(miktar) FILTER (WHERE grup_adi='LASTIK TICARI'),0)::numeric tic, COALESCE(SUM(satir_tutar) FILTER (WHERE grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI')),0)::numeric ciro FROM bi_satis_faturalari WHERE tenant_id=$1 AND fatura_tarihi=$2::date AND satir_tutar>0", [tenantId, gun]); V.satis = { tuk: Math.round(Number(r.rows[0].tuk) || 0), tic: Math.round(Number(r.rows[0].tic) || 0), ciro: Number(r.rows[0].ciro) || 0 }; V.satis.toplam = V.satis.tuk + V.satis.tic; } catch (e) { V.satis = { tuk: 0, tic: 0, ciro: 0, toplam: 0 }; }
  try { const r = await pool.query("SELECT COALESCE(NULLIF(TRIM(r.grup),''),'Diger') kanal, SUM(f.miktar)::numeric adet FROM bi_satis_faturalari f LEFT JOIN LATERAL (SELECT grup FROM bi_musteri_risk mr WHERE mr.tenant_id=$1 AND mr.muhatap_kodu=f.musteri_kodu ORDER BY export_date DESC LIMIT 1) r ON true WHERE f.tenant_id=$1 AND f.fatura_tarihi=$2::date AND f.grup_adi IN ('LASTIK TUKETICI','LASTIK TICARI') AND f.miktar>0 GROUP BY 1 ORDER BY 2 DESC", [tenantId, gun]); V.kanal = r.rows.map(x => ({ k: x.kanal, adet: Math.round(Number(x.adet) || 0) })); } catch (e) { V.kanal = []; }
  // CUSTOMER numbers
  try { const r = await pool.query("SELECT COUNT(*) FILTER (WHERE z.durum='TAMAMLANDI') ziyaret, COUNT(DISTINCT z.musteri_id) FILTER (WHERE z.durum='TAMAMLANDI') musteri, COUNT(*) FILTER (WHERE z.durum='TAMAMLANDI' AND m.tip='TUKETICI') tuk, COUNT(*) FILTER (WHERE z.durum='TAMAMLANDI' AND m.tip='TICARI') tic FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id=z.musteri_id WHERE z.tenant_id=$1 AND z.ziyaret_tarihi=$2::date", [tenantId, gun]); V.zk = { ziyaret: Number(r.rows[0].ziyaret) || 0, musteri: Number(r.rows[0].musteri) || 0, tuk: Number(r.rows[0].tuk) || 0, tic: Number(r.rows[0].tic) || 0 }; } catch (e) { V.zk = { ziyaret: 0, musteri: 0, tuk: 0, tic: 0 }; }
  // FIELD raw (AI)
  try { const r = await pool.query("SELECT z.notlar, m.firma, m.il, m.tip FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id=z.musteri_id WHERE z.tenant_id=$1 AND z.ziyaret_tarihi=$2::date AND z.notlar IS NOT NULL AND length(trim(z.notlar))>0 ORDER BY z.created_at DESC LIMIT 80", [tenantId, gun]); V.notlar = r.rows; } catch (e) { V.notlar = []; }
  try { const r = await pool.query("SELECT s.tip, s.onem, s.ozet, m.firma FROM saha_sinyal s LEFT JOIN saha_musteri m ON m.id=s.musteri_id WHERE s.tenant_id=$1 AND (s.created_at AT TIME ZONE 'Europe/Istanbul')::date=$2::date ORDER BY s.onem DESC, s.created_at DESC LIMIT 80", [tenantId, gun]); V.sinyaller = r.rows; } catch (e) { V.sinyaller = []; }
  try { const r = await pool.query("SELECT DISTINCT jsonb_array_elements_text(CASE WHEN jsonb_typeof(z.detay->'rakipler')='array' THEN z.detay->'rakipler' WHEN jsonb_typeof(z.detay->'tedarikci_markalar')='array' THEN z.detay->'tedarikci_markalar' ELSE '[]'::jsonb END) rk FROM saha_ziyaret z WHERE z.tenant_id=$1 AND z.ziyaret_tarihi=$2::date", [tenantId, gun]); V.rakipler = r.rows.map(x => x.rk).filter(Boolean); } catch (e) { V.rakipler = []; }
  return V;
}

async function _execRaporAI(V) {
  const ctx = {
    tarih: V.gunStr,
    ziyaret_ozet: { toplam: V.zk.ziyaret, musteri: V.zk.musteri, tuketici: V.zk.tuk, ticari: V.zk.tic },
    ziyaret_notlari: (V.notlar || []).map(n => ({ firma: n.firma, il: n.il, tip: n.tip, not: String(n.notlar || "").slice(0, 400) })),
    sinyaller: (V.sinyaller || []).map(x => ({ tip: x.tip, onem: x.onem, firma: x.firma, ozet: String(x.ozet || "").slice(0, 300) })),
    rakip_marka_bahisleri: V.rakipler || []
  };
  const sys = "Sen bir lastik toptancisinin (KRB) saha zekasi asistanisin. Sana DUNKU saha verisi verilecek. SADECE verilenlere dayan, uydurma. Turkce, kisa, patron diliyle. Yanit SADECE JSON: {\"headline\":\"tek cumle en onemli sey\",\"field_voice\":\"2-3 cumle piyasa nabzi/mood\",\"customer\":\"2-3 cumle dun ziyaret edilen musteriler ne hissediyor, ozel talep/durum\",\"competitors\":\"2-3 cumle rakip lastik MARKA haberleri ve DISTRIBUTOR haberleri; ayir\"}. Bir alanda veri yoksa 'Dun kayda deger not yok.' yaz.";
  try {
    const msg = await anthropic.messages.create({ model: "claude-haiku-4-5-20251001", max_tokens: 700, system: sys, messages: [{ role: "user", content: JSON.stringify(ctx).slice(0, 14000) }] });
    let t = (msg.content || []).filter(b => b.type === "text").map(b => b.text).join("").trim();
    t = t.replace(/^```json/i, "").replace(/^```/, "").replace(/```$/, "").trim();
    const o = JSON.parse(t);
    return { headline: o.headline || "", field_voice: o.field_voice || "", customer: o.customer || "", competitors: o.competitors || "" };
  } catch (e) { return { headline: "", field_voice: "", customer: "", competitors: "", _err: String(e && e.message) }; }
}

function _execRaporHtml(V, ai) {
  const vadeStr = (V.vade.tuk != null || V.vade.tic != null) ? ("Tüketici " + (V.vade.tuk != null ? V.vade.tuk + " gün" : "—") + " · Ticari " + (V.vade.tic != null ? V.vade.tic + " gün" : "—")) : "—";
  const tahsilNote = (V.tahsil === 0) ? " <span style='color:#94a3b8;font-size:12px'>(düne ait ERP yüklemesi yok olabilir)</span>" : "";
  const fin = "<table style='border-collapse:collapse;font-size:14px'>" + _rrow("Tahsil edilen (dün)", _rtl(V.tahsil) + tahsilNote) + _rrow("Toplam gecikmiş alacak", _rtl(V.gecikmis)) + _rrow("Ağırlıklı vade (dünkü satış)", vadeStr) + "</table>";
  const kanalStr = V.kanal.length ? V.kanal.map(c => c.k + " " + _radet(c.adet)).join(" · ") : "—";
  const sal = "<table style='border-collapse:collapse;font-size:14px'>" + _rrow("Toplam adet (lastik)", _radet(V.satis.toplam)) + _rrow("Tüketici / Ticari", _radet(V.satis.tuk) + " / " + _radet(V.satis.tic)) + _rrow("Ciro (lastik)", _rtl(V.satis.ciro)) + _rrow("Kanal", kanalStr) + "</table>";
  const cust = "<table style='border-collapse:collapse;font-size:14px;margin-bottom:6px'>" + _rrow("Ziyaret (dün)", _radet(V.zk.ziyaret)) + _rrow("Ulaşılan müşteri", _radet(V.zk.musteri)) + _rrow("Tüketici / Ticari ziyaret", _radet(V.zk.tuk) + " / " + _radet(V.zk.tic)) + "</table>" + (ai.customer ? "<div style='font-size:13px;color:#334155'>" + ai.customer + "</div>" : "");
  return "<div style='font-family:-apple-system,Segoe UI,Roboto,sans-serif;max-width:640px'>" +
    "<h2 style='margin:0 0 2px'>📊 Yönetici Günlük Raporu</h2>" +
    "<p style='color:#64748b;margin:0 0 14px'>" + V.gunStr + " · dün</p>" +
    (ai.headline ? "<p style='font-size:15px;background:#eff6ff;border-left:3px solid #3b82f6;padding:9px 13px;margin:0 0 16px'>" + ai.headline + "</p>" : "") +
    _rsec("1 · Finance", "#0ea5e9", fin) +
    _rsec("2 · Sales", "#6366f1", sal) +
    _rsec("3 · Field Voice", "#10b981", "<div style='font-size:13px;color:#334155'>" + (ai.field_voice || "—") + "</div>") +
    _rsec("4 · Customer", "#f59e0b", cust) +
    _rsec("5 · Competitors", "#ef4444", "<div style='font-size:13px;color:#334155'>" + (ai.competitors || "—") + "</div>") +
    "<p style='color:#94a3b8;font-size:12px;margin-top:10px'>Derive • KRB — her sabah 08:00 (Europe/Istanbul)</p></div>";
}

async function _execDailyReport(tenantId, opts) {
  opts = opts || {};
  try {
    const gr = await pool.query("SELECT ((now() AT TIME ZONE 'Europe/Istanbul')::date - 1)::text dun");
    const gun = gr.rows[0].dun;
    const V = await _execRaporVeri(tenantId, gun);
    const aktivite = V.tahsil + V.satis.toplam + V.zk.ziyaret + (V.sinyaller || []).length + (V.notlar || []).length + (V.gecikmis > 0 ? 1 : 0);
    if (!aktivite && !opts.force) return { sent: false, reason: "no activity", gun };
    const ai = await _execRaporAI(V);
    const html = _execRaporHtml(V, ai);
    const title = "📊 Yönetici Günlük — " + V.gunStr;
    const line = ai.headline || ("Dün " + _radet(V.zk.ziyaret) + " ziyaret · " + _radet(V.satis.toplam) + " adet satış · tahsil " + _rtl(V.tahsil) + ".");
    const body = line + " (Finans/Satış/Saha — e-postada tam rapor)";
    if (opts.dry) return { sent: false, dry: true, gun, veri: V, ai, push: { title, body }, html };
    const ids = await sahaManagerIds(tenantId, null);
    let pushed = 0;
    if (ids.length) { try { await pushToUsers(tenantId, ids, title, body.slice(0, 200), { room: "saha", type: "gunluk_rapor" }); pushed = ids.length; } catch (e) {} }
    let mailed = 0;
    try { const em = await pool.query("SELECT DISTINCT lower(email) email FROM users WHERE id = ANY($1::uuid[]) AND email IS NOT NULL AND email <> ''", [ids]); for (const e2 of em.rows) { try { await sendGraphMail({ to: e2.email, subject: title, body: html }); mailed++; } catch (e) {} } } catch (e) {}
    return { sent: true, gun, inbox: ids.length, pushed, mailed };
  } catch (e) { return { sent: false, err: String(e && e.message) }; }
}

async function _gunlukRaporExecTick(force) {
  if (_execRaporBusy && !force) return { busy: true };
  _execRaporBusy = true;
  try {
    const t = await pool.query("SELECT (now() AT TIME ZONE 'Europe/Istanbul')::date bugun, EXTRACT(hour FROM now() AT TIME ZONE 'Europe/Istanbul')::int saat");
    const bugun = t.rows[0].bugun, saat = Number(t.rows[0].saat);
    if (!force && (saat < 8 || saat >= 12)) { _execRaporBusy = false; return { skipped: "saat " + saat }; }
    await _ensureRaporLog();
    const tens = await pool.query("SELECT DISTINCT tenant_id FROM saha_ziyaret");
    const out = [];
    for (const row of tens.rows) {
      const T = row.tenant_id;
      if (!force) { const g = await pool.query("INSERT INTO saha_rapor_gunluk_log (tenant_id,gun,tur) VALUES ($1,$2,'exec') ON CONFLICT DO NOTHING RETURNING 1", [T, bugun]); if (!g.rowCount) continue; }
      out.push(await _execDailyReport(T, { force: !!force }));
    }
    if (out.length) { try { console.log("[rapor] exec gunluk:", out.length); } catch (e) {} }
    _execRaporBusy = false;
    return { ran: out.length, out };
  } catch (e) { _execRaporBusy = false; try { console.warn("gunlukRaporExecTick:", e.message); } catch (er) {} return { err: String(e && e.message) }; }
}"""

assert s.count(A1) == 1, "A1 anchor=%d" % s.count(A1)
s = s.replace(A1, B1, 1)

# ── EDIT 2: onizleme/tetik ucu (gunluk-ozet ucundan sonra) ──
A2 = """      const _out = [];
      for (const _row of _ten.rows) { _out.push(await _sahaGunlukOzet(_row.tenant_id)); }
      sendJson(response, 200, { ok: true, results: _out });
      return;
    }"""

B2 = A2 + r"""

    // GUNLUK_RAPOR_EXEC_V1 — manuel onizleme/tetik (secret'li). ?dry=1 gondermeden hesapla; ?force=1 saat/guard bypass.
    if ((method === "POST" || method === "GET") && path === "/api/saha/gunluk-rapor-exec") {
      let secret = "";
      try { secret = url.searchParams.get("key") || request.headers["x-ozet-secret"] || ""; } catch (e) {}
      let ok = false;
      try { const _s = await pool.query("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'"); ok = !!(_s.rows[0] && _s.rows[0].value && _s.rows[0].value === secret); } catch (e) {}
      if (!ok) { sendJson(response, 403, { error: "forbidden" }); return; }
      const dry = url.searchParams.get("dry") === "1", force = url.searchParams.get("force") === "1";
      if (dry) {
        const _ten = await pool.query("SELECT DISTINCT tenant_id FROM saha_ziyaret");
        const _out = [];
        for (const _r of _ten.rows) { _out.push(await _execDailyReport(_r.tenant_id, { dry: true, force: true })); }
        sendJson(response, 200, { ok: true, dry: true, results: _out });
        return;
      }
      const r = await _gunlukRaporExecTick(force);
      sendJson(response, 200, { ok: true, result: r });
      return;
    }"""

assert s.count(A2) == 1, "A2 anchor=%d" % s.count(A2)
s = s.replace(A2, B2, 1)

# ── EDIT 3: zamanlayici (reminderInit setTimeout'undan sonra) ──
A3 = "setTimeout(function () { _reminderInit(); }, 30000);"
B3 = A3 + """

// GUNLUK_RAPOR_EXEC_V1 — sabah 08:00 (Europe/Istanbul) yonetici raporu; 15 dk kontrol, gun-guard.
setTimeout(function () { _gunlukRaporExecTick().catch(function () {}); }, 60000);
setInterval(function () { _gunlukRaporExecTick().catch(function () {}); }, 15 * 60 * 1000);"""

assert s.count(A3) == 1, "A3 anchor=%d" % s.count(A3)
s = s.replace(A3, B3, 1)

open(F, "w", encoding="utf-8").write(s)
print("[done] GUNLUK_RAPOR_EXEC_V1 (server)")
