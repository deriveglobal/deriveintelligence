#!/usr/bin/env python3
# INTENT_V1 — intent-reading engine + field-activity feed + CEO awareness
# Idempotent-guarded, atomic: builds new content in memory, asserts each anchor
# appears exactly once, writes only at the end.
import sys

fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
src = open(fn, encoding="utf-8").read()
orig_len = len(src)

def rep(needle, replacement, tag):
    global src
    n = src.count(needle)
    assert n == 1, "ABORT [%s]: anchor found %d times (need 1): %r" % (tag, n, needle[:70])
    src = src.replace(needle, replacement, 1)
    print("OK: %s" % tag)

# ── Edit 1: saha_sinyal table (after brain_conversations create, startup init) ──
BRAIN_CONV = "        await query('CREATE TABLE IF NOT EXISTS brain_conversations (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, role TEXT NOT NULL, content TEXT NOT NULL, created_at TIMESTAMPTZ DEFAULT NOW())', []);"
SINYAL = BRAIN_CONV + r"""
        await query("CREATE TABLE IF NOT EXISTS saha_sinyal (id UUID PRIMARY KEY DEFAULT gen_random_uuid(), tenant_id UUID NOT NULL, tip TEXT NOT NULL, onem SMALLINT NOT NULL DEFAULT 1, ozet TEXT NOT NULL, detay JSONB DEFAULT '{}'::jsonb, kaynak_tip TEXT, kaynak_id UUID, rep_id UUID, musteri_id UUID, ham_metin TEXT, owner_bildirildi BOOLEAN DEFAULT FALSE, ozet_dahil BOOLEAN DEFAULT FALSE, okundu BOOLEAN DEFAULT FALSE, created_at TIMESTAMPTZ DEFAULT NOW())", []);
        await query("CREATE INDEX IF NOT EXISTS idx_saha_sinyal_tc ON saha_sinyal(tenant_id, created_at DESC)", []);"""
rep(BRAIN_CONV, SINYAL, "saha_sinyal-table")

