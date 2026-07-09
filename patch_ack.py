#!/usr/bin/env python3
# ACK_V1 — make the intent engine visibly responsive.
# _applyIntents now builds a warm Turkish acknowledgment and returns it;
# note/visit/quote save handlers await the intent and return {asistan: mesaj}.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK (x%d): %s" % (c, tag))

# ── 1a: acks accumulator ──
rep("  let severe = false;\n  for (const s of (sinyaller || [])) {",
    "  let severe = false; const acks = [];\n  for (const s of (sinyaller || [])) {",
    "acks-init")

# ── 1b: action block -> add acknowledgments for every intent type ──
OLD_BLOCK = r"""      if (tip === "takip" && s.hatirlatma_tarihi) {
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
      }"""
NEW_BLOCK = r"""      if (tip === "takip" && s.hatirlatma_tarihi) {
        if (ctx.kaynakTip === "not" && ctx.kaynakId) {
          await pool.query("UPDATE saha_rep_not SET hatirlatma_tarihi=COALESCE(hatirlatma_tarihi,$2) WHERE id=$1", [ctx.kaynakId, s.hatirlatma_tarihi]);
        } else {
          await pool.query("INSERT INTO saha_rep_not (id,tenant_id,rep_id,icerik,hatirlatma_tarihi) VALUES (gen_random_uuid(),$1,$2,$3,$4)", [ctx.tenantId, ctx.repId || null, "[oto] " + ozet, s.hatirlatma_tarihi]);
        }
        let _ds = s.hatirlatma_tarihi;
        try { _ds = new Date(s.hatirlatma_tarihi + "T00:00:00").toLocaleDateString("tr-TR", { weekday: "long", day: "numeric", month: "long" }); } catch (e) {}
        acks.push("📅 " + _ds + " için hatırlatma kurdum");
      } else if (tip === "rakip" && (s.marka || s.fiyat)) {
        const kaynak = ctx.kaynakTip === "ziyaret" ? "ZIYARET" : "MANUEL";
        await pool.query(
          "INSERT INTO saha_rakip_teklif (tenant_id,kaynak,rakip_marka,rakip_model,ebat,rakip_fiyat,musteri_id,rep_id,notlar,created_by) VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$8)",
          [ctx.tenantId, kaynak, s.marka || "Bilinmiyor", s.model || null, s.ebat || null, s.fiyat != null ? Number(s.fiyat) : null, ctx.musteriId || null, ctx.repId || null, (s.supheli ? "[supheli/blof olabilir] " : "") + ozet]
        );
        acks.push("🏁 Rakip fiyat kaydettim: " + (s.marka || "") + (s.ebat ? (" " + s.ebat) : "") + (s.fiyat != null ? (" " + s.fiyat + "TL") : "") + (s.supheli ? " (şüpheli olabilir)" : ""));
      } else if (tip === "risk") {
        acks.push((onem >= 3 ? "⚠ " : "") + "Risk sinyali kaydettim" + (onem >= 3 ? " ve patrona ilettim" : "") + ": " + ozet);
      } else if (tip === "teklif_talep") {
        acks.push("📝 Teklif talebini not ettim: " + ozet);
      } else if (tip === "firsat") {
        acks.push("🌱 Fırsatı kaydettim: " + ozet);
      }"""
rep(OLD_BLOCK, NEW_BLOCK, "acks-actions")

# ── 1c: return the acknowledgment ──
rep("  if (severe) { await _pushSevereSignals(ctx.tenantId); }",
    "  if (severe) { await _pushSevereSignals(ctx.tenantId); }\n  return { mesaj: acks.length ? (\"Anladım. \" + acks.join(\" · \") + \".\") : null, severe };",
    "acks-return")

# ── 2: note POST — await + return asistan ──
rep(r"""      _extractIntent(icerik).then(function(sg){ return _applyIntents(sg, { tenantId: session.tenantId, repId: session.userId, musteriId: null, kaynakTip: "not", kaynakId: r.rows[0].id, hamMetin: icerik }); }).catch(function(){});
      sendJson(response, 201, { not: r.rows[0] });""",
    r"""      let _asistan = null;
      try { const _sg = await _extractIntent(icerik); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: null, kaynakTip: "not", kaynakId: r.rows[0].id, hamMetin: icerik }); _asistan = _ack && _ack.mesaj; } catch (e) {}
      const _n2 = await pool.query("SELECT * FROM saha_rep_not WHERE id=$1", [r.rows[0].id]);
      sendJson(response, 201, { not: (_n2.rows[0] || r.rows[0]), asistan: _asistan });""",
    "note-await")

# ── 3: visit POST + PUT (x2) — await + return asistan ──
rep(r"""      if (p.notlar) { const _zr = result.rows[0]; _extractIntent(p.notlar).then(function(sg){ return _applyIntents(sg, { tenantId: session.tenantId, repId: session.userId, musteriId: _zr.musteri_id, kaynakTip: "ziyaret", kaynakId: _zr.id, hamMetin: p.notlar }); }).catch(function(){}); }
      sendJson(response, 200, { ziyaret: result.rows[0] });""",
    r"""      let _asistan = null;
      if (p.notlar) { try { const _zr = result.rows[0]; const _sg = await _extractIntent(p.notlar); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: _zr.musteri_id, kaynakTip: "ziyaret", kaynakId: _zr.id, hamMetin: p.notlar }); _asistan = _ack && _ack.mesaj; } catch (e) {} }
      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan });""",
    "visit-await", n=2)

# ── 4: quote POST — await + return asistan ──
rep(r"""      if (p.notlar) { _extractIntent(p.notlar).then(function(sg){ return _applyIntents(sg, { tenantId: session.tenantId, repId: session.userId, musteriId: p.musteri_id, kaynakTip: "teklif", kaynakId: teklifId, hamMetin: p.notlar }); }).catch(function(){}); }
      sendJson(response, 200, { teklif: { ...hdr.rows[0], kalem_sayisi: lines.length } });""",
    r"""      let _asistan = null;
      if (p.notlar) { try { const _sg = await _extractIntent(p.notlar); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: p.musteri_id, kaynakTip: "teklif", kaynakId: teklifId, hamMetin: p.notlar }); _asistan = _ack && _ack.mesaj; } catch (e) {} }
      sendJson(response, 200, { teklif: { ...hdr.rows[0], kalem_sayisi: lines.length }, asistan: _asistan });""",
    "quote-await")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
