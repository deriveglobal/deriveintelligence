# -*- coding: utf-8 -*-
#!/usr/bin/env python3
# ZIYARET_EDIT — Eftal: "ziyaret notu kaydedildikten sonra düzenlenemiyor".
#
# The guncelle branch already updates notlar — but the handler re-runs the intent
# engine on EVERY PUT that carries a note. Wire up an edit button as-is and each
# typo fix would spawn ANOTHER reminder/task/CEO signal from the same visit.
# Fix: extract intent when a note is FIRST written, not when it is corrected.
#
# Also: visits are the field's audit record. Editing is allowed, but stamped —
# original note preserved, editor and timestamp recorded, shown in the UI.
import sys
which = sys.argv[1]
fn = sys.argv[2]
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b); print("OK: %s" % tag)

if which == "server":
    # 1) we need the previous note to know whether this is a first write or an edit
    rep(
'''      const own = await query(`SELECT rep_id, durum FROM saha_ziyaret WHERE tenant_id = $1 AND id = $2`,
        [session.tenantId, m[1]]);
      if (!own.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      if (session.sahaRole === "rep" && own.rows[0].rep_id !== session.userId) {
        sendJson(response, 403, { error: "Sadece kendi ziyaretlerinizi güncelleyebilirsiniz." }); return;
      }''',
'''      const own = await query(`SELECT rep_id, durum, notlar FROM saha_ziyaret WHERE tenant_id = $1 AND id = $2`,
        [session.tenantId, m[1]]);
      if (!own.rowCount) { sendJson(response, 404, { error: "Ziyaret bulunamadı." }); return; }
      if (session.sahaRole === "rep" && own.rows[0].rep_id !== session.userId) {
        sendJson(response, 403, { error: "Sadece kendi ziyaretlerinizi güncelleyebilirsiniz." }); return;
      }
      const _oncekiNot = own.rows[0].notlar;
      const _ilkKezNot = !(_oncekiNot && String(_oncekiNot).trim());''',
        "edit-prev-note")

    # 2) guncelle: also allow fixing the visit date, and record the edit trail
    rep(
'''        result = await query(`
          UPDATE saha_ziyaret
          SET planlanan_tarih = COALESCE($3, planlanan_tarih),
              katilimci = COALESCE($4, katilimci),
              notlar = COALESCE($5, notlar),
              detay = COALESCE($6::jsonb, detay),
              updated_at = now()
          WHERE tenant_id = $1 AND id = $2 RETURNING *
        `, [session.tenantId, m[1], p.planlanan_tarih || null, p.katilimci || null,
            p.notlar || null, p.detay ? JSON.stringify(p.detay) : null]);''',
'''        result = await query(`
          UPDATE saha_ziyaret
          SET planlanan_tarih = COALESCE($3, planlanan_tarih),
              katilimci = COALESCE($4, katilimci),
              notlar = COALESCE($5, notlar),
              detay = COALESCE($6::jsonb, detay),
              ziyaret_tarihi = COALESCE($7, ziyaret_tarihi),
              -- keep the first version of the note; never overwrite it silently
              notlar_orijinal = CASE
                  WHEN $5 IS NOT NULL AND $5 IS DISTINCT FROM notlar
                    THEN COALESCE(notlar_orijinal, notlar)
                  ELSE notlar_orijinal END,
              duzenlendi_at = CASE
                  WHEN $5 IS NOT NULL AND $5 IS DISTINCT FROM notlar THEN now()
                  ELSE duzenlendi_at END,
              duzenleyen = CASE
                  WHEN $5 IS NOT NULL AND $5 IS DISTINCT FROM notlar THEN $8::uuid
                  ELSE duzenleyen END,
              updated_at = now()
          WHERE tenant_id = $1 AND id = $2 RETURNING *
        `, [session.tenantId, m[1], p.planlanan_tarih || null, p.katilimci || null,
            p.notlar || null, p.detay ? JSON.stringify(p.detay) : null,
            p.ziyaret_tarihi || null, session.userId]);''',
        "edit-guncelle-trail")

    # 3) THE IMPORTANT ONE — do not re-parse a corrected note into new tasks/signals
    rep(
'''      let _asistan = null;
      if (p.notlar) { try { const _zr = result.rows[0]; const _sg = await _extractIntent(p.notlar); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: _zr.musteri_id, kaynakTip: "ziyaret", kaynakId: _zr.id, hamMetin: p.notlar }); _asistan = _ack && _ack.mesaj; } catch (e) {} }
      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan });
      return;
    }

    // ── Foto yükle (base64 JSON; istemci 1280px'e küçültür) ──''',
'''      let _asistan = null;
      // Intent extraction runs when a note is FIRST written (create / tamamla / first
      // note on an edit) — NOT when an existing note is corrected. Otherwise every
      // typo fix would create a duplicate reminder, task and CEO signal.
      const _notAnalizEt = p.notlar && (action !== "guncelle" || _ilkKezNot);
      if (_notAnalizEt) { try { const _zr = result.rows[0]; const _sg = await _extractIntent(p.notlar); const _ack = await _applyIntents(_sg, { tenantId: session.tenantId, repId: session.userId, musteriId: _zr.musteri_id, kaynakTip: "ziyaret", kaynakId: _zr.id, hamMetin: p.notlar }); _asistan = _ack && _ack.mesaj; } catch (e) {} }
      sendJson(response, 200, { ziyaret: result.rows[0], asistan: _asistan, duzenlendi: action === "guncelle" && !_ilkKezNot });
      return;
    }

    // ── Foto yükle (base64 JSON; istemci 1280px'e küçültür) ──''',
        "edit-no-duplicate-intents")

