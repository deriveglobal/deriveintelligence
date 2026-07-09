#!/usr/bin/env python3
# PERLINE_INTENT_V1 — feed per-line quote notes (not just the header note) to the
# intent engine, so rivals reps write per-product get captured on the quote.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = '      if (p.notlar) { try { const _sg = await _extractIntent(p.notlar); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: p.musteri_id, kaynakTip: "teklif", kaynakId: teklifId, hamMetin: p.notlar }); _asistan = _ack && _ack.mesaj; } catch (e) {} }'
NEW = '      const _teklifNotlar = [p.notlar].concat((lines || []).map(function (l) { return l && l.notlar; })).filter(Boolean).join(" · ");\n      if (_teklifNotlar) { try { const _sg = await _extractIntent(_teklifNotlar); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: p.musteri_id, kaynakTip: "teklif", kaynakId: teklifId, hamMetin: _teklifNotlar }); _asistan = _ack && _ack.mesaj; } catch (e) {} }'

c = s.count(OLD)
assert c == 1, "ABORT: quote hook anchor found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: perline-intent")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
