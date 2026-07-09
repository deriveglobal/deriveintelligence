#!/usr/bin/env python3
# ANALIZ_V1 — GET /api/saha/teklifler/:id/analiz : per-line decision context for
# the approval screen (stock+cost, e-commerce range, real field-offer range) +
# the rep-reported rival captured from this quote's intent signals + notes.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

def rep(a, b, tag, n=1):
    global s
    c = s.count(a)
    assert c == n, "ABORT [%s]: found %d (need %d)" % (tag, c, n)
    s = s.replace(a, b)
    print("OK: %s" % tag)

ENDPOINT = r"""    if (method === "GET" && (m = path.match(new RegExp("^/api/saha/teklifler/(" + SAHA_UUID_RE + ")/analiz$")))) {
      const session = await requireSahaAccess(request);
      const _tid = m[1];
      const _num = function (x) { return x != null ? Number(x) : null; };
      const th = await pool.query("SELECT id, musteri_id, notlar, rakip_marka, rakip_fiyat FROM saha_teklif WHERE tenant_id=$1 AND id=$2", [session.tenantId, _tid]);
      if (!th.rowCount) { sendJson(response, 404, { error: "Teklif bulunamadı." }); return; }
      const kl = await pool.query("SELECT kalem_sira, kalem_kodu, marka, model, ebat, adet, birim_fiyat, talep_fiyat, notlar FROM saha_teklif_kalem WHERE tenant_id=$1 AND teklif_id=$2 ORDER BY kalem_sira", [session.tenantId, _tid]);
      let _rows = kl.rows;
      if (!_rows.length) {
        const h = await pool.query("SELECT 1 AS kalem_sira, kalem_kodu, marka, model, ebat, adet, birim_fiyat, talep_fiyat, notlar FROM saha_teklif WHERE tenant_id=$1 AND id=$2", [session.tenantId, _tid]);
        _rows = h.rows;
      }
      const kalemler = [];
      for (const k of _rows) {
        let stok = null, maliyet = null;
        if (k.kalem_kodu) {
          const sres = await pool.query("SELECT SUM(eldeki_miktar) AS m, MAX(birim_maliyet) AS c FROM bi_stok_durumu WHERE tenant_id=$1 AND kalem_kodu=$2 AND export_date=(SELECT MAX(export_date) FROM bi_stok_durumu WHERE tenant_id=$1 AND kalem_kodu=$2)", [session.tenantId, k.kalem_kodu]);
          stok = _num(sres.rows[0].m); maliyet = _num(sres.rows[0].c);
        }
        let eticaret = { en_dusuk: null, en_yuksek: null, ilan: 0 }, marka_araligi = null, saha = null;
        if (k.ebat) {
          const r2 = await pool.query("SELECT MIN(fiyat) mn, MAX(fiyat) mx, COUNT(*) n FROM bi_rakip_fiyat_son WHERE ebat=$1", [k.ebat]);
          eticaret = { en_dusuk: _num(r2.rows[0].mn), en_yuksek: _num(r2.rows[0].mx), ilan: Number(r2.rows[0].n || 0) };
          if (k.marka) {
            const r3 = await pool.query("SELECT MIN(fiyat) mn, MAX(fiyat) mx, COUNT(*) n FROM bi_rakip_fiyat_son WHERE ebat=$1 AND lower(marka)=lower($2)", [k.ebat, k.marka]);
            if (Number(r3.rows[0].n || 0) > 0) marka_araligi = { en_dusuk: _num(r3.rows[0].mn), en_yuksek: _num(r3.rows[0].mx), ilan: Number(r3.rows[0].n) };
          }
          const r4 = await pool.query("SELECT MIN(rakip_fiyat) mn, MAX(rakip_fiyat) mx, ROUND(AVG(rakip_fiyat)) av, COUNT(*) n, MAX(teklif_tarihi) son FROM saha_rakip_teklif WHERE tenant_id=$1 AND ebat=$2", [session.tenantId, k.ebat]);
          if (Number(r4.rows[0].n || 0) > 0) saha = { en_dusuk: _num(r4.rows[0].mn), en_yuksek: _num(r4.rows[0].mx), ortalama: _num(r4.rows[0].av), adet: Number(r4.rows[0].n), son_tarih: r4.rows[0].son };
        }
        const talep = k.talep_fiyat != null ? Number(k.talep_fiyat) : (k.birim_fiyat != null ? Number(k.birim_fiyat) : null);
        const marj = (talep && maliyet) ? Math.round((talep - maliyet) / talep * 1000) / 10 : null;
        kalemler.push({ kalem_sira: k.kalem_sira, marka: k.marka, model: k.model, ebat: k.ebat, adet: k.adet, notlar: k.notlar, talep_fiyat: talep, mevcut_stok: stok, birim_maliyet: maliyet, marj_pct: marj, eticaret: eticaret, marka_araligi: marka_araligi, saha_teklifler: saha });
      }
      const rr = await pool.query("SELECT ozet, detay FROM saha_sinyal WHERE tenant_id=$1 AND kaynak_tip='teklif' AND kaynak_id=$2 AND tip='rakip' ORDER BY created_at DESC", [session.tenantId, _tid]);
      const rep_rakip = rr.rows.map(function (x) { const d = x.detay || {}; return { marka: d.marka || null, model: d.model || null, ebat: d.ebat || null, fiyat: d.fiyat != null ? Number(d.fiyat) : null, supheli: !!d.supheli, ozet: x.ozet }; });
      sendJson(response, 200, { teklif_id: _tid, notlar: th.rows[0].notlar, header_rakip: th.rows[0].rakip_marka ? { marka: th.rows[0].rakip_marka, fiyat: th.rows[0].rakip_fiyat != null ? Number(th.rows[0].rakip_fiyat) : null } : null, rep_rakip: rep_rakip, kalemler: kalemler });
      return;
    }
    """
rep('    if (method === "GET" && path === "/api/saha/rakip-teklif-ozet") {',
    ENDPOINT + 'if (method === "GET" && path === "/api/saha/rakip-teklif-ozet") {',
    "analiz-endpoint")

open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