elif which == "front":
    # 4) show the edit trail on the visit card
    rep(
'''    ${z.notlar ? `<div class="det-not">${esc(z.notlar)}</div>` : ""}
    <div id="det-fotolar" class="foto-izgara"></div>''',
'''    ${z.notlar ? `<div class="det-not">${esc(z.notlar)}</div>` : ""}
    ${z.duzenlendi_at ? `
      <details style="margin-top:4px">
        <summary style="font-size:11px;color:#b45309;cursor:pointer">✏️ ${new Date(z.duzenlendi_at).toLocaleString("tr-TR")} tarihinde düzenlendi — ilk hâlini gör</summary>
        <div style="font-size:12px;color:#64748b;background:#f8fafc;border-radius:8px;padding:8px;margin-top:4px;white-space:pre-wrap">${esc(z.notlar_orijinal || "—")}</div>
      </details>` : ""}
    <div id="det-fotolar" class="foto-izgara"></div>''',
        "edit-trail-display")

    # 5) the Düzenle button + the edit modal
    rep(
'''    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn" id="det-teklif">＋ Teklif</button>
    </div>`);

  document.getElementById("det-teklif")?.addEventListener("click", () => {
    kapatModal(); teklifFormModal({ id: z.musteri_id, firma: z.firma }, zid);
  });''',
'''    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Kapat</button>
      <button class="btn cizgili" id="det-duzenle">✏️ Düzenle</button>
      <button class="btn" id="det-teklif">＋ Teklif</button>
    </div>`);

  document.getElementById("det-teklif")?.addEventListener("click", () => {
    kapatModal(); teklifFormModal({ id: z.musteri_id, firma: z.firma }, zid);
  });

  document.getElementById("det-duzenle")?.addEventListener("click", () => {
    kapatModal(); ziyaretDuzenleModal(z);
  });''',
        "edit-button")

    # 6) the edit modal itself
    rep(
'''async function ziyaretFormModal(mus, mod, presetDate = null) {''',
'''// ── Ziyaret düzenle (kendi ziyaretin) — not/katılımcı/tarih ─────────────────
async function ziyaretDuzenleModal(z) {
  modal(`
    <h3>✏️ Ziyaret Düzenle — ${esc(z.firma || "")}</h3>
    <div style="font-size:11px;color:#64748b;margin-bottom:10px">Düzeltmeler kayıt altına alınır; notun ilk hâli saklanır.</div>
    <div class="yanyana">
      <label>Ziyaret tarihi
        <input class="giris" id="zd-tarih" type="date" value="${z.ziyaret_tarihi ? String(z.ziyaret_tarihi).slice(0, 10) : ""}">
      </label>
      <label>Katılımcı
        <input class="giris" id="zd-katilimci" value="${esc(z.katilimci || "")}" placeholder="Görüşülen kişi">
      </label>
    </div>
    <label>Notlar
      <textarea class="giris" id="zd-notlar" rows="6" placeholder="Ziyaret notu…">${esc(z.notlar || "")}</textarea>
    </label>
    <div class="modal-btnlar">
      <button class="btn gri" data-kapat>Vazgeç</button>
      <button class="btn" id="zd-kaydet">Kaydet</button>
    </div>`);

  document.getElementById("zd-kaydet").addEventListener("click", async () => {
    const notlar = document.getElementById("zd-notlar").value.trim();
    const katilimci = document.getElementById("zd-katilimci").value.trim();
    const tarih = document.getElementById("zd-tarih").value || null;
    if (!notlar) { uyari("Not boş olamaz."); return; }
    const btn = document.getElementById("zd-kaydet");
    btn.disabled = true; btn.textContent = "Kaydediliyor…";
    try {
      await api(`/api/saha/ziyaretler/${z.id}`, {
        method: "PUT",
        body: JSON.stringify({ action: "guncelle", notlar, katilimci: katilimci || null, ziyaret_tarihi: tarih })
      });
      kapatModal();
      uyari("✓ Ziyaret güncellendi.", true);
      await loadView("ziyaretler");
    } catch (e) {
      btn.disabled = false; btn.textContent = "Kaydet";
      uyari(e.message);
    }
  });
}

async function ziyaretFormModal(mus, mod, presetDate = null) {''',
        "edit-modal")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
