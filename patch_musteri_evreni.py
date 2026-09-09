#!/usr/bin/env python3
# MUSTERI_EVRENI_V1 — additive + 1 kucuk duzeltme.
#  (1) Yeni READ-ONLY uc: GET /api/bi/musteri-evreni?ay=N (veya ?ytd=1)
#      -> {bar:{tuk,tic}, nakit:{tuketici,ticari,sinifsiz,toplam}, musteriler:[...], kim_tasiyor:{...}}
#      musteri sinifi = 12ay alis karmasinda PSR>=yari ? TUK : TIC (verify_umbrella C2/D ile ayni).
#  (2) DUZELTME: kokpit-umbrella toplam.marj'i HAM sum(brut_kar)/sum(ciro)'dan hesapla (10.4->10.5).
# Idempotent (MUSTERI_EVRENI_V1 varsa cikar). Mevcut mantik degismez; sadece 1 satir marj-duzeltme + yeni route.
import sys
F = sys.argv[1] if len(sys.argv) > 1 else "server_container.mjs"
s = open(F, encoding="utf-8").read()
if "MUSTERI_EVRENI_V1" in s:
    print("[skip] MUSTERI_EVRENI_V1 zaten var — degisiklik yok")
    sys.exit(0)

# (2) toplam.marj HAM hesap duzeltmesi (kokpit-umbrella blogundaki tek satir)
OLD = '      const wmarj = cc ? +(((tk.c * (tk.mj || 0)) + (tc.c * (tc.mj || 0))) / cc).toFixed(1) : null;'
NEW = '      const _gm = (await query("SELECT round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + winSql + "", params)).rows[0]; const wmarj = _gm ? _gm.mj : null; /* MARJ_RAW_FIX */'
if OLD in s:
    s = s.replace(OLD, NEW, 1)
    print("[ok] toplam.marj HAM hesaba cevrildi")
else:
    print("[uyari] wmarj satiri bulunamadi (kokpit-umbrella once deploy edilmemis olabilir) — sadece yeni uc eklenecek")

anchor = 'if (request.method === "GET" && url.pathname === "/api/bi/kokpit-data") {'
i = s.find(anchor)
assert i != -1, "HATA: kokpit-data anchor bulunamadi — iptal."
ls = s.rfind("\n", 0, i) + 1