# ── Edit 2: intent engine (module scope, before createServer) ──
ENGINE = r"""// ═══════════ INTENT ENGINE (INTENT_V1) ═══════════
// Reads a rep's free text, extracts structured intent, feeds saha_sinyal + acts.
async function _extractIntent(text) {
  try {
    if (!text || String(text).trim().length < 4) return [];
    const today = new Date().toLocaleDateString("en-CA", { timeZone: "Europe/Istanbul" });
    const sys = "Sen bir saha satis CRM'inde niyet-cozumleyicisin. Turk lastik saha temsilcisinin serbest metnini oku, GERCEK NIYETI cikar. SADECE JSON dondur.\n" +
      "Bugun: " + today + " (Europe/Istanbul).\n" +
      "Su tiplerde sinyal uret (yoksa bos dizi):\n" +
      "- takip: temsilci bir TAAHHUT/donus sozu veriyorsa (yarin ararim, Persembe donerim, dusunup donecek, hafta sonu tekrar). hatirlatma_tarihi=YYYY-MM-DD (bugune gore hesapla; yarin=+1 gun, gun adi=o haftanin o gunu).\n" +
      "- rakip: bir rakip marka/fiyat bilgisi geciyorsa (Pirelli 1200 veriyor, Michelin daha ucuz). marka, model(varsa/null), ebat(varsa/null), fiyat(sayi/null), supheli(true eger cok dusuk/blof ihtimali).\n" +
      "- teklif_talep: musteri fiyat/iskonto/adet-urun istiyorsa (20 adet 385 lazim, iskonto istiyor). urunler=[{ebat,adet}] cikarabilirsen.\n" +
      "- risk: musteri kaybi/sikayet/odeme/guven sorunu sinyali (baska yere bakiyor, memnun degil, odemesi gecikti, sozunu tutmadi). kategori=kayip|odeme|sikayet.\n" +
      "- firsat: buyume/upsell/yeni is firsati (filo alacak, yeni sube aciyor, stok artiracak).\n" +
      "Her sinyal: {tip, onem(1-3; 3=acil mudahale), ozet(kisa Turkce cumle), ...alanlar}.\n" +
      "Onem: risk kayip/odeme=3, buyuk/acil teklif_talep=3, rakip belirgin ucuz=3, normal takip=1-2, firsat=2.\n" +
      "Metin anlamsiz/sadece selam ise: {\"sinyaller\":[]}.\n" +
      "Cikti formati: {\"sinyaller\":[{...}]}";
    const msg = await anthropic.messages.create({
      model: "claude-haiku-4-5-20251001", max_tokens: 700, system: sys,
      messages: [{ role: "user", content: String(text).slice(0, 2000) }]
    });
    let out = (msg.content || []).filter(b => b.type === "text").map(b => b.text).join("").trim();
    const a = out.indexOf("{"), b = out.lastIndexOf("}");
    if (a < 0 || b < 0) return [];
    const parsed = JSON.parse(out.slice(a, b + 1));
    return Array.isArray(parsed.sinyaller) ? parsed.sinyaller : [];
  } catch (e) { console.error("extractIntent:", e && e.message); return []; }
}

async function _ownerAlarmEmail() {
  try { const r = await pool.query("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_email'"); if (r.rows[0] && r.rows[0].value) return r.rows[0].value; } catch (e) {}
  return process.env.MICROSOFT_SENDER || "consult@deriveglobal.com";
}

async function _pushSevereSignals(tenantId) {
  try {
    const r = await pool.query("SELECT s.id,s.tip,s.ozet,m.firma,u.full_name AS rep FROM saha_sinyal s LEFT JOIN saha_musteri m ON m.id=s.musteri_id LEFT JOIN users u ON u.id=s.rep_id WHERE s.tenant_id=$1 AND s.onem>=3 AND s.owner_bildirildi=FALSE ORDER BY s.created_at ASC LIMIT 20", [tenantId]);
    if (!r.rows.length) return;
    const to = await _ownerAlarmEmail();
    const ad = { risk: "RISK", teklif_talep: "Teklif Talebi", rakip: "Rakip Fiyat", takip: "Takip", firsat: "Firsat" };
    const body = "Sahadan acil dikkat gerektiren gelismeler:\n\n" + r.rows.map(x =>
      "[" + (ad[x.tip] || x.tip) + "] " + x.ozet + (x.firma ? "\nMusteri: " + x.firma : "") + (x.rep ? "\nTemsilci: " + x.rep : "") + "\n"
    ).join("\n");
    await sendGraphMail({ to, subject: "Saha Uyarisi: " + r.rows.length + " acil sinyal", body });
    await pool.query("UPDATE saha_sinyal SET owner_bildirildi=TRUE WHERE id = ANY($1::uuid[])", [r.rows.map(x => x.id)]);
  } catch (e) { console.error("pushSevere:", e && e.message); }
}

async function _applyIntents(sinyaller, ctx) {
  let severe = false;
  for (const s of (sinyaller || [])) {
    try {
      const tip = String(s.tip || "").toLowerCase();
      if (!["takip", "rakip", "teklif_talep", "risk", "firsat"].includes(tip)) continue;
      const onem = Math.min(3, Math.max(1, Number(s.onem) || 1));
      const ozet = (String(s.ozet || "").slice(0, 500)) || tip;
      await pool.query(
        "INSERT INTO saha_sinyal (tenant_id,tip,onem,ozet,detay,kaynak_tip,kaynak_id,rep_id,musteri_id,ham_metin) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)",
        [ctx.tenantId, tip, onem, ozet, JSON.stringify(s), ctx.kaynakTip || null, ctx.kaynakId || null, ctx.repId || null, ctx.musteriId || null, (ctx.hamMetin || "").slice(0, 2000)]
      );
      if (onem >= 3) severe = true;
      if (tip === "takip" && s.hatirlatma_tarihi) {
        if (ctx.kaynakTip === "not" && ctx.kaynakId) {
          await pool.query("UPDATE saha_rep_not SET hatirlatma_tarihi=COALESCE(hatirlatma_tarihi,$2) WHERE id=$1", [ctx.kaynakId, s.hatirlatma_tarihi]);
        } else {
          await pool.query("INSERT INTO saha_rep_not (id,tenant_id,rep_id,icerik,hatirlatma_tarihi) VALUES (gen_random_uuid(),$1,$2,$3,$4)", [ctx.tenantId, ctx.repId || null, "[oto] " + ozet, s.hatirlatma_tarihi]);
        }
      } else if (tip === "rakip" && (s.marka || s.fiyat)) {
        const kaynak = ctx.kaynakTip === "ziyaret" ? "ZIYARET" : "MANUEL";
        await pool.query(
          "INSERT INTO saha_rakip_teklif (tenant_id,kaynak,rakip_marka,rakip_model,ebat,rakip_fiyat,musteri_id,rep_id,notlar,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$8)",
          [ctx.tenantId, kaynak, s.marka || "Bilinmiyor", s.model || null, s.ebat || null, s.fiyat != null ? Number(s.fiyat) : null, ctx.musteriId || null, ctx.repId || null, (s.supheli ? "[supheli/blof olabilir] " : "") + ozet]
        );
      }
    } catch (e) { console.error("applyIntent:", e && e.message); }
  }
  if (severe) { await _pushSevereSignals(ctx.tenantId); }
}

async function _sahaGunlukOzet(tenantId) {
  try {
    const S = "NOW() - INTERVAL '24 hours'";
    const sig = await pool.query("SELECT s.tip,s.onem,s.ozet,m.firma,u.full_name rep FROM saha_sinyal s LEFT JOIN saha_musteri m ON m.id=s.musteri_id LEFT JOIN users u ON u.id=s.rep_id WHERE s.tenant_id=$1 AND s.created_at>=" + S + " ORDER BY s.onem DESC, s.created_at DESC", [tenantId]);
    const ziy = await pool.query("SELECT z.notlar,z.durum,m.firma,u.full_name rep FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id=z.musteri_id LEFT JOIN users u ON u.id=z.rep_id WHERE z.tenant_id=$1 AND z.created_at>=" + S + " AND z.notlar IS NOT NULL ORDER BY z.created_at DESC LIMIT 40", [tenantId]);
    const tek = await pool.query("SELECT t.marka,t.ebat,t.adet,t.talep_fiyat,t.toplam_tutar,t.durum,m.firma FROM saha_teklif t LEFT JOIN saha_musteri m ON m.id=t.musteri_id WHERE t.tenant_id=$1 AND t.created_at>=" + S + " ORDER BY t.created_at DESC LIMIT 40", [tenantId]);
    const dyr = await pool.query("SELECT baslik,icerik,yazan_adi FROM saha_duyuru WHERE tenant_id=$1 AND created_at>=" + S + " ORDER BY created_at DESC LIMIT 20", [tenantId]);
    if (!sig.rows.length && !ziy.rows.length && !tek.rows.length && !dyr.rows.length) return { sent: false, reason: "no activity" };
    const raw = JSON.stringify({ sinyaller: sig.rows, ziyaretler: ziy.rows, teklifler: tek.rows, duyurular: dyr.rows });
    let digest = "";
    try {
      const msg = await anthropic.messages.create({
        model: "claude-haiku-4-5-20251001", max_tokens: 900,
        system: "Sen KRB sahibinin CEO asistanisin. Asagidaki son 24 saatlik saha verisini (sinyaller, ziyaret notlari, teklifler, duyurular) oku ve sahibe kisa, insan gibi bir GUNLUK OZET yaz Turkce. Once en kritik riskler/firsatlar, sonra bekleyen teklifler, sonra genel aktivite. Kisa madde isaretleri, rakam ve musteri adi ver, patronun zamanina saygi goster.",
        messages: [{ role: "user", content: raw.slice(0, 12000) }]
      });
      digest = (msg.content || []).filter(b => b.type === "text").map(b => b.text).join("").trim();
    } catch (e) { digest = "Ozet olusturulamadi. Sinyal sayisi: " + sig.rows.length; }
    const to = await _ownerAlarmEmail();
    await sendGraphMail({ to, subject: "Saha Gunluk Ozet - " + new Date().toLocaleDateString("tr-TR", { timeZone: "Europe/Istanbul" }), body: digest });
    await pool.query("UPDATE saha_sinyal SET ozet_dahil=TRUE WHERE tenant_id=$1 AND created_at>=" + S, [tenantId]);
    return { sent: true, to, chars: digest.length };
  } catch (e) { return { sent: false, err: String(e && e.message) }; }
}

"""
rep("createServer(async (request, response) => {", ENGINE + "createServer(async (request, response) => {", "intent-engine")

