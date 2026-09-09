#!/usr/bin/env python3
# SMARTKIYAS_V1 — Musteri vs KRB ortalamasi kiyaslama motoru.
#   GET /api/bi/musteri-kiyas?musteri=  -> tek musteri: tahsilat/marj/gecikme/buyume vs KRB ort + verdict
#   GET /api/bi/iyilestirme-hedefleri   -> KRB'yi en cok dusuren musteriler (marj-drag ₺ × hacim sirali)
# Ortak metrik CTE (12 ay lastik). Maliyet: bi_satis_faturalari × bi_marj_atom (kalem_kodu+ay) birim_maliyet.
# Yetki: intelligence VEYA saha manager/admin. Idempotent. node --check.
def read(p): return open(p, encoding="utf-8").read()
def write(p, s): open(p, "w", encoding="utf-8").write(s)

FP = "server_container.mjs"
s = read(FP)
if "SMARTKIYAS_V1" in s:
    print("smartkiyas: already present, skip"); print("DONE."); raise SystemExit

ANCHOR = (
    '  if (request.method === "GET" && url.pathname === "/api/bi/kokpit") {\n'
    '    try {\n'
    '      const _h = await readFile("/app/shells/kokpit.html", "utf8");'
)
assert s.count(ANCHOR) == 1, "kokpit anchor"

# Ortak CTE + metrik SELECT'i (final WHERE/ORDER cagiran ekler). $1=tenant.
CTE = r'''`WITH cust AS (
        SELECT f.musteri_kodu, max(f.musteri_adi) musteri_adi,
          SUM(f.satir_tutar) ciro, SUM(f.miktar) adet,
          SUM(f.miktar*(f.vade_tarihi-f.fatura_tarihi)::numeric)/NULLIF(SUM(f.miktar),0) vade,
          SUM(f.miktar*a.birim_maliyet) maliyet,
          SUM(f.satir_tutar) FILTER (WHERE f.fatura_tarihi >= CURRENT_DATE - INTERVAL '3 months') son3,
          SUM(f.satir_tutar) FILTER (WHERE f.fatura_tarihi >= CURRENT_DATE - INTERVAL '6 months' AND f.fatura_tarihi < CURRENT_DATE - INTERVAL '3 months') onceki3
        FROM bi_satis_faturalari f
        LEFT JOIN bi_marj_atom a ON a.tenant_id::text=f.tenant_id::text AND a.kalem_kodu=f.kalem_kodu AND a.ay=date_trunc('month',f.fatura_tarihi)::date
        WHERE f.tenant_id::text=$1 AND f.grup_adi LIKE 'LASTIK%' AND f.miktar>0
          AND f.fatura_tarihi>=CURRENT_DATE-INTERVAL '12 months'
        GROUP BY f.musteri_kodu),
      risk AS (
        SELECT DISTINCT ON (muhatap_kodu) muhatap_kodu, COALESCE(vadesi_gecmis,0) overdue, COALESCE(hesap_bakiyesi,0) bakiye
        FROM bi_musteri_risk WHERE tenant_id::text=$1 AND musteri_mi ORDER BY muhatap_kodu, export_date DESC),
      kb AS (SELECT SUM(vade*adet)/NULLIF(SUM(adet),0) krb_vade,
        (SUM(ciro)-SUM(maliyet))/NULLIF(SUM(ciro),0)*100 krb_marj FROM cust),
      kro AS (SELECT SUM(overdue)/NULLIF(SUM(bakiye),0) krb_od FROM risk)
      SELECT c.musteri_kodu, c.musteri_adi, round(c.ciro)::float8 ciro,
        round(c.vade)::float8 vade, round(kb.krb_vade)::float8 krb_vade,
        round((c.ciro-c.maliyet)/NULLIF(c.ciro,0)*100,1)::float8 marj, round(kb.krb_marj,1)::float8 krb_marj,
        round(COALESCE(r.overdue,0))::float8 overdue,
        round(CASE WHEN COALESCE(r.bakiye,0)>0 THEN r.overdue/r.bakiye*100 ELSE 0 END,1)::float8 od_pct,
        round(kro.krb_od*100,1)::float8 krb_od_pct,
        round((c.son3-c.onceki3)/NULLIF(c.onceki3,0)*100)::float8 buyume,
        round(GREATEST(0, kb.krb_marj/100.0 - (c.ciro-c.maliyet)/NULLIF(c.ciro,0)) * c.ciro)::float8 marj_drag
      FROM cust c LEFT JOIN risk r ON r.muhatap_kodu=c.musteri_kodu CROSS JOIN kb CROSS JOIN kro`'''

