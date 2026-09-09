import shutil, sys
F = "server_container.mjs"
src = open(F, encoding="utf-8").read(); orig = src

def patch(src, marker, anchor, before=None, after=None):
    if marker in src:
        print("SKIP (zaten var):", marker); return src
    n = src.count(anchor)
    if n != 1:
        print("HATA anchor tekil degil (%d): %s" % (n, marker)); sys.exit(1)
    rep = (before + anchor) if before is not None else (anchor + after)
    print("OK:", marker); return src.replace(anchor, rep, 1)

H1a = 'async function getSessionUser(request) {'
H1 = '''async function kaydetOlay(opts) { /* KAYDET_OLAY_V1 */
  try {
    var o = opts || {};
    if (o.audit) {
      await query("INSERT INTO audit_events (organization_id, actor_user_id, event_type, entity_type, entity_id, metadata) VALUES ($1,$2,$3,$4,$5,$6)",
        [o.organizationId || null, o.userId || null, o.tip || "olay", o.entityTip || null, o.entityId || null, o.payload || {}]);
    } else {
      await query("INSERT INTO bi_etkinlik (tenant_id, kullanici, oda, bolum, olay_tipi, ref_id, payload) VALUES ($1,$2,$3,$4,$5,$6,$7)",
        [o.tenantId || null, o.kullanici || null, o.oda || null, o.bolum || null, o.tip || "olay", o.refId || null, o.payload || {}]);
    }
  } catch (e) {}
}

'''
src = patch(src, "KAYDET_OLAY_V1", H1a, before=H1)

H2a = '  const _role = normalizeRole(row.assignment_role || row.project_role || row.organization_role || row.role);'
H2 = '''  query("UPDATE user_sessions SET last_active_at = now() WHERE id = $1 AND (last_active_at IS NULL OR last_active_at < now() - interval '60 seconds')", [row.session_id]).catch(function(){}); /* LAST_ACTIVE_HEARTBEAT_V1 */
'''
src = patch(src, "LAST_ACTIVE_HEARTBEAT_V1", H2a, before=H2)

H3a = '      // TEKLIF_TALEP_STOK_V1 — talep fiyatı + mevcut stok snapshot (header, first line)'
H3 = '''      kaydetOlay({ tenantId: session.tenantId, kullanici: session.userId, oda: "teklif", bolum: "olustur", tip: "teklif_olustur", refId: teklifId, payload: { musteri_id: p.musteri_id, kategori: ilk.kategori || null, marka: ilk.marka || null, adet: lines.reduce(function (s, l) { return s + l.adet; }, 0), toplam: toplamTutar, liste: ilk.listeFiyati || null, birim: ilk.birim != null ? ilk.birim : null, talep: ilk.talep_fiyat != null ? Number(ilk.talep_fiyat) : null, ek_iskonto: ilk.ekIsk > 0 ? ilk.ekIsk : null, stok: ilk.mevcut_stok != null ? Number(ilk.mevcut_stok) : null, kaynak: p.ziyaret_id ? "ZIYARET" : "DIGER" } }); /* TEKLIF_OLAY_V1 */
'''
src = patch(src, "TEKLIF_OLAY_V1", H3a, before=H3)

H4a = '''      } catch (e) { console.error("[rep-aktivite]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }'''
H4 = '''

    if (method === "POST" && path === "/api/saha/iz") { /* SAHA_IZ_V1 */
      try {
        const session = await requireSahaAccess(request);
        const T = session.tenantId, U = session.userId;
        if (!T || !U) { sendJson(response, 401, { error: "oturum yok" }); return; }
        let body = {}; try { body = await readJson(request); } catch (e) {}
        const oda = String(body.oda || "").slice(0, 40);
        const bolum = String(body.bolum || "").slice(0, 60);
        const tip = String(body.olay || body.tip || "goruntule").slice(0, 40);
        const payload = (body.payload && typeof body.payload === "object") ? body.payload : {};
        const refId = /^[0-9a-f-]{36}$/i.test(String(body.ref_id || "")) ? body.ref_id : null;
        await kaydetOlay({ tenantId: T, kullanici: U, oda: oda || null, bolum: bolum || null, tip: tip, refId: refId, payload: payload });
        sendJson(response, 200, { ok: true });
      } catch (e) { console.error("[saha-iz]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }'''
src = patch(src, "SAHA_IZ_V1", H4a, after=H4)

if src != orig:
    shutil.copy(F, F + ".bak_telemetri_v1")
    open(F, "w", encoding="utf-8").write(src)
    print("YAZILDI + .bak_telemetri_v1")
else:
    print("Degisiklik yok")
