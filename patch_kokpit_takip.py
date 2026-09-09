#!/usr/bin/env python3
# KOKPIT_TAKIP — Izle->Ogren backend (IZOLE, 2 yeni route). Aksiyon-bagli takip.
#   POST /api/bi/takip-baslat  : aksiyon dux gmesine basilinca takip acar (tur, konu, aksiyon, baz).
#   GET  /api/bi/takip-durum   : acik takipleri DEGERLENDIRIR (bi_tenant_hafiza gozlem / bi_musteri_risk) -> sonuc.
#   Tablo bi_kokpit_takip (tenant-scoped, race-safe). Mevcut hicbir seye dokunmaz. Onkosul: HAFIZA_FULL.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "KOKPIT_TAKIP" in s:
    print("[skip] KOKPIT_TAKIP zaten var"); sys.exit(0)

ANCHOR = '  if (request.method === "GET" && url.pathname === "/api/bi/mobil-dikkat") { /* MOBIL_DIKKAT */'
assert ANCHOR in s and s.count(ANCHOR) == 1, "HATA: mobil-dikkat anchor sorunu"

BLOCK = r'''  if (url.pathname === "/api/bi/takip-baslat" || url.pathname === "/api/bi/takip-durum") { /* KOKPIT_TAKIP */
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      await query("CREATE TABLE IF NOT EXISTS bi_kokpit_takip (id SERIAL PRIMARY KEY, tenant_id UUID NOT NULL, tur TEXT NOT NULL, konu TEXT NOT NULL, aksiyon TEXT, baz_json JSONB DEFAULT '{}'::jsonb, durum TEXT DEFAULT 'acik', acilis_ts TIMESTAMPTZ DEFAULT now(), son_kontrol_ts TIMESTAMPTZ)", []).catch(function(){});
      // ---- BASLAT ----
      if (request.method === "POST" && url.pathname === "/api/bi/takip-baslat") {
        let body = {}; try { body = await readJson(request); } catch (e) { body = {}; }
        const tur = String(body.tur || "").slice(0, 24);
        const aksiyon = String(body.aksiyon || "").slice(0, 48);
        const baz = body.baz && typeof body.baz === "object" ? body.baz : {};
        const konular = Array.isArray(body.konular) ? body.konular.slice(0, 12) : [];
        if (!tur || !konular.length) { sendJson(response, 400, { error: "tur/konular gerekli" }); return; }
        let n = 0;
        for (const k0 of konular) {
          const konu = String(k0 || "").trim().slice(0, 160); if (konu.length < 2) continue;
          const ex = await query("SELECT 1 FROM bi_kokpit_takip WHERE tenant_id=$1 AND tur=$2 AND konu=$3 AND durum='acik' AND acilis_ts > now() - interval '30 days' LIMIT 1", [T, tur, konu]);
          if (ex.rows.length) continue;
          await query("INSERT INTO bi_kokpit_takip (tenant_id, tur, konu, aksiyon, baz_json) VALUES ($1,$2,$3,$4,$5)", [T, tur, konu, aksiyon, JSON.stringify(baz)]);
          n++;
        }
        sendJson(response, 200, { ok: true, eklendi: n });
        return;
      }
      // ---- DURUM (degerlendir) ----
      if (request.method === "GET" && url.pathname === "/api/bi/takip-durum") {
        const rows = (await query("SELECT id, tur, konu, aksiyon, baz_json, EXTRACT(DAY FROM now()-acilis_ts)::int gun FROM bi_kokpit_takip WHERE tenant_id=$1 AND durum='acik' ORDER BY acilis_ts DESC LIMIT 30", [T])).rows;
        const out = [];
        for (const r of rows) {
          let durum = "izleniyor", sonuc = "izleniyor", iyi = null;
          if (r.tur === "gecikme") {
            const bazNet = r.baz_json && r.baz_json.net != null ? Number(r.baz_json.net) : null;
            const _q = "WITH ov AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, muhatap_adi ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu) SELECT COALESCE(SUM(GREATEST(o.vg+COALESCE(cb.borc,0),0)),0)::float8 net FROM ov o LEFT JOIN cb ON cb.musteri_kodu=o.kod WHERE o.musteri_mi AND o.muhatap_adi ILIKE $2||'%'";
            const cr = (await query(_q, [String(T), r.konu])).rows[0];
            const curNet = cr ? Number(cr.net) / 1e6 : null;
            if (bazNet != null && curNet != null) {
              if (curNet <= bazNet * 0.7) { durum = "iyilesti"; iyi = true; sonuc = "gecikmiş " + Math.round((1 - curNet / bazNet) * 100) + "% azaldı ✓"; }
              else if (curNet >= bazNet * 1.1) { durum = "kotulesti"; iyi = false; sonuc = "gecikmiş arttı"; }
              else { durum = "suruyor"; iyi = false; sonuc = "hâlâ açık (~" + curNet.toLocaleString("tr-TR", { maximumFractionDigits: 1 }) + "M)"; }
            } else sonuc = "izleniyor";
          } else {
            const g = (await query("SELECT icerik FROM bi_tenant_hafiza WHERE tenant_id=$1 AND kaynak='gozlem' AND gecerli AND icerik ILIKE $2||'%' ORDER BY son_gorulme DESC LIMIT 1", [T, r.konu])).rows[0];
            const ic = g ? (g.icerik || "").toLowerCase() : "";
            const artar = ic.indexOf("artir") >= 0, azalir = ic.indexOf("azalt") >= 0;
            if (r.tur === "kayip") {
              if (artar) { durum = "toparladi"; iyi = true; sonuc = "alımı toparladı ✓"; }
              else if (azalir) { durum = "suruyor"; iyi = false; sonuc = "hâlâ düşüyor"; }
              else { durum = "notr"; iyi = null; sonuc = "artık riskte değil"; }
            } else { // firsat
              if (artar) { durum = "suruyor"; iyi = true; sonuc = "büyümeye devam ✓"; }
              else if (azalir) { durum = "durdu"; iyi = false; sonuc = "ivme durdu, düşüşe geçti"; }
              else { durum = "notr"; iyi = null; sonuc = "ivme durdu"; }
            }
          }
          out.push({ id: r.id, tur: r.tur, konu: r.konu, aksiyon: r.aksiyon, gun: r.gun, durum: durum, iyi: iyi, sonuc: sonuc });
        }
        sendJson(response, 200, { takipler: out });
        return;
      }
      sendJson(response, 405, { error: "method" });
    } catch (e) { console.error("[kokpit-takip]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
'''

s = s.replace(ANCHOR, BLOCK + ANCHOR, 1) + "\n/* KOKPIT_TAKIP */\n"
open(F, "w", encoding="utf-8").write(s)
print("[ok] KOKPIT_TAKIP — /api/bi/takip-baslat (POST) + /api/bi/takip-durum (GET) eklendi")
