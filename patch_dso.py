#!/usr/bin/env python3
# DSO_IKI — /api/bi/dso-icgoru: isE-bazinda DSO SAYILARI (deterministik SQL) + AI ANLATI (anthropic, marka-marj deseni).
#   Sayilar: {tuketici,ticari,sinifsiz}{odeme(bi_tahsilat olculen), dso(bakiye/gunluk), bakiye, gecikmis, gec, top(en cok siseren hesap)}.
#   Anlati: claude-sonnet-4-6, KATI prompt (sadece verilen sayilar). facts-hash ile in-memory cache. AI coker -> sayilar yine doner.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "DSO_IKI" in s:
    print("[skip] DSO_IKI zaten var"); sys.exit(0)

ANCHOR = '  // === MUSTERI_EVRENI_V1'
assert ANCHOR in s, "HATA: musteri-evreni anchor bulunamadi"

BLOCK = r'''  if (request.method === "GET" && url.pathname === "/api/bi/dso-icgoru") { /* DSO_IKI */
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const _dsoSql = "WITH cls AS (SELECT f.musteri_kodu kod, CASE WHEN COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)='PSR'),0) >= COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)<>'PSR'),0) THEN 'TUK' ELSE 'TIC' END sinif FROM bi_satis_faturalari f JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date WHERE f.tenant_id::text=$1 AND f.fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months' AND f.satir_tutar>0 GROUP BY 1), rev AS (SELECT COALESCE(c.sinif,'SINIFSIZ') sinif, SUM(f.satir_tutar) rev12 FROM bi_satis_faturalari f LEFT JOIN cls c ON c.kod=f.musteri_kodu WHERE f.tenant_id::text=$1 AND f.fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months' AND f.satir_tutar>0 GROUP BY 1), r1 AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, GREATEST(hesap_bakiyesi,0) bak, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu), risk AS (SELECT COALESCE(c.sinif,'SINIFSIZ') sinif, SUM(r.bak) bakiye, SUM(GREATEST(r.vg+COALESCE(cb.borc,0),0)) gecikmis FROM r1 r LEFT JOIN cls c ON c.kod=r.kod LEFT JOIN cb ON cb.musteri_kodu=r.kod WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%' GROUP BY 1), tah AS (SELECT COALESCE(c.sinif,'SINIFSIZ') sinif, sum(bt.son12_suresi*bt.son12_tutar)/nullif(sum(bt.son12_tutar),0) odeme, sum(bt.son12_gec_orani*bt.son12_tutar)/nullif(sum(bt.son12_tutar),0) gec FROM bi_tahsilat bt LEFT JOIN cls c ON c.kod=bt.muhatap_kodu WHERE bt.tenant_id::text=$1 AND bt.musteri_mi AND bt.son12_tutar>0 GROUP BY 1), spine AS (SELECT unnest(ARRAY['TUK','TIC','SINIFSIZ']) sinif) SELECT sp.sinif, COALESCE(rev.rev12,0)::float8 rev12, COALESCE(risk.bakiye,0)::float8 bakiye, COALESCE(risk.gecikmis,0)::float8 gecikmis, tah.odeme::float8 odeme, tah.gec::float8 gec FROM spine sp LEFT JOIN rev USING(sinif) LEFT JOIN risk USING(sinif) LEFT JOIN tah USING(sinif)";
      const _dr = (await query(_dsoSql, [String(T)])).rows;
      const _dget = (sf) => { const r = _dr.find((x) => x.sinif === sf) || {}; const gun = (r.rev12 || 0) / 365; return { odeme: r.odeme != null ? Math.round(r.odeme) : null, gec: r.gec != null ? Math.round(r.gec) : null, dso: gun > 0 ? Math.round(r.bakiye / gun) : null, bakiye: +((r.bakiye || 0) / 1e6).toFixed(1), gecikmis: +((r.gecikmis || 0) / 1e6).toFixed(1), ciro: +((r.rev12 || 0) / 1e6).toFixed(1) }; };
      const _topSql = "WITH cls AS (SELECT f.musteri_kodu kod, CASE WHEN COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)='PSR'),0) >= COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)<>'PSR'),0) THEN 'TUK' ELSE 'TIC' END sinif FROM bi_satis_faturalari f JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date WHERE f.tenant_id::text=$1 AND f.fatura_tarihi >= CURRENT_DATE - INTERVAL '12 months' AND f.satir_tutar>0 GROUP BY 1), ov AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu kod, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu), n AS (SELECT COALESCE(c.sinif,'SINIFSIZ') sinif, o.ad, GREATEST(o.vg+COALESCE(cb.borc,0),0) net FROM ov o LEFT JOIN cls c ON c.kod=o.kod LEFT JOIN cb ON cb.musteri_kodu=o.kod WHERE o.musteri_mi AND o.grup NOT ILIKE '%TEDAR%') SELECT DISTINCT ON (sinif) sinif, ad, round((net/1e6)::numeric,1)::float8 net FROM n WHERE net>0 ORDER BY sinif, net DESC";
      const _tr = (await query(_topSql, [String(T)])).rows;
      const _topOf = (sf) => { const r = _tr.find((x) => x.sinif === sf); return r ? { ad: r.ad, overdue: r.net } : null; };
      const dso = { tuketici: Object.assign(_dget("TUK"), { top: _topOf("TUK") }), ticari: Object.assign(_dget("TIC"), { top: _topOf("TIC") }), sinifsiz: Object.assign(_dget("SINIFSIZ"), { top: _topOf("SINIFSIZ") }) };
      const _key = String(T) + "|" + JSON.stringify([dso.tuketici, dso.ticari, dso.sinifsiz]);
      const _c = (globalThis.__dsoIc = globalThis.__dsoIc || new Map());
      let anlati = _c.get(_key) || null;
      if (!anlati && typeof anthropic !== "undefined" && anthropic) {
        try {
          const SYS = "Sen KRB adli lastik toptancisinin finans analistisin. Isletme sahibine tahsilat/DSO durumunu anlatiyorsun.\nSana JSON verilecek: her is kolu (tuketici=binek/PSR, ticari=TBR/OTR/filo, sinifsiz=lastik-disi/dormant) icin: odeme=OLCULEN ortalama odeme suresi (gun), dso=bakiye/gunluk-satis (gun), bakiye ve gecikmis (milyon TL), gec=gec odeme orani (%), top=o isi en cok siseren hesap {ad, overdue milyon TL}.\nGorevin: bunun NE DEMEK oldugunu isletme sahibine 3-5 cumlelik TEK paragrafta sade Turkce anlatmak. Sayi degil ANLAM once.\nKATI KURALLAR:\n- SADECE JSON'daki sayilari kullan. ASLA yeni sayi/oran/tarih UYDURMA. Olmayan hesap adi yazma.\n- Odeme suresi DUSUK ama DSO YUKSEK ise TESHIS koy: 'hizli oduyorlar ama birkac eski hesap bakiyeyi sisiriyor' + top.ad'i ver.\n- Iki is kolunu KIYASLA (hangisi daha temiz/riskli). Sinifsiz'i kisaca degin (dormant/lastik-disi).\n- AKSIYON one cikar: sistemik mi (vade sikma) yoksa isimli hesap mi (su hesabi kapat).\n- Madde/baslik YOK; duz paragraf, isletme sahibi diliyle. Sayilari Turkce yaz (gun, M TL, %).";
          const msg = await anthropic.messages.create({ model: "claude-sonnet-4-6", max_tokens: 420, messages: [{ role: "user", content: SYS + "\n\nJSON:\n" + JSON.stringify(dso) + "\n\nSadece anlati paragrafini yaz." }] });
          anlati = ((msg.content && msg.content[0] && msg.content[0].text) || "").trim();
          if (anlati) { if (_c.size > 40) _c.clear(); _c.set(_key, anlati); }
        } catch (e) { console.error("[dso-icgoru-ai]", e && e.message); }
      }
      sendJson(response, 200, { dso: dso, anlati: anlati });
    } catch (e) { console.error("[dso-icgoru]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }
'''

s = s.replace(ANCHOR, BLOCK + ANCHOR, 1)
open(F, "w", encoding="utf-8").write(s)
print("[ok] DSO_IKI — /api/bi/dso-icgoru (sayilar + AI anlati) eklendi")