BLOCK = r'''  // === MUSTERI_EVRENI_V1 — musteri kadrani (ciro×marj×overdue+sinif) + nakit split + adil barlar ===
  if (request.method === "GET" && url.pathname === "/api/bi/musteri-evreni") {
    try {
      let session = await requireModuleAccess(request, "intelligence").catch(() => null);
      if (!session) { const _ss = await requireSahaAccess(request).catch(() => null); if (_ss && ["manager", "admin"].includes(_ss.sahaRole)) session = _ss; }
      if (!session) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = session && session.tenantId;
      if (!T) { sendJson(response, 401, { error: "oturum yok" }); return; }
      const ytd = url.searchParams.get("ytd") === "1";
      let ayN = parseInt(url.searchParams.get("ay") || "12", 10); if (!(ayN >= 1 && ayN <= 24)) ayN = 12;
      const aWin = ytd ? "ay >= date_trunc('year', CURRENT_DATE)" : "ay >= (CURRENT_DATE - ($2 * INTERVAL '1 month'))";
      const fWin = ytd ? "f.fatura_tarihi >= date_trunc('year', CURRENT_DATE)" : "f.fatura_tarihi >= (CURRENT_DATE - ($2 * INTERVAL '1 month'))";
      const params = ytd ? [String(T)] : [String(T), ayN];
      // adil barlar = urun-split umbrella marj (KPI ile birebir)
      const barRows = (await query("SELECT CASE WHEN kategori_segment(kategori)='PSR' THEN 'TUK' ELSE 'TIC' END umb, round((sum(brut_kar)/nullif(sum(ciro),0)*100)::numeric,1)::float8 mj FROM bi_marj_atom WHERE tenant_id::text=$1 AND " + aWin + " GROUP BY 1", params)).rows;
      const _bt = (u) => { const r = barRows.find((x) => x.umb === u); return r ? r.mj : null; };
      const bar = { tuk: _bt("TUK"), tic: _bt("TIC") };
      // musteri agregasyonu (donem): ciro, kar, psr_ciro -> sinif + marj
      const cust = (await query("SELECT f.musteri_kodu kod, sum(f.satir_tutar)::float8 ciro, (sum(f.satir_tutar)-sum(f.miktar*a.birim_maliyet))::float8 kar, COALESCE(sum(f.satir_tutar) FILTER (WHERE kategori_segment(a.kategori)='PSR'),0)::float8 psr FROM bi_satis_faturalari f JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date WHERE f.tenant_id::text=$1 AND " + fWin + " AND f.miktar>0 GROUP BY 1", params)).rows;
      // overdue (bugun, net) + isim — tum musteriler (donemden bagimsiz)
      const ov = (await query("WITH r AS (SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(NULLIF(TRIM(muhatap_adi),''),muhatap_kodu) ad, GREATEST(vadesi_gecmis,0) vg, musteri_mi, GREATEST(hesap_bakiyesi,0) bak, COALESCE(NULLIF(TRIM(grup),''),'') grup FROM bi_musteri_risk WHERE tenant_id::text=$1 ORDER BY muhatap_kodu, export_date DESC), cb AS (SELECT musteri_kodu, MIN(LEAST(tedarikci_bakiye,0)) borc FROM bi_cari_bakiye WHERE tenant_id::text=$1 GROUP BY musteri_kodu) SELECT r.muhatap_kodu kod, r.ad, GREATEST(r.vg+COALESCE(cb.borc,0),0)::float8 net FROM r LEFT JOIN cb ON cb.musteri_kodu=r.muhatap_kodu WHERE r.musteri_mi AND r.grup NOT ILIKE '%TEDAR%'", [String(T)])).rows;
      const ovMap = {}; for (const o of ov) ovMap[o.kod] = o;
      const sinifOf = {};
      const musteriler = cust.map((c) => {
        const sinif = (c.psr || 0) >= (c.ciro || 0) / 2 ? "TUK" : "TIC";
        sinifOf[c.kod] = sinif;
        const o = ovMap[c.kod];
        return { ad: o ? o.ad : c.kod, ciro: +((c.ciro || 0) / 1e6).toFixed(2), marj: c.ciro ? +(c.kar / c.ciro * 100).toFixed(1) : null, overdue: +(((o && o.net) || 0) / 1e6).toFixed(2), sinif: sinif };
      }).filter((m) => m.ciro > 0).sort((a, b) => b.ciro - a.ciro).slice(0, 200);
      // nakit split (verify blok D): overdue'yu sinifa yaz; cust'ta yoksa SINIFSIZ
      const nakit = { tuketici: 0, ticari: 0, sinifsiz: 0, toplam: 0 };
      for (const o of ov) { const n = o.net || 0; if (n <= 0) continue; nakit.toplam += n; const sf = sinifOf[o.kod]; if (sf === "TUK") nakit.tuketici += n; else if (sf === "TIC") nakit.ticari += n; else nakit.sinifsiz += n; }
      for (const k of Object.keys(nakit)) nakit[k] = +(nakit[k] / 1e6).toFixed(1);
      // kim tasiyor: sinif basina en buyuk 6 gecikmis
      const ws = ov.filter((o) => o.net > 0).map((o) => ({ ad: o.ad, overdue: +(o.net / 1e6).toFixed(2), sinif: sinifOf[o.kod] || "SINIFSIZ" }));
      const kim = { tuketici: ws.filter((x) => x.sinif === "TUK").sort((a, b) => b.overdue - a.overdue).slice(0, 6), ticari: ws.filter((x) => x.sinif === "TIC").sort((a, b) => b.overdue - a.overdue).slice(0, 6) };
      sendJson(response, 200, { ay: ytd ? "ytd" : ayN, bar: bar, nakit: nakit, musteriler: musteriler, kim_tasiyor: kim });
    } catch (e) { console.error("[musteri-evreni]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
    return;
  }

'''

s = s[:ls] + BLOCK + s[ls:]
open(F, "w", encoding="utf-8").write(s)
print("[ok] MUSTERI_EVRENI_V1 eklendi @ offset", ls)