BLK = '''    // ===== SMARTKIYAS_V1 — Musteri vs KRB kiyas =====
    if (request.method === "GET" && url.pathname === "/api/bi/musteri-kiyas") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const musteri = (url.searchParams.get("musteri") || "").trim();
      if (!musteri) { sendJson(response, 400, { error: "musteri zorunlu" }); return; }
      try {
        const x = (await query(''' + CTE + ''' + ` WHERE c.musteri_kodu=$2`, [T, musteri])).rows[0];
        if (!x) { sendJson(response, 200, { musteri, yok: true }); return; }
        const n = v => v == null ? null : Number(v);
        const vade = n(x.vade), krbVade = n(x.krb_vade), marj = n(x.marj), krbMarj = n(x.krb_marj);
        const overdue = n(x.overdue), odPct = n(x.od_pct), krbOd = n(x.krb_od_pct), buyume = n(x.buyume);
        const M = [];
        // tahsilat (vade dusuk=iyi)
        { const kotu = vade != null && krbVade != null && vade > krbVade * 1.15;
          M.push({ anahtar: "tahsilat", ad: "Tahsilat", deger: vade != null ? vade + " gün" : "—", krb: krbVade != null ? krbVade + " gün" : "—",
            durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Vadeyi kısalt / peşin teşvik et" : null }); }
        // marj (yuksek=iyi)
        { const kotu = marj != null && krbMarj != null && marj < krbMarj - 3;
          M.push({ anahtar: "marj", ad: "Marj", deger: marj != null ? "%" + marj : "—", krb: krbMarj != null ? "%" + krbMarj : "—",
            durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Fiyatı yükselt (Akıllı Fiyat önerisine bak)" : null }); }
        // gecikme (dusuk=iyi)
        { const kotu = odPct != null && krbOd != null && odPct > krbOd * 1.2 && overdue > 50000;
          M.push({ anahtar: "gecikme", ad: "Gecikme", deger: overdue != null ? Math.round(overdue).toLocaleString("tr-TR") + " ₺ (%" + odPct + ")" : "—",
            krb: krbOd != null ? "%" + krbOd + " ort" : "—", durum: kotu ? "kotu" : "iyi", aksiyon: kotu ? "Tahsilat planı / kredi limitini gözden geçir" : null }); }
        // buyume (>0=iyi)
        { const kotu = buyume != null && buyume < -5;
          M.push({ anahtar: "buyume", ad: "Büyüme", deger: buyume != null ? "%" + buyume : "—", krb: "0 (düz)",
            durum: kotu ? "kotu" : (buyume != null && buyume > 5 ? "iyi" : "notr"), aksiyon: kotu ? "Kampanya / ziyaret sıklığını artır" : null }); }
        const drag = M.filter(x2 => x2.durum === "kotu").length;
        const headline = drag === 0 ? "KRB ortalamasının üzerinde ✓" : ("KRB ortalamasını " + drag + " metrikte düşürüyor");
        sendJson(response, 200, { musteri, musteri_adi: x.musteri_adi, ciro: n(x.ciro), drag_sayisi: drag, headline, metrikler: M });
      } catch (e) { console.error("[musteri-kiyas]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }

    if (request.method === "GET" && url.pathname === "/api/bi/iyilestirme-hedefleri") {
      let _s = await requireModuleAccess(request, "intelligence").catch(() => null);
      let _ss = _s ? null : await requireSahaAccess(request).catch(() => null);
      const _sess = _s || _ss;
      if (!_sess) { sendJson(response, 403, { error: "yetki yok" }); return; }
      if (!_s && !(_ss && ["manager", "admin"].includes(_ss.sahaRole))) { sendJson(response, 403, { error: "yetki yok" }); return; }
      const T = _sess.tenantId;
      const minCiro = Math.max(0, parseInt(url.searchParams.get("min_ciro") || "200000", 10));
      try {
        const rows = (await query(''' + CTE + ''' + ` WHERE c.ciro > $2 ORDER BY marj_drag DESC NULLS LAST LIMIT 60`, [T, minCiro])).rows;
        const n = v => v == null ? null : Number(v);
        const out = rows.map(x => {
          const marj = n(x.marj), krbMarj = n(x.krb_marj), vade = n(x.vade), krbVade = n(x.krb_vade);
          const odPct = n(x.od_pct), krbOd = n(x.krb_od_pct), buyume = n(x.buyume), overdue = n(x.overdue);
          const bayrak = [];
          if (marj != null && krbMarj != null && marj < krbMarj - 3) bayrak.push("marj");
          if (vade != null && krbVade != null && vade > krbVade * 1.15) bayrak.push("tahsilat");
          if (odPct != null && krbOd != null && odPct > krbOd * 1.2 && overdue > 50000) bayrak.push("gecikme");
          if (buyume != null && buyume < -5) bayrak.push("buyume");
          return { musteri_adi: x.musteri_adi, ciro: n(x.ciro), marj, krb_marj: krbMarj, vade, krb_vade: krbVade,
            overdue, od_pct: odPct, krb_od_pct: krbOd, buyume, marj_drag: n(x.marj_drag), bayraklar: bayrak };
        }).filter(r => r.bayraklar.length > 0);
        const toplamDrag = out.reduce((a, r) => a + (r.marj_drag || 0), 0);
        sendJson(response, 200, { toplam_marj_drag: Math.round(toplamDrag), musteri_sayisi: out.length, hedefler: out.slice(0, 40) });
      } catch (e) { console.error("[iyilestirme-hedefleri]", e && e.message); sendJson(response, 500, { error: String(e && e.message) }); }
      return;
    }

'''

s = s.replace(ANCHOR, BLK + ANCHOR, 1)
write(FP, s)
print("smartkiyas: /api/bi/musteri-kiyas + /api/bi/iyilestirme-hedefleri eklendi")
print("marker count:", s.count("SMARTKIYAS_V1"))
print("DONE.")