# ── Edit 3: CEO read tool definition ──
TOOLDEF = r"""      const _BRAIN_TOOLS = [
        {
          name: 'saha_faaliyet_ozet',
          description: 'Sahadaki TUM insan-girisi icerigi okur: temsilci ziyaret notlari, kisisel notlar, teklifler, rakip fiyat girisleri, cikarilan sinyaller (risk/firsat/takip/teklif_talep), duyurular ve mesajlar. Owner "sahada neler oluyor", "riskli musteriler", "bu hafta ozeti", "bekleyen isler", "duyurularda ne var", "rakip haberleri" gibi sorularda kullan.',
          input_schema: { type: 'object', properties: {
            gun: { type: 'number', description: 'Kac gun geriye (varsayilan 7)' },
            tip: { type: 'string', enum: ['takip','rakip','teklif_talep','risk','firsat'], description: 'opsiyonel sinyal tipi filtresi' },
            onem_min: { type: 'number', description: 'minimum onem 1-3 (opsiyonel)' }
          } }
        },"""
rep("      const _BRAIN_TOOLS = [", TOOLDEF, "ceo-tool-def")

# ── Edit 4: CEO read tool handler ──
BRANCH = r"""      async function _runBrainTool(toolName, input, tenantId) {
        if (toolName === 'saha_faaliyet_ozet') {
          const gun = Math.min(90, Math.max(1, Number(input.gun) || 7));
          const S = "NOW() - INTERVAL '" + gun + " days'";
          const p = [tenantId];
          let w = "s.tenant_id=$1 AND s.created_at>=" + S;
          if (input.tip) { p.push(input.tip); w += " AND s.tip=$" + p.length; }
          if (input.onem_min) { p.push(Number(input.onem_min)); w += " AND s.onem>=$" + p.length; }
          const sig = await query("SELECT s.tip,s.onem,s.ozet,s.created_at,m.firma,u.full_name rep FROM saha_sinyal s LEFT JOIN saha_musteri m ON m.id=s.musteri_id LEFT JOIN users u ON u.id=s.rep_id WHERE " + w + " ORDER BY s.onem DESC, s.created_at DESC LIMIT 60", p);
          const ziy = await query("SELECT z.notlar,z.durum,z.ziyaret_tarihi,m.firma,u.full_name rep FROM saha_ziyaret z LEFT JOIN saha_musteri m ON m.id=z.musteri_id LEFT JOIN users u ON u.id=z.rep_id WHERE z.tenant_id=$1 AND z.created_at>=" + S + " AND z.notlar IS NOT NULL ORDER BY z.created_at DESC LIMIT 40", [tenantId]);
          const tek = await query("SELECT t.marka,t.ebat,t.adet,t.talep_fiyat,t.toplam_tutar,t.durum,m.firma FROM saha_teklif t LEFT JOIN saha_musteri m ON m.id=t.musteri_id WHERE t.tenant_id=$1 AND t.created_at>=" + S + " ORDER BY t.created_at DESC LIMIT 40", [tenantId]);
          const rak = await query("SELECT rakip_marka,rakip_model,ebat,rakip_fiyat,kaynak,created_at FROM saha_rakip_teklif WHERE tenant_id=$1 AND created_at>=" + S + " ORDER BY created_at DESC LIMIT 40", [tenantId]);
          const dyr = await query("SELECT baslik,icerik,yazan_adi,onem,created_at FROM saha_duyuru WHERE tenant_id=$1 AND created_at>=" + S + " ORDER BY created_at DESC LIMIT 20", [tenantId]);
          const msj = await query("SELECT icerik,gonderen_adi,gonderen_rol,created_at FROM saha_konusma_mesaj WHERE tenant_id=$1 AND created_at>=" + S + " ORDER BY created_at DESC LIMIT 40", [tenantId]);
          return { gun, sinyaller: sig.rows, ziyaret_notlari: ziy.rows, teklifler: tek.rows, rakip_fiyatlar: rak.rows, duyurular: dyr.rows, mesajlar: msj.rows };
        }"""
