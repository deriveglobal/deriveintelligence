#!/usr/bin/env python3
# PRICELIST_MARGIN_V1 — /analiz margin from price model #1 (list - incentives).
# net cost = liste_fiyati x (1-b1/100)(1-b2/100)(1-ds/100)(1-sk/100), incentives
# from bi_fiyat_iskonto (brand + rim tier). States: liste_yok / tesvik_yok / ok.
import sys
fn = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(fn, encoding="utf-8").read(); o = len(s)

OLD = '''        const talep = k.talep_fiyat != null ? Number(k.talep_fiyat) : (k.birim_fiyat != null ? Number(k.birim_fiyat) : null);
        const marj = (talep && maliyet) ? Math.round((talep - maliyet) / talep * 1000) / 10 : null;
        kalemler.push({ kalem_sira: k.kalem_sira, marka: k.marka, model: k.model, ebat: k.ebat, adet: k.adet, notlar: k.notlar, talep_fiyat: talep, mevcut_stok: stok, birim_maliyet: maliyet, marj_pct: marj, eticaret: eticaret, marka_araligi: marka_araligi, saha_teklifler: saha });'''

NEW = r'''        const talep = k.talep_fiyat != null ? Number(k.talep_fiyat) : (k.birim_fiyat != null ? Number(k.birim_fiyat) : null);
        // Price model #1: list price - incentives (net buy cost)
        let _liste = null, _iskPct = null, _netMaliyet = null, _fiyatDurumu = "liste_yok";
        try {
          const _pl = await pool.query("SELECT k2.liste_fiyati FROM bi_fiyat_listesi_kalemler k2 JOIN bi_fiyat_listesi_uploads u ON u.id=k2.upload_id WHERE k2.tenant_id=$1 AND u.aktif=true AND k2.liste_fiyati IS NOT NULL AND regexp_replace(upper(k2.ebat),'\\s+','','g')=regexp_replace(upper($2),'\\s+','','g') ORDER BY (upper(u.marka)=upper($3)) DESC, u.liste_tarihi DESC LIMIT 1", [session.tenantId, k.ebat || "", k.marka || ""]);
          if (_pl.rows[0] && _pl.rows[0].liste_fiyati != null) {
            _liste = Number(_pl.rows[0].liste_fiyati);
            _fiyatDurumu = "tesvik_yok";
            const _rm = String(k.ebat || "").match(/R\s*(\d{2})/i);
            const _rim = _rm ? parseInt(_rm[1]) : null;
            if (_rim != null) {
              const _isk = await pool.query("SELECT baz_iskonto1 b1, baz_iskonto2 b2, ds, skala_primi sk FROM bi_fiyat_iskonto WHERE tenant_id=$1 AND upper(marka)=upper($2) AND aktif=true AND (rim_alt IS NULL OR $3>=rim_alt) AND (rim_ust IS NULL OR $3<=rim_ust) ORDER BY rim_alt NULLS LAST LIMIT 1", [session.tenantId, k.marka || "", _rim]);
              if (_isk.rows[0]) {
                const _b1 = Number(_isk.rows[0].b1) || 0, _b2 = Number(_isk.rows[0].b2) || 0, _ds = Number(_isk.rows[0].ds) || 0, _sk = Number(_isk.rows[0].sk) || 0;
                const _nd = 1 - (1 - _b1 / 100) * (1 - _b2 / 100) * (1 - _ds / 100) * (1 - _sk / 100);
                if (_nd > 0) { _iskPct = Math.round(_nd * 1000) / 10; _fiyatDurumu = "ok"; }
              }
            }
            _netMaliyet = _iskPct != null ? Math.round(_liste * (1 - _iskPct / 100) * 100) / 100 : _liste;
          }
        } catch (e) { console.error("analiz pricelist:", e && e.message); }
        const marj = (talep && _netMaliyet) ? Math.round((talep - _netMaliyet) / talep * 1000) / 10 : null;
        const _karAdet = (talep != null && _netMaliyet != null) ? Math.round(talep - _netMaliyet) : null;
        kalemler.push({ kalem_sira: k.kalem_sira, marka: k.marka, model: k.model, ebat: k.ebat, adet: k.adet, notlar: k.notlar, talep_fiyat: talep, mevcut_stok: stok, birim_maliyet: maliyet, liste_fiyati: _liste, iskonto_pct: _iskPct, net_maliyet: _netMaliyet, marj_pct: marj, kar_adet: _karAdet, fiyat_durumu: _fiyatDurumu, eticaret: eticaret, marka_araligi: marka_araligi, saha_teklifler: saha });'''

c = s.count(OLD)
assert c == 1, "ABORT: analiz loop anchor found %d (need 1)" % c
s = s.replace(OLD, NEW)
print("OK: pricelist-margin")
open(fn, "w", encoding="utf-8").write(s)
print("WROTE %s (%d -> %d)" % (fn, o, len(s)))