rep("      async function _runBrainTool(toolName, input, tenantId) {", BRANCH, "ceo-tool-handler")

# ── Edit 5: CEO system prompt rule 14 ──
rep("Excel gerekmez.';",
    r"""Excel gerekmez.\n14. Saha farkindaligi: temsilcilerin sahada yazdigi HER SEYI (ziyaret notlari, teklifler, rakip fiyatlari, riskler, firsatlar, duyurular, mesajlar) saha_faaliyet_ozet araci ile oku. Sahada ne var, riskli musteriler, bu hafta ozeti, bekleyen isler, rakip haberleri gibi sorularda bu araci kullan; sonra insan gibi ozetle ve onemli konularda proaktif uyar.';""",
    "ceo-prompt-rule14")

# ── Edit 6: visit save hook (POST create + PUT update — both return spots) ──
VISIT_NEEDLE = "      sendJson(response, 200, { ziyaret: result.rows[0] });"
VISIT_HOOK = r"""      if (p.notlar) { const _zr = result.rows[0]; _extractIntent(p.notlar).then(function(sg){ return _applyIntents(sg, { tenantId: session.tenantId, repId: session.userId, musteriId: _zr.musteri_id, kaynakTip: "ziyaret", kaynakId: _zr.id, hamMetin: p.notlar }); }).catch(function(){}); }
      sendJson(response, 200, { ziyaret: result.rows[0] });"""
_nv = src.count(VISIT_NEEDLE)
assert _nv == 2, "ABORT [hook-visit]: expected 2 occurrences, found %d" % _nv
src = src.replace(VISIT_NEEDLE, VISIT_HOOK)
print("OK: hook-visit (x2)")

# ── Edit 7: note save hook ──
rep("      sendJson(response, 201, { not: r.rows[0] });",
    r"""      _extractIntent(icerik).then(function(sg){ return _applyIntents(sg, { tenantId: session.tenantId, repId: session.userId, musteriId: null, kaynakTip: "not", kaynakId: r.rows[0].id, hamMetin: icerik }); }).catch(function(){});
      sendJson(response, 201, { not: r.rows[0] });""",
    "hook-note")

# ── Edit 8: quote save hook ──
rep("      sendJson(response, 200, { teklif: { ...hdr.rows[0], kalem_sayisi: lines.length } });",
    r"""      if (p.notlar) { _extractIntent(p.notlar).then(function(sg){ return _applyIntents(sg, { tenantId: session.tenantId, repId: session.userId, musteriId: p.musteri_id, kaynakTip: "teklif", kaynakId: teklifId, hamMetin: p.notlar }); }).catch(function(){}); }
      sendJson(response, 200, { teklif: { ...hdr.rows[0], kalem_sayisi: lines.length } });""",
    "hook-quote")

# ── Edit 9: daily digest endpoint (before POST /api/saha/notlar) ──
ENDPOINT = r"""    if (method === "POST" && path === "/api/saha/gunluk-ozet") {
      let secret = "";
      try { secret = request.headers["x-ozet-secret"] || ""; } catch (e) {}
      let ok = false;
      try { const _s = await pool.query("SELECT value FROM bi_rakip_izle_ayar WHERE key='alarm_flush_secret'"); ok = !!(_s.rows[0] && _s.rows[0].value && _s.rows[0].value === secret); } catch (e) {}
      if (!ok) { sendJson(response, 403, { error: "forbidden" }); return; }
      const _ten = await pool.query("SELECT DISTINCT tenant_id FROM saha_ziyaret");
      const _out = [];
      for (const _row of _ten.rows) { _out.push(await _sahaGunlukOzet(_row.tenant_id)); }
      sendJson(response, 200, { ok: true, results: _out });
      return;
    }
    """
rep('    if (method === "POST" && path === "/api/saha/notlar") {',
    ENDPOINT + 'if (method === "POST" && path === "/api/saha/notlar") {',
    "endpoint-gunluk-ozet")

open(fn, "w", encoding="utf-8").write(src)
print("WROTE %s  (%d -> %d chars, +%d)" % (fn, orig_len, len(src), len(src) - orig_len))
